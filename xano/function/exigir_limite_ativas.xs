// Limite de reservas ativas no tipo atual do espaço (C6, design D5), extraído de criar_reserva
// (C9, design D7) sem mudar a mensagem. Ocupação pela situação efetiva (C7, D2; C10, D2): a
// pendente cujo início já chegou expirou e não conta; a confirmada sem check-in depois da janela
// (NAO_COMPARECEU) e a que já terminou também não. Entradas de fila não contam (não são reservas).
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

    function.run obter_configuracao_comparecimento as $comparecimento

    // Início mínimo de uma confirmada sem check-in que ainda está na janela
    var $inicio_minimo {
      value = $input.agora - $comparecimento.depois_ms
    }

    db.query reserva {
      where = $db.reserva.usuario_id == $input.usuario_id && $db.reserva.espaco_id in $ids_do_tipo && (($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $input.agora) || ($db.reserva.status == "CONFIRMADA" && $db.reserva.fim > $input.agora && ($db.reserva.check_in_em != null || $db.reserva.inicio >= $inicio_minimo || $db.reserva.inicio < $comparecimento.comparecimento_desde)))
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
