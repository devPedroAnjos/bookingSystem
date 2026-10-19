// Carrega a configuração geral e garante que os parâmetros desta change estão preenchidos.
// O código nunca usa valor padrão embutido: sem parâmetro, a operação falha (design.md, D2).
// Devolve o registro de configuração geral com os limites preenchidos
function obter_configuracao {
  input {
  }

  stack {
    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao
  
    precondition ($configuracao != null && $configuracao.max_coordenadores_unidade != null && $configuracao.max_unidades_coordenador != null && $configuracao.max_pedidos_cadastro != null) {
      error = "Configuração incompleta: execute o bootstrap."
    }
  }

  response = $configuracao
  guid = "dqAgbdh_holOv9Z22HACaUPFtcw"
}