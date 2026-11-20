// Geração e encadeamento da penalidade ao registrar uma falta (C10, design D5). Pressupõe a trava
// de governança e as faltas do usuário gravadas em ordem cronológica (D3).
// - Conta as faltas do usuário sem penalidade com ocorrida_em entre (falta - janela), inclusive, e a
//   própria falta, inclusive (decisão 15).
// - Com pelo menos faltas_para_penalidade, gera uma ATIVA que começa no instante da falta ou no fim
//   da última penalidade não anulada, o que for mais tarde, e vincula todas as faltas contadas.
// - Se a penalidade nasce em vigor no agora da operação, encerra as entradas de fila (D7).
// Dias corridos em ms: America/Sao_Paulo não tem horário de verão desde 2019.
// Devolve a penalidade gerada, ou null
function avaliar_penalidade {
  input {
    int usuario_id

    // Instante real da falta que acabou de ser registrada, em ms
    int ocorrida_em

    // Agora da operação, em ms
    int agora
  }

  stack {
    function.run obter_configuracao_comparecimento as $configuracao

    var $desde_janela {
      value = $input.ocorrida_em - ($configuracao.janela_faltas_dias * 86400000)
    }

    db.query falta {
      where = $db.falta.usuario_id == $input.usuario_id && $db.falta.penalidade_id == null && $db.falta.ocorrida_em >= $desde_janela && $db.falta.ocorrida_em <= $input.ocorrida_em
      sort = {ocorrida_em: "asc"}
      return = {type: "list"}
    } as $sem_penalidade

    var $penalidade {
      value = null
    }

    conditional {
      if (($sem_penalidade|count) >= $configuracao.faltas_para_penalidade) {
        // Encadeamento: nunca sobrepõe uma penalidade não anulada do usuário
        db.query penalidade {
          where = $db.penalidade.usuario_id == $input.usuario_id && $db.penalidade.status != "ANULADA"
          return = {type: "list"}
        } as $anteriores

        var $inicio {
          value = $input.ocorrida_em
        }

        conditional {
          if (($anteriores|count) > 0) {
            var $maior_fim {
              value = ($anteriores|map:$$.fim|max)|to_int
            }

            // conditional em vez de |max: o filtro também é alias de array_max (C9)
            conditional {
              if ($maior_fim > $inicio) {
                var.update $inicio {
                  value = $maior_fim
                }
              }
            }
          }
        }

        var $fim {
          value = $inicio + ($configuracao.duracao_penalidade_dias * 86400000)
        }

        db.add penalidade {
          data = {
            usuario_id: $input.usuario_id
            inicio    : $inicio
            fim       : $fim
            status    : "ATIVA"
            criado_em : now
          }
        } as $gerada

        foreach ($sem_penalidade) {
          each as $falta {
            db.edit falta {
              field_name = "id"
              field_value = $falta.id
              data = {penalidade_id: $gerada.id}
            } as $vinculada
          }
        }

        var $ids_faltas {
          value = $sem_penalidade|map:$$.id
        }

        var $dados_depois {
          value = {}
            |set:"status":$gerada.status
            |set:"inicio":$inicio
            |set:"fim":$fim
            |set:"faltas":$ids_faltas
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : null
            acao        : "APLICAR_PENALIDADE"
            entidade    : "penalidade"
            entidade_id : $gerada.id
            unidade_id  : null
            dados_antes : null
            dados_depois: $dados_depois
          }
        } as $registro

        // Penalidade que nasce em vigor encerra as entradas de fila (decisão 4)
        conditional {
          if ($inicio <= $input.agora && $input.agora < $fim) {
            function.run encerrar_entradas_penalizado {
              input = {usuario_id: $input.usuario_id}
            } as $encerradas
          }
        }

        var.update $penalidade {
          value = $gerada
        }
      }
    }
  }

  response = $penalidade
  guid = "PlTJhbi_j5S25mUaDKwBGHP7RVA"
}
