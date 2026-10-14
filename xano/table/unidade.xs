// Campus ou prédio da instituição.
table unidade {
  auth = false

  schema {
    int id
    text nome filters=trim
    text endereco filters=trim
    bool ativa?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "nome"}]}
  ]

  guid = "smvUNO73QiH6ZV87eduV1h49iYc"
}