// Dados do usuário autenticado, sem senha nem hash.
// Devolve o usuário do token, se a conta estiver ATIVA
query me verb=GET {
  api_group = "auth"
  auth = "usuario"

  input {
  }

  stack {
    function.run usuario_ativo {
      input = {usuario_id: $auth.id}
    } as $usuario
  }

  response = $usuario
  guid = "x1iyxXL93IGY2zVSxLXRabbZwGY"
}