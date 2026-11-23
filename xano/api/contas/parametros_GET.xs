// Parâmetros editáveis pelo admin principal (spec parametros; design.md da C3, D9).
// Devolve os parâmetros atuais
query parametros verb=GET {
  api_group = "contas"
  auth = "usuario"

  input {
  }

  stack {
    function.run exigir_principal {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator
  
    function.run obter_configuracao as $configuracao
  }

  response = {
    dominios_email           : $configuracao.dominios_email
    max_coordenadores_unidade: $configuracao.max_coordenadores_unidade
    max_unidades_coordenador : $configuracao.max_unidades_coordenador
    max_pedidos_cadastro     : $configuracao.max_pedidos_cadastro
    max_admins               : $configuracao.max_admins
    granularidade_minutos    : $configuracao.granularidade_minutos
    dias_funcionamento       : $configuracao.dias_funcionamento
    prazo_cancelamento_minutos: $configuracao.prazo_cancelamento_minutos
    prazo_deslocamento_minutos: $configuracao.prazo_deslocamento_minutos
    prazo_fila_minutos        : $configuracao.prazo_fila_minutos
    prazo_confirmacao_fila_minutos: $configuracao.prazo_confirmacao_fila_minutos
    tempo_minimo_fila_minutos : $configuracao.tempo_minimo_fila_minutos
    checkin_antes_minutos     : $configuracao.checkin_antes_minutos
    checkin_depois_minutos    : $configuracao.checkin_depois_minutos
    faltas_para_penalidade    : $configuracao.faltas_para_penalidade
    janela_faltas_dias        : $configuracao.janela_faltas_dias
    duracao_penalidade_dias   : $configuracao.duracao_penalidade_dias
    prazo_avaliacao_dias      : $configuracao.prazo_avaliacao_dias
  }

  guid = "h6GVCCaN38gcd5oNxeK8RY3fNdw"
}