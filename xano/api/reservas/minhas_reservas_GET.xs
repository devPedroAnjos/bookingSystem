// Reservas do próprio usuário (spec reservas; design D9), da mais recente para a mais antiga.
// Uma consulta por tabela, sem consulta por reserva. Data e horas em America/Sao_Paulo.
// pode_cancelar usa o prazo atual e a mesma comparação em ms de cancelar_reserva (só usabilidade;
// a rota de cancelar revalida). O motivo da desativação só aparece em ESPACO_INDISPONIVEL; na
// inativação de conta não há detalhe (a pessoa inativada não vê o motivo).
// C7: o status devolvido é a situação efetiva (design D2): a pendente vencida aparece EXPIRADA
// mesmo antes de ser gravada. Devolve o motivo da recusa, mas não quem decidiu, assim como não
// devolve quem cancelou (D7).
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

    precondition ($configuracao != null && !($configuracao.prazo_cancelamento_minutos|is_null)) {
      error = "Configuração de reservas incompleta: execute o bootstrap."
    }

    var $limite_cancelamento {
      value = $configuracao.prazo_cancelamento_minutos * 60000
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
            status: $reserva.status
            inicio: $reserva.inicio
            agora : $agora
          }
        } as $situacao

        var $pode_cancelar {
          value = false
        }

        conditional {
          if ($situacao == "PENDENTE" || $situacao == "CONFIRMADA") {
            conditional {
              if ($reserva.inicio >= $agora + $limite_cancelamento) {
                var.update $pode_cancelar {
                  value = true
                }
              }
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
            |set:"pode_cancelar":$pode_cancelar
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
