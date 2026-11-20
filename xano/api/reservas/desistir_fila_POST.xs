// Desistência da fila (spec fila-espera; design D6): sair da fila enquanto AGUARDANDO ou abrir mão
// da vaga retida enquanto NOTIFICADA; as duas levam a DESISTIU. A entrada de outra pessoa tem a
// mesma recusa de inexistente. Desistir da vaga retida a libera para a fila na mesma transação.
// Desiste de uma entrada própria, dentro da trava de governança
query desistir_fila verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int entrada_id
  }

  stack {
    // Faxina de vencimentos e da fila em transação própria (C7, D3; C9, D5)
    function.run aplicar_vencimentos as $vencimentos

    var $estava_notificada {
      value = false
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava

        function.run usuario_ativo {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator

        db.get entrada_fila {
          field_name = "id"
          field_value = $input.entrada_id
        } as $entrada

        var $propria {
          value = false
        }

        conditional {
          if ($entrada != null) {
            conditional {
              if ($entrada.usuario_id == $ator.id) {
                var.update $propria {
                  value = true
                }
              }
            }
          }
        }

        precondition ($propria) {
          error_type = "inputerror"
          error = "Entrada não encontrada."
        }

        precondition ($entrada.status == "AGUARDANDO" || $entrada.status == "NOTIFICADA") {
          error_type = "inputerror"
          error = "Esta entrada não está mais ativa."
        }

        db.edit entrada_fila {
          field_name = "id"
          field_value = $entrada.id
          data = {status: "DESISTIU"}
        } as $desistencia

        db.get espaco {
          field_name = "id"
          field_value = $entrada.espaco_id
        } as $espaco

        var $dados_antes {
          value = {}|set:"status":$entrada.status
        }

        var $dados_depois {
          value = {}|set:"status":$desistencia.status
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "DESISTIR_FILA"
            entidade    : "entrada_fila"
            entidade_id : $entrada.id
            unidade_id  : $espaco.unidade_id
            dados_antes : $dados_antes
            dados_depois: $dados_depois
          }
        } as $registro_auditoria

        // A vaga retida liberada passa ao próximo na mesma transação (C9, D5)
        conditional {
          if ($entrada.status == "NOTIFICADA") {
            var.update $estava_notificada {
              value = true
            }

            var $agora {
              value = now
            }

            function.run processar_fila {
              input = {agora: $agora}
            } as $fila
          }
        }
      }
    }

    var $mensagem {
      value = "Você saiu da fila."
    }

    conditional {
      if ($estava_notificada) {
        var.update $mensagem {
          value = "Você desistiu da vaga."
        }
      }
    }

    var $resposta {
      value = {}|set:"mensagem":$mensagem
    }
  }

  response = $resposta
  guid = "3d3HOSGpQ-iSaYvgDwfwo8vBXHk"
}
