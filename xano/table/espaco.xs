// Local físico reservável de uma unidade. Nunca é excluído; só desativado.
// O código é único dentro da unidade (divergência do DER, design D2).
table espaco {
  auth = false

  schema {
    int id
    int unidade_id {
      table = "unidade"
    }
  
    int tipo_espaco_id {
      table = "tipo_espaco"
    }
  
    text nome filters=trim
    text codigo filters=trim
    int capacidade
    text localizacao? filters=trim
    text descricao? filters=trim
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "unidade_id"}, {name: "codigo"}]
    }
    {type: "btree", field: [{name: "tipo_espaco_id"}]}
  ]

  guid = "6bm9y3XuvQFtOayObYI6yWvRCtU"
}