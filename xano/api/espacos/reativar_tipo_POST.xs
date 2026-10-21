// Reativação de tipo de espaço por qualquer admin (spec tipos-espaco). Os espaços ativos do tipo,
// em unidades ativas, voltam a ser reserváveis sem nenhuma ação sobre eles.
// Reativa um tipo de espaço desativado, dentro da trava de governança
query reativar_tipo verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int tipo_espaco_id
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

        db.get tipo_espaco {
          field_name = "id"
          field_value = $input.tipo_espaco_id
        } as $tipo

        precondition ($tipo != null) {
          error_type = "notfound"
          error = "Tipo de espaço não encontrado."
        }

        precondition ($tipo.ativo != true) {
          error_type = "inputerror"
          error = "O tipo de espaço já está ativo."
        }

        db.edit tipo_espaco {
          field_name = "id"
          field_value = $tipo.id
          data = {ativo: true}
        } as $reativado

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "REATIVAR_TIPO_ESPACO"
            entidade    : "tipo_espaco"
            entidade_id : $tipo.id
            dados_antes : {ativo: false}
            dados_depois: {ativo: true}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Tipo de espaço reativado."}
  guid = "UfItqEo3lSqgAiD0-WOq5cXrn-s"
}
