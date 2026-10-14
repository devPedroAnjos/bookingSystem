// Registro imutável de ações sensíveis. Somente inserção.
table log_auditoria {
  auth = false

  schema {
    int id
  
    // Vazio quando a ação é do sistema
    int? ator_id? {
      table = "usuario"
    }
  
    text acao
    text entidade
    int entidade_id
    int? unidade_id? {
      table = "unidade"
    }
  
    json? dados_antes?
    json? dados_depois?
    timestamp criado_em?=now
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "criado_em", op: "desc"}]}
    {
      type : "btree"
      field: [{name: "entidade"}, {name: "entidade_id"}]
    }
  ]

  guid = "I4yjF82lE6guKwFjyjXvvrXj2Bg"
}