// Exclusão mútua das operações de governança (design.md, D3).
// Deve ser a PRIMEIRA instrução de um db.transaction: o db.edit na linha "governanca" faz as
// transações concorrentes esperarem até o commit ou rollback desta. Depois dela, releia e valide.
// Pega a trava de governança dentro da transação atual
function travar_governanca {
  input {
  }

  stack {
    db.get trava {
      field_name = "nome"
      field_value = "governanca"
    } as $linha_trava
  
    precondition ($linha_trava != null) {
      error = "Configuração incompleta: execute o bootstrap."
    }
  
    db.edit trava {
      field_name = "id"
      field_value = $linha_trava.id
      data = {usado_em: now}
    } as $trava
  }

  response = true
  guid = "-SuqFvn3uvzgLpBWNQAeateKuh8"
}