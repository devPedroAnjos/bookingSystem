// Confere e-mail e senha, com a mesma resposta genérica para e-mail inexistente e senha errada.
// Usada por login, situacao_pedido e reenviar_pedido (design.md, D7).
// Devolve o registro completo do usuário: quem chama NUNCA o repassa na resposta (contém senha_hash).
// Devolve o usuário com e-mail e senha corretos, ou 401 genérico
function conferir_credenciais {
  input {
    text? email? filters=trim|lower {
      sensitive = true
    }
  
    text? senha? {
      sensitive = true
    }
  }

  stack {
    db.get usuario {
      field_name = "email"
      field_value = $input.email|first_notnull:""
    } as $usuario
  
    var $senha_confere {
      value = false
    }
  
    conditional {
      if ($usuario != null) {
        security.check_password {
          text_password = $input.senha|first_notnull:""
          hash_password = $usuario.senha_hash
        } as $resultado_senha
      
        var.update $senha_confere {
          value = $resultado_senha
        }
      }
    }
  
    precondition ($senha_confere) {
      error_type = "unauthorized"
      error = "E-mail ou senha inválidos."
    }
  }

  response = $usuario
  guid = "qZq_5ZDSuElaEabI8P_CVsefZ1Y"
}