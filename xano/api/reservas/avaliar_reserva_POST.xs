// Avaliação de uma reserva própria (spec avaliacoes; change espaco-feed-avaliacoes, design D2).
// Nota inteira de 1 a 5 e comentário opcional (trim, até 500 caracteres; vazio vira ausente),
// validados antes de tudo. A faxina com o usuário roda antes para gravar a conclusão já devida,
// mas a decisão usa a situação efetiva, que vale mesmo se a faxina não gravar nada. Só reserva
// CONCLUIDA, até prazo_avaliacao_dias × 24 h depois do término (limite incluído), pelo valor atual.
// Reserva de outra pessoa ou inexistente tem a mesma recusa. Uma por reserva: a checagem prévia dá a
// mensagem, e o índice único de avaliacao.reserva_id recusa a segunda de duas avaliações simultâneas
// (padrão de cadastro_POST, C2). Sem trava de governança: não há contagem seguida de gravação.
// Avalia uma reserva concluída do próprio usuário
query avaliar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int reserva_id

    // Decimal para recusar 4,5 com a mensagem certa, em vez de truncar
    decimal? nota?

    text? comentario? filters=trim
  }

  stack {
    var $nota_informada {
      value = $input.nota
    }

    precondition (!($nota_informada|is_null)) {
      error_type = "inputerror"
      error = "Informe uma nota de 1 a 5."
    }

    precondition ($nota_informada >= 1 && $nota_informada <= 5 && ($nota_informada|round:0) == $nota_informada) {
      error_type = "inputerror"
      error = "A nota deve ser um número inteiro de 1 a 5."
    }

    var $nota {
      value = $nota_informada|to_int
    }

    var $comentario_texto {
      value = $input.comentario|first_notnull:""
    }

    precondition (($comentario_texto|strlen) <= 500) {
      error_type = "inputerror"
      error = "O comentário deve ter no máximo 500 caracteres."
    }

    var $comentario {
      value = null
    }

    conditional {
      if (($comentario_texto|strlen) > 0) {
        var.update $comentario {
          value = $comentario_texto
        }
      }
    }

    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator

    // Grava a conclusão já devida (a falha da faxina não bloqueia; ver aplicar_vencimentos)
    function.run aplicar_vencimentos {
      input = {usuario_id: $ator.id}
    } as $vencimentos

    var $agora {
      value = now
    }

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

    function.run obter_configuracao_comparecimento as $configuracao

    precondition (!($configuracao.prazo_avaliacao_dias|is_null)) {
      error = "Configuração de avaliações incompleta: execute o bootstrap."
    }

    function.run situacao_efetiva {
      input = {
        status                : $reserva.status
        inicio                : $reserva.inicio
        agora                 : $agora
        fim                   : $reserva.fim
        check_in_em           : $reserva.check_in_em
        checkin_depois_minutos: $configuracao.checkin_depois_minutos
        comparecimento_desde  : $configuracao.comparecimento_desde
      }
    } as $situacao

    precondition ($situacao == "CONCLUIDA") {
      error_type = "inputerror"
      error = "Só reservas concluídas podem ser avaliadas."
    }

    var $limite {
      value = $reserva.fim + ($configuracao.prazo_avaliacao_dias * 86400000)
    }

    precondition ($agora <= $limite) {
      error_type = "inputerror"
      error = "O prazo para avaliar esta reserva terminou."
    }

    db.has avaliacao {
      field_name = "reserva_id"
      field_value = $reserva.id
    } as $ja_avaliada

    precondition (!$ja_avaliada) {
      error_type = "inputerror"
      error = "Esta reserva já foi avaliada."
    }

    db.get espaco {
      field_name = "id"
      field_value = $reserva.espaco_id
    } as $espaco

    var $tem_comentario {
      value = !($comentario|is_null)
    }

    var $dados_depois {
      value = {}
        |set:"reserva_id":$reserva.id
        |set:"espaco_id":$reserva.espaco_id
        |set:"nota":$nota
        |set:"tem_comentario":$tem_comentario
    }

    var $avaliacao_id {
      value = null
    }

    // Avaliação e auditoria na mesma transação. Se duas avaliações simultâneas passarem pela
    // checagem acima, o índice único de reserva_id recusa a segunda, que recebe a mesma mensagem.
    try_catch {
      try {
        db.transaction {
          stack {
            db.add avaliacao {
              data = {
                reserva_id: $reserva.id
                usuario_id: $ator.id
                nota      : $nota
                comentario: $comentario
                criado_em : $agora
              }
            } as $avaliacao

            function.run registrar_auditoria {
              input = {
                ator_id     : $ator.id
                acao        : "AVALIAR_RESERVA"
                entidade    : "avaliacao"
                entidade_id : $avaliacao.id
                unidade_id  : $espaco.unidade_id
                dados_depois: $dados_depois
              }
            } as $registro

            var.update $avaliacao_id {
              value = $avaliacao.id
            }
          }
        }
      }

      catch {
        db.has avaliacao {
          field_name = "reserva_id"
          field_value = $reserva.id
        } as $avaliada_apos_falha

        precondition (!$avaliada_apos_falha) {
          error_type = "inputerror"
          error = "Esta reserva já foi avaliada."
        }

        precondition (false) {
          error = "Não foi possível registrar a avaliação. Tente novamente."
        }
      }
    }

    var $resposta {
      value = {}
        |set:"mensagem":"Avaliação registrada."
        |set:"avaliacao_id":$avaliacao_id
        |set:"nota":$nota
    }
  }

  response = $resposta
  guid = "rrSnM99Md15uqPmy4OObnCB9C6E"
}
