// Criação de bloqueio de um espaço por um período (spec bloqueios; C11, design D5), pelo coordenador
// da unidade do espaço ou pelo admin. Recusada, sem gravar nada, em espaço desativado, com fim no
// passado ou com reserva confirmada em andamento sobreposta ao período. Na mesma transação, cancela
// as reservas sobrepostas que ainda não começaram (BLOQUEIO, com o bloqueio_id, sem falta), encerra
// as entradas de fila sobrepostas e passa à fila os trechos liberados fora do período.
// aplicar_vencimentos antes da transação (decisão 19): a pendente já iniciada fica EXPIRADA.
// Cria um bloqueio, dentro da trava de governança
query criar_bloqueio verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
    text? tipo? filters=trim
    text? motivo? filters=trim
    text? data_inicio? filters=trim
    text? hora_inicio? filters=trim
    text? data_fim? filters=trim
    text? hora_fim? filters=trim
  }

  stack {
    var $tipo {
      value = $input.tipo|first_notnull:""
    }

    precondition ($tipo == "MANUTENCAO" || $tipo == "EVENTO" || $tipo == "FERIADO") {
      error_type = "inputerror"
      error = "Escolha o tipo do bloqueio: manutenção, evento ou feriado."
    }

    var $motivo {
      value = $input.motivo|first_notnull:""
    }

    precondition (($motivo|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o motivo do bloqueio."
    }

    precondition (($motivo|strlen) <= 500) {
      error_type = "inputerror"
      error = "O motivo deve ter no máximo 500 caracteres."
    }

    function.run converter_periodo_bloqueio {
      input = {
        data_inicio: $input.data_inicio
        hora_inicio: $input.hora_inicio
        data_fim   : $input.data_fim
        hora_fim   : $input.hora_fim
      }
    } as $periodo

    function.run aplicar_vencimentos as $vencimentos

    // Declaradas fora da transação, como $texto_cancelamento em desativar_espaco
    var $canceladas {
      value = 0
    }

    var $encerradas {
      value = 0
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $carregado

        precondition ($carregado.espaco.ativo) {
          error_type = "inputerror"
          error = "O espaço está desativado e não pode ser bloqueado."
        }

        var $agora {
          value = now
        }

        precondition ($periodo.fim > $agora) {
          error_type = "inputerror"
          error = "O fim do bloqueio deve estar no futuro."
        }

        function.run exigir_sem_reserva_em_andamento {
          input = {
            espacos_ids: [$carregado.espaco.id]
            agora      : $agora
            inicio     : $periodo.inicio
            fim        : $periodo.fim
          }
        } as $sem_reserva_em_uso

        db.add bloqueio {
          data = {
            espaco_id    : $carregado.espaco.id
            criado_por_id: $carregado.ator.id
            inicio       : $periodo.inicio
            fim          : $periodo.fim
            tipo         : $tipo
            motivo       : $motivo
            status       : "ATIVO"
          }
        } as $bloqueio

        var $dados_depois {
          value = {}
            |set:"espaco_id":$carregado.espaco.id
            |set:"tipo":$tipo
            |set:"motivo":$motivo
            |set:"inicio":$periodo.inicio
            |set:"fim":$periodo.fim
            |set:"status":"ATIVO"
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "CRIAR_BLOQUEIO"
            entidade    : "bloqueio"
            entidade_id : $bloqueio.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : null
            dados_depois: $dados_depois
          }
        } as $registro_auditoria

        function.run cancelar_reservas {
          input = {
            modo       : "bloqueio"
            espacos_ids: [$carregado.espaco.id]
            bloqueio_id: $bloqueio.id
            inicio     : $periodo.inicio
            fim        : $periodo.fim
            motivo     : "BLOQUEIO"
            ator_id    : $carregado.ator.id
            agora      : $agora
          }
        } as $cancelamento

        var.update $canceladas {
          value = $cancelamento.quantidade
        }

        var.update $encerradas {
          value = $cancelamento.entradas_encerradas
        }
      }
    }

    var $mensagem {
      value = "Espaço bloqueado. Reservas canceladas: " ~ $canceladas ~ ". Entradas de fila encerradas: " ~ $encerradas ~ "."
    }
  }

  response = {
    mensagem             : $mensagem
    reservas_canceladas  : $canceladas
    entradas_encerradas  : $encerradas
  }
  guid = "eY5DExSlQnRIbYmZyPo_YPlVD4c"
}
