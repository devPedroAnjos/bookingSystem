// Penalidade de um usuário (C10, design D1). Nunca é excluída; só muda de situação.
// Em vigor quando ATIVA e inicio <= agora < fim; fim - inicio é a duração, preservada na antecipação.
// parecer: divergência do DER, exigido pelo §2.13 na anulação.
table penalidade {
  auth = false

  schema {
    int id

    int usuario_id {
      table = "usuario"
    }

    timestamp inicio

    timestamp fim

    enum status {
      values = ["ATIVA", "CUMPRIDA", "ANULADA"]
    }

    timestamp criado_em?=now

    // Admin que anulou
    int? anulada_por_id? {
      table = "usuario"
    }

    timestamp? anulada_em?

    // Parecer da anulação, de 1 a 500 caracteres, visível ao dono sem o nome de quem anulou
    text? parecer? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "usuario_id"}, {name: "status"}]
    }
    {
      type : "btree"
      field: [{name: "status"}, {name: "fim"}]
    }
  ]
  guid = "GykODURLVIKBNnxw09t1oExuLBE"
}
