// Tabela técnica de exclusão mútua (fora do modelo de domínio).
// Um db.edit numa linha, como primeira instrução de uma transação, faz as transações
// concorrentes que editam a mesma linha esperarem até o commit ou rollback.
table trava {
  auth = false

  schema {
    int id
    text nome filters=trim
    timestamp? usado_em?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "nome"}]}
  ]

  guid = "atT0c91Aputw38suOgWNGl9fUU0"
}