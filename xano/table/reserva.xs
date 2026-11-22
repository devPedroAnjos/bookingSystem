// Reserva de um espaço por um usuário (C6, design D1). Nunca é excluída; só muda de situação.
// Subconjunto do DER: serie_id (reserva recorrente, fora da v1) fica de fora. A decisão da
// aprovação entrou na C7 (design D1), o deslocamento na C8 (design D1), o check-in na C10 e o
// bloqueio_id na C11 (design D1).
table reserva {
  auth = false

  schema {
    int id
  
    // Dono da reserva: sempre quem a criou (não há reserva em nome de outra pessoa)
    int usuario_id {
      table = "usuario"
    }
  
    int espaco_id {
      table = "espaco"
    }
  
    // Instantes absolutos; as regras são avaliadas em America/Sao_Paulo
    timestamp inicio
  
    timestamp fim
  
    // Enum completo do DER, para as próximas changes não alterarem o tipo.
    // PENDENTE e CONFIRMADA ocupam o horário.
    enum status {
      values = [
        "PENDENTE"
        "CONFIRMADA"
        "CONCLUIDA"
        "NAO_COMPARECEU"
        "CANCELADA"
        "RECUSADA"
        "EXPIRADA"
      ]
    
    }
  
    // Nível do papel na criação: ALUNO 1, PROFESSOR 2, COORDENADOR e ADMIN 3
    int nivel_prioridade
  
    // Só DIRETA até agora; FILA (C9) e RECORRENTE (C12) depois
    enum origem {
      values = ["DIRETA", "FILA", "RECORRENTE"]
    }
  
    // Instante registrado pelo backend: desempate por ordem de criação (fila, C9)
    timestamp criado_em?=now
  
    // Quem executou a ação que cancelou: o dono, o gestor ou o admin que inativou a conta
    int? cancelado_por_id? {
      table = "usuario"
    }
  
    timestamp? cancelado_em?
  
    // Os cinco motivos do DER mais CONTA_INATIVADA e ESPACO_INDISPONIVEL (divergência, design D1)
    enum? motivo_cancelamento? {
      values = [
        "USUARIO"
        "USUARIO_TARDIO"
        "BLOQUEIO"
        "PRIORIDADE"
        "SERIE"
        "CONTA_INATIVADA"
        "ESPACO_INDISPONIVEL"
      ]
    
    }
  
    // Código do motivo da desativação (design D17), só em ESPACO_INDISPONIVEL por desativação
    text? motivo_detalhe? filters=trim
  
    // Descrição digitada quando o motivo da desativação é OUTRO
    text? motivo_descricao? filters=trim
  
    // Quem aprovou ou recusou a pendente (C7); a expiração não preenche a decisão
    int? decidido_por_id? {
      table = "usuario"
    }
  
    timestamp? decidido_em?
  
    // Motivo da recusa, de 1 a 500 caracteres, visível ao dono da reserva
    text? motivo_recusa? filters=trim

    // Reserva nova que deslocou esta por prioridade (C8); só no motivo PRIORIDADE
    int? deslocada_por_reserva_id? {
      table = "reserva"
    }

    // Instante do check-in feito pelo dono (C10, design D1); vazio sem check-in
    timestamp? check_in_em?

    // Bloqueio que cancelou esta reserva (C11, design D1); só no motivo BLOQUEIO
    int? bloqueio_id? {
      table = "bloqueio"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "espaco_id"}, {name: "inicio"}]
    }
    {type: "btree", field: [{name: "usuario_id"}]}
    {type: "btree", field: [{name: "status"}, {name: "inicio"}]}
  ]

  guid = "hdF1P-fQdw9P9jMe48QocezL2aY"
}