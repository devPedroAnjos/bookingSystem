// Permissão de um admin sobre uma conta-alvo (design.md da C3, D5):
// - o principal nunca é alvo (400);
// - admins secundários só são alvo do principal (403 para os demais);
// - alunos, professores e coordenadores são alvo de qualquer admin.
// Deve ser chamada dentro da trava de governança.
// Devolve {ator, alvo} (o alvo é o registro completo: quem chama não repassa senha_hash)
function autorizar_sobre_conta {
  input {
    int ator_id
    int alvo_id
    int? emitido_em?
  }

  stack {
    function.run exigir_admin {
      input = {
        usuario_id: $input.ator_id
        emitido_em: $input.emitido_em
      }
    } as $ator
  
    db.get usuario {
      field_name = "id"
      field_value = $input.alvo_id
    } as $alvo
  
    precondition ($alvo != null) {
      error_type = "notfound"
      error = "Conta não encontrada."
    }
  
    precondition ($alvo.admin_principal != true) {
      error_type = "inputerror"
      error = "O administrador principal não pode ser alterado por esta operação."
    }
  
    precondition ($alvo.papel != "ADMIN" || $ator.admin_principal) {
      error_type = "accessdenied"
      error = "Só o administrador principal altera outros administradores."
    }
  }

  response = {ator: $ator, alvo: $alvo}
  guid = "wHRBFrV-q9A1XnLdnmqkKcM8CTA"
}