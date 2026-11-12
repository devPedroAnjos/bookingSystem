// Recusa de reserva PENDENTE com motivo obrigatório (spec aprovacao-reservas; design D5 e D6).
// O motivo é validado antes da faxina, com as mesmas mensagens da recusa de cadastro: uma recusa
// por formato não aciona a faxina. Depois, como em aprovar_reserva.
// Recusa uma reserva pendente, dentro da trava de governança
query recusar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int reserva_id
    text motivo? filters=trim
  }

  stack {
    var $motivo {
      value = $input.motivo|first_notnull:""
    }

    precondition (($motivo|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o motivo da recusa."
    }

    precondition (($motivo|strlen) <= 500) {
      error_type = "inputerror"
      error = "O motivo deve ter no máximo 500 caracteres."
    }

    function.run aplicar_vencimentos as $vencimentos

    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run decidir_reserva {
          input = {
            ator_id   : $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
            reserva_id: $input.reserva_id
            decisao   : "RECUSAR"
            motivo    : $motivo
          }
        } as $status
      }
    }
  }

  response = {mensagem: "Reserva recusada."}
  guid = "vFoDJBPnCFcVqUKUDqI9hkZqWbI"
}
