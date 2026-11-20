// Entrada na fila de espera (spec fila-espera; design D6). Formato e conversão do horário e faxina
// fora da trava; dentro dela, na ordem: conta ativa, validações da criação (validar_pedido_reserva,
// menos o conflito e o limite de ativas), corte da fila, entrada repetida, reserva própria
// sobreposta e ocupação. Intervalo livre e ocupação deslocável são recusados: a fila só serve a
// quem não pode deslocar (avaliar_deslocamento, a mesma regra da criação). A vaga retida nunca é
// deslocável. A entrada nasce AGUARDANDO com o nível do papel atual. Recusas são 400.
// Coloca o usuário na fila de um intervalo ocupado, dentro da trava de governança
query entrar_fila verb=POST {
  api_group = "reservas"
  auth = "usuario"

  input {
    int espaco_id
    text? data? filters=trim
    text? hora_inicio? filters=trim
    text? hora_fim? filters=trim
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

    // Faxina de vencimentos e da fila em transação própria (C7, D3; C9, D5)
    function.run aplicar_vencimentos as $vencimentos

    var $entrada_id {
      value = null
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

        var $agora {
          value = now
        }

        // 2. Validações da criação (D7): espaço reservável, papel e regras de horário
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

        // 3. (Ponto de extensão C10: recusar quem tem penalidade ativa.)

        // 4. (Ponto de extensão C11: recusar intervalo com bloqueio ativo sobreposto.)

        // 5. Fechamento da fila (D3 e D12): corte menos o tempo mínimo útil; exatamente no
        // fechamento a fila já está encerrada
        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao

        precondition ($configuracao != null && !($configuracao.prazo_fila_minutos|is_null) && !($configuracao.tempo_minimo_fila_minutos|is_null) && !($configuracao.prazo_deslocamento_minutos|is_null)) {
          error = "Configuração de reservas incompleta: execute o bootstrap."
        }

        // Filtro fora do input da função (lição da C5)
        var $antecedencia_min {
          value = $pedido.tipo.antecedencia_min_minutos|first_notnull:0
        }

        function.run corte_fila {
          input = {
            inicio                  : $inicio
            prazo_fila_minutos       : $configuracao.prazo_fila_minutos
            antecedencia_min_minutos : $antecedencia_min
            tempo_minimo_fila_minutos: $configuracao.tempo_minimo_fila_minutos
          }
        } as $instantes

        precondition ($agora < $instantes.fechamento) {
          error_type = "inputerror"
          error = "A fila deste horário já está encerrada."
        }

        // 6. Uma entrada ativa por usuário, espaço e intervalo (garantida aqui, dentro da trava)
        db.query entrada_fila {
          where = $db.entrada_fila.usuario_id == $ator.id && $db.entrada_fila.espaco_id == $espaco.id && $db.entrada_fila.inicio == $inicio && $db.entrada_fila.fim == $fim && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA")
          return = {type: "exists"}
        } as $repetida

        precondition (!$repetida) {
          error_type = "inputerror"
          error = "Você já está na fila deste espaço nesse horário."
        }

        // 7. Ninguém entra na fila contra a própria reserva (decisão 9)
        db.query reserva {
          where = $db.reserva.usuario_id == $ator.id && $db.reserva.espaco_id == $espaco.id && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
          return = {type: "exists"}
        } as $reserva_propria

        precondition (!$reserva_propria) {
          error_type = "inputerror"
          error = "Você já tem reserva neste espaço nesse intervalo."
        }

        // 8. Ocupação (D4): vaga retida no prazo ou reserva ocupando
        db.query entrada_fila {
          where = $db.entrada_fila.espaco_id == $espaco.id && $db.entrada_fila.status == "NOTIFICADA" && $db.entrada_fila.prazo_confirmacao >= $agora && $db.entrada_fila.inicio < $fim && $db.entrada_fila.fim > $inicio
          return = {type: "exists"}
        } as $vaga_retida

        db.query reserva {
          where = $db.reserva.espaco_id == $espaco.id && ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
          sort = {inicio: "asc"}
          return = {type: "list"}
        } as $conflitantes

        var $quantidade_conflitantes {
          value = $conflitantes|count
        }

        precondition ($vaga_retida || $quantidade_conflitantes > 0) {
          error_type = "inputerror"
          error = "Este horário está livre. Faça a reserva diretamente."
        }

        function.run nivel_do_papel {
          input = {papel: $ator.papel}
        } as $nivel

        // Sem vaga retida, quem pode deslocar deve deslocar (§7.3)
        conditional {
          if (!$vaga_retida) {
            // Booleano calculado à parte: operador dentro do input falha em execução (lição da C5)
            var $nasce_confirmada {
              value = true
            }

            conditional {
              if ($pedido.regra.exige_aprovacao) {
                var.update $nasce_confirmada {
                  value = false
                }
              }
            }

            function.run avaliar_deslocamento {
              input = {
                conflitantes     : $conflitantes
                nivel_solicitante: $nivel
                inicio_novo      : $inicio
                nasce_confirmada : $nasce_confirmada
                prazo_minutos    : $configuracao.prazo_deslocamento_minutos
                agora            : $agora
              }
            } as $avaliacao

            precondition (!$avaliacao.deslocavel) {
              error_type = "inputerror"
              error = "Você pode deslocar a ocupação deste horário. Use Deslocar e reservar."
            }
          }
        }

        // 9. Gravação e auditoria (D8)
        db.add entrada_fila {
          data = {
            usuario_id      : $ator.id
            espaco_id       : $espaco.id
            inicio          : $inicio
            fim             : $fim
            nivel_prioridade: $nivel
            status          : "AGUARDANDO"
            criado_em       : now
          }
        } as $entrada

        var.update $entrada_id {
          value = $entrada.id
        }

        var $dados_depois {
          value = {}
            |set:"status":$entrada.status
            |set:"espaco_id":$entrada.espaco_id
            |set:"inicio":$entrada.inicio
            |set:"fim":$entrada.fim
            |set:"nivel_prioridade":$entrada.nivel_prioridade
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "ENTRAR_FILA"
            entidade    : "entrada_fila"
            entidade_id : $entrada.id
            unidade_id  : $espaco.unidade_id
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
      }
    }

    var $resposta {
      value = {}
        |set:"mensagem":"Você entrou na fila. Quando a vaga for liberada, ela aparece no sistema e precisa ser confirmada dentro do prazo."
        |set:"entrada_id":$entrada_id
    }
  }

  response = $resposta
  guid = "1jOBY3vBVcoQaseVaynbBlr7rt4"
}
