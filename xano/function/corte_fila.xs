// Corte e fechamento da fila de um intervalo (C9, design D3 e D12).
// corte = inicio menos o maior entre prazo_fila_minutos e a antecedência mínima do tipo atual do
// espaço; nenhuma confirmação passa dele. fechamento = corte menos tempo_minimo_fila_minutos; a
// partir dele, inclusive, ninguém entra na fila, ninguém é avisado e as AGUARDANDO ficam ENCERRADA.
// O maior é calculado com conditional: |max também é o alias de array_max (Confirmações do apply).
// Devolve {corte, fechamento}, em ms
function corte_fila {
  input {
    // Início do intervalo da fila, em ms
    int inicio

    int prazo_fila_minutos

    // Antecedência mínima do tipo (0 quando o tipo não exige)
    int antecedencia_min_minutos

    int tempo_minimo_fila_minutos
  }

  stack {
    var $minutos {
      value = $input.prazo_fila_minutos
    }

    conditional {
      if ($input.antecedencia_min_minutos > $input.prazo_fila_minutos) {
        var.update $minutos {
          value = $input.antecedencia_min_minutos
        }
      }
    }

    var $corte {
      value = $input.inicio - ($minutos * 60000)
    }

    var $fechamento {
      value = $corte - ($input.tempo_minimo_fila_minutos * 60000)
    }

    var $resultado {
      value = {}
        |set:"corte":$corte
        |set:"fechamento":$fechamento
    }
  }

  response = $resultado
  guid = "at9TaoKm1-b20mvMsQ0sQnF3RJA"
}
