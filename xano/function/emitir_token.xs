// Emite o token de autenticação com o instante da emissão nos extras (design.md da C3, D3):
// usuario_ativo recusa tokens emitidos antes da última troca de senha.
// A duração vem de AUTH_TOKEN_TTL_SEGUNDOS. Usada pelo login e pela troca de senha.
// Devolve o token
function emitir_token {
  input {
    int usuario_id
  }

  stack {
    var $duracao_token {
      value = $env.AUTH_TOKEN_TTL_SEGUNDOS|first_notnull:0|to_int
    }
  
    precondition ($duracao_token > 0) {
      error = "Não foi possível entrar agora. Tente novamente mais tarde."
    }
  
    // now só é avaliado fora de objetos livres: em extras = {emitido_em: now} vira o texto "now"
    var $emitido_em {
      value = now
    }
  
    security.create_auth_token {
      table = "usuario"
      extras = {emitido_em: $emitido_em}
      expiration = $duracao_token
      id = $input.usuario_id
    } as $token
  }

  response = $token
  guid = "dtEZO5Qj8_dmaOZkSV43-U3ZvCk"
}