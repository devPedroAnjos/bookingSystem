// Vínculo entre um coordenador e uma unidade que ele coordena.
// A remoção apaga a linha; o histórico fica em log_auditoria.
table coordenacao_unidade {
  auth = false

  schema {
    int id
    int usuario_id {
      table = "usuario"
    }
  
    int unidade_id {
      table = "unidade"
    }
  
    timestamp desde?=now
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "usuario_id"}, {name: "unidade_id"}]
    }
    {type: "btree", field: [{name: "unidade_id"}]}
  ]

  guid = "gZr4AzenqID7dPUcPXX3iIlREGY"
}