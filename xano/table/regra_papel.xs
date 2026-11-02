// Regra por papel de um tipo de espaço: se o papel pode reservar e se exige aprovação.
// Só ALUNO e PROFESSOR; COORDENADOR e ADMIN têm regra fixa (design D4).
table regra_papel {
  auth = false

  schema {
    int id
    int tipo_espaco_id {
      table = "tipo_espaco"
    }
  
    text papel filters=trim|upper
    bool pode_reservar
    bool exige_aprovacao
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "tipo_espaco_id"}, {name: "papel"}]
    }
  ]

  guid = "LapyKgk9COIFT9at3AGdFUOERsQ"
}