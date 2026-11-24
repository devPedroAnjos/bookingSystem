// Espaços sob o escopo do usuário (spec espacos; design D8): ADMIN recebe os de todas as unidades,
// COORDENADOR só os das unidades que coordena; ALUNO e PROFESSOR recebem 403.
// Uma consulta por tabela e junção em memória. Cada espaço traz unidade, tipo, recursos e a
// disponibilidade derivada (inclui "tipo sem regras", C5). Ordem: nome da unidade e código.
// espaco-feed-avaliacoes (D8): foto_url e foto_tamanho_max_kb em cada espaço.
// Lista os espaços geridos com recursos e disponibilidade
query geridos verb=GET {
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
  
    db.query unidade {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $todas_unidades
  
    var $unidades {
      value = $todas_unidades
    }
  
    conditional {
      if ($ator.papel != "ADMIN") {
        function.run unidades_coordenadas {
          input = {usuario_id: $ator.id}
        } as $coordenadas
      
        var.update $unidades {
          value = $todas_unidades|filter:($coordenadas|in:$$.id)
        }
      }
    }
  
    db.query espaco {
      return = {type: "list"}
    } as $espacos
  
    db.query tipo_espaco {
      return = {type: "list"}
    } as $tipos
  
    db.query recurso {
      return = {type: "list"}
    } as $recursos

    db.query regra_papel {
      return = {type: "list"}
    } as $todas_regras

    db.query espaco_recurso {
      return = {type: "list"}
    } as $associacoes
  
    // Tamanho máximo da foto em vigor, em cada item (a resposta continua uma lista)
    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao

    var $foto_tamanho_max_kb {
      value = $configuracao.foto_tamanho_max_kb
    }

    var $resultado {
      value = []
    }
  
    foreach ($unidades) {
      each as $unidade {
        var $da_unidade {
          value = ($espacos|filter:$$.unidade_id == $unidade.id)|sort:"codigo":"itext":true
        }
      
        foreach ($da_unidade) {
          each as $espaco {
            var $tipo {
              value = $tipos|find:$$.id == $espaco.tipo_espaco_id
            }
          
            var $do_espaco {
              value = $associacoes|filter:$$.espaco_id == $espaco.id
            }
          
            var $recursos_do_espaco {
              value = []
            }
          
            foreach ($do_espaco) {
              each as $associacao {
                var $recurso {
                  value = $recursos|find:$$.id == $associacao.recurso_id
                }
              
                var.update $recursos_do_espaco {
                  value = $recursos_do_espaco
                    |push:```
                      {
                        id        : $associacao.recurso_id,
                        nome      : $recurso.nome,
                        quantidade: $associacao.quantidade
                      }
                      ```
                }
              }
            }
          
            function.run tipo_com_regras {
              input = {
                tipo          : $tipo
                regras_do_tipo: $todas_regras|filter:$$.tipo_espaco_id == $tipo.id
              }
            } as $com_regras

            function.run disponibilidade_espaco {
              input = {
                espaco_ativo   : $espaco.ativo
                unidade_ativa  : $unidade.ativa
                tipo_ativo     : $tipo.ativo
                tipo_com_regras: $com_regras
              }
            } as $disponibilidade

            // Foto de capa (espaco-feed-avaliacoes, D8)
            function.run url_da_foto {
              input = {foto: $espaco.foto_capa}
            } as $foto_url

            var.update $resultado {
              value = $resultado
                |push:```
                  {
                    id         : $espaco.id,
                    nome       : $espaco.nome,
                    codigo     : $espaco.codigo,
                    capacidade : $espaco.capacidade,
                    localizacao: $espaco.localizacao,
                    descricao  : $espaco.descricao,
                    ativo      : $espaco.ativo == true,
                    unidade    : {
                      id   : $unidade.id,
                      nome : $unidade.nome,
                      ativa: $unidade.ativa == true
                    },
                    tipo       : {
                      id   : $tipo.id,
                      nome : $tipo.nome,
                      ativo: $tipo.ativo == true
                    },
                    recursos   : $recursos_do_espaco|sort:"nome":"itext":true,
                    reservavel : $disponibilidade.reservavel,
                    motivos    : $disponibilidade.motivos,
                    foto_url   : $foto_url,
                    foto_tamanho_max_kb: $foto_tamanho_max_kb
                  }
                  ```
            }
          }
        }
      }
    }
  }

  response = $resultado
  guid = "VBxUuJIo8e1HDhRKCQcG6gTQT-0"
}