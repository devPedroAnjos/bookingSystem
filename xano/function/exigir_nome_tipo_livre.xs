// Nome de tipo de espaço único, sem diferenciar maiúsculas e minúsculas e sem espaços nas pontas
// (spec tipos-espaco). ignorar_id desconsidera o próprio tipo na edição.
// Deve ser chamada dentro da trava de governança.
// Falha com 400 se já existe outro tipo com esse nome
function exigir_nome_tipo_livre {
  input {
    text nome
    int? ignorar_id?
  }

  stack {
    var $nome_normalizado {
      value = $input.nome|trim|to_lower
    }

    db.query tipo_espaco {
      where = ($db.tipo_espaco.nome|to_lower) == $nome_normalizado && $db.tipo_espaco.id !=? $input.ignorar_id
      return = {type: "exists"}
    } as $nome_em_uso

    precondition (!$nome_em_uso) {
      error_type = "inputerror"
      error = "Já existe um tipo de espaço com esse nome."
    }
  }

  response = true
  guid = "m2Oi-FRH8RWVP386_ViKdV1I6mg"
}
