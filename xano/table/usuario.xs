// Pessoa que acessa o sistema. Tabela de autenticação (JWT).
table usuario {
  auth = true

  schema {
    int id
    text nome filters=trim
    email email filters=trim|lower {
      sensitive = true
    }
  
    // Guarda apenas o hash: o tipo password aplica o hash ao gravar
    password senha_hash {
      sensitive = true
    }
  
    enum papel {
      values = ["ALUNO", "PROFESSOR", "COORDENADOR", "ADMIN"]
    }
  
    enum status_conta {
      values = ["PENDENTE", "ATIVA", "RECUSADA", "INATIVA"]
    }
  
    // Unidade informada no cadastro de professor (usada na aprovação)
    int? unidade_vinculo_id? {
      table = "unidade"
    }
  
    timestamp criado_em?=now
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "email"}]}
  ]

  guid = "hCdqCxMCxdqJFRt_kNjAhha7qz0"
}