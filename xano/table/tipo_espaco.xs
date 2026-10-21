// Categoria de espaço (sala de aula, laboratório, biblioteca, auditório e outras).
// As regras de uso do tipo e a regra por papel chegam na C5. Tipos nunca são excluídos.
table tipo_espaco {
  auth = false

  schema {
    int id
    text nome filters=trim
    text descricao? filters=trim
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "nome"}]}
  ]

  guid = "0WIX5mkMaz7ZIKrspsfvvDDzrNw"
}