// Única porta de gravação dos vencimentos (C7, design D3 e D4). Pressupõe que quem chama já
// segura a trava de governança (use aplicar_vencimentos). Ordem:
// 1. Expiração (C7): grava EXPIRADA nas PENDENTE cujo início já chegou, com um EXPIRAR_RESERVA por
//    reserva, ator vazio e o instante real (o início). No máximo 50 por rodada, das que venceram
//    primeiro: o teto é técnico (33 vencidas levaram cerca de 3 s no teste 7.6 da C7), e o que
//    sobrar continua coberto pela situação efetiva (D2) e vai na próxima rodada.
// 2. Comparecimento do usuário informado (C10, D3), por inteiro, antes do lote global.
// 3. Comparecimento em lote (C10, D3): até 50 CONFIRMADA vencidas, por início, e no máximo 10
//    usuários distintos delas, cada um processado por inteiro (processar_vencimentos_usuario).
// 4. Cumprimento (C10, D3): até 50 ATIVA cujo fim chegou passam a CUMPRIDA, com CUMPRIR_PENALIDADE.
// 5. Fila (C9, D5): processar_fila expira as vagas retidas vencidas, encerra as entradas no
//    fechamento e avisa as filas liberadas, inclusive pelas pendentes que acabaram de expirar e
//    pelas entradas encerradas por penalidade.
// Grava os vencimentos já ocorridos e devolve quantas reservas expirou
function processar_vencimentos {
  input {
    // Instante de referência, em ms
    int agora

    // Usuário cujos vencimentos de comparecimento são processados por inteiro antes do lote
    int? usuario_id?
  }

  stack {
    // Parâmetros da C10 lidos primeiro: sem bootstrap, a faxina falha antes de qualquer gravação
    function.run obter_configuracao_comparecimento as $configuracao

    db.query reserva {
      where = $db.reserva.status == "PENDENTE" && $db.reserva.inicio <= $input.agora
      sort = {inicio: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 50, metadata: false}
      }
    } as $vencidas

    // Caso comum: nada vencido. Sem consulta com lista vazia (como em cancelar_reservas)
    conditional {
      if (($vencidas|count) > 0) {
        var $ids_espacos {
          value = $vencidas|map:$$.espaco_id|unique
        }

        db.query espaco {
          where = $db.espaco.id in $ids_espacos
          return = {type: "list"}
        } as $espacos

        foreach ($vencidas) {
          each as $reserva {
            db.edit reserva {
              field_name = "id"
              field_value = $reserva.id
              data = {status: "EXPIRADA"}
            } as $expirada

            var $espaco {
              value = $espacos|find:$$.id == $reserva.espaco_id
            }

            var $dados_antes {
              value = {}|set:"status":$reserva.status
            }

            var $dados_depois {
              value = {}
                |set:"status":$expirada.status
                |set:"expirou_em":$reserva.inicio
            }

            function.run registrar_auditoria {
              input = {
                ator_id     : null
                acao        : "EXPIRAR_RESERVA"
                entidade    : "reserva"
                entidade_id : $reserva.id
                unidade_id  : $espaco.unidade_id
                dados_antes : $dados_antes
                dados_depois: $dados_depois
              }
            } as $registro_auditoria
          }
        }
      }
    }

    var $quantidade {
      value = $vencidas|count
    }

    // 2. Usuário da operação, por inteiro
    conditional {
      if (!($input.usuario_id|is_null)) {
        function.run processar_vencimentos_usuario {
          input = {usuario_id: $input.usuario_id, agora: $input.agora}
        } as $do_usuario
      }
    }

    // 3. Lote global por usuário
    var $inicio_limite {
      value = $input.agora - $configuracao.depois_ms
    }

    db.query reserva {
      where = $db.reserva.status == "CONFIRMADA" && $db.reserva.inicio >= $configuracao.comparecimento_desde && (($db.reserva.check_in_em == null && ($db.reserva.inicio < $inicio_limite || $db.reserva.fim < $input.agora)) || ($db.reserva.check_in_em != null && $db.reserva.fim <= $input.agora))
      sort = {inicio: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 50, metadata: false}
      }
    } as $comparecimento_vencido

    conditional {
      if (($comparecimento_vencido|count) > 0) {
        var $usuarios_do_lote {
          value = $comparecimento_vencido|map:$$.usuario_id|unique|slice:0:10
        }

        foreach ($usuarios_do_lote) {
          each as $usuario_id {
            function.run processar_vencimentos_usuario {
              input = {usuario_id: $usuario_id, agora: $input.agora}
            } as $do_lote
          }
        }
      }
    }

    // 4. Cumprimento das penalidades, com o fim como instante real
    db.query penalidade {
      where = $db.penalidade.status == "ATIVA" && $db.penalidade.fim <= $input.agora
      sort = {fim: "asc"}
      return = {
        type  : "list"
        paging: {page: 1, per_page: 50, metadata: false}
      }
    } as $cumpridas

    foreach ($cumpridas) {
      each as $penalidade {
        db.edit penalidade {
          field_name = "id"
          field_value = $penalidade.id
          data = {status: "CUMPRIDA"}
        } as $cumprida

        var $dados_antes_cumprida {
          value = {}|set:"status":$penalidade.status
        }

        var $dados_depois_cumprida {
          value = {}
            |set:"status":$cumprida.status
            |set:"cumpriu_em":$penalidade.fim
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : null
            acao        : "CUMPRIR_PENALIDADE"
            entidade    : "penalidade"
            entidade_id : $penalidade.id
            unidade_id  : null
            dados_antes : $dados_antes_cumprida
            dados_depois: $dados_depois_cumprida
          }
        } as $registro_cumprida
      }
    }

    // 5. Fila de espera (C9, D5), na mesma transação e trava
    function.run processar_fila {
      input = {agora: $input.agora}
    } as $fila
  }

  response = $quantidade
  guid = "bPSHWf6cQqki571kpEh7paloLnE"
}
