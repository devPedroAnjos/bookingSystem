// Login: a senha é verificada antes da situação da conta, para que a situação
// só seja revelada a quem conhece a senha.
// Emite o token para conta ATIVA com e-mail e senha corretos
query login verb=POST {
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
    var $mensagem_credenciais {
      value = "E-mail ou senha inválidos."
    }
  
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
      error = $mensagem_credenciais
    }
  
    precondition ($usuario.status_conta != "PENDENTE") {
      error_type = "accessdenied"
      error = "Sua conta aguarda aprovação."
    }
  
    precondition ($usuario.status_conta == "ATIVA") {
      error_type = "accessdenied"
      error = "O acesso não está liberado para esta conta."
    }
  
    var $duracao_token {
      value = $env.AUTH_TOKEN_TTL_SEGUNDOS|first_notnull:0|to_int
    }
  
    precondition ($duracao_token > 0) {
      error = "Não foi possível entrar agora. Tente novamente mais tarde."
    }
  
    security.create_auth_token {
      table = "usuario"
      extras = {}
      expiration = $duracao_token
      id = $usuario.id
    } as $token
  }

  response = {
    token  : $token
    usuario: ```
      {
        id   : $usuario.id,
        nome : $usuario.nome,
        email: $usuario.email,
        papel: $usuario.papel
      }
      ```
  }

  guid = "dlcqydsj5HEPBxPVAYaeDP5p9e0"
}