// Listagem de usuários para o admin (spec papeis), com filtros opcionais.
// Cada usuário traz a unidade de professor e as unidades que coordena. Nunca devolve senha.
// Lista os usuários com papel, situação, unidade e coordenações
query usuarios verb=GET {
  api_group = "contas"
  auth = "usuario"

  input {
    text papel? filters=trim|upper
    text status_conta? filters=trim|upper
    text busca? filters=trim|lower
  }

  stack {
    function.run exigir_admin {
      input = {usuario_id: $auth.id}
    } as $ator
  
    var $papel {
      value = ($input.papel|first_notnull:"") == "" ? null : $input.papel
    }
  
    var $status_conta {
      value = ($input.status_conta|first_notnull:"") == "" ? null : $input.status_conta
    }
  
    db.query usuario {
      join = {
        unidade: {
          table: "unidade"
          type : "left"
          where: $db.usuario.unidade_vinculo_id == $db.unidade.id
        }
      }
    
      where = $db.usuario.papel ==? $papel && $db.usuario.status_conta ==? $status_conta
      sort = {nome: "asc"}
      eval = {unidade_nome: $db.unidade.nome}
      return = {type: "list"}
    } as $contas
  
    var $busca {
      value = $input.busca|first_notnull:""
    }
  
    conditional {
      if (($busca|strlen) > 0) {
        var.update $contas {
          value = $contas|filter:((($$.nome|to_lower)|contains:$busca) || (($$.email|to_lower)|contains:$busca))
        }
      }
    }
  
    db.query coordenacao_unidade {
      join = {
        unidade: {
          table: "unidade"
          where: $db.coordenacao_unidade.unidade_id == $db.unidade.id
        }
      }
    
      sort = {unidade_nome: "asc"}
      eval = {unidade_nome: $db.unidade.nome}
      return = {type: "list"}
    } as $coordenacoes
  
    var $usuarios {
      value = []
    }
  
    foreach ($contas) {
      each as $conta {
        var $coordenacoes_da_conta {
          value = []
        }
      
        foreach ($coordenacoes) {
          each as $coordenacao {
            conditional {
              if ($coordenacao.usuario_id == $conta.id) {
                var.update $coordenacoes_da_conta {
                  value = $coordenacoes_da_conta
                    |push:{unidade_id: $coordenacao.unidade_id, nome: $coordenacao.unidade_nome}
                }
              }
            }
          }
        }
      
        var.update $usuarios {
          value = $usuarios
            |push:```
              {
                id                : $conta.id
                nome              : $conta.nome
                email             : $conta.email
                papel             : $conta.papel
                status_conta      : $conta.status_conta
                unidade_vinculo_id: $conta.unidade_vinculo_id
                unidade_nome      : $conta.unidade_nome
                coordenacoes      : $coordenacoes_da_conta
              }
              ```
        }
      }
    }
  }

  response = $usuarios
  guid = "l9oFfLQ9XlAERg_T3PdicgO3QYw"
}