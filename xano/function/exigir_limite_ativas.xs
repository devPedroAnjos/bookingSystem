// Limite de reservas ativas no tipo atual do espaço (C6, design D5), extraído de criar_reserva
// (C9, design D7) sem mudar a contagem nem a mensagem. fim > agora porque, até a C10, reservas
// passadas continuam CONFIRMADA. Ocupação pela situação efetiva (C7, D2): a pendente cujo início
// já chegou expirou e não conta. Entradas de fila não contam (não são reservas).
// Recusa (400) quando o usuário já tem o máximo de reservas ativas no tipo
function exigir_limite_ativas {
  input {
    int usuario_id
    int tipo_espaco_id
    int max_reservas_ativas_usuario

    // Instante lido dentro da trava, em ms
    int agora
  }

  stack {
    db.query espaco {
      where = $db.espaco.tipo_espaco_id == $input.tipo_espaco_id
      return = {type: "list"}
    } as $espacos_do_tipo

    var $ids_do_tipo {
      value = $espacos_do_tipo|map:$$.id
    }

    db.query reserva {
      where = $db.reserva.usuario_id == $input.usuario_id && $db.reserva.espaco_id in $ids_do_tipo && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $input.agora)) && $db.reserva.fim > $input.agora
      return = {type: "count"}
    } as $ativas_no_tipo

    precondition ($ativas_no_tipo < $input.max_reservas_ativas_usuario) {
      error_type = "inputerror"
      error = "Você já tem o máximo de " ~ $input.max_reservas_ativas_usuario ~ " reservas ativas neste tipo de espaço."
    }
  }

  response = true
  guid = "-HM4JbU_QOBGrQivtA6HSlFpfps"
}
