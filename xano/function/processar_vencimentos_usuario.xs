// Vencimentos de comparecimento de um usuário (C10, design D3). Pressupõe a trava de governança.
// Sem teto: grava por inteiro, em ordem cronológica do instante real, as CONFIRMADA do usuário que
// começam a partir do marco comparecimento_desde e já venceram:
// - sem check-in e janela fechada: NAO_COMPARECEU no fechamento, min(inicio + depois, fim), com
//   MARCAR_NAO_COMPARECEU e a falta (registrar_falta, que avalia a penalidade);
// - com check-in e fim chegado: CONCLUIDA no fim, com CONCLUIR_RESERVA.
// A ordem garante que a janela das faltas e o encadeamento das penalidades saiam certos (D5).
// Devolve quantas reservas gravou
function processar_vencimentos_usuario {
  input {
    int usuario_id

    // Agora da operação, em ms
    int agora
  }

  stack {
    function.run obter_configuracao_comparecimento as $configuracao

    // Fechamento da janela antes de agora: inicio + depois < agora ou fim < agora
    var $inicio_limite {
      value = $input.agora - $configuracao.depois_ms
    }

    db.query reserva {
      where = $db.reserva.usuario_id == $input.usuario_id && $db.reserva.status == "CONFIRMADA" && $db.reserva.inicio >= $configuracao.comparecimento_desde && (($db.reserva.check_in_em == null && ($db.reserva.inicio < $inicio_limite || $db.reserva.fim < $input.agora)) || ($db.reserva.check_in_em != null && $db.reserva.fim <= $input.agora))
      return = {type: "list"}
    } as $vencidas

    conditional {
      if (($vencidas|count) > 0) {
        // Instante real de cada uma, para ordenar
        var $com_instante {
          value = []
        }

        foreach ($vencidas) {
          each as $reserva {
            var $instante {
              value = $reserva.fim
            }

            conditional {
              if ($reserva.check_in_em|is_null) {
                function.run fechamento_checkin {
                  input = {inicio: $reserva.inicio, fim: $reserva.fim, depois_ms: $configuracao.depois_ms}
                } as $fechamento

                var.update $instante {
                  value = $fechamento
                }
              }
            }

            // Calculado antes: filtro dentro de argumento de filtro pode falhar em execução (C5)
            var $item {
              value = $reserva|set:"instante":$instante
            }

            var.update $com_instante {
              value = $com_instante|push:$item
            }
          }
        }

        var $ordenadas {
          value = $com_instante|sort:"instante":"number":true
        }

        var $ids_espacos {
          value = $vencidas|map:$$.espaco_id|unique
        }

        db.query espaco {
          where = $db.espaco.id in $ids_espacos
          return = {type: "list"}
        } as $espacos

        foreach ($ordenadas) {
          each as $reserva {
            var $espaco {
              value = $espacos|find:$$.id == $reserva.espaco_id
            }

            var $dados_antes {
              value = {}|set:"status":$reserva.status
            }

            conditional {
              if ($reserva.check_in_em|is_null) {
                db.edit reserva {
                  field_name = "id"
                  field_value = $reserva.id
                  data = {status: "NAO_COMPARECEU"}
                } as $nao_compareceu

                var $dados_nao_compareceu {
                  value = {}
                    |set:"status":$nao_compareceu.status
                    |set:"nao_compareceu_em":$reserva.instante
                }

                function.run registrar_auditoria {
                  input = {
                    ator_id     : null
                    acao        : "MARCAR_NAO_COMPARECEU"
                    entidade    : "reserva"
                    entidade_id : $reserva.id
                    unidade_id  : $espaco.unidade_id
                    dados_antes : $dados_antes
                    dados_depois: $dados_nao_compareceu
                  }
                } as $registro_nao_compareceu

                function.run registrar_falta {
                  input = {
                    usuario_id : $reserva.usuario_id
                    reserva_id : $reserva.id
                    tipo       : "NAO_COMPARECIMENTO"
                    ocorrida_em: $reserva.instante
                    ator_id    : null
                    unidade_id : $espaco.unidade_id
                    agora      : $input.agora
                  }
                } as $falta
              }

              else {
                db.edit reserva {
                  field_name = "id"
                  field_value = $reserva.id
                  data = {status: "CONCLUIDA"}
                } as $concluida

                var $dados_concluida {
                  value = {}
                    |set:"status":$concluida.status
                    |set:"concluiu_em":$reserva.instante
                }

                function.run registrar_auditoria {
                  input = {
                    ator_id     : null
                    acao        : "CONCLUIR_RESERVA"
                    entidade    : "reserva"
                    entidade_id : $reserva.id
                    unidade_id  : $espaco.unidade_id
                    dados_antes : $dados_antes
                    dados_depois: $dados_concluida
                  }
                } as $registro_concluida
              }
            }
          }
        }
      }
    }

    var $quantidade {
      value = $vencidas|count
    }
  }

  response = $quantidade
  guid = "FmD-Vmzo4x9IBDSs3cdbZKm7Fu0"
}
