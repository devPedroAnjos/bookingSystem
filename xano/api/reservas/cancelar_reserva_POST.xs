// Cancelamento pelo próprio usuário (spec reservas; design D6), sem falta. Reserva de outra pessoa
// ou inexistente tem a mesma recusa. Aceito só se inicio >= agora + prazo, comparando em ms:
// exatamente no limite é aceito ("até 2 horas antes", §7.8). O cancelamento tardio é da C9.
// O prazo é lido direto de configuracao_geral (D12), com a precondição do bootstrap.
// Cancela uma reserva própria dentro do prazo, dentro da trava de governança
query cancelar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int reserva_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run usuario_ativo {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        db.get reserva {
          field_name = "id"
          field_value = $input.reserva_id
        } as $reserva
      
        var $propria {
          value = false
        }
      
        conditional {
          if ($reserva != null) {
            conditional {
              if ($reserva.usuario_id == $ator.id) {
                var.update $propria {
                  value = true
                }
              }
            }
          }
        }
      
        precondition ($propria) {
          error_type = "inputerror"
          error = "Reserva não encontrada."
        }
      
        precondition ($reserva.status == "PENDENTE" || $reserva.status == "CONFIRMADA") {
          error_type = "inputerror"
          error = "Esta reserva não está ativa."
        }
      
        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao
      
        precondition ($configuracao != null && !($configuracao.prazo_cancelamento_minutos|is_null)) {
          error = "Configuração de reservas incompleta: execute o bootstrap."
        }
      
        var $prazo {
          value = $configuracao.prazo_cancelamento_minutos
        }
      
        var $agora {
          value = now
        }
      
        precondition ($reserva.inicio >= $agora + ($prazo * 60000)) {
          error_type = "inputerror"
          error = "O cancelamento sem penalidade é permitido até " ~ $prazo ~ " minutos antes do início."
        }
      
        db.edit reserva {
          field_name = "id"
          field_value = $reserva.id
          data = {
            status             : "CANCELADA"
            motivo_cancelamento: "USUARIO"
            cancelado_por_id   : $ator.id
            cancelado_em       : now
          }
        } as $cancelada
      
        db.get espaco {
          field_name = "id"
          field_value = $reserva.espaco_id
        } as $espaco
      
        var $dados_antes {
          value = {}|set:"status":$reserva.status
        }
      
        var $dados_depois {
          value = {}
            |set:"status":$cancelada.status
            |set:"motivo_cancelamento":$cancelada.motivo_cancelamento
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CANCELAR_RESERVA"
            entidade    : "reserva"
            entidade_id : $reserva.id
            unidade_id  : $espaco.unidade_id
            dados_antes : $dados_antes
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Reserva cancelada."}
  guid = "rhyhnAEhlvhI1ZBWRDYwtfnYp6A"
}