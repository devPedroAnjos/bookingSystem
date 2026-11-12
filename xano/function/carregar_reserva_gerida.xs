// Carrega a reserva e verifica se o ator pode decidi-la (C7, design D5), no padrão de
// carregar_espaco_gerido. Deve ser chamada DEPOIS de travar_governanca, dentro da transação.
// - ADMIN decide reservas de qualquer unidade; reserva inexistente responde 404.
// - COORDENADOR decide só reservas de espaços da unidade ATUAL que coordena; reserva inexistente
//   ou fora do escopo responde 403, com a mesma mensagem, para não revelar ids.
// A regra da própria reserva e a situação ficam com as rotas de decisão.
// Devolve o ator, a reserva e o espaço
function carregar_reserva_gerida {
  input {
    int ator_id
    int reserva_id
    int? emitido_em?
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $input.ator_id
        emitido_em: $input.emitido_em
      }
    } as $ator

    precondition ($ator.papel == "ADMIN" || $ator.papel == "COORDENADOR") {
      error_type = "accessdenied"
      error = "Você não tem acesso à gestão de reservas."
    }

    db.get reserva {
      field_name = "id"
      field_value = $input.reserva_id
    } as $reserva

    var $espaco {
      value = null
    }

    conditional {
      if ($reserva != null) {
        db.get espaco {
          field_name = "id"
          field_value = $reserva.espaco_id
        } as $espaco_da_reserva

        var.update $espaco {
          value = $espaco_da_reserva
        }
      }
    }

    conditional {
      if ($ator.papel == "ADMIN") {
        precondition ($reserva != null) {
          error_type = "notfound"
          error = "Reserva não encontrada."
        }
      }

      else {
        var $no_escopo {
          value = false
        }

        conditional {
          if ($espaco != null) {
            db.query coordenacao_unidade {
              where = $db.coordenacao_unidade.usuario_id == $ator.id && $db.coordenacao_unidade.unidade_id == $espaco.unidade_id
              return = {type: "exists"}
            } as $coordena

            var.update $no_escopo {
              value = $coordena
            }
          }
        }

        precondition ($no_escopo) {
          error_type = "accessdenied"
          error = "Você não tem acesso a esta reserva."
        }
      }
    }
  }

  response = {ator: $ator, reserva: $reserva, espaco: $espaco}
  guid = "Z807MhyAQLihOdFdWLs64XgBiL8"
}
