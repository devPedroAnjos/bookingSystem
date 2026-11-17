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

    // Faxina de vencimentos em transação própria (C7, design D3)
    function.run aplicar_vencimentos as $vencimentos

    // Rótulos dos motivos de validar_horario_reserva (os mesmos da tela de busca). Cadeia de |set
    // em vez de objeto literal: o Xano tira as vírgulas dos literais e eles podem perder chaves
    var $rotulos_horario {
      value = {}
        |set:"TIPO_SEM_REGRAS":"tipo sem regras"
        |set:"FIM_NAO_DEPOIS_DO_INICIO":"o fim deve ser depois do início"
        |set:"DIAS_DIFERENTES":"início e fim em dias diferentes"
        |set:"DIA_SEM_FUNCIONAMENTO":"dia sem funcionamento"
        |set:"FORA_DA_GRANULARIDADE":"horário fora da granularidade"
        |set:"ANTES_DA_ABERTURA":"início antes da abertura"
        |set:"DEPOIS_DO_FECHAMENTO":"fim depois do fechamento"
        |set:"DURACAO_ABAIXO_DA_MINIMA":"duração abaixo da mínima"
        |set:"DURACAO_ACIMA_DA_MAXIMA":"duração acima da máxima"
        |set:"ANTECEDENCIA_MINIMA":"antecedência menor que a mínima"
        |set:"ANTECEDENCIA_MAXIMA":"antecedência maior que a máxima"
    }
  
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
      
        // 2. Releitura dentro da trava (corrida com desativação, C4 D13)
        db.get espaco {
          field_name = "id"
          field_value = $input.espaco_id
        } as $espaco
      
        // Espaço inexistente tem a mesma recusa de espaço não reservável
        precondition ($espaco != null) {
          error_type = "inputerror"
          error = "Este espaço não está disponível para reserva."
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $espaco.unidade_id
        } as $unidade
      
        db.get tipo_espaco {
          field_name = "id"
          field_value = $espaco.tipo_espaco_id
        } as $tipo
      
        db.query regra_papel {
          where = $db.regra_papel.tipo_espaco_id == $espaco.tipo_espaco_id
          return = {type: "list"}
        } as $regras_do_tipo
      
        function.run obter_configuracao_horario as $configuracao
        function.run tipo_com_regras {
          input = {tipo: $tipo, regras_do_tipo: $regras_do_tipo}
        } as $com_regras
      
        // 3. Espaço reservável
        function.run disponibilidade_espaco {
          input = {
            espaco_ativo   : $espaco.ativo
            unidade_ativa  : $unidade.ativa
            tipo_ativo     : $tipo.ativo
            tipo_com_regras: $com_regras
          }
        } as $disponibilidade
      
        precondition ($disponibilidade.reservavel) {
          error_type = "inputerror"
          error = "Este espaço não está disponível para reserva."
        }
      
        // 4. Regra do papel
        function.run regra_do_papel {
          input = {papel: $ator.papel, regras_do_tipo: $regras_do_tipo}
        } as $regra
      
        precondition ($regra.pode_reservar) {
          error_type = "inputerror"
          error = "Seu papel não pode reservar este tipo de espaço."
        }
      
        // 5. Regras de horário, com o agora lido dentro da trava
        var $agora {
          value = now
        }
      
        function.run validar_horario_reserva {
          input = {
            tipo            : $tipo
            regras_completas: $com_regras
            configuracao    : $configuracao
            inicio          : $inicio
            fim             : $fim
            agora           : $agora
          }
        } as $validacao
      
        var $motivos_horario {
          value = $validacao.motivos|map:($rotulos_horario|get:$$)|join:"; "
        }
      
        precondition ($validacao.dentro_das_regras) {
          error_type = "inputerror"
          error = "Horário fora das regras do tipo: " ~ $motivos_horario ~ "."
        }
      
        // 6. (Ponto de extensão C10: recusar quem tem penalidade ativa.)

        // 7. Limite de reservas ativas no tipo atual do espaço (D5); fim > agora porque, até a C10,
        // reservas passadas continuam CONFIRMADA. Ocupação pela situação efetiva (C7, D2): a
        // pendente cujo início já chegou expirou e não conta.
        db.query espaco {
          where = $db.espaco.tipo_espaco_id == $espaco.tipo_espaco_id
          return = {type: "list"}
        } as $espacos_do_tipo

        var $ids_do_tipo {
          value = $espacos_do_tipo|map:$$.id
        }

        db.query reserva {
          where = $db.reserva.usuario_id == $ator.id && $db.reserva.espaco_id in $ids_do_tipo && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.fim > $agora
          return = {type: "count"}
        } as $ativas_no_tipo
      
        precondition ($ativas_no_tipo < $tipo.max_reservas_ativas_usuario) {
          error_type = "inputerror"
          error = "Você já tem o máximo de " ~ $tipo.max_reservas_ativas_usuario ~ " reservas ativas neste tipo de espaço."
        }
      
        // 8. (Ponto de extensão C11: recusar horário com bloqueio ativo sobreposto.)

        // 9. Conflito (D7): ocupação sobreposta no mesmo espaço; encostadas não conflitam. Ocupam
        // a confirmada e a pendente que ainda não começou (C7, D2).
        // (Ponto de extensão C9: vaga retida pela fila, que não é deslocável.)
        db.query reserva {
          where = $db.reserva.espaco_id == $espaco.id && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
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