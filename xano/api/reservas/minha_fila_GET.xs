// Fila do próprio usuário (spec fila-espera; design D6), carregada em toda página autenticada para
// o aviso de vaga retida. Verificação rápida, só de leitura: se há pendente vencida ou vaga retida
// vencida, chama aplicar_vencimentos (trava e faxina, decisão 10); senão, não grava nada. Lista as
// entradas ativas e as finalizadas cujo intervalo começa a partir de 30 dias atrás, com a situação
// efetiva (situacao_efetiva_fila), a posição (só na mesma fila: mesmo espaço e intervalo, sem nomes)
// e o prazo, em America/Sao_Paulo. `avisos` são as NOTIFICADA no prazo.
// Lista as entradas de fila do usuário autenticado
query minha_fila verb=GET {
  api_group = "reservas"
  auth = "usuario"

  input {
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator
  
    var $agora_verificacao {
      value = now
    }
  
    // Verificação rápida (D6): duas contagens, sem trava
    db.query reserva {
      where = $db.reserva.status == "PENDENTE" && $db.reserva.inicio <= $agora_verificacao
      return = {type: "count"}
    } as $pendentes_vencidas
  
    db.query entrada_fila {
      where = $db.entrada_fila.status == "NOTIFICADA" && $db.entrada_fila.prazo_confirmacao < $agora_verificacao
      return = {type: "count"}
    } as $retidas_vencidas
  
    conditional {
      if ($pendentes_vencidas > 0 || $retidas_vencidas > 0) {
        function.run aplicar_vencimentos as $vencimentos
      }
    }
  
    var $agora {
      value = now
    }
  
    var $desde {
      value = $agora - 2592000000
    }
  
    db.query entrada_fila {
      where = $db.entrada_fila.usuario_id == $ator.id && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA" || $db.entrada_fila.inicio >= $desde)
      sort = {inicio: "desc"}
      return = {type: "list"}
    } as $entradas
  
    var $ativas {
      value = []
    }
  
    var $finalizadas {
      value = []
    }
  
    var $avisos {
      value = []
    }
  
    // Sem entradas, nada mais a ler (e o prazo da fila não é exigido antes do bootstrap)
    conditional {
      if (($entradas|count) > 0) {
        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao
      
        precondition ($configuracao != null && !($configuracao.prazo_fila_minutos|is_null) && !($configuracao.tempo_minimo_fila_minutos|is_null)) {
          error = "Configuração de reservas incompleta: execute o bootstrap."
        }
      
        db.query espaco {
          return = {type: "list"}
        } as $espacos
      
        db.query unidade {
          return = {type: "list"}
        } as $unidades
      
        db.query tipo_espaco {
          return = {type: "list"}
        } as $tipos
      
        // Para a posição: as AGUARDANDO dos espaços em que o usuário aguarda
        var $ids_espacos_aguardando {
          value = ($entradas|filter:($$.status == "AGUARDANDO"))|map:$$.espaco_id|unique
        }
      
        var $fila_dos_espacos {
          value = []
        }
      
        conditional {
          if (($ids_espacos_aguardando|count) > 0) {
            db.query entrada_fila {
              where = $db.entrada_fila.espaco_id in $ids_espacos_aguardando && $db.entrada_fila.status == "AGUARDANDO"
              return = {type: "list"}
            } as $aguardando_nos_espacos
          
            var.update $fila_dos_espacos {
              value = $aguardando_nos_espacos
            }
          }
        }
      
        foreach ($entradas) {
          each as $entrada {
            var $espaco {
              value = $espacos|find:$$.id == $entrada.espaco_id
            }
          
            var $unidade {
              value = $unidades|find:$$.id == $espaco.unidade_id
            }
          
            var $tipo {
              value = $tipos|find:$$.id == $espaco.tipo_espaco_id
            }
          
            var $antecedencia_min {
              value = $tipo.antecedencia_min_minutos|first_notnull:0
            }
          
            function.run corte_fila {
              input = {
                inicio                  : $entrada.inicio
                prazo_fila_minutos       : $configuracao.prazo_fila_minutos
                antecedencia_min_minutos : $antecedencia_min
                tempo_minimo_fila_minutos: $configuracao.tempo_minimo_fila_minutos
              }
            } as $instantes

            var $fechamento {
              value = $instantes.fechamento
            }

            function.run situacao_efetiva_fila {
              input = {
                status           : $entrada.status
                prazo_confirmacao: $entrada.prazo_confirmacao
                fechamento       : $fechamento
                agora            : $agora
              }
            } as $situacao
          
            function.run formatar_reserva {
              input = {inicio: $entrada.inicio, fim: $entrada.fim}
            } as $formatada
          
            var $posicao {
              value = null
            }
          
            conditional {
              if ($situacao == "AGUARDANDO") {
                var $a_frente {
                  value = $fila_dos_espacos|filter:($$.espaco_id == $entrada.espaco_id && $$.inicio == $entrada.inicio && $$.fim == $entrada.fim && ($$.nivel_prioridade > $entrada.nivel_prioridade || ($$.nivel_prioridade == $entrada.nivel_prioridade && ($$.criado_em < $entrada.criado_em || ($$.criado_em == $entrada.criado_em && $$.id < $entrada.id)))))
                }
              
                var.update $posicao {
                  value = ($a_frente|count) + 1
                }
              }
            }
          
            var $prazo {
              value = null
            }
          
            var $prazo_data {
              value = null
            }
          
            var $prazo_hora {
              value = null
            }
          
            conditional {
              if ($situacao == "NOTIFICADA") {
                var.update $prazo {
                  value = $entrada.prazo_confirmacao
                }
              
                function.run formatar_reserva {
                  input = {
                    inicio: $entrada.prazo_confirmacao
                    fim   : $entrada.prazo_confirmacao
                  }
                } as $prazo_formatado
              
                var.update $prazo_data {
                  value = $prazo_formatado.data
                }
              
                var.update $prazo_hora {
                  value = $prazo_formatado.hora_inicio
                }
              }
            }
          
            var $espaco_item {
              value = {}
                |set:"id":$espaco.id
                |set:"nome":$espaco.nome
                |set:"codigo":$espaco.codigo
            }
          
            var $unidade_item {
              value = {}
                |set:"id":$unidade.id
                |set:"nome":$unidade.nome
            }
          
            var $tipo_item {
              value = {}
                |set:"id":$tipo.id
                |set:"nome":$tipo.nome
            }
          
            var $item {
              value = {}
                |set:"id":$entrada.id
                |set:"espaco":$espaco_item
                |set:"unidade":$unidade_item
                |set:"tipo":$tipo_item
                |set:"inicio":$entrada.inicio
                |set:"fim":$entrada.fim
                |set:"data":$formatada.data
                |set:"hora_inicio":$formatada.hora_inicio
                |set:"hora_fim":$formatada.hora_fim
                |set:"status":$situacao
                |set:"posicao":$posicao
                |set:"prazo_confirmacao":$prazo
                |set:"prazo_data":$prazo_data
                |set:"prazo_hora":$prazo_hora
            }
          
            conditional {
              if ($situacao == "AGUARDANDO" || $situacao == "NOTIFICADA") {
                var.update $ativas {
                  value = $ativas|push:$item
                }
              
                conditional {
                  if ($situacao == "NOTIFICADA") {
                    var.update $avisos {
                      value = $avisos|push:$item
                    }
                  }
                }
              }
            
              elseif ($entrada.inicio >= $desde) {
                var.update $finalizadas {
                  value = $finalizadas|push:$item
                }
              }
            }
          }
        }
      }
    }
  
    // Ativas da mais próxima para a mais distante; finalizadas já vêm da mais recente. Ordenação
    // calculada antes: filtro dentro da montagem da resposta falha em execução (lição da C5)
    var $ativas_ordenadas {
      value = $ativas|sort:"inicio":"number":true
    }
  
    var $avisos_ordenados {
      value = $avisos|sort:"inicio":"number":true
    }
  
    var $resposta {
      value = {}
        |set:"ativas":$ativas_ordenadas
        |set:"finalizadas":$finalizadas
        |set:"avisos":$avisos_ordenados
    }
  }

  response = $resposta
  guid = "d76c-WfNVpgLxbOpuxScIiuqXvI"
}