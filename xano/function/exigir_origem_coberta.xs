// Garante que a unidade de origem continua com pelo menos um coordenador ativo
// além do que está saindo (reorganização nunca esvazia a origem; spec coordenacao).
// Deve ser chamada dentro da trava de governança.
// Falha com 400 se a origem ficaria sem coordenador ativo
function exigir_origem_coberta {
  input {
    int unidade_id
    int usuario_id
  }

  stack {
    function.run coordenadores_ativos {
      input = {unidade_id: $input.unidade_id}
    } as $coordenadores
  
    var $restantes {
      value = $coordenadores|filter:$$.id != $input.usuario_id
    }
  
    db.get unidade {
      field_name = "id"
      field_value = $input.unidade_id
    } as $unidade
  
    precondition (($restantes|count) > 0) {
      error_type = "inputerror"
      error = "A unidade " ~ ($unidade.nome|first_notnull:"de origem") ~ " ficaria sem coordenador."
    }
  }

  response = true
  guid = "3UipWEMDmof348HmU-Ttbgzo6BQ"
}