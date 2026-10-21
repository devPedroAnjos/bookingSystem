// Correção de nome e descrição de um tipo de espaço por qualquer admin (spec tipos-espaco).
// Situação e espaços do tipo não mudam.
// Edita um tipo de espaço, dentro da trava de governança
query editar_tipo verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int tipo_espaco_id
    text nome? filters=trim
    text descricao? filters=trim
  }

  stack {
    var $nome {
      value = $input.nome|first_notnull:""
    }

    var $descricao {
      value = $input.descricao|first_notnull:""
    }

    precondition (($nome|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o nome do tipo de espaço."
    }

    precondition (($nome|strlen) <= 60) {
      error_type = "inputerror"
      error = "O nome do tipo deve ter até 60 caracteres."
    }

    precondition (($descricao|strlen) <= 300) {
      error_type = "inputerror"
      error = "A descrição deve ter até 300 caracteres."
    }

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

        function.run exigir_nome_tipo_livre {
          input = {nome: $nome, ignorar_id: $tipo.id}
        } as $nome_livre

        db.edit tipo_espaco {
          field_name = "id"
          field_value = $tipo.id
          data = {nome: $nome, descricao: $descricao}
        } as $editado

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "EDITAR_TIPO_ESPACO"
            entidade    : "tipo_espaco"
            entidade_id : $tipo.id
            dados_antes : {nome: $tipo.nome, descricao: $tipo.descricao}
            dados_depois: {nome: $editado.nome, descricao: $editado.descricao}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Tipo de espaço atualizado."}
  guid = "FlJnR9byRLA0hcysmv22ORF-N44"
}
