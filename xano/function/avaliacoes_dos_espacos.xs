// Média e quantidade de avaliações por espaço (change espaco-feed-avaliacoes, design D3). Duas
// consultas para todos os espaços pedidos: as avaliações e as reservas avaliadas (para obter o
// espaço, já que avaliacao não guarda espaco_id). Devolve uma lista com um item por espaço pedido:
// espaco_id, total e media (uma casa decimal; null quando o espaço não tem avaliações).
// Média e quantidade de avaliações de cada espaço
function avaliacoes_dos_espacos {
  input {
    // Lista de ids de espaço
    json espacos_ids
  }

  stack {
    var $ids {
      value = ($input.espacos_ids|first_notnull:[])|map:($$|to_int)|unique
    }

    var $resultado {
      value = []
    }

    conditional {
      if (($ids|count) > 0) {
        db.query avaliacao {
          return = {type: "list"}
        } as $avaliacoes

        var $ids_reservas {
          value = $avaliacoes|map:$$.reserva_id|unique
        }

        var $reservas {
          value = []
        }

        conditional {
          if (($ids_reservas|count) > 0) {
            db.query reserva {
              where = $db.reserva.id in $ids_reservas && $db.reserva.espaco_id in $ids
              return = {type: "list"}
            } as $reservas_avaliadas

            var.update $reservas {
              value = $reservas_avaliadas
            }
          }
        }

        foreach ($ids) {
          each as $espaco_id {
            var $reservas_do_espaco {
              value = ($reservas|filter:$$.espaco_id == $espaco_id)|map:$$.id
            }

            var $notas {
              value = ($avaliacoes|filter:($reservas_do_espaco|in:$$.reserva_id))|map:$$.nota
            }

            var $total {
              value = $notas|count
            }

            var $media {
              value = null
            }

            conditional {
              if ($total > 0) {
                var.update $media {
                  value = (($notas|sum) / $total)|round:1
                }
              }
            }

            var $item {
              value = {}
                |set:"espaco_id":$espaco_id
                |set:"total":$total
                |set:"media":$media
            }

            var.update $resultado {
              value = $resultado|push:$item
            }
          }
        }
      }
    }
  }

  response = $resultado
  guid = "FNvBRia3o0lilIz7Iy7Gewxhzro"
}
