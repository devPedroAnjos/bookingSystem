// Recusa por bloqueio (C11, design D4): o intervalo pedido não pode se sobrepor a um bloqueio ATIVO
// do espaço (encostado não conta; REMOVIDO não impede). Usada pela criação de reserva, antes do
// conflito e do deslocamento (um bloqueio nunca é deslocado), pela entrada na fila e pela
// confirmação da vaga retida. A mensagem dá o tipo, nunca o motivo nem o autor (decisão 17).
// Recusa com o tipo do bloqueio, ou devolve true
function exigir_sem_bloqueio {
  input {
    int espaco_id
    int inicio
    int fim
  }

  stack {
    db.query bloqueio {
      where = $db.bloqueio.espaco_id == $input.espaco_id && $db.bloqueio.status == "ATIVO" && $db.bloqueio.inicio < $input.fim && $db.bloqueio.fim > $input.inicio
      sort = {inicio: "asc"}
      return = {type: "list"}
    } as $sobrepostos

    conditional {
      if (($sobrepostos|count) > 0) {
        var $tipo {
          value = ($sobrepostos|first).tipo
        }

        var $rotulo {
          value = "manutenção"
        }

        conditional {
          if ($tipo == "EVENTO") {
            var.update $rotulo {
              value = "evento"
            }
          }

          elseif ($tipo == "FERIADO") {
            var.update $rotulo {
              value = "feriado"
            }
          }
        }

        precondition (false) {
          error_type = "inputerror"
          error = "O espaço está bloqueado neste período (" ~ $rotulo ~ ")."
        }
      }
    }
  }

  response = true
  guid = "jBFaKVy-iJX7xKaQnLj-03dGjd4"
}
