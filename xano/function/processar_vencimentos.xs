// Única porta de gravação dos vencimentos (C7, design D3 e D4). Pressupõe que quem chama já
// segura a trava de governança (use aplicar_vencimentos). Nesta change: grava EXPIRADA nas
// PENDENTE cujo início já chegou, com um EXPIRAR_RESERVA por reserva, ator vazio e o instante real
// do vencimento (o início). No máximo 50 por rodada, das que venceram primeiro: o teto é técnico
// (33 vencidas levaram cerca de 3 s no teste 7.6), e o que sobrar continua coberto pela situação
// efetiva (D2) e vai na próxima rodada.
// As próximas changes (C8, C9) acrescentam aqui os seus vencimentos.
// Grava os vencimentos já ocorridos e devolve quantas reservas expirou
function processar_vencimentos {
  input {
    // Instante de referência, em ms
    int agora
  }

  stack {
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
  }

  response = $quantidade
  guid = "bPSHWf6cQqki571kpEh7paloLnE"
}
