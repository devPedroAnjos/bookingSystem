// Catálogo de recursos para gestores (spec recursos), por nome. Para o admin, cada recurso traz
// quantos espaços o usam, para a tela só oferecer a exclusão dos que não estão em uso.
// ALUNO e PROFESSOR recebem 403.
// Lista o catálogo de recursos
query recursos verb=GET {
  api_group = "espacos"
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

    precondition ($ator.papel == "ADMIN" || $ator.papel == "COORDENADOR") {
      error_type = "accessdenied"
      error = "Você não tem acesso à gestão de espaços."
    }

    db.query recurso {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $recursos

    var $resultado {
      value = $recursos|map:{id: $$.id, nome: $$.nome}
    }

    conditional {
      if ($ator.papel == "ADMIN") {
        db.query espaco_recurso {
          return = {type: "list"}
        } as $associacoes

        var $com_uso {
          value = []
        }

        foreach ($resultado) {
          each as $recurso {
            var.update $com_uso {
              value = $com_uso
                |push:($recurso
                  |set:"espacos":(($associacoes|filter:$$.recurso_id == $recurso.id)|count)
                )
            }
          }
        }

        var.update $resultado {
          value = $com_uso
        }
      }
    }
  }

  response = $resultado
  guid = "hCsuaeGcB2yKhRANw6VbIQocjqg"
}
