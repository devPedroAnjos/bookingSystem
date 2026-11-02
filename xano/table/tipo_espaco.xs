// Categoria de espaço (sala de aula, laboratório, biblioteca, auditório e outras).
// Tem regras de uso próprias e a regra por papel em regra_papel. Tipos nunca são excluídos.
table tipo_espaco {
  auth = false

  schema {
    int id
    text nome filters=trim
    text descricao? filters=trim
    bool ativo?=true

    // Regras de uso (C5). Vazias = tipo sem regras, não reservável. Horários em minutos
    // desde a meia-noite (o Xano não tem `time`); 0 e false são gravados explicitamente.
    int? duracao_min_minutos?

    int? duracao_max_minutos?
    int? antecedencia_min_minutos?
    int? antecedencia_max_dias?
    int? max_reservas_ativas_usuario?
    int? hora_abertura_minutos?
    int? hora_fechamento_minutos?
    bool? permite_recorrencia?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "nome"}]}
  ]

  guid = "0WIX5mkMaz7ZIKrspsfvvDDzrNw"
}