// Reserva avulsa para o próprio usuário (spec reservas; design D4). Formato e conversão do
// horário fora da trava; dentro dela, na ordem: conta ativa, releitura do espaço, da unidade, do
// tipo e das regras, espaço reservável, regra do papel, regras de horário, limite de reservas
// ativas no tipo e conflito. Todas as recusas são 400 com uma mensagem só. Nasce PENDENTE quando
// o tipo exige aprovação para o papel, senão CONFIRMADA. Nunca reserva em nome de outra pessoa.
// C7: depois da conversão do horário e antes da transação, aplicar_vencimentos grava as pendentes
// vencidas (design D3); o limite e o conflito usam o predicado de ocupação da situação efetiva
// (D2), que ignora a pendente cujo início já chegou mesmo antes de ela ser gravada.
// C8 (design D3 a D6): no conflito, avaliar_deslocamento diz se as conflitantes podem ser
// deslocadas. Não deslocável: a mesma recusa de horário ocupado. Deslocável sem `deslocar`: 200 sem
// gravar nada, com requer_confirmacao e a quantidade (reserva_id nulo = nada gravado). Deslocável
// com `deslocar`: grava a nova e cancela as conflitantes (PRIORIDADE) na mesma transação.
// C9 (design D4 e D7): as validações dos passos 2 a 5 e 7 vêm de validar_pedido_reserva e
// exigir_limite_ativas, compartilhadas com entrar_fila e confirmar_fila, sem mudar ordem nem
// mensagens. A vaga retida pela fila (NOTIFICADA no prazo) ocupa e nunca é deslocável: com ela no
// intervalo, a recusa é a mesma de horário ocupado, antes de avaliar o deslocamento. A faxina antes
// da transação já processa a fila, então uma reserva direta não fura a fila (C8, decisão 4).
// Cria uma reserva, dentro da trava de governança
query criar_reserva verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int espaco_id
    text? data? filters=trim
    text? hora_inicio? filters=trim
    text? hora_fim? filters=trim

    // Confirmação do deslocamento por prioridade (C8); ausente = não confirmado
    bool? deslocar?
  }

  stack {
    function.run converter_horario_pedido {
      input = {
        data       : $input.data
        hora_inicio: $input.hora_inicio
        hora_fim   : $input.hora_fim
      }
    } as $horario
  
    var $inicio {
      value = $horario.inicio
    }
  
    var $fim {
      value = $horario.fim
    }

    // Faxina de vencimentos em transação própria (C7, design D3), que também processa a fila (C9)
    // e grava por inteiro os vencimentos de comparecimento do usuário (C10, D3)
    function.run aplicar_vencimentos {
      input = {usuario_id: $auth.id}
    } as $vencimentos

    // Declaradas fora da transação, como $unidade_criada_id em unidades/criar
    var $reserva_id {
      value = null
    }
  
    var $status_gravado {
      value = null
    }

    // C8: pedido deslocável sem confirmação (nada gravado) e quantas reservas foram ou seriam
    // deslocadas
    var $requer_confirmacao {
      value = false
    }

    var $quantidade_deslocada {
      value = 0
    }

    var $deslocar {
      value = $input.deslocar|first_notnull:false
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava
      
        // 1. Conta ativa e papel atual
        function.run usuario_ativo {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        // 2 a 5. Releitura dentro da trava (corrida com desativação, C4 D13), espaço reservável,
        // regra do papel e regras de horário, com o agora lido dentro da trava (C9, D7)
        var $agora {
          value = now
        }

        function.run validar_pedido_reserva {
          input = {
            espaco_id: $input.espaco_id
            papel    : $ator.papel
            inicio   : $inicio
            fim      : $fim
            agora    : $agora
          }
        } as $pedido

        var $espaco {
          value = $pedido.espaco
        }

        var $tipo {
          value = $pedido.tipo
        }

        var $regra {
          value = $pedido.regra
        }

        // 6. Penalidade em vigor (C10, D3 e D6): as faltas do usuário são gravadas por inteiro e em
        // ordem antes da verificação, mesmo que a faxina tenha falhado
        function.run processar_vencimentos_usuario {
          input = {usuario_id: $ator.id, agora: $agora}
        } as $vencimentos_usuario

        function.run penalidade_em_vigor {
          input = {usuario_id: $ator.id, agora: $agora}
        } as $penalidade

        precondition (!$penalidade.em_vigor) {
          error_type = "inputerror"
          error = "Você está com penalidade até " ~ $penalidade.ate_texto ~ ". Até lá, não é possível criar reservas nem entrar em filas."
        }

        // 7. Limite de reservas ativas no tipo atual do espaço (D5)
        function.run exigir_limite_ativas {
          input = {
            usuario_id                 : $ator.id
            tipo_espaco_id             : $espaco.tipo_espaco_id
            max_reservas_ativas_usuario: $tipo.max_reservas_ativas_usuario
            agora                      : $agora
          }
        } as $limite_ok

        // 8. Bloqueio ativo sobreposto (C11, design D4): recusa antes do conflito, então o
        // deslocamento nunca passa por cima de um bloqueio
        function.run exigir_sem_bloqueio {
          input = {espaco_id: $espaco.id, inicio: $inicio, fim: $fim}
        } as $sem_bloqueio

        // 9. Conflito (D7): ocupação sobreposta no mesmo espaço; encostadas não conflitam. Ocupam
        // a confirmada e a pendente que ainda não começou (C7, D2) e a vaga retida pela fila no
        // prazo (C9, D4). A vaga retida nunca é deslocável: a recusa vem antes do deslocamento,
        // com a mesma mensagem, sem identificar quem ocupa.
        db.query entrada_fila {
          where = $db.entrada_fila.espaco_id == $espaco.id && $db.entrada_fila.status == "NOTIFICADA" && $db.entrada_fila.prazo_confirmacao >= $agora && $db.entrada_fila.inicio < $fim && $db.entrada_fila.fim > $inicio
          return = {type: "exists"}
        } as $vaga_retida

        precondition (!$vaga_retida) {
          error_type = "inputerror"
          error = "Horário ocupado: já existe uma reserva neste espaço nesse intervalo."
        }

        // Predicado de ocupação da C10 (D2): a confirmada sem check-in depois da janela não ocupa
        function.run obter_configuracao_comparecimento as $comparecimento

        var $inicio_minimo {
          value = $agora - $comparecimento.depois_ms
        }

        db.query reserva {
          where = $db.reserva.espaco_id == $espaco.id && (($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora) || ($db.reserva.status == "CONFIRMADA" && $db.reserva.fim > $agora && ($db.reserva.check_in_em != null || $db.reserva.inicio >= $inicio_minimo || $db.reserva.inicio < $comparecimento.comparecimento_desde))) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
          sort = {inicio: "asc"}
          return = {type: "list"}
        } as $conflitantes

        // Situação e nível da nova reserva, que valem também para o deslocamento (C8, D3)
        var $status {
          value = "CONFIRMADA"
        }

        // Booleano calculado à parte: operador dentro do input falha em execução (lição da C5)
        var $nasce_confirmada {
          value = true
        }

        conditional {
          if ($regra.exige_aprovacao) {
            var.update $status {
              value = "PENDENTE"
            }

            var.update $nasce_confirmada {
              value = false
            }
          }
        }

        function.run nivel_do_papel {
          input = {papel: $ator.papel}
        } as $nivel

        var $deslocavel {
          value = false
        }

        var $quantidade_conflitantes {
          value = $conflitantes|count
        }

        conditional {
          if ($quantidade_conflitantes > 0) {
            // Prazo lido direto da tabela, como o de cancelamento (C6, D12; C8, D1)
            db.query configuracao_geral {
              return = {type: "single"}
            } as $configuracao_reservas

            precondition ($configuracao_reservas != null && !($configuracao_reservas.prazo_deslocamento_minutos|is_null)) {
              error = "Configuração de reservas incompleta: execute o bootstrap."
            }

            function.run avaliar_deslocamento {
              input = {
                conflitantes     : $conflitantes
                nivel_solicitante: $nivel
                inicio_novo      : $inicio
                nasce_confirmada : $nasce_confirmada
                prazo_minutos    : $configuracao_reservas.prazo_deslocamento_minutos
                agora            : $agora
              }
            } as $avaliacao

            var.update $deslocavel {
              value = $avaliacao.deslocavel
            }
          }
        }

        // Não deslocável: a mesma recusa da C6, sem identificar quem ocupa
        precondition ($quantidade_conflitantes == 0 || $deslocavel) {
          error_type = "inputerror"
          error = "Horário ocupado: já existe uma reserva neste espaço nesse intervalo."
        }

        conditional {
          // Deslocável sem confirmação: nada é gravado (D4)
          if ($quantidade_conflitantes > 0 && !$deslocar) {
            var.update $requer_confirmacao {
              value = true
            }

            var.update $quantidade_deslocada {
              value = $quantidade_conflitantes
            }
          }

          else {
            // 10. Gravação. A nova vem antes do cancelamento das conflitantes, que precisam do id
            // dela; a sobreposição momentânea fica dentro da transação e da trava (D3).
            db.add reserva {
              data = {
                usuario_id      : $ator.id
                espaco_id       : $espaco.id
                inicio          : $inicio
                fim             : $fim
                status          : $status
                nivel_prioridade: $nivel
                origem          : "DIRETA"
                criado_em       : now
              }
            } as $reserva

            var.update $reserva_id {
              value = $reserva.id
            }

            var.update $status_gravado {
              value = $reserva.status
            }

            var $ids_deslocadas {
              value = []
            }

            // Deslocamento confirmado (D5): CANCELADA, PRIORIDADE, sem falta, um CANCELAR_RESERVA cada
            conditional {
              if ($quantidade_conflitantes > 0) {
                function.run cancelar_reservas {
                  input = {
                    modo                    : "prioridade"
                    reservas                : $conflitantes
                    deslocada_por_reserva_id: $reserva.id
                    motivo                  : "PRIORIDADE"
                    ator_id                 : $ator.id
                    agora                   : $agora
                  }
                } as $cancelamento

                var.update $quantidade_deslocada {
                  value = $cancelamento.quantidade
                }

                var.update $ids_deslocadas {
                  value = $conflitantes|map:$$.id
                }
              }
            }

            // 11. Auditoria (D6): com deslocamento, a lista das deslocadas
            var $dados_depois {
              value = {}
                |set:"espaco_id":$reserva.espaco_id
                |set:"inicio":$reserva.inicio
                |set:"fim":$reserva.fim
                |set:"status":$reserva.status
            }

            conditional {
              if ($quantidade_conflitantes > 0) {
                var.update $dados_depois {
                  value = $dados_depois|set:"deslocadas":$ids_deslocadas
                }
              }
            }

            function.run registrar_auditoria {
              input = {
                ator_id     : $ator.id
                acao        : "CRIAR_RESERVA"
                entidade    : "reserva"
                entidade_id : $reserva.id
                unidade_id  : $espaco.unidade_id
                dados_depois: $dados_depois
              }
            } as $registro_auditoria
          }
        }
      }
    }

    var $mensagem {
      value = "Reserva confirmada."
    }

    conditional {
      if ($requer_confirmacao && $quantidade_deslocada == 1) {
        var.update $mensagem {
          value = "Este horário está ocupado por 1 reserva de prioridade menor. Confirme para deslocá-la."
        }
      }

      elseif ($requer_confirmacao) {
        var.update $mensagem {
          value = "Este horário está ocupado por " ~ $quantidade_deslocada ~ " reservas de prioridade menor. Confirme para deslocá-las."
        }
      }

      elseif ($status_gravado == "PENDENTE") {
        var.update $mensagem {
          value = "Reserva criada e aguardando aprovação."
        }
      }
    }

    // Complemento do sucesso com deslocamento (D4)
    conditional {
      if (!$requer_confirmacao && $quantidade_deslocada == 1) {
        var.update $mensagem {
          value = $mensagem ~ " 1 reserva de prioridade menor foi deslocada."
        }
      }

      elseif (!$requer_confirmacao && $quantidade_deslocada > 1) {
        var.update $mensagem {
          value = $mensagem ~ " " ~ $quantidade_deslocada ~ " reservas de prioridade menor foram deslocadas."
        }
      }
    }

    // Com requer_confirmacao, reserva_id e status ficam nulos: nada foi gravado (D4)
    var $resposta {
      value = {}
        |set:"mensagem":$mensagem
        |set:"reserva_id":$reserva_id
        |set:"status":$status_gravado
        |set:"requer_confirmacao":$requer_confirmacao
        |set:"deslocadas":$quantidade_deslocada
    }
  }

  response = $resposta
  guid = "trGOImG6DvIWTIVuno09wfEE6w4"
}