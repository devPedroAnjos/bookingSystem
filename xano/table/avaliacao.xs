// Avaliação do uso de um espaço (change espaco-feed-avaliacoes, design D1): nota de 1 a 5 e
// comentário opcional do dono de uma reserva CONCLUIDA, até prazo_avaliacao_dias depois do término.
// Uma por reserva, garantida pelo índice único de reserva_id (design D2); sem edição nem exclusão.
// Sem espaco_id: a média por espaço junta com reserva em memória (avaliacoes_dos_espacos, D3).
table avaliacao {
  auth = false

  schema {
    int id

    int reserva_id {
      table = "reserva"
    }

    // Autor: o dono da reserva
    int usuario_id {
      table = "usuario"
    }

    // Inteiro de 1 a 5, validado pela rota avaliar_reserva
    int nota

    // Até 500 caracteres; vazio é gravado como ausente
    text comentario? filters=trim

    timestamp criado_em
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "reserva_id"}]}
    {type: "btree", field: [{name: "usuario_id"}]}
  ]
  guid = "7eP1gb55qJkd1oeISIrbn34P-5s"
}
