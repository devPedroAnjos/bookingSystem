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
  
    // PENDENTE ou RECUSADA: unidade pedida no cadastro.
    // PROFESSOR ATIVA: unidade a que o professor pertence. Vazia para aluno e coordenador.
    int? unidade_vinculo_id? {
      table = "unidade"
    }
  
    timestamp criado_em?=now
  
    // Quem decidiu o pedido de cadastro (aprovação ou recusa) e quando
    int? aprovado_por_id? {
      table = "usuario"
    }
  
    timestamp? aprovado_em?
  
    // Preenchido apenas quando o último pedido foi recusado
    text? motivo_recusa_cadastro? filters=trim
  
    // Pedidos de cadastro enviados (cadastro inicial + reenvios)
    int pedidos_cadastro?=1
  
    // Justificativa opcional escrita no reenvio
    text? justificativa_cadastro? filters=trim
  
    // Recusa automática por desativação da unidade: o próximo reenvio não consome pedido.
    // Vazio equivale a falso (o Xano descarta o padrão false ao salvar).
    bool recusa_sem_custo?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "email"}]}
  ]

  guid = "hCdqCxMCxdqJFRt_kNjAhha7qz0"
}