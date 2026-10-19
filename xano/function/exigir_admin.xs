// Garante que o usuário do token está ATIVA e tem papel ADMIN (design.md, D5).
// Devolve o usuário autenticado (sem senha), ou 401/403
function exigir_admin {
  input {
    int usuario_id
  }

  stack {
    function.run usuario_ativo {
      input = {usuario_id: $input.usuario_id}
    } as $usuario
  
    precondition ($usuario.papel == "ADMIN") {
      error_type = "accessdenied"
      error = "Acesso restrito à administração."
    }
  }

  response = $usuario
  guid = "gnnIUOhOAKRhQwKI8RwhMDQTzIE"
}