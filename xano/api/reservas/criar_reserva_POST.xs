// Reserva avulsa para o próprio usuário (spec reservas; design D4). Formato e conversão do
// horário fora da trava; dentro dela, na ordem: conta ativa, releitura do espaço, da unidade, do
// tipo e das regras, espaço reservável, regra do papel, regras de horário, limite de reservas
// ativas no tipo e conflito. Todas as recusas são 400 com uma mensagem só. Nasce PENDENTE quando
// o tipo exige aprovação para o papel, senão CONFIRMADA. Nunca reserva em nome de outra pessoa.
// C7: depois da conversão do horário e antes da transação, aplicar_vencimentos grava as pendentes
// vencidas (design D3); o limite e o conflito usam o predicado de ocupação da situação efetiva
// (D2), que ignora a pendente cujo início já chegou mesmo antes de ela ser gravada.
// Cria uma reserva, dentro da trava de governança
query criar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int espaco_id
    text? data? filters=trim
    text? hora_inicio? filters=trim
    text? hora_fim? filters=trim
  }

  stack {
    function.run converter_horario_pedido {
      input = {
        data       : $input.data
        hora_inicio: $input.hora_inicio
        hora_fim   : $input.hora_fim
      }
    } as $horario
  
    var $inicio {
      value = $horario.inicio
    }
  
    var $fim {
      value = $horario.fim
    }

    // Faxina de vencimentos em transação própria (C7, design D3)
    function.run aplicar_vencimentos as $vencimentos

    // Rótulos dos motivos de validar_horario_reserva (os mesmos da tela de busca). Cadeia de |set
    // em vez de objeto literal: o Xano tira as vírgulas dos literais e eles podem perder chaves
    var $rotulos_horario {
      value = {}
        |set:"TIPO_SEM_REGRAS":"tipo sem regras"
        |set:"FIM_NAO_DEPOIS_DO_INICIO":"o fim deve ser depois do início"
        |set:"DIAS_DIFERENTES":"início e fim em dias diferentes"
        |set:"DIA_SEM_FUNCIONAMENTO":"dia sem funcionamento"
        |set:"FORA_DA_GRANULARIDADE":"horário fora da granularidade"
        |set:"ANTES_DA_ABERTURA":"início antes da abertura"
        |set:"DEPOIS_DO_FECHAMENTO":"fim depois do fechamento"
        |set:"DURACAO_ABAIXO_DA_MINIMA":"duração abaixo da mínima"
        |set:"DURACAO_ACIMA_DA_MAXIMA":"duração acima da máxima"
        |set:"ANTECEDENCIA_MINIMA":"antecedência menor que a mínima"
        |set:"ANTECEDENCIA_MAXIMA":"antecedência maior que a máxima"
    }
  
    // Declaradas fora da transação, como $unidade_criada_id em unidades/criar
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
      
        // 2. Releitura dentro da trava (corrida com desativação, C4 D13)
        db.get espaco {
          field_name = "id"
          field_value = $input.espaco_id
        } as $espaco
      
        // Espaço inexistente tem a mesma recusa de espaço não reservável
        precondition ($espaco != null) {
          error_type = "inputerror"
          error = "Este espaço não está disponível para reserva."
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $espaco.unidade_id
        } as $unidade
      
        db.get tipo_espaco {
          field_name = "id"
          field_value = $espaco.tipo_espaco_id
        } as $tipo
      
        db.query regra_papel {
          where = $db.regra_papel.tipo_espaco_id == $espaco.tipo_espaco_id
          return = {type: "list"}
        } as $regras_do_tipo
      
        function.run obter_configuracao_horario as $configuracao
        function.run tipo_com_regras {
          input = {tipo: $tipo, regras_do_tipo: $regras_do_tipo}
        } as $com_regras
      
        // 3. Espaço reservável
        function.run disponibilidade_espaco {
          input = {
            espaco_ativo   : $espaco.ativo
            unidade_ativa  : $unidade.ativa
            tipo_ativo     : $tipo.ativo
            tipo_com_regras: $com_regras
          }
        } as $disponibilidade
      
        precondition ($disponibilidade.reservavel) {
          error_type = "inputerror"
          error = "Este espaço não está disponível para reserva."
        }
      
        // 4. Regra do papel
        function.run regra_do_papel {
          input = {papel: $ator.papel, regras_do_tipo: $regras_do_tipo}
        } as $regra
      
        precondition ($regra.pode_reservar) {
          error_type = "inputerror"
          error = "Seu papel não pode reservar este tipo de espaço."
        }
      
        // 5. Regras de horário, com o agora lido dentro da trava
        var $agora {
          value = now
        }
      
        function.run validar_horario_reserva {
          input = {
            tipo            : $tipo
            regras_completas: $com_regras
            configuracao    : $configuracao
            inicio          : $inicio
            fim             : $fim
            agora           : $agora
          }
        } as $validacao
      
        var $motivos_horario {
          value = $validacao.motivos|map:($rotulos_horario|get:$$)|join:"; "
        }
      
        precondition ($validacao.dentro_das_regras) {
          error_type = "inputerror"
          error = "Horário fora das regras do tipo: " ~ $motivos_horario ~ "."
        }
      
        // 6. (Ponto de extensão C9: recusar quem tem penalidade ativa.)
      
        // 7. Limite de reservas ativas no tipo atual do espaço (D5); fim > agora porque, até a C9,
        // reservas passadas continuam CONFIRMADA. Ocupação pela situação efetiva (C7, D2): a
        // pendente cujo início já chegou expirou e não conta.
        db.query espaco {
          where = $db.espaco.tipo_espaco_id == $espaco.tipo_espaco_id
          return = {type: "list"}
        } as $espacos_do_tipo

        var $ids_do_tipo {
          value = $espacos_do_tipo|map:$$.id
        }

        db.query reserva {
          where = $db.reserva.usuario_id == $ator.id && $db.reserva.espaco_id in $ids_do_tipo && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.fim > $agora
          return = {type: "count"}
        } as $ativas_no_tipo
      
        precondition ($ativas_no_tipo < $tipo.max_reservas_ativas_usuario) {
          error_type = "inputerror"
          error = "Você já tem o máximo de " ~ $tipo.max_reservas_ativas_usuario ~ " reservas ativas neste tipo de espaço."
        }
      
        // 8. (Ponto de extensão C10: recusar horário com bloqueio ativo sobreposto.)
      
        // 9. Conflito (D7): ocupação sobreposta no mesmo espaço; encostadas não conflitam. Ocupam
        // a confirmada e a pendente que ainda não começou (C7, D2).
        // (Ponto de extensão C8: vaga retida pela fila e deslocamento por prioridade.)
        db.query reserva {
          where = $db.reserva.espaco_id == $espaco.id && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
          return = {type: "exists"}
        } as $conflito
      
        precondition (!$conflito) {
          error_type = "inputerror"
          error = "Horário ocupado: já existe uma reserva neste espaço nesse intervalo."
        }
      
        // 10. Gravação
        var $status {
          value = "CONFIRMADA"
        }
      
        conditional {
          if ($regra.exige_aprovacao) {
            var.update $status {
              value = "PENDENTE"
            }
          }
        }
      
        var $nivel {
          value = 3
        }
      
        conditional {
          if ($ator.papel == "ALUNO") {
            var.update $nivel {
              value = 1
            }
          }
        
          elseif ($ator.papel == "PROFESSOR") {
            var.update $nivel {
              value = 2
            }
          }
        }
      
        db.add reserva {
          data = {
            usuario_id      : $ator.id
            espaco_id       : $espaco.id
            inicio          : $inicio
            fim             : $fim
            status          : $status
            nivel_prioridade: $nivel
            origem          : "DIRETA"
            criado_em       : now
          }
        } as $reserva
      
        var.update $reserva_id {
          value = $reserva.id
        }
      
        var.update $status_gravado {
          value = $reserva.status
        }
      
        // 11. Auditoria
        var $dados_depois {
          value = {}
            |set:"espaco_id":$reserva.espaco_id
            |set:"inicio":$reserva.inicio
            |set:"fim":$reserva.fim
            |set:"status":$reserva.status
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_RESERVA"
            entidade    : "reserva"
            entidade_id : $reserva.id
            unidade_id  : $espaco.unidade_id
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
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
  guid = "trGOImG6DvIWTIVuno09wfEE6w4"
}