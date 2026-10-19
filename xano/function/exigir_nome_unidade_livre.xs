// Nome de unidade único, sem diferenciar maiúsculas e minúsculas e sem espaços nas pontas
// (spec unidades). ignorar_id desconsidera a própria unidade na edição.
// Deve ser chamada dentro da trava de governança.
// Falha com 400 se já existe outra unidade com esse nome
function exigir_nome_unidade_livre {
  input {
    text nome
    int? ignorar_id?
  }

  stack {
    var $nome_normalizado {
      value = $input.nome|trim|to_lower
    }
  
    db.query unidade {
      where = ($db.unidade.nome|to_lower) == $nome_normalizado && $db.unidade.id !=? $input.ignorar_id
      return = {type: "exists"}
    } as $nome_em_uso
  
    precondition (!$nome_em_uso) {
      error_type = "inputerror"
      error = "Já existe uma unidade com esse nome."
    }
  }

  response = true
  guid = "o5sJRUXaYtNb2lN4HXeaDs3zyH8"
}