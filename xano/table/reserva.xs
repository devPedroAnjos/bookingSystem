// Reserva de um espaço por um usuário (C6, design D1). Nunca é excluída; só muda de situação.
// Subconjunto do DER: serie_id (C11), deslocamento (C8), bloqueio_id (C10) e check-in (C9)
// entram nas changes que os usarem. A decisão da aprovação entrou na C7 (design D1).
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
  
    // Só DIRETA nesta change; FILA (C8) e RECORRENTE (C11) depois
    enum origem {
      values = ["DIRETA", "FILA", "RECORRENTE"]
    }
  
    // Instante registrado pelo backend: desempate por ordem de criação (C8)
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