// Edição dos parâmetros pelo admin principal (spec parametros; design.md da C3, D9).
// Limites inteiros >= 1; ao menos 1 domínio, sem @ nem espaço, sem repetição, em minúsculas.
// Reduzir um limite não remove ninguém. Se algo for inválido, nada é gravado.
// Grava os parâmetros, dentro da trava de governança
query parametros verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    text[]? dominios_email?
    int? max_coordenadores_unidade?
    int? max_unidades_coordenador?
    int? max_pedidos_cadastro?
    int? max_admins?
  }

  stack {
    var $dominios {
      value = ($input.dominios_email|first_notnull:[])|map:($$|trim|to_lower)
    }
  
    precondition (($dominios|count) > 0) {
      error_type = "inputerror"
      error = "Informe ao menos um domínio de e-mail."
    }
  
    precondition (!($dominios|some:(($$|strlen) == 0 || ($$|contains:"@") || ($$|contains:" ")))) {
      error_type = "inputerror"
      error = "Domínio inválido: informe só a parte após o @, sem espaços."
    }
  
    precondition (($dominios|unique|count) == ($dominios|count)) {
      error_type = "inputerror"
      error = "Há domínios repetidos."
    }
  
    var $limites {
      value = {
        max_coordenadores_unidade: $input.max_coordenadores_unidade
        max_unidades_coordenador : $input.max_unidades_coordenador
        max_pedidos_cadastro     : $input.max_pedidos_cadastro
        max_admins               : $input.max_admins
      }
    }
  
    foreach ($limites|keys) {
      each as $limite {
        precondition ((($limites|get:$limite)|first_notnull:0) >= 1) {
          error_type = "inputerror"
          error = "O parâmetro " ~ $limite ~ " deve ser um número inteiro a partir de 1."
        }
      }
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_principal {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        function.run obter_configuracao as $antes
        db.patch configuracao_geral {
          field_name = "id"
          field_value = $antes.id
          data = $limites|set:"dominios_email":$dominios
        } as $depois
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "ALTERAR_PARAMETROS"
            entidade    : "configuracao_geral"
            entidade_id : $antes.id
            dados_antes : {
            dominios_email           : $antes.dominios_email
            max_coordenadores_unidade: $antes.max_coordenadores_unidade
            max_unidades_coordenador : $antes.max_unidades_coordenador
            max_pedidos_cadastro     : $antes.max_pedidos_cadastro
            max_admins               : $antes.max_admins
          }
            dados_depois: {
            dominios_email           : $depois.dominios_email
            max_coordenadores_unidade: $depois.max_coordenadores_unidade
            max_unidades_coordenador : $depois.max_unidades_coordenador
            max_pedidos_cadastro     : $depois.max_pedidos_cadastro
            max_admins               : $depois.max_admins
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Parâmetros atualizados."}
  guid = "BXHSzuDMXhxXjpaSYGMa7TvzDyc"
}