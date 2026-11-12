// Situação efetiva de uma reserva (C7, design D2): a PENDENTE cujo início já chegou sem decisão
// é EXPIRADA, mesmo antes de processar_vencimentos gravar. Todas as leituras usam esta regra.
// Nas consultas ao banco, a mesma regra vira o predicado de ocupação:
// status == "CONFIRMADA" || (status == "PENDENTE" && inicio > agora).
// Devolve a situação que a reserva tem de fato no instante informado
function situacao_efetiva {
  input {
    text status

    // Instantes em ms
    int inicio

    int agora
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
    }
  }

  response = $situacao
  guid = "nDlldlArOX-OCfPzRsukMk52k6w"
}
