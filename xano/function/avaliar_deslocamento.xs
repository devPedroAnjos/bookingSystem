// Regra única do deslocamento por prioridade (spec reservas; C8, design D2), usada por
// criar_reserva (que decide, dentro da trava) e por buscar_espacos (que só informa), para o aviso e
// a ação nunca divergirem. Função pura: quem chama monta as conflitantes, já filtradas pelo
// predicado de ocupação da situação efetiva (C7, D2).
// Deslocável só quando, ao mesmo tempo: há conflitantes; todas têm nivel_prioridade estritamente
// menor que o do solicitante; a nova reserva nasce CONFIRMADA; a nova e cada conflitante começam a
// MAIS DE prazo_minutos de agora (exatamente o prazo não basta, decisions-log 7 e 8), o que exclui
// a reserva em andamento.
// Diz se as conflitantes podem ser deslocadas e quantas são
function avaliar_deslocamento {
  input {
    // Reservas ativas sobrepostas ao pedido, com nivel_prioridade e inicio
    json conflitantes

    int nivel_solicitante

    // Instantes em ms
    int inicio_novo

    bool nasce_confirmada
    int prazo_minutos
    int agora
  }

  stack {
    var $lista {
      value = $input.conflitantes|first_notnull:[]
    }

    var $quantidade {
      value = $lista|count
    }

    // Instante a partir do qual (exclusive) a reserva ainda pode ser deslocada
    var $limite {
      value = $input.agora + ($input.prazo_minutos * 60000)
    }

    var $de_nivel_igual_ou_maior {
      value = $lista|filter:($$.nivel_prioridade >= $input.nivel_solicitante)
    }

    var $dentro_do_prazo {
      value = $lista|filter:($$.inicio <= $limite)
    }

    // Booleano composto calculado em conditional, nunca em value (lição da C5)
    var $deslocavel {
      value = false
    }

    conditional {
      if ($quantidade > 0 && ($de_nivel_igual_ou_maior|count) == 0 && ($dentro_do_prazo|count) == 0 && $input.nasce_confirmada && $input.inicio_novo > $limite) {
        var.update $deslocavel {
          value = true
        }
      }
    }

    var $avaliacao {
      value = {}
        |set:"deslocavel":$deslocavel
        |set:"quantidade":$quantidade
    }
  }

  response = $avaliacao
  guid = "ZDbNWCeLmA2wqLxs5i4k8g9id68"
}
