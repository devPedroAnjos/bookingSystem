// Situação efetiva de uma reserva (C7, design D2; C10, design D2). Todas as leituras usam esta regra:
// - PENDENTE cujo início já chegou sem decisão: EXPIRADA;
// - CONFIRMADA anterior ao marco comparecimento_desde: continua CONFIRMADA (regra anterior à C10);
// - CONFIRMADA sem check-in depois do fechamento da janela, min(inicio + checkin_depois, fim):
//   NAO_COMPARECEU (agora == fechamento ainda é CONFIRMADA);
// - CONFIRMADA com check-in cujo fim chegou: CONCLUIDA (agora == fim já é CONCLUIDA).
// Nas consultas ao banco, a mesma regra vira o predicado de ocupação (C10, D2):
// (PENDENTE && inicio > agora) || (CONFIRMADA && fim > agora && (check_in_em != null ||
// inicio >= agora - depois_ms || inicio < comparecimento_desde)).
// Devolve a situação que a reserva tem de fato no instante informado
function situacao_efetiva {
  input {
    text status

    // Instantes em ms
    int inicio

    int agora

    // C10: opcionais para os chamadores antigos continuarem válidos; sem eles, só a expiração vale
    int? fim?

    int? check_in_em?

    int? checkin_depois_minutos?

    int? comparecimento_desde?
  }

  stack {
    var $situacao {
      value = $input.status
    }

    conditional {
      if ($input.status == "PENDENTE" && $input.inicio <= $input.agora) {
        var.update $situacao {
          value = "EXPIRADA"
        }
      }

      elseif ($input.status == "CONFIRMADA" && !($input.fim|is_null) && !($input.checkin_depois_minutos|is_null) && !($input.comparecimento_desde|is_null)) {
        conditional {
          if ($input.inicio >= $input.comparecimento_desde) {
            conditional {
              if ($input.check_in_em|is_null) {
                var $depois_ms {
                  value = $input.checkin_depois_minutos * 60000
                }

                function.run fechamento_checkin {
                  input = {inicio: $input.inicio, fim: $input.fim, depois_ms: $depois_ms}
                } as $fechamento

                conditional {
                  if ($input.agora > $fechamento) {
                    var.update $situacao {
                      value = "NAO_COMPARECEU"
                    }
                  }
                }
              }

              elseif ($input.agora >= $input.fim) {
                var.update $situacao {
                  value = "CONCLUIDA"
                }
              }
            }
          }
        }
      }
    }
  }

  response = $situacao
  guid = "nDlldlArOX-OCfPzRsukMk52k6w"
}
