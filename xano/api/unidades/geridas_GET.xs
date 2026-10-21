// Unidades sob o escopo do usuário (spec unidades): ADMIN recebe todas, ativas e desativadas,
// com professores e pedidos pendentes (para o formulário de desativação); COORDENADOR recebe
// só as que coordena; ALUNO e PROFESSOR recebem 403.
// Lista as unidades geridas com coordenadores ativos e indicador de unidade sem coordenador
query geridas verb=GET {
  api_group = "unidades"
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
      error = "Você não tem acesso à gestão de unidades."
    }
  
    var $e_admin {
      value = $ator.papel == "ADMIN"
    }
  
    db.query unidade {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $todas
  
    var $unidades {
      value = $todas
    }
  
    conditional {
      if (!$e_admin) {
        function.run unidades_coordenadas {
          input = {usuario_id: $ator.id}
        } as $coordenadas
      
        var.update $unidades {
          value = $todas|filter:($coordenadas|in:$$.id)
        }
      }
    }
  
    var $resultado {
      value = []
    }
  
    foreach ($unidades) {
      each as $unidade {
        function.run coordenadores_ativos {
          input = {unidade_id: $unidade.id}
        } as $coordenadores
      
        var $item {
          value = {
            id             : $unidade.id
            nome           : $unidade.nome
            endereco       : $unidade.endereco
            ativa          : $unidade.ativa
            coordenadores  : $coordenadores
            sem_coordenador: ($coordenadores|count) == 0
          }
        }
      
        conditional {
          if ($e_admin) {
            db.query usuario {
              where = $db.usuario.papel == "PROFESSOR" && $db.usuario.status_conta == "ATIVA" && $db.usuario.unidade_vinculo_id == $unidade.id
              sort = {nome: "asc"}
              return = {type: "list"}
            } as $professores
          
            db.query usuario {
              where = $db.usuario.status_conta == "PENDENTE" && $db.usuario.unidade_vinculo_id == $unidade.id
              return = {type: "count"}
            } as $pendentes
          
            var.update $item {
              value = $item
                |set:"professores":($professores|map:{id: $$.id, nome: $$.nome})
                |set:"pedidos_pendentes":$pendentes
            }
          }
        }
      
        var.update $resultado {
          value = $resultado|push:$item
        }
      }
    }
  }

  response = $resultado
  guid = "DqwNlg3n9trNbm-dJpcyzFuHSyo"
}