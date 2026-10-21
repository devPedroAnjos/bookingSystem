// Nome de recurso único, sem diferenciar maiúsculas e minúsculas e sem espaços nas pontas
// (spec recursos). ignorar_id desconsidera o próprio recurso no renome.
// Deve ser chamada dentro da trava de governança.
// Falha com 400 se já existe outro recurso com esse nome
function exigir_nome_recurso_livre {
  input {
    text nome
    int? ignorar_id?
  }

  stack {
    var $nome_normalizado {
      value = $input.nome|trim|to_lower
    }

    db.query recurso {
      where = ($db.recurso.nome|to_lower) == $nome_normalizado && $db.recurso.id !=? $input.ignorar_id
      return = {type: "exists"}
    } as $nome_em_uso

    precondition (!$nome_em_uso) {
      error_type = "inputerror"
      error = "Já existe um recurso com esse nome."
    }
  }

  response = true
  guid = "TaHxiOZkDYmUbBTMnfONjSQdD74"
}
