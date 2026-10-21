// Desativação de tipo de espaço por qualquer admin (spec tipos-espaco). Os espaços do tipo não
// mudam de situação, mas deixam de ser reserváveis (disponibilidade derivada, design D8).
// Desativa um tipo de espaço ativo, dentro da trava de governança
query desativar_tipo verb=POST {
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
      
        precondition ($tipo.ativo) {
          error_type = "inputerror"
          error = "O tipo de espaço já está desativado."
        }
      
        db.edit tipo_espaco {
          field_name = "id"
          field_value = $tipo.id
          data = {ativo: false}
        } as $desativado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "DESATIVAR_TIPO_ESPACO"
            entidade    : "tipo_espaco"
            entidade_id : $tipo.id
            dados_antes : {ativo: true}
            dados_depois: {ativo: false}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Tipo de espaço desativado."}
  guid = "keRDFe5AlCPuecBMGD0REByXbd4"
}