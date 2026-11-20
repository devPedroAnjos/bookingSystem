// Confirmação da vaga retida pela fila (spec fila-espera; design D6). Faxina fora da trava; dentro
// dela, na ordem: conta ativa, entrada própria (a de outra pessoa tem a mesma recusa de
// inexistente), situação e prazo (aceita até o prazo, inclusive), validações da criação
// (validar_pedido_reserva e exigir_limite_ativas) e conferência defensiva da ocupação. Cria a
// reserva com origem FILA: PENDENTE se o tipo exige aprovação para o papel, senão CONFIRMADA.
// A entrada fica ATENDIDA com a reserva gerada. Recusas são 400 e não mudam nada.
// Confirma a vaga retida e cria a reserva, dentro da trava de governança
query confirmar_fila verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int entrada_id
  }

  stack {
    // Faxina de vencimentos e da fila em transação própria (C7, D3; C9, D5)
    function.run aplicar_vencimentos as $vencimentos
  
    var $reserva_id {
      value = null
    }
  
    var $status_gravado {
      value = null
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
      
        // 1. Conta ativa e papel atual
        function.run usuario_ativo {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        // 2. Entrada própria
        db.get entrada_fila {
          field_name = "id"
          field_value = $input.entrada_id
        } as $entrada
      
        var $propria {
          value = false
        }
      
        conditional {
          if ($entrada != null) {
            conditional {
              if ($entrada.usuario_id == $ator.id) {
                var.update $propria {
                  value = true
                }
              }
            }
          }
        }
      
        precondition ($propria) {
          error_type = "inputerror"
          error = "Entrada não encontrada."
        }
      
        // 3. Situação e prazo. A faxina pode ter acabado de gravar a expiração
        var $agora {
          value = now
        }
      
        precondition ($entrada.status != "AGUARDANDO") {
          error_type = "inputerror"
          error = "Ainda não há vaga para confirmar."
        }
      
        precondition ($entrada.status == "NOTIFICADA" || $entrada.status == "EXPIRADA") {
          error_type = "inputerror"
          error = "Esta entrada não está mais ativa."
        }
      
        precondition ($entrada.status == "NOTIFICADA" && $agora <= $entrada.prazo_confirmacao) {
          error_type = "inputerror"
          error = "O prazo para confirmar terminou."
        }
      
        // 4. Validações da criação (D7), inclusive o limite de ativas
        function.run validar_pedido_reserva {
          input = {
            espaco_id: $entrada.espaco_id
            papel    : $ator.papel
            inicio   : $entrada.inicio
            fim      : $entrada.fim
            agora    : $agora
          }
        } as $pedido
      
        // (Ponto de extensão C10: recusar quem tem penalidade ativa.)
      
        function.run exigir_limite_ativas {
          input = {
            usuario_id                 : $ator.id
            tipo_espaco_id             : $pedido.espaco.tipo_espaco_id
            max_reservas_ativas_usuario: $pedido.tipo.max_reservas_ativas_usuario
            agora                      : $agora
          }
        } as $limite_ok
      
        // 5. Conferência defensiva: pela invariante, nenhuma reserva ocupa a vaga retida
        db.query reserva {
          where = $db.reserva.espaco_id == $entrada.espaco_id && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.inicio < $entrada.fim && $db.reserva.fim > $entrada.inicio
          return = {type: "exists"}
        } as $ocupado
      
        precondition (!$ocupado) {
          error_type = "inputerror"
          error = "Horário ocupado: já existe uma reserva neste espaço nesse intervalo."
        }
      
        // 6. Gravação: reserva com origem FILA e entrada ATENDIDA
        var $status {
          value = "CONFIRMADA"
        }
      
        conditional {
          if ($pedido.regra.exige_aprovacao) {
            var.update $status {
              value = "PENDENTE"
            }
          }
        }
      
        function.run nivel_do_papel {
          input = {papel: $ator.papel}
        } as $nivel
      
        db.add reserva {
          data = {
            usuario_id      : $ator.id
            espaco_id       : $entrada.espaco_id
            inicio          : $entrada.inicio
            fim             : $entrada.fim
            status          : $status
            nivel_prioridade: $nivel
            origem          : "FILA"
            criado_em       : now
          }
        } as $reserva
      
        db.edit entrada_fila {
          field_name = "id"
          field_value = $entrada.id
          data = {status: "ATENDIDA", reserva_gerada_id: $reserva.id}
        } as $atendida
      
        var.update $reserva_id {
          value = $reserva.id
        }
      
        var.update $status_gravado {
          value = $reserva.status
        }
      
        // 7. Auditoria (D8): CRIAR_RESERVA da reserva e CONFIRMAR_FILA da entrada
        var $dados_reserva {
          value = {}
            |set:"espaco_id":$reserva.espaco_id
            |set:"inicio":$reserva.inicio
            |set:"fim":$reserva.fim
            |set:"status":$reserva.status
            |set:"origem":$reserva.origem
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_RESERVA"
            entidade    : "reserva"
            entidade_id : $reserva.id
            unidade_id  : $pedido.espaco.unidade_id
            dados_depois: $dados_reserva
          }
        } as $registro_reserva
      
        var $dados_antes_entrada {
          value = {}|set:"status":$entrada.status
        }
      
        var $dados_depois_entrada {
          value = {}
            |set:"status":$atendida.status
            |set:"reserva_gerada_id":$reserva.id
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CONFIRMAR_FILA"
            entidade    : "entrada_fila"
            entidade_id : $entrada.id
            unidade_id  : $pedido.espaco.unidade_id
            dados_antes : $dados_antes_entrada
            dados_depois: $dados_depois_entrada
          }
        } as $registro_entrada
      }
    }
  
    var $mensagem {
      value = "Reserva confirmada."
    }
  
    conditional {
      if ($status_gravado == "PENDENTE") {
        var.update $mensagem {
          value = "Reserva criada e aguardando aprovação."
        }
      }
    }
  
    var $resposta {
      value = {}
        |set:"mensagem":$mensagem
        |set:"reserva_id":$reserva_id
        |set:"status":$status_gravado
    }
  }

  response = $resposta
  guid = "WIkv_MpzHSdFgYcZA7RGgMf6FdU"
}