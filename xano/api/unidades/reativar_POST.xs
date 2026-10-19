// Reativação de unidade pelo admin (spec unidades). Ela volta à listagem pública sem
// coordenadores e sem professores, até que alguém seja movido, acrescentado, transferido ou aprovado.
// Reativa uma unidade desativada, dentro da trava de governança
query reativar verb=POST {
  api_group = "unidades"
  auth = "usuario"

  input {
    int unidade_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {usuario_id: $auth.id}
        } as $ator
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_id
        } as $unidade
      
        precondition ($unidade != null) {
          error_type = "notfound"
          error = "Unidade não encontrada."
        }
      
        precondition (!$unidade.ativa) {
          error_type = "inputerror"
          error = "A unidade já está ativa."
        }
      
        db.edit unidade {
          field_name = "id"
          field_value = $unidade.id
          data = {ativa: true}
        } as $reativada
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "REATIVAR_UNIDADE"
            entidade    : "unidade"
            entidade_id : $unidade.id
            unidade_id  : $unidade.id
            dados_antes : {ativa: $unidade.ativa}
            dados_depois: {ativa: $reativada.ativa}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Unidade reativada."}
  guid = "wW8tam6s1d5eZB00N8zlMlJA1UM"
}