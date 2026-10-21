// Carrega o usuário do token e garante que a conta continua ATIVA.
// Toda rota autenticada chama esta função: inativar a conta corta o acesso mesmo com token válido.
// emitido_em vem da rota ($auth.extras não existe dentro de funções; design.md, D3): tokens
// emitidos antes da última troca ou redefinição de senha são recusados. Sem emitido_em, o token
// conta como antigo (0). Senha provisória só passa quando permite_senha_provisoria == true (D4).
// Devolve o usuário autenticado sem a senha, ou 401/403
function usuario_ativo {
  input {
    int usuario_id
    int? emitido_em?
    bool? permite_senha_provisoria?
  }

  stack {
    db.get usuario {
      field_name = "id"
      field_value = $input.usuario_id
    } as $usuario
  
    precondition ($usuario != null && $usuario.status_conta == "ATIVA") {
      error_type = "unauthorized"
      error = "Sessão inválida. Faça login novamente."
    }
  
    var $emitido_em {
      value = $input.emitido_em|first_notnull:0
    }
  
    precondition ($usuario.sessoes_validas_desde == null || $emitido_em >= $usuario.sessoes_validas_desde) {
      error_type = "unauthorized"
      error = "Sua sessão foi encerrada após uma troca de senha. Faça login novamente."
    }
  
    var $senha_provisoria {
      value = $usuario.senha_provisoria == true
    }
  
    precondition (!$senha_provisoria || $input.permite_senha_provisoria) {
      error_type = "accessdenied"
      error = "Troque sua senha para continuar."
    }
  
    var $usuario_publico {
      value = {
        id                : $usuario.id
        nome              : $usuario.nome
        email             : $usuario.email
        papel             : $usuario.papel
        status_conta      : $usuario.status_conta
        unidade_vinculo_id: $usuario.unidade_vinculo_id
        admin_principal   : $usuario.admin_principal == true
        senha_provisoria  : $senha_provisoria
      }
    }
  }

  response = $usuario_publico
  guid = "08T8VY1vB5N2nsEbZ5u4GPtNLUs"
}