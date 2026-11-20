// Situação efetiva de uma entrada de fila (C9, design D3), no padrão de situacao_efetiva (C7):
// a NOTIFICADA cujo prazo já venceu é EXPIRADA, e a AGUARDANDO que chegou ao fechamento da fila
// (corte menos o tempo mínimo útil, D12) é ENCERRADA, mesmo antes de processar_fila gravar. Nas consultas ao banco, a vaga retida vira o predicado
// status == "NOTIFICADA" && prazo_confirmacao >= agora.
// Devolve a situação que a entrada tem de fato no instante informado
function situacao_efetiva_fila {
  input {
    text status

    // Instantes em ms; prazo_confirmacao só existe na NOTIFICADA e nas que passaram por ela
    int? prazo_confirmacao?

    // Fechamento da fila do intervalo (corte_fila), em ms
    int fechamento

    int agora
  }

  stack {
    var $situacao {
      value = $input.status
    }

    conditional {
      if ($input.status == "NOTIFICADA" && !($input.prazo_confirmacao|is_null)) {
        conditional {
          if ($input.prazo_confirmacao < $input.agora) {
            var.update $situacao {
              value = "EXPIRADA"
            }
          }
        }
      }

      elseif ($input.status == "AGUARDANDO" && $input.agora >= $input.fechamento) {
        var.update $situacao {
          value = "ENCERRADA"
        }
      }
    }
  }

  response = $situacao
  guid = "B7MXEuox-4Y3w5BgbrIisy_D4zU"
}
