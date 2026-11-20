// Check-in pelo próprio usuário (spec comparecimento; C10, design D8). Só em reserva CONFIRMADA, de
// checkin_antes_minutos antes até checkin_depois_minutos depois do início, sem passar do fim, com os
// dois limites incluídos (decisão 5), pelos parâmetros atuais (decisão 9). Uma única vez. Reserva de
// outra pessoa ou inexistente tem a mesma recusa. A faxina com o usuário roda antes (D3): se a
// janela já fechou, a reserva chega NAO_COMPARECEU e recebe a recusa da janela encerrada.
// Registra o check-in de uma reserva própria, dentro da trava de governança
query fazer_checkin verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int reserva_id
  }

  stack {
    function.run aplicar_vencimentos {
      input = {usuario_id: $auth.id}
    } as $vencimentos

    var $check_in_em {
      value = null
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava

        var $agora {
          value = now
        }

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

        precondition (!($reserva.status == "PENDENTE" && $reserva.inicio > $agora)) {
          error_type = "inputerror"
          error = "Esta reserva aguarda aprovação e ainda não aceita check-in."
        }

        precondition ($reserva.status != "NAO_COMPARECEU") {
          error_type = "inputerror"
          error = "A janela de check-in terminou."
        }

        precondition ($reserva.status == "CONFIRMADA") {
          error_type = "inputerror"
          error = "A reserva não está confirmada."
        }

        precondition ($reserva.check_in_em|is_null) {
          error_type = "inputerror"
          error = "O check-in já foi feito."
        }

        function.run obter_configuracao_comparecimento as $configuracao

        var $abre {
          value = $reserva.inicio - ($configuracao.checkin_antes_minutos * 60000)
        }

        function.run fechamento_checkin {
          input = {inicio: $reserva.inicio, fim: $reserva.fim, depois_ms: $configuracao.depois_ms}
        } as $fecha

        var $abre_texto {
          value = $abre|format_timestamp:"H:i":"America/Sao_Paulo"
        }

        precondition ($agora >= $abre) {
          error_type = "inputerror"
          error = "O check-in abre às " ~ $abre_texto ~ "."
        }

        precondition ($agora <= $fecha) {
          error_type = "inputerror"
          error = "A janela de check-in terminou."
        }

        db.edit reserva {
          field_name = "id"
          field_value = $reserva.id
          data = {check_in_em: $agora}
        } as $com_check_in

        db.get espaco {
          field_name = "id"
          field_value = $reserva.espaco_id
        } as $espaco

        var $dados_antes {
          value = {}|set:"check_in_em":null
        }

        var $dados_depois {
          value = {}|set:"check_in_em":$agora
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CHECK_IN"
            entidade    : "reserva"
            entidade_id : $reserva.id
            unidade_id  : $espaco.unidade_id
            dados_antes : $dados_antes
            dados_depois: $dados_depois
          }
        } as $registro

        var.update $check_in_em {
          value = $agora
        }
      }
    }

    var $resposta {
      value = {}
        |set:"mensagem":"Check-in registrado."
        |set:"check_in_em":$check_in_em
    }
  }

  response = $resposta
  guid = "JFz4keP0GjR5Wm4YGyae14ajwIY"
}
