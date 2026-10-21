// Escopo de unidade por papel (spec autorizacao): ADMIN em todas; COORDENADOR só nas que
// coordena no momento da requisição; os demais em nenhuma. Papel e coordenações vêm do banco.
// Devolve o usuário autenticado se ele tem escopo sobre a unidade, ou 401/403
function autorizar_unidade {
  input {
    int usuario_id
    int? unidade_id
    int? emitido_em?
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $input.usuario_id
        emitido_em: $input.emitido_em
      }
    } as $usuario
  
    var $autorizado {
      value = $usuario.papel == "ADMIN"
    }
  
    conditional {
      if ($usuario.papel == "COORDENADOR" && $input.unidade_id != null) {
        db.query coordenacao_unidade {
          where = $db.coordenacao_unidade.usuario_id == $usuario.id && $db.coordenacao_unidade.unidade_id == $input.unidade_id
          return = {type: "exists"}
        } as $coordena
      
        var.update $autorizado {
          value = $coordena
        }
      }
    }
  
    precondition ($autorizado) {
      error_type = "accessdenied"
      error = "Você não tem acesso a esta unidade."
    }
  }

  response = $usuario
  guid = "Vmz0CreDD4ElbdBtO9sGrqAJwYM"
}