// Carrega o espaço e verifica se o ator pode geri-lo (design D4).
// Deve ser chamada DEPOIS de travar_governanca, dentro da transação.
// - ADMIN gere espaços de todas as unidades, ativas ou desativadas.
// - COORDENADOR gere só espaços das unidades que coordena.
// Para o coordenador, espaço inexistente ou fora do escopo responde 403, nunca 404.
// Devolve o ator e o espaço
function carregar_espaco_gerido {
  input {
    int ator_id
    int espaco_id
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
      error = "Você não tem acesso à gestão de espaços."
    }

    db.get espaco {
      field_name = "id"
      field_value = $input.espaco_id
    } as $espaco

    conditional {
      if ($ator.papel == "ADMIN") {
        precondition ($espaco != null) {
          error_type = "notfound"
          error = "Espaço não encontrado."
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
          error = "Você não tem acesso a este espaço."
        }
      }
    }
  }

  response = {ator: $ator, espaco: $espaco}
  guid = "vv3g-nFwEvXvbEqEn1SR28vl4wI"
}
