// Reservas do próprio usuário (spec reservas; design D9), da mais recente para a mais antiga.
// Uma consulta por tabela, sem consulta por reserva. Data e horas em America/Sao_Paulo.
// pode_cancelar usa o prazo atual e a mesma comparação em ms de cancelar_reserva (só usabilidade;
// a rota de cancelar revalida). O motivo da desativação só aparece em ESPACO_INDISPONIVEL; na
// inativação de conta não há detalhe (a pessoa inativada não vê o motivo).
// C7: o status devolvido é a situação efetiva (design D2): a pendente vencida aparece EXPIRADA
// mesmo antes de ser gravada. Devolve o motivo da recusa, mas não quem decidiu, assim como não
// devolve quem cancelou (D7).
// C10 (D8): situação efetiva com NAO_COMPARECEU e CONCLUIDA; pode_cancelar só antes do início e sem
// check-in; cancelamento_gera_falta; janela de check-in (horas em São Paulo) e checkin_possivel;
// falta derivada da situação (aparece antes da gravação).
// C11 (design D6): a reserva cancelada por bloqueio traz o tipo e o motivo do bloqueio, sem o autor.
// Lista as reservas do usuário autenticado
query minhas_reservas verb=GET {
  api_group = "reservas"
  auth = "usuario"

  input {
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator

    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao

    precondition ($configuracao != null && !($configuracao.prazo_cancelamento_minutos|is_null) && !($configuracao.checkin_antes_minutos|is_null) && !($configuracao.checkin_depois_minutos|is_null) && !($configuracao.comparecimento_desde|is_null)) {
      error = "Configuração de reservas incompleta: execute o bootstrap."
    }

    var $limite_cancelamento {
      value = $configuracao.prazo_cancelamento_minutos * 60000
    }

    // Janela de check-in (C10, D2), com os parâmetros atuais
    var $antes_ms {
      value = $configuracao.checkin_antes_minutos * 60000
    }

    var $depois_ms {
      value = $configuracao.checkin_depois_minutos * 60000
    }

    var $agora {
      value = now
    }

    db.query reserva {
      where = $db.reserva.usuario_id == $ator.id
      sort = {inicio: "desc"}
      return = {type: "list"}
    } as $reservas

    db.query espaco {
      return = {type: "list"}
    } as $espacos

    db.query unidade {
      return = {type: "list"}
    } as $unidades

    db.query tipo_espaco {
      return = {type: "list"}
    } as $tipos

    // C11: os bloqueios que cancelaram reservas do usuário, numa consulta só
    var $ids_bloqueios {
      value = ($reservas|filter:!($$.bloqueio_id|is_null))|map:$$.bloqueio_id|unique
    }

    var $bloqueios {
      value = []
    }

    conditional {
      if (($ids_bloqueios|count) > 0) {
        db.query bloqueio {
          where = $db.bloqueio.id in $ids_bloqueios
          return = {type: "list"}
        } as $bloqueios_das_reservas

        var.update $bloqueios {
          value = $bloqueios_das_reservas
        }
      }
    }

    var $lista {
      value = []
    }

    foreach ($reservas) {
      each as $reserva {
        var $espaco {
          value = $espacos|find:$$.id == $reserva.espaco_id
        }

        var $unidade {
          value = $unidades|find:$$.id == $espaco.unidade_id
        }

        var $tipo {
          value = $tipos|find:$$.id == $espaco.tipo_espaco_id
        }

        function.run formatar_reserva {
          input = {inicio: $reserva.inicio, fim: $reserva.fim}
        } as $formatada

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

        // C10 (D8): cancela só antes do início e sem check-in; a confirmada depois do prazo
        // geraria falta (decisões 2, 3 e 13). Só usabilidade: a rota de cancelar revalida.
        var $pode_cancelar {
          value = false
        }

        var $cancelamento_gera_falta {
          value = false
        }

        conditional {
          if (($situacao == "PENDENTE" || $situacao == "CONFIRMADA") && $reserva.inicio > $agora && ($reserva.check_in_em|is_null)) {
            var.update $pode_cancelar {
              value = true
            }

            conditional {
              if ($situacao == "CONFIRMADA" && $reserva.inicio < $agora + $limite_cancelamento) {
                var.update $cancelamento_gera_falta {
                  value = true
                }
              }
            }
          }
        }

        // Janela de check-in: de antes do início até depois dele, sem passar do fim (decisão 5)
        var $checkin_abre {
          value = $reserva.inicio - $antes_ms
        }

        function.run fechamento_checkin {
          input = {inicio: $reserva.inicio, fim: $reserva.fim, depois_ms: $depois_ms}
        } as $checkin_fecha

        var $checkin_possivel {
          value = false
        }

        conditional {
          if ($situacao == "CONFIRMADA" && ($reserva.check_in_em|is_null) && $agora >= $checkin_abre && $agora <= $checkin_fecha) {
            var.update $checkin_possivel {
              value = true
            }
          }
        }

        var $checkin_abre_hora {
          value = $checkin_abre|format_timestamp:"H:i":"America/Sao_Paulo"
        }

        var $checkin_fecha_hora {
          value = $checkin_fecha|format_timestamp:"H:i":"America/Sao_Paulo"
        }

        var $check_in_hora {
          value = null
        }

        conditional {
          if (!($reserva.check_in_em|is_null)) {
            var.update $check_in_hora {
              value = $reserva.check_in_em|format_timestamp:"H:i":"America/Sao_Paulo"
            }
          }
        }

        // Falta derivada da situação efetiva, para aparecer mesmo antes da gravação
        var $falta {
          value = null
        }

        conditional {
          if ($situacao == "NAO_COMPARECEU") {
            var.update $falta {
              value = "NAO_COMPARECIMENTO"
            }
          }

          elseif ($situacao == "CANCELADA" && $reserva.motivo_cancelamento == "USUARIO_TARDIO") {
            var.update $falta {
              value = "CANCELAMENTO_TARDIO"
            }
          }
        }

        var $motivo_detalhe {
          value = null
        }

        var $motivo_descricao {
          value = null
        }

        conditional {
          if ($reserva.motivo_cancelamento == "ESPACO_INDISPONIVEL") {
            var.update $motivo_detalhe {
              value = $reserva.motivo_detalhe
            }

            var.update $motivo_descricao {
              value = $reserva.motivo_descricao
            }
          }
        }

        var $bloqueio_tipo {
          value = null
        }

        var $bloqueio_motivo {
          value = null
        }

        conditional {
          if ($reserva.motivo_cancelamento == "BLOQUEIO" && !($reserva.bloqueio_id|is_null)) {
            var $bloqueio {
              value = $bloqueios|find:$$.id == $reserva.bloqueio_id
            }

            conditional {
              if ($bloqueio != null) {
                var.update $bloqueio_tipo {
                  value = $bloqueio.tipo
                }

                var.update $bloqueio_motivo {
                  value = $bloqueio.motivo
                }
              }
            }
          }
        }

        var $espaco_item {
          value = {}
            |set:"id":$espaco.id
            |set:"nome":$espaco.nome
            |set:"codigo":$espaco.codigo
        }

        var $unidade_item {
          value = {}
            |set:"id":$unidade.id
            |set:"nome":$unidade.nome
        }

        var $tipo_item {
          value = {}
            |set:"id":$tipo.id
            |set:"nome":$tipo.nome
        }

        var $item {
          value = {}
            |set:"id":$reserva.id
            |set:"espaco":$espaco_item
            |set:"unidade":$unidade_item
            |set:"tipo":$tipo_item
            |set:"inicio":$reserva.inicio
            |set:"fim":$reserva.fim
            |set:"data":$formatada.data
            |set:"hora_inicio":$formatada.hora_inicio
            |set:"hora_fim":$formatada.hora_fim
            |set:"status":$situacao
            |set:"motivo_cancelamento":$reserva.motivo_cancelamento
            |set:"motivo_detalhe":$motivo_detalhe
            |set:"motivo_descricao":$motivo_descricao
            |set:"motivo_recusa":$reserva.motivo_recusa
            |set:"bloqueio_tipo":$bloqueio_tipo
            |set:"bloqueio_motivo":$bloqueio_motivo
            |set:"pode_cancelar":$pode_cancelar
            |set:"cancelamento_gera_falta":$cancelamento_gera_falta
            |set:"check_in_em":$reserva.check_in_em
            |set:"check_in_hora":$check_in_hora
            |set:"checkin_abre":$checkin_abre_hora
            |set:"checkin_fecha":$checkin_fecha_hora
            |set:"checkin_possivel":$checkin_possivel
            |set:"falta":$falta
        }

        var.update $lista {
          value = $lista|push:$item
        }
      }
    }

    var $resposta {
      value = {}
        |set:"reservas":$lista
        |set:"prazo_cancelamento_minutos":$configuracao.prazo_cancelamento_minutos
    }
  }

  response = $resposta
  guid = "H9OBd0-_JHf9E8GjIDhnSjTzrJI"
}
