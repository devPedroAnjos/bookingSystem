// Entrada na fila de espera (C9, design D1). Nunca é excluída; só muda de situação.
// Ocupa o intervalo só enquanto NOTIFICADA e no prazo (vaga retida, design D4). O motivo e o
// instante real do encerramento e da expiração ficam na auditoria (design D8).
table entrada_fila {
  auth = false

  schema {
    int id

    // Dono da entrada: sempre quem entrou na fila
    int usuario_id {
      table = "usuario"
    }

    int espaco_id {
      table = "espaco"
    }

    // O intervalo exato pedido; instantes absolutos, regras avaliadas em America/Sao_Paulo
    timestamp inicio

    timestamp fim

    // Nível do papel na entrada: ALUNO 1, PROFESSOR 2, COORDENADOR e ADMIN 3
    int nivel_prioridade

    // AGUARDANDO e NOTIFICADA são ativas; as demais são finais
    enum status {
      values = [
        "AGUARDANDO"
        "NOTIFICADA"
        "ATENDIDA"
        "EXPIRADA"
        "DESISTIU"
        "ENCERRADA"
      ]

    }

    // Instante registrado pelo backend: desempate da ordem da fila
    timestamp criado_em?=now

    // Instante do aviso (passagem a NOTIFICADA)
    timestamp? notificado_em?

    // Fim do prazo para confirmar, inclusive; nunca depois do corte (design D3)
    timestamp? prazo_confirmacao?

    // Reserva criada pela confirmação
    int? reserva_gerada_id? {
      table = "reserva"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "espaco_id"}, {name: "status"}]
    }
    {type: "btree", field: [{name: "usuario_id"}]}
    {
      type : "btree"
      field: [{name: "status"}, {name: "prazo_confirmacao"}]
    }
  ]
  guid = "QBlpfVBqhWRN_pKbC4th66g4bqI"
}
