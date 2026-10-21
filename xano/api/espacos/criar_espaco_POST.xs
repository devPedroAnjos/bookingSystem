// Criação de espaço por admin (qualquer unidade) ou coordenador (só as que coordena)
// (spec espacos; design D4 e D6). Unidade e tipo precisam estar ativos e o código, livre na
// unidade. O espaço nasce ativo e sem recursos.
// Cria um espaço, dentro da trava de governança
query criar_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int unidade_id
    int tipo_espaco_id
    text nome? filters=trim
    text codigo? filters=trim
    int? capacidade?
    text localizacao? filters=trim
    text descricao? filters=trim
  }

  stack {
    var $nome {
      value = $input.nome|first_notnull:""
    }
  
    var $codigo {
      value = $input.codigo|first_notnull:""
    }
  
    var $localizacao {
      value = $input.localizacao|first_notnull:""
    }
  
    var $descricao {
      value = $input.descricao|first_notnull:""
    }
  
    precondition (($nome|strlen) > 0 && ($nome|strlen) <= 100) {
      error_type = "inputerror"
      error = "Informe o nome do espaço, com até 100 caracteres."
    }
  
    precondition (($codigo|strlen) > 0 && ($codigo|strlen) <= 20) {
      error_type = "inputerror"
      error = "Informe o código do espaço, com até 20 caracteres."
    }
  
    precondition ($input.capacidade != null && $input.capacidade >= 1) {
      error_type = "inputerror"
      error = "A capacidade deve ser de pelo menos 1."
    }
  
    precondition (($localizacao|strlen) <= 150) {
      error_type = "inputerror"
      error = "A localização deve ter até 150 caracteres."
    }
  
    precondition (($descricao|strlen) <= 500) {
      error_type = "inputerror"
      error = "A descrição deve ter até 500 caracteres."
    }
  
    var $espaco_criado_id {
      value = null
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run autorizar_unidade {
          input = {
            usuario_id: $auth.id
            unidade_id: $input.unidade_id
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
      
        precondition ($unidade.ativa) {
          error_type = "inputerror"
          error = "A unidade está desativada."
        }
      
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
          error = "O tipo de espaço está desativado."
        }
      
        function.run exigir_codigo_livre {
          input = {unidade_id: $unidade.id, codigo: $codigo}
        } as $codigo_livre
      
        db.add espaco {
          data = {
            unidade_id    : $unidade.id
            tipo_espaco_id: $tipo.id
            nome          : $nome
            codigo        : $codigo
            capacidade    : $input.capacidade
            localizacao   : $localizacao
            descricao     : $descricao
            ativo         : true
          }
        } as $espaco
      
        var.update $espaco_criado_id {
          value = $espaco.id
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_ESPACO"
            entidade    : "espaco"
            entidade_id : $espaco.id
            unidade_id  : $unidade.id
            dados_depois: {
            tipo_espaco_id: $espaco.tipo_espaco_id
            nome          : $espaco.nome
            codigo        : $espaco.codigo
            capacidade    : $espaco.capacidade
            localizacao   : $espaco.localizacao
            descricao     : $espaco.descricao
            ativo         : $espaco.ativo
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem : "Espaço criado."
    espaco_id: $espaco_criado_id
  }

  guid = "6IA-PmakAK1Xk29vqmYSqgwexAU"
}