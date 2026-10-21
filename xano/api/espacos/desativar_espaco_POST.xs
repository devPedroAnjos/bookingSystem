// Desativação de espaço por quem tem escopo sobre a unidade dele (spec espacos). Espaços nunca
// são excluídos; mantêm código, tipo e recursos. O efeito sobre reservas é da C6/C7 (design D13).
// Desativa um espaço ativo, dentro da trava de governança
query desativar_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $carregado
      
        precondition ($carregado.espaco.ativo) {
          error_type = "inputerror"
          error = "O espaço já está desativado."
        }
      
        db.edit espaco {
          field_name = "id"
          field_value = $carregado.espaco.id
          data = {ativo: false}
        } as $desativado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "DESATIVAR_ESPACO"
            entidade    : "espaco"
            entidade_id : $carregado.espaco.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : {ativo: true}
            dados_depois: {ativo: false}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Espaço desativado."}
  guid = "o_gJTefS-xtB4-GupUgUi0rotZs"
}