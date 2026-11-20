// Falta de um usuário (C10, design D1): não comparecimento ou cancelamento tardio. Nunca é excluída.
// Uma por reserva, garantido por registrar_falta dentro da trava de governança (C2, D3).
table falta {
  auth = false

  schema {
    int id

    // Dono da reserva que gerou a falta
    int usuario_id {
      table = "usuario"
    }

    int reserva_id {
      table = "reserva"
    }

    enum tipo {
      values = ["NAO_COMPARECIMENTO", "CANCELAMENTO_TARDIO"]
    }

    // Instante real: fechamento da janela de check-in ou instante do cancelamento
    timestamp ocorrida_em

    // Penalidade em que a falta entrou; vazio enquanto não contribuiu para nenhuma
    int? penalidade_id? {
      table = "penalidade"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "usuario_id"}, {name: "ocorrida_em"}]
    }
    {type: "btree", field: [{name: "reserva_id"}]}
  ]
  guid = "yBcpsy_zqnxnNIei2zL9XPLPE_o"
}
