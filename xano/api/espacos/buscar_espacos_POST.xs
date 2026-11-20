// Busca de espaços para qualquer conta ativa (spec busca-espacos; design D7). Espaços de todas as
// unidades, só reserváveis e só de tipos que o papel pode reservar. Filtros opcionais: unidade,
// tipo, capacidade mínima, recursos (todos) e data com hora de início e fim (juntos). Com horário,
// cada espaço diz se o pedido está dentro das regras do tipo e os motivos, e se está ocupado por
// reserva PENDENTE ou CONFIRMADA sobreposta (C6, D13), sem dizer quem ocupa. É informativo: a
// reserva confere tudo de novo. Bloqueios entram na C11. POST para receber listas no corpo (D5).
// C8 (design D7): o espaço ocupado e dentro das regras diz se quem busca poderia deslocar a
// ocupação (avaliar_deslocamento, a mesma regra da criação) e quantas reservas seriam deslocadas;
// livre ou fora das regras: deslocavel falso e deslocaria 0. Só a quantidade sai, nunca quem.
// C9 (design D9): a vaga retida pela fila no prazo também ocupa e torna o espaço não deslocável
// (deslocaria 0). na_fila diz se quem busca já está na fila desse espaço e intervalo exatos;
// pode_entrar_fila, se pode entrar: ocupado, dentro das regras, não deslocável, fora da fila, sem
// reserva própria ocupando e antes do fechamento da fila (corte menos o tempo mínimo útil, D12).
// Nunca sai quem ocupa nem quem está na fila.
// Busca espaços reserváveis pelo usuário
query buscar_espacos verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int? unidade_id?
    int? tipo_espaco_id?
    int? capacidade_minima?
    json? recursos_ids?
    text? data? filters=trim
    text? hora_inicio? filters=trim
    text? hora_fim? filters=trim
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator
  
    var $data {
      value = $input.data|first_notnull:""
    }
  
    var $hora_inicio {
      value = $input.hora_inicio|first_notnull:""
    }
  
    var $hora_fim {
      value = $input.hora_fim|first_notnull:""
    }
  
    var $com_horario {
      value = ($data|strlen) > 0 || ($hora_inicio|strlen) > 0 || ($hora_fim|strlen) > 0
    }
  
    var $inicio {
      value = 0
    }
  
    var $fim {
      value = 0
    }
  
    var $configuracao {
      value = null
    }

    var $ids_ocupados {
      value = []
    }

    // C8: ocupações sobrepostas de todos os espaços, o prazo para deslocar e o nível de quem busca
    var $sobrepostas_todas {
      value = []
    }

    var $prazo_deslocamento {
      value = 0
    }

    var $nivel {
      value = 0
    }

    // C9: vagas retidas sobrepostas, espaços em cuja fila o usuário já está e o prazo da fila
    var $ids_retidos {
      value = []
    }

    var $ids_na_fila {
      value = []
    }

    var $prazo_fila {
      value = 0
    }

    // Tempo mínimo útil da fila (D12): o fechamento é o corte menos ele
    var $tempo_minimo_fila {
      value = 0
    }

    // Lido antes da ocupação: a pendente cujo início já chegou não ocupa (C7, design D2)
    var $agora {
      value = now
    }

    // Formato e conversão compartilhados com a criação de reserva (C6, design D3)
    conditional {
      if ($com_horario) {
        function.run converter_horario_pedido {
          input = {
            data       : $data
            hora_inicio: $hora_inicio
            hora_fim   : $hora_fim
          }
        } as $horario

        var.update $inicio {
          value = $horario.inicio
        }

        var.update $fim {
          value = $horario.fim
        }

        function.run obter_configuracao_horario as $configuracao_horario
        var.update $configuracao {
          value = $configuracao_horario
        }

        // Uma consulta para todos os espaços: reservas ativas sobrepostas ao intervalo (D7, D13).
        // Ocupam a pendente que ainda não começou (C7, D2) e a confirmada que não terminou nem
        // ficou sem comparecimento (C10, D2); a busca não grava nada.
        function.run obter_configuracao_comparecimento as $comparecimento

        var $inicio_minimo {
          value = $agora - $comparecimento.depois_ms
        }

        db.query reserva {
          where = (($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora) || ($db.reserva.status == "CONFIRMADA" && $db.reserva.fim > $agora && ($db.reserva.check_in_em != null || $db.reserva.inicio >= $inicio_minimo || $db.reserva.inicio < $comparecimento.comparecimento_desde))) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
          return = {type: "list"}
        } as $sobrepostas

        var.update $ids_ocupados {
          value = $sobrepostas|map:$$.espaco_id|unique
        }

        var.update $sobrepostas_todas {
          value = $sobrepostas
        }

        // Prazo lido direto da tabela, como na criação (C8, D1 e D7)
        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao_reservas

        precondition ($configuracao_reservas != null && !($configuracao_reservas.prazo_deslocamento_minutos|is_null) && !($configuracao_reservas.prazo_fila_minutos|is_null) && !($configuracao_reservas.tempo_minimo_fila_minutos|is_null)) {
          error = "Configuração de reservas incompleta: execute o bootstrap."
        }

        var.update $prazo_deslocamento {
          value = $configuracao_reservas.prazo_deslocamento_minutos
        }

        var.update $prazo_fila {
          value = $configuracao_reservas.prazo_fila_minutos
        }

        var.update $tempo_minimo_fila {
          value = $configuracao_reservas.tempo_minimo_fila_minutos
        }

        // C9 (D4 e D9): vagas retidas no prazo sobrepostas ao intervalo, de todos os espaços
        db.query entrada_fila {
          where = $db.entrada_fila.status == "NOTIFICADA" && $db.entrada_fila.prazo_confirmacao >= $agora && $db.entrada_fila.inicio < $fim && $db.entrada_fila.fim > $inicio
          return = {type: "list"}
        } as $retidas

        var.update $ids_retidos {
          value = $retidas|map:$$.espaco_id|unique
        }

        // Entradas ativas do usuário exatamente neste intervalo
        db.query entrada_fila {
          where = $db.entrada_fila.usuario_id == $ator.id && $db.entrada_fila.inicio == $inicio && $db.entrada_fila.fim == $fim && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA")
          return = {type: "list"}
        } as $entradas_do_usuario

        var.update $ids_na_fila {
          value = $entradas_do_usuario|map:$$.espaco_id|unique
        }

        function.run nivel_do_papel {
          input = {papel: $ator.papel}
        } as $nivel_do_ator

        var.update $nivel {
          value = $nivel_do_ator
        }
      }
    }
  
    var $recursos_pedidos {
      value = ($input.recursos_ids|first_notnull:[])|map:($$|to_int)
    }

    db.query unidade {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $unidades
  
    db.query espaco {
      where = $db.espaco.ativo == true
      return = {type: "list"}
    } as $espacos
  
    db.query tipo_espaco {
      return = {type: "list"}
    } as $tipos
  
    db.query regra_papel {
      return = {type: "list"}
    } as $todas_regras
  
    db.query espaco_recurso {
      return = {type: "list"}
    } as $associacoes
  
    db.query recurso {
      return = {type: "list"}
    } as $recursos
  
    var $resultado {
      value = []
    }
  
    foreach ($unidades) {
      each as $unidade {
        var $da_unidade {
          value = ($espacos|filter:$$.unidade_id == $unidade.id)|sort:"codigo":"itext":true
        }
      
        foreach ($da_unidade) {
          each as $espaco {
            var $tipo {
              value = $tipos|find:$$.id == $espaco.tipo_espaco_id
            }
          
            var $regras_do_tipo {
              value = $todas_regras|filter:$$.tipo_espaco_id == $espaco.tipo_espaco_id
            }
          
            function.run tipo_com_regras {
              input = {tipo: $tipo, regras_do_tipo: $regras_do_tipo}
            } as $com_regras
          
            function.run disponibilidade_espaco {
              input = {
                espaco_ativo   : $espaco.ativo
                unidade_ativa  : $unidade.ativa
                tipo_ativo     : $tipo.ativo
                tipo_com_regras: $com_regras
              }
            } as $disponibilidade
          
            function.run regra_do_papel {
              input = {papel: $ator.papel, regras_do_tipo: $regras_do_tipo}
            } as $regra
          
            var $do_espaco {
              value = $associacoes|filter:$$.espaco_id == $espaco.id
            }
          
            var $ids_do_espaco {
              value = $do_espaco|map:$$.recurso_id
            }
          
            var $incluir {
              value = $disponibilidade.reservavel && $regra.pode_reservar && ($input.unidade_id == null || $input.unidade_id == $unidade.id) && ($input.tipo_espaco_id == null || $input.tipo_espaco_id == $espaco.tipo_espaco_id) && ($input.capacidade_minima == null || $espaco.capacidade >= $input.capacidade_minima) && ($recursos_pedidos|every:($ids_do_espaco|in:$$))
            }
          
            conditional {
              if ($incluir) {
                var $recursos_do_espaco {
                  value = []
                }
              
                foreach ($do_espaco) {
                  each as $associacao {
                    var $recurso {
                      value = $recursos|find:$$.id == $associacao.recurso_id
                    }
                  
                    var.update $recursos_do_espaco {
                      value = $recursos_do_espaco
                        |push:```
                          {
                            nome: $recurso.nome,
                            quantidade: $associacao.quantidade
                          }
                          ```
                    }
                  }
                }
              
                var $item {
                  value = {
                    id             : $espaco.id
                    nome           : $espaco.nome
                    codigo         : $espaco.codigo
                    unidade        : {id: $unidade.id, nome: $unidade.nome}
                    tipo           : {id: $tipo.id, nome: $tipo.nome}
                    capacidade     : $espaco.capacidade
                    localizacao    : $espaco.localizacao
                    descricao      : $espaco.descricao
                    recursos       : $recursos_do_espaco|sort:"nome":"itext":true
                    exige_aprovacao: $regra.exige_aprovacao
                  }
                }
              
                conditional {
                  if ($com_horario) {
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
                  
                    var $ocupado_por_reserva {
                      value = $ids_ocupados|in:$espaco.id
                    }

                    var $retido {
                      value = $ids_retidos|in:$espaco.id
                    }

                    var $ocupado {
                      value = $ocupado_por_reserva || $retido
                    }

                    // C8 (D7): só o ocupado e dentro das regras pode ser deslocável; a vaga retida
                    // nunca é deslocável (C9, D9)
                    var $deslocavel {
                      value = false
                    }

                    var $deslocaria {
                      value = 0
                    }

                    conditional {
                      if ($ocupado && $validacao.dentro_das_regras && !$retido) {
                        var $conflitantes {
                          value = $sobrepostas_todas|filter:($$.espaco_id == $espaco.id)
                        }

                        // Booleano calculado à parte: operador dentro do input falha (lição da C5)
                        var $nasce_confirmada {
                          value = true
                        }

                        conditional {
                          if ($regra.exige_aprovacao) {
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
                            prazo_minutos    : $prazo_deslocamento
                            agora            : $agora
                          }
                        } as $avaliacao

                        conditional {
                          if ($avaliacao.deslocavel) {
                            var.update $deslocavel {
                              value = true
                            }

                            var.update $deslocaria {
                              value = $avaliacao.quantidade
                            }
                          }
                        }
                      }
                    }

                    // C9 (D9): fila
                    var $na_fila {
                      value = $ids_na_fila|in:$espaco.id
                    }

                    var $pode_entrar_fila {
                      value = false
                    }

                    conditional {
                      if ($ocupado && $validacao.dentro_das_regras && !$deslocavel && !$na_fila) {
                        var $reserva_propria {
                          value = $sobrepostas_todas|some:($$.espaco_id == $espaco.id && $$.usuario_id == $ator.id)
                        }

                        var $antecedencia_min {
                          value = $tipo.antecedencia_min_minutos|first_notnull:0
                        }

                        function.run corte_fila {
                          input = {
                            inicio                  : $inicio
                            prazo_fila_minutos       : $prazo_fila
                            antecedencia_min_minutos : $antecedencia_min
                            tempo_minimo_fila_minutos: $tempo_minimo_fila
                          }
                        } as $instantes

                        var $fechamento {
                          value = $instantes.fechamento
                        }

                        conditional {
                          if (!$reserva_propria && $agora < $fechamento) {
                            var.update $pode_entrar_fila {
                              value = true
                            }
                          }
                        }
                      }
                    }

                    var.update $item {
                      value = $item
                        |set:"dentro_das_regras":$validacao.dentro_das_regras
                        |set:"motivos":$validacao.motivos
                        |set:"ocupado":$ocupado
                        |set:"deslocavel":$deslocavel
                        |set:"deslocaria":$deslocaria
                        |set:"na_fila":$na_fila
                        |set:"pode_entrar_fila":$pode_entrar_fila
                    }
                  }
                }
              
                var.update $resultado {
                  value = $resultado|push:$item
                }
              }
            }
          }
        }
      }
    }
  }

  response = $resultado
  guid = "YMhrae8AKrQmOllSckiEkuqR3UM"
}