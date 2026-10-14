// Carrega o usuário do token e garante que a conta continua ATIVA.
// Toda rota autenticada chama esta função: inativar a conta corta o acesso mesmo com token válido.
// Devolve o usuário autenticado sem a senha, ou erro 401 se a conta não existe ou não está ATIVA
function usuario_ativo {
  input {
    int usuario_id
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
  
    var $usuario_publico {
      value = {
        id                : $usuario.id
        nome              : $usuario.nome
        email             : $usuario.email
        papel             : $usuario.papel
        status_conta      : $usuario.status_conta
        unidade_vinculo_id: $usuario.unidade_vinculo_id
      }
    }
  }

  response = $usuario_publico
  guid = "08T8VY1vB5N2nsEbZ5u4GPtNLUs"
}