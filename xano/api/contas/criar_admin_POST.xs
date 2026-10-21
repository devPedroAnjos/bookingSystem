// Criação de admin secundário do zero, só pelo principal (spec administradores; D6).
// E-mail institucional e único; a conta nasce com senha provisória e troca obrigatória.
// Cria uma conta ADMIN ativa com senha provisória, dentro da trava de governança
query criar_admin verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    text nome? filters=trim
    text email? filters=trim|lower {
      sensitive = true
    }
  
    text senha_provisoria? {
      sensitive = true
    }
  }

  stack {
    var $nome {
      value = $input.nome|first_notnull:""
    }
  
    var $email {
      value = $input.email|first_notnull:""
    }
  
    precondition (($nome|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o nome."
    }
  
    precondition (($email|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o e-mail."
    }
  
    precondition ((($input.senha_provisoria|first_notnull:"")|strlen) >= 8) {
      error_type = "inputerror"
      error = "A senha provisória deve ter pelo menos 8 caracteres."
    }
  
    function.run validar_email_institucional {
      input = {email: $email}
    } as $email_valido
  
    var $admin_criado_id {
      value = null
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_principal {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        db.has usuario {
          field_name = "email"
          field_value = $email
        } as $email_existe
      
        precondition (!$email_existe) {
          error_type = "inputerror"
          error = "Já existe uma conta com esse e-mail."
        }
      
        function.run vaga_de_admin as $vaga
      
        // Epoch em ms: sessoes_validas_desde é int, e now literal num campo int não é avaliado
        var $agora {
          value = now
        }
      
        db.add usuario {
          data = {
            nome                 : $nome
            email                : $email
            senha_hash           : $input.senha_provisoria
            papel                : "ADMIN"
            status_conta         : "ATIVA"
            criado_em            : now
            senha_provisoria     : true
            sessoes_validas_desde: $agora
          }
        } as $admin
      
        var.update $admin_criado_id {
          value = $admin.id
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_ADMIN"
            entidade    : "usuario"
            entidade_id : $admin.id
            dados_depois: {
            nome            : $admin.nome
            email           : $admin.email
            papel           : $admin.papel
            status_conta    : $admin.status_conta
            senha_provisoria: true
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem: "Administrador criado. Ele deverá trocar a senha no primeiro acesso."
    id      : $admin_criado_id
  }

  guid = "RMkCi4ueaiyXxHFzNTHbiclcbHk"
}