// Exclusão de recurso por qualquer admin, só quando nenhum espaço, ativo ou desativado, o usa
// (spec recursos). A conferência roda dentro da trava, a mesma de definir_recursos, para que
// nenhum espaço fique apontando para um recurso excluído.
// Exclui um recurso sem uso, dentro da trava de governança
query excluir_recurso verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int recurso_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator

        db.get recurso {
          field_name = "id"
          field_value = $input.recurso_id
        } as $recurso

        precondition ($recurso != null) {
          error_type = "notfound"
          error = "Recurso não encontrado."
        }

        db.query espaco_recurso {
          where = $db.espaco_recurso.recurso_id == $recurso.id
          return = {type: "count"}
        } as $em_uso

        precondition ($em_uso == 0) {
          error_type = "inputerror"
          error = "O recurso é usado por " ~ $em_uso ~ " espaço(s)."
        }

        db.del recurso {
          field_name = "id"
          field_value = $recurso.id
        }

        function.run registrar_auditoria {
          input = {
            ator_id    : $ator.id
            acao       : "EXCLUIR_RECURSO"
            entidade   : "recurso"
            entidade_id: $recurso.id
            dados_antes: {nome: $recurso.nome}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Recurso excluído."}
  guid = "tH8kjC-XuNBT85uN1nGsAP8bxIw"
}
