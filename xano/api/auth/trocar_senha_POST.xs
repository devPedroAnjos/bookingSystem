// Troca da própria senha (spec senha; design.md da C3, D8). Funciona também com senha provisória.
// Grava sessoes_validas_desde = now (derruba os tokens anteriores) e devolve um token novo,
// emitido depois disso, para a sessão atual continuar logada.
// Troca a senha do usuário autenticado e devolve um token novo
query trocar_senha verb=POST {
  api_group = "auth"
  auth = "usuario"

  input {
    text senha_atual? {
      sensitive = true
    }
  
    text nova_senha? {
      sensitive = true
    }
  }

  stack {
    var $nova_senha {
      value = $input.nova_senha|first_notnull:""
    }
  
    precondition (($nova_senha|strlen) >= 8) {
      error_type = "inputerror"
      error = "A nova senha deve ter pelo menos 8 caracteres."
    }
  
    function.run usuario_ativo {
      input = {
        usuario_id              : $auth.id
        emitido_em              : ($auth.extras|get:"emitido_em")|first_notnull:0
        permite_senha_provisoria: true
      }
    } as $usuario_publico
  
    db.get usuario {
      field_name = "id"
      field_value = $usuario_publico.id
    } as $usuario
  
    security.check_password {
      text_password = $input.senha_atual|first_notnull:""
      hash_password = $usuario.senha_hash
    } as $senha_atual_confere
  
    precondition ($senha_atual_confere) {
      error_type = "inputerror"
      error = "A senha atual está incorreta."
    }
  
    security.check_password {
      text_password = $nova_senha
      hash_password = $usuario.senha_hash
    } as $nova_igual_atual
  
    precondition (!$nova_igual_atual) {
      error_type = "inputerror"
      error = "A nova senha deve ser diferente da atual."
    }
  
    // Epoch em ms: sessoes_validas_desde é int, e now literal num campo int não é avaliado
    var $agora {
      value = now
    }
  
    db.transaction {
      stack {
        db.edit usuario {
          field_name = "id"
          field_value = $usuario.id
          data = {
            senha_hash           : $nova_senha
            senha_provisoria     : false
            sessoes_validas_desde: $agora
          }
        } as $atualizado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $usuario.id
            acao        : "TROCAR_SENHA"
            entidade    : "usuario"
            entidade_id : $usuario.id
            dados_antes : {senha_provisoria: $usuario.senha_provisoria == true}
            dados_depois: {senha_provisoria: false}
          }
        } as $registro_auditoria
      }
    }
  
    // Emitido depois da gravação: vale (emitido_em >= sessoes_validas_desde)
    function.run emitir_token {
      input = {usuario_id: $usuario.id}
    } as $token
  }

  response = {mensagem: "Senha alterada.", token: $token}
  guid = "QMFiE-D8QmXwBrm3hP0hSsJ88K8"
}