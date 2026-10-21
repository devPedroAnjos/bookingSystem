// Recursos de um espaço, com a quantidade de cada um.
// Redefinir os recursos apaga as linhas; o histórico fica em log_auditoria.
table espaco_recurso {
  auth = false

  schema {
    int id
    int espaco_id {
      table = "espaco"
    }
  
    int recurso_id {
      table = "recurso"
    }
  
    int quantidade
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "espaco_id"}, {name: "recurso_id"}]
    }
    {type: "btree", field: [{name: "recurso_id"}]}
  ]

  guid = "1PPoAch63F44xZ91rWsGdKRl7jc"
}