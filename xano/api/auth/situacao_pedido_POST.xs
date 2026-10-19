// Consulta pública da situação do próprio pedido de cadastro, com e-mail e senha (design.md, D7).
// Só responde para PENDENTE ou RECUSADA; nos demais casos, a mesma resposta genérica do login.
// Devolve situação, papel, unidade, motivo e pedidos restantes do pedido de cadastro
query situacao_pedido verb=POST {
  api_group = "auth"

  input {
    text email? filters=trim|lower {
      sensitive = true
    }
  
    text senha? {
      sensitive = true
    }
  }

  stack {
    function.run conferir_credenciais {
      input = {email: $input.email, senha: $input.senha}
    } as $usuario
  
    precondition ($usuario.status_conta == "PENDENTE" || $usuario.status_conta == "RECUSADA") {
      error_type = "unauthorized"
      error = "E-mail ou senha inválidos."
    }
  
    function.run obter_configuracao as $configuracao
    var $pedidos_restantes {
      value = $configuracao.max_pedidos_cadastro - ($usuario.pedidos_cadastro|first_notnull:1)
    }
  
    conditional {
      if ($pedidos_restantes < 0) {
        var.update $pedidos_restantes {
          value = 0
        }
      }
    }
  
    // Após recusa por desativação da unidade, o próximo reenvio é gratuito (não soma pedido):
    // ele se acrescenta aos pedidos que ainda restam
    conditional {
      if ($usuario.status_conta == "RECUSADA" && $usuario.recusa_sem_custo) {
        var.update $pedidos_restantes {
          value = $pedidos_restantes + 1
        }
      }
    }
  
    var $unidade_nome {
      value = null
    }
  
    conditional {
      if ($usuario.unidade_vinculo_id != null) {
        db.get unidade {
          field_name = "id"
          field_value = $usuario.unidade_vinculo_id
        } as $unidade
      
        var.update $unidade_nome {
          value = $unidade.nome
        }
      }
    }
  }

  response = {
    status_conta          : $usuario.status_conta
    papel                 : $usuario.papel
    unidade_vinculo_id    : $usuario.unidade_vinculo_id
    unidade_nome          : $unidade_nome
    motivo_recusa_cadastro: $usuario.motivo_recusa_cadastro
    pedidos_restantes     : $pedidos_restantes
  }

  guid = "jzaRJo7DU3CaoTenRdqTWROW8WI"
}