// Parâmetros globais do sistema (registro único). Cada change acrescenta os parâmetros que usar.
table configuracao_geral {
  auth = false

  schema {
    int id
  
    // Domínios de e-mail aceitos no cadastro (comparação exata com a parte após o @)
    text[] dominios_email
  
    // Limites da coordenação e do cadastro, preenchidos pelo bootstrap
    int? max_coordenadores_unidade?
  
    int? max_unidades_coordenador?
    int? max_pedidos_cadastro?
  
    // Máximo de administradores ativos, contando o principal
    int? max_admins?

    // Horário (C5): granularidade em minutos (divisor de 60) e dias de funcionamento em ISO
    // (1 = segunda a 7 = domingo). Preenchidos pelo bootstrap; lidos por obter_configuracao_horario.
    int? granularidade_minutos?

    int[] dias_funcionamento?

    // Reservas (C6, design D12): minutos antes do início até os quais o usuário cancela sem falta.
    // Preenchido pelo bootstrap; lido direto da tabela por cancelar_reserva e minhas_reservas.
    int? prazo_cancelamento_minutos?

    // Deslocamento por prioridade (C8, design D1): minutos que a nova reserva e cada deslocada
    // precisam estar, no mínimo, à frente do início. Preenchido pelo bootstrap; lido direto da
    // tabela por criar_reserva e buscar_espacos.
    int? prazo_deslocamento_minutos?

    // Fila de espera (C9, design D2 e D3): prazo para confirmar a vaga retida e corte da fila
    // antes do início (ou a antecedência mínima do tipo, se maior). Preenchido pelo bootstrap;
    // lido direto da tabela pelas rotas da fila, por processar_fila e por buscar_espacos.
    int? prazo_fila_minutos?

    // Fila de espera, update D12: prazo para confirmar a vaga retida, contado do aviso e limitado
    // ao corte, e tempo mínimo útil (o fechamento da fila é o corte menos este valor)
    int? prazo_confirmacao_fila_minutos?

    int? tempo_minimo_fila_minutos?

    // Check-in e penalidades (C10, design D1): janela de check-in em minutos antes e depois do
    // início, faltas para penalidade, janela das faltas e duração da penalidade em dias.
    // Preenchidos pelo bootstrap; lidos direto da tabela.
    int? checkin_antes_minutos?

    int? checkin_depois_minutos?
    int? faltas_para_penalidade?
    int? janela_faltas_dias?
    int? duracao_penalidade_dias?

    // Avaliação (change espaco-feed-avaliacoes, design D1): dias depois do término em que o dono
    // de uma reserva concluída pode avaliá-la. Preenchido pelo bootstrap; lido direto da tabela.
    int? prazo_avaliacao_dias?

    // Marco técnico (C10, decisão 20): reservas que começam antes dele seguem a regra anterior,
    // sem check-in nem falta. Gravado uma vez pelo bootstrap; não é parâmetro editável.
    timestamp? comparecimento_desde?
  }

  index = [{type: "primary", field: [{name: "id"}]}]
  guid = "VPFHLbqxacmD0JuqMtUJsYRt2Mg"
}