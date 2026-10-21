// Correção de nome e endereço de uma unidade por qualquer admin (spec unidades).
// Situação e coordenações não mudam.
// Edita nome e endereço de uma unidade, dentro da trava de governança
query editar verb=POST {
  api_group = "unidades"
  auth = "usuario"

  input {
    int unidade_id
    text nome? filters=trim
    text endereco? filters=trim
  }

  stack {
    var $nome {
      value = $input.nome|first_notnull:""
    }
  
    var $endereco {
      value = $input.endereco|first_notnull:""
    }
  
    precondition (($nome|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o nome da unidade."
    }
  
    precondition (($endereco|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o endereço da unidade."
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
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_id
        } as $unidade
      
        precondition ($unidade != null) {
          error_type = "notfound"
          error = "Unidade não encontrada."
        }
      
        function.run exigir_nome_unidade_livre {
          input = {nome: $nome, ignorar_id: $unidade.id}
        } as $nome_livre
      
        db.edit unidade {
          field_name = "id"
          field_value = $unidade.id
          data = {nome: $nome, endereco: $endereco}
        } as $editada
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "EDITAR_UNIDADE"
            entidade    : "unidade"
            entidade_id : $unidade.id
            unidade_id  : $unidade.id
            dados_antes : {nome: $unidade.nome, endereco: $unidade.endereco}
            dados_depois: {nome: $editada.nome, endereco: $editada.endereco}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Unidade atualizada."}
  guid = "Qik8OLTy4VwBz9rYxQdTgSZwuFI"
}