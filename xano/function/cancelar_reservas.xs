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
// C9 (design D5), nesta ordem, depois dos cancelamentos: nos modos conta e espaço, encerra as
// entradas de fila ativas da conta ou dos espaços (ENCERRAR_FILA com o ator e o motivo, e a unidade
// atual do espaço, que na mudança de unidade ainda é a de origem); depois, em todos os modos,
// processar_fila avisa as filas das vagas liberadas na mesma transação.
// C11 (design D3): modo "bloqueio" (espacos_ids com o espaço, inicio, fim e bloqueio_id), motivo
// BLOQUEIO. Cancela as reservas sobrepostas que ainda não começaram, grava o bloqueio_id e encerra
// só as entradas de fila sobrepostas ao período. Devolve também entradas_encerradas (todos os modos).
// Cancela as reservas selecionadas e devolve a quantidade e o texto para a mensagem da rota
function cancelar_reservas {
  input {
    text modo
    int? usuario_id?
    json? espacos_ids?

    // Modo prioridade: as conflitantes deslocadas e a reserva nova que as deslocou
    json? reservas?

    int? deslocada_por_reserva_id?

    // Modo bloqueio: o bloqueio gravado e o período dele
    int? bloqueio_id?
    int? inicio?
    int? fim?
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
            inicio     : $input.inicio
            fim        : $input.fim
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

    var $bloqueio {
      value = null
    }

    conditional {
      if ($input.modo == "bloqueio") {
        var.update $bloqueio {
          value = $input.bloqueio_id
        }
      }
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
            bloqueio_id        : $bloqueio
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

          // O cancelamento por bloqueio registra qual bloqueio o causou (C11)
          elseif ($input.modo == "bloqueio") {
            var.update $dados_depois {
              value = $dados_depois|set:"bloqueio_id":$bloqueio
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

    // Encerramento das entradas de fila (C9, D5): explícito, porque as rotas chamam esta função
    // antes de gravar a desativação, a nova unidade ou o novo tipo
    var $entradas_a_encerrar {
      value = []
    }

    conditional {
      if ($input.modo == "conta") {
        db.query entrada_fila {
          where = $db.entrada_fila.usuario_id == $input.usuario_id && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA")
          return = {type: "list"}
        } as $entradas_da_conta

        var.update $entradas_a_encerrar {
          value = $entradas_da_conta
        }
      }

      elseif ($input.modo == "espaco") {
        var $ids_espacos_fila {
          value = ($input.espacos_ids|first_notnull:[])|map:($$|to_int)
        }

        conditional {
          if (($ids_espacos_fila|count) > 0) {
            db.query entrada_fila {
              where = $db.entrada_fila.espaco_id in $ids_espacos_fila && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA")
              return = {type: "list"}
            } as $entradas_dos_espacos

            var.update $entradas_a_encerrar {
              value = $entradas_dos_espacos
            }
          }
        }
      }

      // C11: só as entradas do espaço cujo intervalo se sobrepõe ao bloqueio (encostado não conta)
      elseif ($input.modo == "bloqueio") {
        var $ids_espacos_bloqueio {
          value = ($input.espacos_ids|first_notnull:[])|map:($$|to_int)
        }

        db.query entrada_fila {
          where = $db.entrada_fila.espaco_id in $ids_espacos_bloqueio && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA") && $db.entrada_fila.inicio < $input.fim && $db.entrada_fila.fim > $input.inicio
          return = {type: "list"}
        } as $entradas_sobrepostas

        var.update $entradas_a_encerrar {
          value = $entradas_sobrepostas
        }
      }
    }

    conditional {
      if (($entradas_a_encerrar|count) > 0) {
        var $ids_espacos_entradas {
          value = $entradas_a_encerrar|map:$$.espaco_id|unique
        }

        db.query espaco {
          where = $db.espaco.id in $ids_espacos_entradas
          return = {type: "list"}
        } as $espacos_entradas

        foreach ($entradas_a_encerrar) {
          each as $entrada {
            db.edit entrada_fila {
              field_name = "id"
              field_value = $entrada.id
              data = {status: "ENCERRADA"}
            } as $encerrada

            var $espaco_entrada {
              value = $espacos_entradas|find:$$.id == $entrada.espaco_id
            }

            var $dados_antes_entrada {
              value = {}|set:"status":$entrada.status
            }

            var $dados_depois_entrada {
              value = {}
                |set:"status":$encerrada.status
                |set:"motivo":$input.motivo
            }

            function.run registrar_auditoria {
              input = {
                ator_id     : $input.ator_id
                acao        : "ENCERRAR_FILA"
                entidade    : "entrada_fila"
                entidade_id : $entrada.id
                unidade_id  : $espaco_entrada.unidade_id
                dados_antes : $dados_antes_entrada
                dados_depois: $dados_depois_entrada
              }
            } as $registro_encerramento
          }
        }
      }
    }

    // As vagas liberadas vão para as filas na mesma transação (C9, D5), em todos os modos
    function.run processar_fila {
      input = {agora: $input.agora}
    } as $fila

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
  
    var $entradas_encerradas {
      value = $entradas_a_encerrar|count
    }

    var $resultado {
      value = {}
        |set:"quantidade":$quantidade
        |set:"texto":$texto
        |set:"entradas_encerradas":$entradas_encerradas
    }
  }

  response = $resultado
  guid = "J2I-PAxEton0hCKuh8yr5GLF9f8"
}