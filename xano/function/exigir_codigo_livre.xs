// Código de espaço único dentro da unidade, sem diferenciar maiúsculas e minúsculas e sem espaços
// nas pontas (spec espacos; design D5). Vale também para espaços desativados.
// ignorar_id desconsidera o próprio espaço na edição e na mudança de unidade.
// Deve ser chamada dentro da trava de governança.
// Falha com 400 se a unidade já tem outro espaço com esse código
function exigir_codigo_livre {
  input {
    int unidade_id
    text codigo
    int? ignorar_id?
  }

  stack {
    var $codigo_normalizado {
      value = $input.codigo|trim|to_lower
    }

    db.query espaco {
      where = $db.espaco.unidade_id == $input.unidade_id && ($db.espaco.codigo|to_lower) == $codigo_normalizado && $db.espaco.id !=? $input.ignorar_id
      return = {type: "exists"}
    } as $codigo_em_uso

    precondition (!$codigo_em_uso) {
      error_type = "inputerror"
      error = "A unidade já tem um espaço com esse código."
    }
  }

  response = true
  guid = "vjye3UA_Vmh1PfnOs0zX29tviHE"
}
