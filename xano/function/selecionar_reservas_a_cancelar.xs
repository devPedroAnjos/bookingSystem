// Seleção das reservas que uma ação cancelaria (C6, design D10). Só leitura: usada pelo
// cancelamento em lote (dentro da trava de quem chama) e pela consulta de impacto (D8), para o
// aviso e a ação nunca divergirem na regra. Reservas que já terminaram nunca entram.
// Modo "conta" (usuario_id): PENDENTE ou CONFIRMADA que ainda não começaram; a em andamento continua.
// Modo "espaco" (espacos_ids): PENDENTE ou CONFIRMADA que ainda não terminaram, exceto as
// CONFIRMADA em andamento, que impedem a ação; devolve quantas são e o maior fim entre elas.
// C10 (D2): a NAO_COMPARECEU efetiva não está em andamento e não é cancelada. A reserva com check-in
// que ainda não começou é cancelada como qualquer outra (cancelamento automático, sem falta).
// Devolve as reservas a cancelar, a quantidade em andamento e o fim da última em andamento
function selecionar_reservas_a_cancelar {
  input {
    text modo
    int? usuario_id?
    json? espacos_ids?
    int agora
  }

  stack {
    precondition ($input.modo == "conta" || $input.modo == "espaco") {
      error = "Modo de seleção de reservas inválido."
    }

    var $agora {
      value = $input.agora
    }

    var $reservas {
      value = []
    }

    var $em_andamento {
      value = []
    }

    conditional {
      if ($input.modo == "conta") {
        precondition (!($input.usuario_id|is_null)) {
          error = "Informe a conta das reservas."
        }

        db.query reserva {
          where = $db.reserva.usuario_id == $input.usuario_id && $db.reserva.status in ["PENDENTE", "CONFIRMADA"] && $db.reserva.inicio > $agora
          sort = {inicio: "asc"}
          return = {type: "list"}
        } as $da_conta

        var.update $reservas {
          value = $da_conta
        }
      }

      else {
        var $ids {
          value = ($input.espacos_ids|first_notnull:[])|map:($$|to_int)
        }

        // Tipo ou unidade sem espaços: nada a consultar
        conditional {
          if (($ids|count) > 0) {
            db.query reserva {
              where = $db.reserva.espaco_id in $ids && $db.reserva.status in ["PENDENTE", "CONFIRMADA"] && $db.reserva.fim > $agora
              sort = {inicio: "asc"}
              return = {type: "list"}
            } as $dos_espacos

            // C10 (D2): a confirmada sem check-in cuja janela fechou é NAO_COMPARECEU pela situação
            // efetiva; ela não está em andamento e não é cancelada (a falta continua valendo)
            function.run obter_configuracao_comparecimento as $comparecimento

            foreach ($dos_espacos) {
              each as $reserva {
                var $sem_comparecimento {
                  value = false
                }

                conditional {
                  if ($reserva.status == "CONFIRMADA" && $reserva.inicio <= $agora && $reserva.inicio >= $comparecimento.comparecimento_desde && ($reserva.check_in_em|is_null)) {
                    function.run fechamento_checkin {
                      input = {inicio: $reserva.inicio, fim: $reserva.fim, depois_ms: $comparecimento.depois_ms}
                    } as $fechamento

                    conditional {
                      if ($agora > $fechamento) {
                        var.update $sem_comparecimento {
                          value = true
                        }
                      }
                    }
                  }
                }

                // A sem comparecimento fica de fora das duas listas
                conditional {
                  if (!$sem_comparecimento && $reserva.status == "CONFIRMADA" && $reserva.inicio <= $agora) {
                    var.update $em_andamento {
                      value = $em_andamento|push:$reserva
                    }
                  }

                  // Pendente já iniciada não impede a ação e é cancelada junto (D10)
                  elseif (!$sem_comparecimento) {
                    var.update $reservas {
                      value = $reservas|push:$reserva
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    var $quantidade_em_andamento {
      value = $em_andamento|count
    }

    var $em_andamento_ate {
      value = null
    }

    conditional {
      if ($quantidade_em_andamento > 0) {
        var.update $em_andamento_ate {
          value = ($em_andamento|map:$$.fim|max)|to_int
        }
      }
    }

    // Só referências simples no objeto: filtros dentro de literal falham em execução
    var $selecao {
      value = {}
        |set:"reservas":$reservas
        |set:"em_andamento":$quantidade_em_andamento
        |set:"em_andamento_ate":$em_andamento_ate
    }
  }

  response = $selecao
  guid = "MP95WlcTBMvoaUVR7pqYeNTzE0A"
}
