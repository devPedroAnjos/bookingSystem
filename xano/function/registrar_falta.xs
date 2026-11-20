// Registro de uma falta (C10, design D4). Pressupõe a trava de governança. Uma falta por reserva:
// a segunda é recusada por proteção, porque as rotas não deveriam chegar lá. Grava a falta com um
// REGISTRAR_FALTA (ator vazio no não comparecimento; o dono no cancelamento tardio) e avalia a
// penalidade (D5).
// Devolve a falta e a penalidade gerada, se houver
function registrar_falta {
  input {
    int usuario_id
    int reserva_id

    // NAO_COMPARECIMENTO ou CANCELAMENTO_TARDIO
    text tipo

    // Instante real, em ms: fechamento da janela ou instante do cancelamento
    int ocorrida_em

    // Vazio quando a falta é registrada pelo sistema
    int? ator_id?

    // Unidade do espaço da reserva, para a auditoria
    int? unidade_id?

    // Agora da operação, em ms
    int agora
  }

  stack {
    precondition ($input.tipo == "NAO_COMPARECIMENTO" || $input.tipo == "CANCELAMENTO_TARDIO") {
      error = "Tipo de falta inválido."
    }

    db.query falta {
      where = $db.falta.reserva_id == $input.reserva_id
      return = {type: "exists"}
    } as $repetida

    precondition (!$repetida) {
      error = "Esta reserva já tem falta registrada."
    }

    db.add falta {
      data = {
        usuario_id : $input.usuario_id
        reserva_id : $input.reserva_id
        tipo       : $input.tipo
        ocorrida_em: $input.ocorrida_em
      }
    } as $falta

    var $dados_depois {
      value = {}
        |set:"tipo":$falta.tipo
        |set:"reserva_id":$falta.reserva_id
        |set:"ocorrida_em":$input.ocorrida_em
    }

    function.run registrar_auditoria {
      input = {
        ator_id     : $input.ator_id
        acao        : "REGISTRAR_FALTA"
        entidade    : "falta"
        entidade_id : $falta.id
        unidade_id  : $input.unidade_id
        dados_antes : null
        dados_depois: $dados_depois
      }
    } as $registro

    function.run avaliar_penalidade {
      input = {
        usuario_id : $input.usuario_id
        ocorrida_em: $input.ocorrida_em
        agora      : $input.agora
      }
    } as $penalidade

    var $resultado {
      value = {}
        |set:"falta":$falta
        |set:"penalidade":$penalidade
    }
  }

  response = $resultado
  guid = "8QLIV_w7hrm5z5oI6jvYSIFDz74"
}
