// Criação de recurso no catálogo por qualquer admin (spec recursos).
// Cria um recurso, dentro da trava de governança
query criar_recurso verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
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
  
    var $recurso_criado_id {
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
      
        function.run exigir_nome_recurso_livre {
          input = {nome: $nome}
        } as $nome_livre
      
        db.add recurso {
          data = {nome: $nome}
        } as $recurso
      
        var.update $recurso_criado_id {
          value = $recurso.id
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_RECURSO"
            entidade    : "recurso"
            entidade_id : $recurso.id
            dados_depois: {nome: $recurso.nome}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem  : "Recurso criado."
    recurso_id: $recurso_criado_id
  }

  guid = "1nXzv1t2PUxtwFUpovLWhUdRfaE"
}