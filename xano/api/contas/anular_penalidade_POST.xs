// Anulação de penalidade pelo admin (spec penalidades; C10, design D6). Só admin, só uma ATIVA cujo
// fim ainda não chegou (em vigor ou futura), com parecer de 1 a 500 caracteres, e ninguém anula a
// própria (decisão 14). As faltas continuam vinculadas. Na mesma transação, as ATIVA do usuário que
// começam a partir da anulada são antecipadas, em ordem: cada uma começa no instante da falta que a
// gerou (o maior ocorrida_em das faltas dela) ou no fim da anterior não anulada, o que for mais
// tarde, e mantém a duração (decisão 15). Entradas de fila encerradas não voltam (D7).
// Anula uma penalidade, dentro da trava de governança
query anular_penalidade verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int penalidade_id
    text? parecer? filters=trim
  }

  stack {
    var $parecer {
      value = $input.parecer|first_notnull:""
    }

    precondition (($parecer|strlen) >= 1 && ($parecer|strlen) <= 500) {
      error_type = "inputerror"
      error = "O parecer é obrigatório, com até 500 caracteres."
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava

        var $agora {
          value = now
        }

        function.run exigir_admin {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator

        db.get penalidade {
          field_name = "id"
          field_value = $input.penalidade_id
        } as $penalidade

        precondition ($penalidade != null) {
          error_type = "inputerror"
          error = "Penalidade não encontrada."
        }

        precondition ($penalidade.status == "ATIVA" && $penalidade.fim > $agora) {
          error_type = "inputerror"
          error = "Só uma penalidade ativa pode ser anulada."
        }

        precondition ($penalidade.usuario_id != $ator.id) {
          error_type = "inputerror"
          error = "Ninguém anula a própria penalidade."
        }

        db.edit penalidade {
          field_name = "id"
          field_value = $penalidade.id
          data = {
            status        : "ANULADA"
            anulada_por_id: $ator.id
            anulada_em    : $agora
            parecer       : $parecer
          }
        } as $anulada

        // Fim da última penalidade não anulada que começa antes da anulada
        db.query penalidade {
          where = $db.penalidade.usuario_id == $penalidade.usuario_id && $db.penalidade.status != "ANULADA" && $db.penalidade.inicio < $penalidade.inicio
          return = {type: "list"}
        } as $anteriores

        var $anterior_fim {
          value = 0
        }

        conditional {
          if (($anteriores|count) > 0) {
            var.update $anterior_fim {
              value = ($anteriores|map:$$.fim|max)|to_int
            }
          }
        }

        // Encadeadas depois da anulada, em ordem
        db.query penalidade {
          where = $db.penalidade.usuario_id == $penalidade.usuario_id && $db.penalidade.status == "ATIVA" && $db.penalidade.inicio >= $penalidade.inicio
          sort = {inicio: "asc"}
          return = {type: "list"}
        } as $seguintes

        var $antecipadas {
          value = []
        }

        foreach ($seguintes) {
          each as $seguinte {
            db.query falta {
              where = $db.falta.penalidade_id == $seguinte.id
              return = {type: "list"}
            } as $faltas_da_seguinte

            var $gatilho {
              value = $seguinte.inicio
            }

            conditional {
              if (($faltas_da_seguinte|count) > 0) {
                var.update $gatilho {
                  value = ($faltas_da_seguinte|map:$$.ocorrida_em|max)|to_int
                }
              }
            }

            var $duracao {
              value = $seguinte.fim - $seguinte.inicio
            }

            // conditional em vez de |max: o filtro também é alias de array_max (C9)
            var $novo_inicio {
              value = $gatilho
            }

            conditional {
              if ($anterior_fim > $gatilho) {
                var.update $novo_inicio {
                  value = $anterior_fim
                }
              }
            }

            var $novo_fim {
              value = $novo_inicio + $duracao
            }

            conditional {
              if ($novo_inicio != $seguinte.inicio) {
                db.edit penalidade {
                  field_name = "id"
                  field_value = $seguinte.id
                  data = {inicio: $novo_inicio, fim: $novo_fim}
                } as $antecipada

                var $registro_antecipada {
                  value = {}
                    |set:"id":$seguinte.id
                    |set:"inicio_antes":$seguinte.inicio
                    |set:"fim_antes":$seguinte.fim
                    |set:"inicio_depois":$novo_inicio
                    |set:"fim_depois":$novo_fim
                }

                var.update $antecipadas {
                  value = $antecipadas|push:$registro_antecipada
                }
              }
            }

            var.update $anterior_fim {
              value = $novo_fim
            }
          }
        }

        var $dados_antes {
          value = {}|set:"status":$penalidade.status
        }

        var $dados_depois {
          value = {}
            |set:"status":$anulada.status
            |set:"parecer":$parecer
            |set:"antecipadas":$antecipadas
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "ANULAR_PENALIDADE"
            entidade    : "penalidade"
            entidade_id : $penalidade.id
            unidade_id  : null
            dados_antes : $dados_antes
            dados_depois: $dados_depois
          }
        } as $registro
      }
    }
  }

  response = {mensagem: "Penalidade anulada."}
  guid = "zUMkuFwxZjzKMa7kaPpu1NCTz88"
}
