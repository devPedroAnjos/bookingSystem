// Define a lista completa de recursos de um espaço, com quantidade (spec espacos; design D7).
// O formato (quantidade >= 1, sem repetição) é validado antes da trava; a existência dos recursos é
// relida dentro dela, a mesma de excluir_recurso. A lista nova substitui a anterior: cada linha
// antiga é apagada por id e as novas são gravadas, como em remover_coordenacao.
// Substitui os recursos de um espaço, dentro da trava de governança
query definir_recursos verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
    json? recursos?
  }

  stack {
    // Item sem recurso ou sem quantidade vira 0 e cai nas validações abaixo (400, não 500)
    var $lista {
      value = ```
        ($input.recursos|first_notnull:[])|map:{
                  recurso_id: ($$.recurso_id|to_int)|first_notnull:0,
                  quantidade: ($$.quantidade|to_int)|first_notnull:0
                }
        ```
    }
  
    precondition ((($lista|filter:$$.quantidade < 1)|count) == 0) {
      error_type = "inputerror"
      error = "A quantidade de cada recurso deve ser de pelo menos 1."
    }
  
    precondition ((($lista|map:$$.recurso_id)|unique|count) == ($lista|count)) {
      error_type = "inputerror"
      error = "Cada recurso pode aparecer só uma vez na lista."
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $carregado
      
        var $espaco {
          value = $carregado.espaco
        }
      
        db.query recurso {
          return = {type: "list"}
        } as $catalogo
      
        var $depois {
          value = []
        }
      
        foreach ($lista) {
          each as $item {
            var $recurso {
              value = $catalogo|find:$$.id == $item.recurso_id
            }
          
            precondition ($recurso != null) {
              error_type = "inputerror"
              error = "Recurso não encontrado no catálogo."
            }
          
            var.update $depois {
              value = $depois
                |push:```
                  {
                    recurso_id: $item.recurso_id,
                    nome      : $recurso.nome,
                    quantidade: $item.quantidade
                  }
                  ```
            }
          }
        }
      
        db.query espaco_recurso {
          where = $db.espaco_recurso.espaco_id == $espaco.id
          return = {type: "list"}
        } as $atuais
      
        var $antes {
          value = []
        }
      
        foreach ($atuais) {
          each as $atual {
            var $recurso_atual {
              value = $catalogo|find:$$.id == $atual.recurso_id
            }
          
            var.update $antes {
              value = $antes
                |push:```
                  {
                    recurso_id: $atual.recurso_id,
                    nome      : $recurso_atual.nome,
                    quantidade: $atual.quantidade
                  }
                  ```
            }
          
            db.del espaco_recurso {
              field_name = "id"
              field_value = $atual.id
            }
          }
        }
      
        foreach ($depois) {
          each as $novo {
            db.add espaco_recurso {
              data = {
                espaco_id : $espaco.id
                recurso_id: $novo.recurso_id
                quantidade: $novo.quantidade
              }
            } as $linha
          }
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "ALTERAR_RECURSOS_ESPACO"
            entidade    : "espaco"
            entidade_id : $espaco.id
            unidade_id  : $espaco.unidade_id
            dados_antes : {recursos: $antes|sort:"nome":"itext":true}
            dados_depois: {recursos: $depois|sort:"nome":"itext":true}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Recursos do espaço atualizados."}
  guid = "6IcYQ-Rf3PKQHWcePKII4KygWWk"
}