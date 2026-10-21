// Criação de unidade pelo admin, sempre com um coordenador (spec unidades; design.md, D10).
// modo MOVER: o coordenador sai da origem (que precisa continuar coberta).
// modo ACRESCENTAR: o coordenador fica também na unidade nova (respeitando o limite de unidades).
// Cria uma unidade ativa com seu primeiro coordenador, dentro da trava de governança
query criar verb=POST {
  api_group = "unidades"
  auth = "usuario"

  input {
    text nome? filters=trim
    text endereco? filters=trim
    int coordenador_id
    text modo filters=trim|upper
    int? origem_id?
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
  
    precondition ($input.modo == "MOVER" || $input.modo == "ACRESCENTAR") {
      error_type = "inputerror"
      error = "Escolha se o coordenador será movido ou acrescentado."
    }
  
    precondition ($input.modo != "MOVER" || $input.origem_id != null) {
      error_type = "inputerror"
      error = "Escolha a unidade de origem do coordenador."
    }
  
    var $unidade_criada_id {
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
      
        function.run exigir_nome_unidade_livre {
          input = {nome: $nome}
        } as $nome_livre
      
        function.run carregar_coordenador {
          input = {usuario_id: $input.coordenador_id}
        } as $carregado
      
        conditional {
          if ($input.modo == "MOVER") {
            precondition ($carregado.unidades_ids|in:$input.origem_id) {
              error_type = "inputerror"
              error = $carregado.coordenador.nome ~ " não coordena a unidade de origem."
            }
          
            function.run exigir_origem_coberta {
              input = {
                unidade_id: $input.origem_id
                usuario_id: $input.coordenador_id
              }
            } as $origem_coberta
          }
        
          else {
            function.run obter_configuracao as $configuracao
            precondition (($carregado.unidades_ids|count) < $configuracao.max_unidades_coordenador) {
              error_type = "inputerror"
              error = $carregado.coordenador.nome ~ " já coordena o máximo de unidades."
            }
          }
        }
      
        db.add unidade {
          data = {nome: $nome, endereco: $endereco, ativa: true}
        } as $unidade
      
        var.update $unidade_criada_id {
          value = $unidade.id
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "CRIAR_UNIDADE"
            entidade    : "unidade"
            entidade_id : $unidade.id
            unidade_id  : $unidade.id
            dados_depois: {
            nome    : $unidade.nome
            endereco: $unidade.endereco
            ativa   : $unidade.ativa
          }
          }
        } as $registro_auditoria
      
        conditional {
          if ($input.modo == "MOVER") {
            db.query coordenacao_unidade {
              where = $db.coordenacao_unidade.usuario_id == $input.coordenador_id && $db.coordenacao_unidade.unidade_id == $input.origem_id
              return = {type: "single"}
            } as $coordenacao_origem
          
            function.run remover_coordenacao {
              input = {
                ator_id       : $ator.id
                coordenacao_id: $coordenacao_origem.id
              }
            } as $removida
          }
        }
      
        function.run validar_destino_coordenador {
          input = {
            unidade_id: $unidade.id
            usuario_id: $input.coordenador_id
          }
        } as $destino
      
        function.run atribuir_coordenacao {
          input = {
            ator_id   : $ator.id
            usuario_id: $input.coordenador_id
            unidade_id: $unidade.id
          }
        } as $coordenacao
      }
    }
  }

  response = {
    mensagem  : "Unidade criada."
    unidade_id: $unidade_criada_id
  }

  guid = "c2VWn_Aef7t9pCmx7ocJwDVKP6I"
}