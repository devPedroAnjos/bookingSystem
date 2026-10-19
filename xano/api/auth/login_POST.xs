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
    function.run conferir_credenciais {
      input = {email: $input.email, senha: $input.senha}
    } as $usuario
  
    precondition ($usuario.status_conta != "PENDENTE") {
      error_type = "accessdenied"
      error = "Sua conta aguarda aprovação."
    }
  
    precondition ($usuario.status_conta != "RECUSADA") {
      error_type = "accessdenied"
      error = "Seu cadastro foi recusado. Motivo: " ~ ($usuario.motivo_recusa_cadastro|first_notnull:"não informado")
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