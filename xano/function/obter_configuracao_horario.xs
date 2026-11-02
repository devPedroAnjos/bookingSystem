// Carrega a configuração geral e garante que os parâmetros de horário estão preenchidos.
// Separada de obter_configuracao, que as rotas da C1 à C3 usam e não exige estes campos
// (design D8). O código nunca usa valor padrão embutido: sem parâmetro, a operação falha.
// Devolve o registro de configuração geral com granularidade e dias de funcionamento
function obter_configuracao_horario {
  input {
  }

  stack {
    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao

    precondition ($configuracao != null && $configuracao.granularidade_minutos != null && ($configuracao.dias_funcionamento|first_notnull:[]|count) > 0) {
      error = "Configuração de horário incompleta: execute o bootstrap."
    }
  }

  response = $configuracao
  guid = "eFiIWNI2ELKP02xqsTf-wK-aAR0"
}
