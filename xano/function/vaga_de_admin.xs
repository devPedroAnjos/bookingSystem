// Garante que ainda cabe mais um admin ativo (spec administradores, "Limite de admins ativos").
// Só contam contas ADMIN com situação ATIVA, incluindo o principal.
// Deve ser chamada dentro da trava de governança.
// Falha com 400 se o limite de administradores ativos foi atingido
function vaga_de_admin {
  input {
  }

  stack {
    function.run obter_configuracao as $configuracao
    db.query usuario {
      where = $db.usuario.papel == "ADMIN" && $db.usuario.status_conta == "ATIVA"
      return = {type: "count"}
    } as $admins_ativos
  
    precondition ($admins_ativos < $configuracao.max_admins) {
      error_type = "inputerror"
      error = "O limite de administradores ativos foi atingido."
    }
  }

  response = true
  guid = "NEHtPwU81WgNHdPr7aVCxR43g1k"
}