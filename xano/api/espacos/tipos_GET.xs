// Tipos de espaço para gestores (spec tipos-espaco): todos, ativos e desativados, por nome.
// Para o admin, cada tipo traz quantos espaços ativos tem e em quantas unidades (aviso da
// desativação). ALUNO e PROFESSOR recebem 403.
// Lista os tipos de espaço
query tipos verb=GET {
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

    db.query tipo_espaco {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $tipos

    var $resultado {
      value = $tipos|map:{id: $$.id, nome: $$.nome, descricao: $$.descricao, ativo: $$.ativo == true}
    }

    conditional {
      if ($ator.papel == "ADMIN") {
        db.query espaco {
          where = $db.espaco.ativo == true
          return = {type: "list"}
        } as $espacos_ativos

        var $com_contagem {
          value = []
        }

        foreach ($resultado) {
          each as $tipo {
            var $do_tipo {
              value = $espacos_ativos|filter:$$.tipo_espaco_id == $tipo.id
            }

            var.update $com_contagem {
              value = $com_contagem
                |push:($tipo
                  |set:"espacos_ativos":($do_tipo|count)
                  |set:"unidades":(($do_tipo|map:$$.unidade_id)|unique|count)
                )
            }
          }
        }

        var.update $resultado {
          value = $com_contagem
        }
      }
    }
  }

  response = $resultado
  guid = "ouJO39qex3QdVjMlntzagp-lTUQ"
}
