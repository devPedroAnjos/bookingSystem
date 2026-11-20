// Cancelamento pelo próprio usuário (spec reservas; C6, design D6; C10, design D8). Reserva de outra
// pessoa ou inexistente tem a mesma recusa. Só antes do início e sem check-in (decisões 3 e 13).
// - No prazo (inicio >= agora + prazo, comparando em ms; exatamente no limite é aceito) ou PENDENTE
//   a qualquer momento antes do início: motivo USUARIO, sem falta (decisão 2).
// - CONFIRMADA depois do prazo: sem aceitar_falta, responde requer_confirmacao com status 200 e não
//   altera a reserva (um erro desfaria os vencimentos já gravados); com aceitar_falta, motivo
//   USUARIO_TARDIO e falta de cancelamento tardio no instante do cancelamento.
// O agora é lido uma única vez, dentro da trava, e vale para a classificação e para a falta.
// C7: aplicar_vencimentos antes da transação (design D3), agora com o usuário (C10, D3); dentro da
// trava, processar_vencimentos_usuario garante as faltas anteriores gravadas antes da nova.
// C9 (design D5): a vaga liberada vai para a fila na mesma transação (processar_fila no fim).
// O prazo é lido direto de configuracao_geral (C6, D12), com a precondição do bootstrap.
// Cancela uma reserva própria, dentro da trava de governança
query cancelar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int reserva_id

    // Confirmação de que o usuário aceita a falta do cancelamento tardio. Sem padrão no input: o
    // Xano descarta o padrão falso ao salvar; o nulo vira falso abaixo
    bool aceitar_falta?
  }

  stack {
    // Faxina de vencimentos em transação própria (C7, design D3), com o usuário (C10, D3)
    function.run aplicar_vencimentos {
      input = {usuario_id: $auth.id}
    } as $vencimentos

    var $aceitar_falta {
      value = $input.aceitar_falta|first_notnull:false
    }

    var $requer_confirmacao {
      value = false
    }

    var $mensagem {
      value = "Reserva cancelada."
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava

        var $agora {
          value = now
        }

        function.run usuario_ativo {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator

        db.get reserva {
          field_name = "id"
          field_value = $input.reserva_id
        } as $reserva

        var $propria {
          value = false
        }

        conditional {
          if ($reserva != null) {
            conditional {
              if ($reserva.usuario_id == $ator.id) {
                var.update $propria {
                  value = true
                }
              }
            }
          }
        }

        precondition ($propria) {
          error_type = "inputerror"
          error = "Reserva não encontrada."
        }

        // A pendente vencida é EXPIRADA pela situação efetiva, mesmo se a faxina falhou
        precondition (($reserva.status == "PENDENTE" && $reserva.inicio > $agora) || $reserva.status == "CONFIRMADA") {
          error_type = "inputerror"
          error = "Esta reserva não está ativa."
        }

        precondition ($reserva.inicio > $agora) {
          error_type = "inputerror"
          error = "Esta reserva já começou e não pode mais ser cancelada."
        }

        precondition ($reserva.check_in_em|is_null) {
          error_type = "inputerror"
          error = "A reserva com check-in não pode ser cancelada."
        }

        // Faltas anteriores do usuário gravadas antes de uma falta nova (D3)
        function.run processar_vencimentos_usuario {
          input = {usuario_id: $ator.id, agora: $agora}
        } as $vencimentos_usuario

        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao

        precondition ($configuracao != null && !($configuracao.prazo_cancelamento_minutos|is_null)) {
          error = "Configuração de reservas incompleta: execute o bootstrap."
        }

        var $prazo {
          value = $configuracao.prazo_cancelamento_minutos
        }

        var $tardio {
          value = false
        }

        conditional {
          if ($reserva.status == "CONFIRMADA" && $reserva.inicio < $agora + ($prazo * 60000)) {
            var.update $tardio {
              value = true
            }
          }
        }

        conditional {
          // Tardio sem confirmação: nada muda na reserva (resposta 200, não erro)
          if ($tardio && !$aceitar_falta) {
            var.update $requer_confirmacao {
              value = true
            }

            var.update $mensagem {
              value = "O cancelamento a menos de " ~ $prazo ~ " minutos do início gera uma falta. Confirme para cancelar."
            }
          }

          else {
            var $motivo {
              value = "USUARIO"
            }

            conditional {
              if ($tardio) {
                var.update $motivo {
                  value = "USUARIO_TARDIO"
                }
              }
            }

            db.edit reserva {
              field_name = "id"
              field_value = $reserva.id
              data = {
                status             : "CANCELADA"
                motivo_cancelamento: $motivo
                cancelado_por_id   : $ator.id
                cancelado_em       : $agora
              }
            } as $cancelada

            db.get espaco {
              field_name = "id"
              field_value = $reserva.espaco_id
            } as $espaco

            var $dados_antes {
              value = {}|set:"status":$reserva.status
            }

            var $dados_depois {
              value = {}
                |set:"status":$cancelada.status
                |set:"motivo_cancelamento":$cancelada.motivo_cancelamento
            }

            function.run registrar_auditoria {
              input = {
                ator_id     : $ator.id
                acao        : "CANCELAR_RESERVA"
                entidade    : "reserva"
                entidade_id : $reserva.id
                unidade_id  : $espaco.unidade_id
                dados_antes : $dados_antes
                dados_depois: $dados_depois
              }
            } as $registro_auditoria

            conditional {
              if ($tardio) {
                function.run registrar_falta {
                  input = {
                    usuario_id : $ator.id
                    reserva_id : $reserva.id
                    tipo       : "CANCELAMENTO_TARDIO"
                    ocorrida_em: $agora
                    ator_id    : $ator.id
                    unidade_id : $espaco.unidade_id
                    agora      : $agora
                  }
                } as $falta

                var.update $mensagem {
                  value = "Reserva cancelada. Foi registrada uma falta pelo cancelamento tardio."
                }
              }
            }
          }
        }

        // A vaga liberada (ou a retida por quem acabou de ser penalizado) vai para a fila (C9, D5)
        function.run processar_fila {
          input = {agora: $agora}
        } as $fila
      }
    }

    var $resposta {
      value = {}
        |set:"mensagem":$mensagem
        |set:"requer_confirmacao":$requer_confirmacao
    }
  }

  response = $resposta
  guid = "rhyhnAEhlvhI1ZBWRDYwtfnYp6A"
}
