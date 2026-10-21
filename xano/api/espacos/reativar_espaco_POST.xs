// Reativação de espaço por quem tem escopo sobre a unidade dele (spec espacos). Não confere
// unidade nem tipo: se algum estiver desativado, o espaço fica ativo, mas não reservável.
// Reativa um espaço desativado, dentro da trava de governança
query reativar_espaco verb=POST {
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

        precondition ($carregado.espaco.ativo != true) {
          error_type = "inputerror"
          error = "O espaço já está ativo."
        }

        db.edit espaco {
          field_name = "id"
          field_value = $carregado.espaco.id
          data = {ativo: true}
        } as $reativado

        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "REATIVAR_ESPACO"
            entidade    : "espaco"
            entidade_id : $carregado.espaco.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : {ativo: false}
            dados_depois: {ativo: true}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Espaço reativado."}
  guid = "qJU1Q0nd1qUJvMqWTlexBmDnihc"
}
