// Edição de espaço por quem tem escopo sobre a unidade dele (spec espacos; design D4 e D6).
// Tipo ativo só é exigido quando o tipo muda. A edição não muda unidade nem situação.
// A auditoria guarda só os campos alterados. Trocar o tipo é recusado, sem alterar nenhum campo,
// com reserva confirmada em andamento; senão cancela as reservas que ainda não terminaram
// (ESPACO_INDISPONIVEL, sem motivo próprio). Editar sem trocar o tipo não toca reservas (C6, D10).
// Edita um espaço, dentro da trava de governança
query editar_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
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
  
    // Declarada fora da transação, como $unidade_criada_id em unidades/criar
    var $texto_cancelamento {
      value = ""
    }
  
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
      
        var $espaco {
          value = $carregado.espaco
        }
      
        var $tipo_mudou {
          value = false
        }
      
        var $agora {
          value = now
        }
      
        conditional {
          if ($input.tipo_espaco_id != $espaco.tipo_espaco_id) {
            var.update $tipo_mudou {
              value = true
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
          
            function.run exigir_sem_reserva_em_andamento {
              input = {espacos_ids: [$espaco.id], agora: $agora}
            } as $sem_reserva_em_uso
          }
        }
      
        function.run exigir_codigo_livre {
          input = {
            unidade_id: $espaco.unidade_id
            codigo    : $codigo
            ignorar_id: $espaco.id
          }
        } as $codigo_livre
      
        // Validações concluídas: só agora as gravações
        conditional {
          if ($tipo_mudou) {
            function.run cancelar_reservas {
              input = {
                modo       : "espaco"
                espacos_ids: [$espaco.id]
                motivo     : "ESPACO_INDISPONIVEL"
                ator_id    : $carregado.ator.id
                agora      : $agora
              }
            } as $cancelamento
          
            var.update $texto_cancelamento {
              value = $cancelamento.texto
            }
          }
        }
      
        db.edit espaco {
          field_name = "id"
          field_value = $espaco.id
          data = {
            tipo_espaco_id: $input.tipo_espaco_id
            nome          : $nome
            codigo        : $codigo
            capacidade    : $input.capacidade
            localizacao   : $localizacao
            descricao     : $descricao
          }
        } as $editado
      
        var $antes {
          value = {}
        }
      
        var $depois {
          value = {}
        }
      
        foreach ([
          "tipo_espaco_id"
          "nome"
          "codigo"
          "capacidade"
          "localizacao"
          "descricao"
        ]) {
          each as $campo {
            conditional {
              if ((($espaco|get:$campo)|first_notnull:"") != (($editado|get:$campo)|first_notnull:"")) {
                var.update $antes {
                  value = $antes|set:$campo:($espaco|get:$campo)
                }
              
                var.update $depois {
                  value = $depois|set:$campo:($editado|get:$campo)
                }
              }
            }
          }
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "EDITAR_ESPACO"
            entidade    : "espaco"
            entidade_id : $espaco.id
            unidade_id  : $espaco.unidade_id
            dados_antes : $antes
            dados_depois: $depois
          }
        } as $registro_auditoria
      }
    }
  
    var $mensagem {
      value = "Espaço atualizado." ~ $texto_cancelamento
    }
  }

  response = {mensagem: $mensagem}
  guid = "mAwWmNMwnYBAlPtedClH9lYDmvM"
}