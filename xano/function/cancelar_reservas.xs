// Cancelamento em lote (C6, design D10 e D11), sem falta. Deve rodar dentro do db.transaction e da
// trava de governança de quem chama: inativação de conta (modo "conta", CONTA_INATIVADA), as
// ações de gestão sobre espaços, tipos e unidades (modo "espaco", ESPACO_INDISPONIVEL) e o
// deslocamento por prioridade (modo "prioridade", PRIORIDADE; C8, design D5).
// Nos modos conta e espaço, a seleção é a de selecionar_reservas_a_cancelar; no modo espaço, a rota
// já recusou antes de gravar se havia reserva confirmada em andamento, e essas nunca entram na
// seleção. No modo prioridade, a lista vem de criar_reserva, lida na mesma transação e já avaliada
// por avaliar_deslocamento, e cada reserva grava deslocada_por_reserva_id.
// O motivo da desativação (código e descrição de "Outro") só é gravado no modo espaço (D17).
// Gera um CANCELAR_RESERVA por reserva, com a unidade do espaço no momento do cancelamento.
// Cancela as reservas selecionadas e devolve a quantidade e o texto para a mensagem da rota
function cancelar_reservas {
  input {
    text modo
    int? usuario_id?
    json? espacos_ids?

    // Modo prioridade: as conflitantes deslocadas e a reserva nova que as deslocou
    json? reservas?

    int? deslocada_por_reserva_id?
    text motivo
    text? motivo_detalhe?
    text? motivo_descricao?
    int ator_id
    int agora
  }

  stack {
    var $reservas {
      value = []
    }

    var $deslocada_por {
      value = null
    }

    conditional {
      if ($input.modo == "prioridade") {
        var.update $reservas {
          value = $input.reservas|first_notnull:[]
        }

        var.update $deslocada_por {
          value = $input.deslocada_por_reserva_id
        }
      }

      else {
        function.run selecionar_reservas_a_cancelar {
          input = {
            modo       : $input.modo
            usuario_id : $input.usuario_id
            espacos_ids: $input.espacos_ids
            agora      : $input.agora
          }
        } as $selecao

        var.update $reservas {
          value = $selecao.reservas
        }
      }
    }

    var $detalhe {
      value = null
    }
  
    var $descricao {
      value = null
    }
  
    conditional {
      if ($input.modo == "espaco") {
        var.update $detalhe {
          value = $input.motivo_detalhe
        }
      
        var.update $descricao {
          value = $input.motivo_descricao
        }
      }
    }
  
    var $ids_espacos {
      value = $reservas|map:$$.espaco_id|unique
    }
  
    var $espacos {
      value = []
    }
  
    conditional {
      if (($ids_espacos|count) > 0) {
        db.query espaco {
          where = $db.espaco.id in $ids_espacos
          return = {type: "list"}
        } as $espacos_das_reservas
      
        var.update $espacos {
          value = $espacos_das_reservas
        }
      }
    }
  
    foreach ($reservas) {
      each as $reserva {
        var $espaco {
          value = $espacos|find:$$.id == $reserva.espaco_id
        }
      
        db.edit reserva {
          field_name = "id"
          field_value = $reserva.id
          data = {
            status             : "CANCELADA"
            motivo_cancelamento: $input.motivo
            motivo_detalhe     : $detalhe
            motivo_descricao   : $descricao
            cancelado_por_id   : $input.ator_id
            cancelado_em       : now
            deslocada_por_reserva_id: $deslocada_por
          }
        } as $cancelada

        var $dados_antes {
          value = {}|set:"status":$reserva.status
        }

        var $dados_depois {
          value = {}
            |set:"status":$cancelada.status
            |set:"motivo_cancelamento":$input.motivo
            |set:"motivo_detalhe":$detalhe
            |set:"motivo_descricao":$descricao
        }

        // Só o deslocamento registra a reserva que deslocou (spec auditoria)
        conditional {
          if ($input.modo == "prioridade") {
            var.update $dados_depois {
              value = $dados_depois|set:"deslocada_por_reserva_id":$deslocada_por
            }
          }
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $input.ator_id
            acao        : "CANCELAR_RESERVA"
            entidade    : "reserva"
            entidade_id : $reserva.id
            unidade_id  : $espaco.unidade_id
            dados_antes : $dados_antes
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
      }
    }
  
    var $quantidade {
      value = $reservas|count
    }
  
    // Complemento da mensagem de sucesso das rotas ("Espaço desativado. 3 reservas canceladas.")
    var $texto {
      value = ""
    }
  
    conditional {
      if ($quantidade == 1) {
        var.update $texto {
          value = " 1 reserva cancelada."
        }
      }
    
      elseif ($quantidade > 1) {
        var.update $texto {
          value = " " ~ $quantidade ~ " reservas canceladas."
        }
      }
    }
  
    var $resultado {
      value = {}
        |set:"quantidade":$quantidade
        |set:"texto":$texto
    }
  }

  response = $resultado
  guid = "J2I-PAxEton0hCKuh8yr5GLF9f8"
}