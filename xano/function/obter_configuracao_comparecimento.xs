// Carrega a configuração geral e garante que os parâmetros de check-in e penalidade (C10, design D1)
// e o marco comparecimento_desde estão preenchidos. Separada de obter_configuracao e de
// obter_configuracao_horario, como elas (C5, D8). O código nunca usa valor padrão embutido: sem
// parâmetro, a operação falha. depois_ms já vem calculado para o predicado de ocupação (D2).
// Devolve o registro de configuração geral com depois_ms
function obter_configuracao_comparecimento {
  input {
  }

  stack {
    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao

    precondition ($configuracao != null && !($configuracao.checkin_antes_minutos|is_null) && !($configuracao.checkin_depois_minutos|is_null) && !($configuracao.faltas_para_penalidade|is_null) && !($configuracao.janela_faltas_dias|is_null) && !($configuracao.duracao_penalidade_dias|is_null) && !($configuracao.comparecimento_desde|is_null)) {
      error = "Configuração de reservas incompleta: execute o bootstrap."
    }

    var $depois_ms {
      value = $configuracao.checkin_depois_minutos * 60000
    }

    var $resultado {
      value = $configuracao|set:"depois_ms":$depois_ms
    }
  }

  response = $resultado
  guid = "dQWL0P3nn3Nt51HoEMKHuuE-Sio"
}
