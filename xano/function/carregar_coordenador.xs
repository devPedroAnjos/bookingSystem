// Carrega um coordenador ATIVA e as unidades que ele coordena (design.md, D9).
// Deve ser chamada dentro da trava de governança.
// Devolve {coordenador (sem senha), unidades_ids}, ou 400/404
function carregar_coordenador {
  input {
    int usuario_id
  }

  stack {
    db.get usuario {
      field_name = "id"
      field_value = $input.usuario_id
    } as $usuario
  
    precondition ($usuario != null) {
      error_type = "notfound"
      error = "Conta não encontrada."
    }
  
    precondition ($usuario.papel == "COORDENADOR" && $usuario.status_conta == "ATIVA") {
      error_type = "inputerror"
      error = "O usuário precisa ser um coordenador ativo."
    }
  
    function.run unidades_coordenadas {
      input = {usuario_id: $usuario.id}
    } as $unidades_ids
  }

  response = {
    coordenador : {id: $usuario.id, nome: $usuario.nome}
    unidades_ids: $unidades_ids
  }

  guid = "_mfYtBlcYDIHN7uB0qpPoXfqnJI"
}