// Pedidos de cadastro por escopo (spec aprovacao-cadastro):
// ADMIN vê PENDENTE e RECUSADA de professor e coordenador; COORDENADOR vê só professores
// PENDENTE das unidades que coordena; os demais papéis recebem 403.
// Lista os pedidos de cadastro que o usuário pode decidir
query pedidos verb=GET {
  api_group = "contas"
  auth = "usuario"

  input {
    text situacao?=PENDENTE filters=trim|upper
  }

  stack {
    function.run usuario_ativo {
      input = {usuario_id: $auth.id}
    } as $ator
  
    precondition ($input.situacao == "PENDENTE" || $input.situacao == "RECUSADA") {
      error_type = "inputerror"
      error = "Situação inválida."
    }
  
    precondition ($ator.papel == "ADMIN" || ($ator.papel == "COORDENADOR" && $input.situacao == "PENDENTE")) {
      error_type = "accessdenied"
      error = "Você não tem acesso a estes pedidos."
    }
  
    var $papeis {
      value = ["PROFESSOR", "COORDENADOR"]
    }
  
    var $unidades_ids {
      value = null
    }
  
    conditional {
      if ($ator.papel == "COORDENADOR") {
        var.update $papeis {
          value = ["PROFESSOR"]
        }
      
        function.run unidades_coordenadas {
          input = {usuario_id: $ator.id}
        } as $coordenadas
      
        var.update $unidades_ids {
          value = $coordenadas
        }
      }
    }
  
    db.query usuario {
      join = {
        unidade: {
          table: "unidade"
          type : "left"
          where: $db.usuario.unidade_vinculo_id == $db.unidade.id
        }
      }
    
      where = $db.usuario.status_conta == $input.situacao && $db.usuario.papel in $papeis
      sort = {criado_em: "asc"}
      eval = {unidade_nome: $db.unidade.nome}
      return = {type: "list"}
    } as $contas
  
    // Coordenador: só as unidades que coordena
    var $no_escopo {
      value = $unidades_ids == null ? $contas : ($contas|filter:($unidades_ids|in:$$.unidade_vinculo_id))
    }
  
    var $pedidos {
      value = ```
        $no_escopo|map:{
                id                    : $$.id
                nome                  : $$.nome
                email                 : $$.email
                papel                 : $$.papel
                unidade_vinculo_id    : $$.unidade_vinculo_id
                unidade_nome          : $$.unidade_nome
                pedidos_cadastro      : $$.pedidos_cadastro
                justificativa_cadastro: $$.justificativa_cadastro
                motivo_recusa_cadastro: $$.motivo_recusa_cadastro
                recusa_sem_custo      : $$.recusa_sem_custo
                criado_em             : $$.criado_em
              }
        ```
    }
  }

  response = $pedidos
  guid = "1FLG2pjJ22x_vaU4pr2tVXAElig"
}