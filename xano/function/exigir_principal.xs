// Garante que o usuário do token é o admin principal (design.md da C3, D5).
// Usada pelas operações exclusivas do principal: admins e parâmetros.
// Devolve o usuário autenticado (sem senha), ou 401/403
function exigir_principal {
  input {
    int usuario_id
    int? emitido_em?
  }

  stack {
    function.run exigir_admin {
      input = {
        usuario_id: $input.usuario_id
        emitido_em: $input.emitido_em
      }
    } as $usuario
  
    precondition ($usuario.admin_principal) {
      error_type = "accessdenied"
      error = "Acesso restrito ao administrador principal."
    }
  }

  response = $usuario
  guid = "jC-edTI8NJcADe039t_k6HFgfBQ"
}