// Dados do usuário autenticado, sem senha nem hash.
// Funciona também com senha provisória, para o frontend saber que precisa levar à troca.
// Devolve o usuário do token, se a conta estiver ATIVA
query me verb=GET {
  api_group = "auth"
  auth = "usuario"

  input {
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id              : $auth.id
        emitido_em              : ($auth.extras|get:"emitido_em")|first_notnull:0
        permite_senha_provisoria: true
      }
    } as $usuario
  }

  response = $usuario
  guid = "x1iyxXL93IGY2zVSxLXRabbZwGY"
}