// Bloqueio de um espaço por um período (C11, design D1): manutenção, evento ou feriado. Nunca é
// excluído; a remoção muda a situação para REMOVIDO e não restaura nada. Quem removeu e quando
// ficam no REMOVER_BLOQUEIO da auditoria, como no DER (sem campos de remoção).
table bloqueio {
  auth = false

  schema {
    int id

    int espaco_id {
      table = "espaco"
    }

    // Coordenador da unidade do espaço ou admin
    int criado_por_id {
      table = "usuario"
    }

    // Instantes absolutos; informados em America/Sao_Paulo e podendo cobrir vários dias
    timestamp inicio

    timestamp fim

    enum tipo {
      values = ["MANUTENCAO", "EVENTO", "FERIADO"]
    }

    // De 1 a 500 caracteres; interno da gestão, mostrado só ao dono da reserva cancelada
    text motivo filters=trim

    enum status {
      values = ["ATIVO", "REMOVIDO"]
    }

    timestamp criado_em?=now
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [
        {name: "espaco_id"}
        {name: "inicio"}
        {name: "fim"}
        {name: "status"}
      ]
    }
  ]
  guid = "llhR2wVFAKgCxW4C1HB371nMXOw"
}
