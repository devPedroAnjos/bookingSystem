// Renome de recurso por qualquer admin (spec recursos). Vale para todos os espaços que o têm,
// com as mesmas quantidades.
// Renomeia um recurso, dentro da trava de governança
query editar_recurso verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int recurso_id
    text nome? filters=trim
  }

  stack {
    var $nome {
      value = $input.nome|first_notnull:""
    }

    precondition (($nome|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o nome do recurso."
    }

    precondition (($nome|strlen) <= 60) {
      error_type = "inputerror"
      error = "O nome do recurso deve ter até 60 caracteres."
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

        db.get recurso {
          field_name = "id"
          field_value = $input.recurso_id
        } as $recurso

        precondition ($recurso != null) {
          error_type = "notfound"
          error = "Recurso não encontrado."
        }

        function.run exigir_nome_recurso_livre {
          input = {nome: $nome, ignorar_id: $recurso.id}
        } as $nome_livre

        db.edit recurso {
          field_name = "id"
          field_value = $recurso.id
          data = {nome: $nome}
        } as $editado

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "EDITAR_RECURSO"
            entidade    : "recurso"
            entidade_id : $recurso.id
            dados_antes : {nome: $recurso.nome}
            dados_depois: {nome: $editado.nome}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Recurso atualizado."}
  guid = "nkRPuIXhBX-RwVdib2As_XDUxWg"
}
