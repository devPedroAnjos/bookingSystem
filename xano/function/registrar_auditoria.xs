// Insere um registro em log_auditoria. Quem chama monta dados_antes e dados_depois
// só com os campos permitidos, nunca com o registro inteiro (evita vazar senha_hash).
// Grava uma ação sensível no log de auditoria (somente inserção)
function registrar_auditoria {
  input {
    // Vazio quando a ação é do sistema
    int? ator_id?
  
    text acao
    text entidade
    int entidade_id
    int? unidade_id?
    json? dados_antes?
    json? dados_depois?
  }

  stack {
    db.add log_auditoria {
      data = {
        ator_id     : $input.ator_id
        acao        : $input.acao
        entidade    : $input.entidade
        entidade_id : $input.entidade_id
        unidade_id  : $input.unidade_id
        dados_antes : $input.dados_antes
        dados_depois: $input.dados_depois
        criado_em   : now
      }
    } as $registro
  }

  response = $registro
  guid = "kTIhFFHI6Pkzu9neKrhAv2iJaKI"
}