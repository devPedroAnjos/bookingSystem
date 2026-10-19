// Transferência de professor para outra unidade ativa, só pelo admin (spec papeis; design.md, D9).
// O pedido de transferência acontece fora do sistema. Papel, situação e reservas não mudam.
// Transfere um professor ativo de unidade, dentro da trava de governança
query transferir_professor verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    int unidade_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {usuario_id: $auth.id}
        } as $ator
      
        db.get usuario {
          field_name = "id"
          field_value = $input.usuario_id
        } as $alvo
      
        precondition ($alvo != null) {
          error_type = "notfound"
          error = "Conta não encontrada."
        }
      
        precondition ($alvo.papel == "PROFESSOR" && $alvo.status_conta == "ATIVA") {
          error_type = "inputerror"
          error = "Só professores ativos são transferidos."
        }
      
        precondition ($alvo.unidade_vinculo_id != $input.unidade_id) {
          error_type = "inputerror"
          error = "O professor já pertence a essa unidade."
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_id
        } as $destino
      
        precondition ($destino != null && $destino.ativa) {
          error_type = "inputerror"
          error = "A unidade de destino precisa existir e estar ativa."
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $alvo.id
          data = {unidade_vinculo_id: $destino.id}
        } as $transferido
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "TRANSFERIR_PROFESSOR"
            entidade    : "usuario"
            entidade_id : $alvo.id
            unidade_id  : $destino.id
            dados_antes : {unidade_vinculo_id: $alvo.unidade_vinculo_id}
            dados_depois: {unidade_vinculo_id: $transferido.unidade_vinculo_id}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Professor transferido."}
  guid = "99vzdCtsW1REdT--guA0KHEGsxw"
}