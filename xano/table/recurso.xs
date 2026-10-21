// Catálogo global de recursos dos espaços (projetor, computadores, ar-condicionado...).
// Mantido pelo admin; excluído fisicamente só quando nenhum espaço o usa.
table recurso {
  auth = false

  schema {
    int id
    text nome filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "nome"}]}
  ]

  guid = "kSpJsM9KC7wGixWgSLKAFjqEtfs"
}