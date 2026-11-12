// Aprovação de reserva PENDENTE pelo coordenador da unidade atual do espaço ou por um admin
// (spec aprovacao-reservas; design D5 e D6). A faxina de vencimentos roda antes, em transação
// própria; dentro da trava, decidir_reserva faz a autorização, as recusas e a gravação.
// Aprova uma reserva pendente, dentro da trava de governança
query aprovar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int reserva_id
  }

  stack {
    function.run aplicar_vencimentos as $vencimentos

    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run decidir_reserva {
          input = {
            ator_id   : $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
            reserva_id: $input.reserva_id
            decisao   : "APROVAR"
          }
        } as $status
      }
    }
  }

  response = {mensagem: "Reserva aprovada."}
  guid = "0B30dRhLsVny89KoGmMNaKyPF4c"
}
