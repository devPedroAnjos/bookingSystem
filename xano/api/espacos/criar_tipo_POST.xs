// Criação de tipo de espaço por qualquer admin (spec tipos-espaco). O tipo nasce ativo e sem
// regras de uso, que chegam na C5 (design D2).
// Cria um tipo de espaço, dentro da trava de governança
query criar_tipo verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
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
  
    var $tipo_criado_id {
      value = null
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
      
        function.run exigir_nome_tipo_livre {
          input = {nome: $nome}
        } as $nome_livre
      
        db.add tipo_espaco {
          data = {nome: $nome, descricao: $descricao, ativo: true}
        } as $tipo
      
        var.update $tipo_criado_id {
          value = $tipo.id
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_TIPO_ESPACO"
            entidade    : "tipo_espaco"
            entidade_id : $tipo.id
            dados_depois: {
            nome     : $tipo.nome
            descricao: $tipo.descricao
            ativo    : $tipo.ativo
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem      : "Tipo de espaço criado."
    tipo_espaco_id: $tipo_criado_id
  }

  guid = "EgUsXR9ILIUyX1LiqSMm9MlxsJY"
}