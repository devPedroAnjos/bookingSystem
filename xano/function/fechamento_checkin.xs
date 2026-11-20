// Fechamento da janela de check-in (C10, design D2; decisão 5): min(inicio + depois_ms, fim). O menor
// é calculado com conditional: |min e |max também são aliases das versões de lista (C9, corte_fila).
// Devolve o instante do fechamento, em ms
function fechamento_checkin {
  input {
    // Instantes em ms
    int inicio

    int fim

    int depois_ms
  }

  stack {
    var $fechamento {
      value = $input.inicio + $input.depois_ms
    }

    conditional {
      if ($input.fim < $fechamento) {
        var.update $fechamento {
          value = $input.fim
        }
      }
    }
  }

  response = $fechamento
  guid = "dlYd6a_sEFMoPIvtcJ9-lg0ZQ58"
}
