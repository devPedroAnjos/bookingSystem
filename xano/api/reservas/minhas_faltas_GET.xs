// Faltas e penalidades do próprio usuário (spec penalidades; C10, design D8). A faxina com o
// usuário grava antes os vencimentos dele (D3), então a falta recém-vencida já aparece. Só as
// próprias. Cada falta traz o tipo, o instante, a reserva (espaço, data e horário) e se gerou
// penalidade; cada penalidade, início, fim, situação efetiva e, se anulada, o parecer, sem o nome
// de quem anulou (decisão 16). Datas em America/Sao_Paulo. em_vigor e ate vêm de
// penalidade_em_vigor (fim da cadeia contígua).
// Lista as faltas e as penalidades do usuário autenticado
query minhas_faltas verb=GET {
  api_group = "reservas"
  auth = "usuario"

  input {
  }

  stack {
    function.run aplicar_vencimentos {
      input = {usuario_id: $auth.id}
    } as $vencimentos

    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator

    var $agora {
      value = now
    }

    db.query falta {
      where = $db.falta.usuario_id == $ator.id
      sort = {ocorrida_em: "desc"}
      return = {type: "list"}
    } as $faltas

    db.query penalidade {
      where = $db.penalidade.usuario_id == $ator.id
      sort = {inicio: "desc"}
      return = {type: "list"}
    } as $penalidades

    var $lista_faltas {
      value = []
    }

    conditional {
      if (($faltas|count) > 0) {
        var $ids_reservas {
          value = $faltas|map:$$.reserva_id
        }

        db.query reserva {
          where = $db.reserva.id in $ids_reservas
          return = {type: "list"}
        } as $reservas

        var $ids_espacos {
          value = $reservas|map:$$.espaco_id|unique
        }

        db.query espaco {
          where = $db.espaco.id in $ids_espacos
          return = {type: "list"}
        } as $espacos

        foreach ($faltas) {
          each as $falta {
            var $reserva {
              value = $reservas|find:$$.id == $falta.reserva_id
            }

            var $espaco {
              value = $espacos|find:$$.id == $reserva.espaco_id
            }

            function.run formatar_reserva {
              input = {inicio: $reserva.inicio, fim: $reserva.fim}
            } as $formatada

            var $ocorrida_texto {
              value = $falta.ocorrida_em|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
            }

            // conditional em vez de operador no value (lição da C5)
            var $gerou_penalidade {
              value = false
            }

            conditional {
              if (!($falta.penalidade_id|is_null)) {
                var.update $gerou_penalidade {
                  value = true
                }
              }
            }

            var $espaco_item {
              value = {}
                |set:"nome":$espaco.nome
                |set:"codigo":$espaco.codigo
            }

            var $item_falta {
              value = {}
                |set:"id":$falta.id
                |set:"tipo":$falta.tipo
                |set:"ocorrida_em":$ocorrida_texto
                |set:"espaco":$espaco_item
                |set:"data":$formatada.data
                |set:"hora_inicio":$formatada.hora_inicio
                |set:"hora_fim":$formatada.hora_fim
                |set:"gerou_penalidade":$gerou_penalidade
                |set:"penalidade_id":$falta.penalidade_id
            }

            var.update $lista_faltas {
              value = $lista_faltas|push:$item_falta
            }
          }
        }
      }
    }

    var $lista_penalidades {
      value = []
    }

    foreach ($penalidades) {
      each as $penalidade {
        // Situação efetiva: a ATIVA cujo fim chegou já é CUMPRIDA, mesmo antes da gravação
        var $situacao {
          value = $penalidade.status
        }

        conditional {
          if ($penalidade.status == "ATIVA" && $penalidade.fim <= $agora) {
            var.update $situacao {
              value = "CUMPRIDA"
            }
          }
        }

        var $em_vigor_item {
          value = false
        }

        conditional {
          if ($situacao == "ATIVA" && $penalidade.inicio <= $agora) {
            var.update $em_vigor_item {
              value = true
            }
          }
        }

        var $parecer {
          value = null
        }

        conditional {
          if ($penalidade.status == "ANULADA") {
            var.update $parecer {
              value = $penalidade.parecer
            }
          }
        }

        var $inicio_texto {
          value = $penalidade.inicio|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
        }

        var $fim_texto {
          value = $penalidade.fim|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
        }

        var $item_penalidade {
          value = {}
            |set:"id":$penalidade.id
            |set:"inicio":$inicio_texto
            |set:"fim":$fim_texto
            |set:"status":$situacao
            |set:"em_vigor":$em_vigor_item
            |set:"parecer":$parecer
        }

        var.update $lista_penalidades {
          value = $lista_penalidades|push:$item_penalidade
        }
      }
    }

    function.run penalidade_em_vigor {
      input = {usuario_id: $ator.id, agora: $agora}
    } as $vigor

    var $resposta {
      value = {}
        |set:"faltas":$lista_faltas
        |set:"penalidades":$lista_penalidades
        |set:"em_vigor":$vigor.em_vigor
        |set:"ate":$vigor.ate_texto
    }
  }

  response = $resposta
  guid = "6-nYJTJGUUgKkdaW7Nrgl3i_-Uk"
}
