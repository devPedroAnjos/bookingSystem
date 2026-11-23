// Busca de espaços para qualquer conta ativa (spec busca-espacos; design D7). Espaços de todas as
// unidades, só reserváveis e só de tipos que o papel pode reservar. Filtros opcionais: unidade,
// tipo, capacidade mínima, recursos (todos) e data com hora de início e fim (juntos). Com horário,
// cada espaço diz se o pedido está dentro das regras do tipo e os motivos, e se está ocupado por
// reserva PENDENTE ou CONFIRMADA sobreposta (C6, D13), sem dizer quem ocupa. É informativo: a
// reserva confere tudo de novo. POST para receber listas no corpo (D5).
// C11 (design D6): bloqueado diz se há bloqueio ATIVO sobreposto ao intervalo; o espaço bloqueado
// aparece ocupado, não deslocável, sem fila, e sem o motivo nem o autor do bloqueio.
// C8 (design D7): o espaço ocupado e dentro das regras diz se quem busca poderia deslocar a
// ocupação (avaliar_deslocamento, a mesma regra da criação) e quantas reservas seriam deslocadas;
// livre ou fora das regras: deslocavel falso e deslocaria 0. Só a quantidade sai, nunca quem.
// C9 (design D9): a vaga retida pela fila no prazo também ocupa e torna o espaço não deslocável
// (deslocaria 0). na_fila diz se quem busca já está na fila desse espaço e intervalo exatos;
// pode_entrar_fila, se pode entrar: ocupado, dentro das regras, não deslocável, fora da fila, sem
// reserva própria ocupando e antes do fechamento da fila (corte menos o tempo mínimo útil, D12).
// Nunca sai quem ocupa nem quem está na fila.
// espaco-feed-avaliacoes (design D4): os espaços de tipos que o papel não pode reservar aparecem
// restritos (restrito, restricao com os papéis que podem reservar), só com os dados básicos, sem
// descrição, recursos, aprovação, média nem horário. Filtro texto (até 100 caracteres) no nome,
// código, descrição, localização, unidade e tipo, sem maiúsculas nem acentos; no restrito, só nos
// campos que ele mostra, e o filtro de recursos não o encontra. Média e quantidade de avaliações.
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
    text? texto? filters=trim
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
  
    var $texto {
      value = $input.texto|first_notnull:""
    }

    precondition (($texto|strlen) <= 100) {
      error_type = "inputerror"
      error = "O texto da busca deve ter até 100 caracteres."
    }

    var $texto_normalizado {
      value = $texto|to_lower|unaccent
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

    // C11: espaços com bloqueio ativo sobreposto ao intervalo
    var $ids_bloqueados {
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

        // C11 (D6): uma consulta para todos os espaços (encostado não conta)
        db.query bloqueio {
          where = $db.bloqueio.status == "ATIVO" && $db.bloqueio.inicio < $fim && $db.bloqueio.fim > $inicio
          return = {type: "list"}
        } as $bloqueios_sobrepostos

        var.update $ids_bloqueados {
          value = $bloqueios_sobrepostos|map:$$.espaco_id|unique
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
  
    // Média e quantidade de avaliações de todos os espaços ativos, numa chamada (D3)
    function.run avaliacoes_dos_espacos {
      input = {espacos_ids: $espacos|map:$$.id}
    } as $avaliacoes_por_espaco

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
          
            // D4: o tipo que o papel não pode reservar aparece restrito, em vez de ficar de fora
            var $restrito {
              value = $regra.pode_reservar != true
            }

            var $incluir {
              value = $disponibilidade.reservavel && ($input.unidade_id == null || $input.unidade_id == $unidade.id) && ($input.tipo_espaco_id == null || $input.tipo_espaco_id == $espaco.tipo_espaco_id) && ($input.capacidade_minima == null || $espaco.capacidade >= $input.capacidade_minima) && ($recursos_pedidos|every:($ids_do_espaco|in:$$))
            }

            // O restrito não mostra recursos, então o filtro de recursos não o encontra
            conditional {
              if ($restrito && ($recursos_pedidos|count) > 0) {
                var.update $incluir {
                  value = false
                }
              }
            }

            // Texto: só nos campos que o espaço mostra (o restrito não mostra a descrição)
            conditional {
              if ($incluir && ($texto_normalizado|strlen) > 0) {
                var $campos_texto {
                  value = $espaco.nome ~ " " ~ $espaco.codigo ~ " " ~ ($espaco.localizacao|first_notnull:"") ~ " " ~ $unidade.nome ~ " " ~ $tipo.nome
                }

                conditional {
                  if (!$restrito) {
                    var.update $campos_texto {
                      value = $campos_texto ~ " " ~ ($espaco.descricao|first_notnull:"")
                    }
                  }
                }

                var $campos_normalizados {
                  value = $campos_texto|to_lower|unaccent
                }

                conditional {
                  if (!($campos_normalizados|contains:$texto_normalizado)) {
                    var.update $incluir {
                      value = false
                    }
                  }
                }
              }
            }

            // Foto de capa pública (D7), para completos e restritos
            var $foto_url {
              value = null
            }

            conditional {
              if ($incluir) {
                function.run url_da_foto {
                  input = {foto: $espaco.foto_capa}
                } as $url_foto

                var.update $foto_url {
                  value = $url_foto
                }
              }
            }

            conditional {
              if ($incluir && $restrito) {
                // Papéis que podem reservar o tipo, em ordem de prioridade (decisão 16)
                var $papeis_texto {
                  value = ""
                }

                conditional {
                  if (($regras_do_tipo|find:($$.papel == "ALUNO" && $$.pode_reservar == true)) != null) {
                    var.update $papeis_texto {
                      value = "alunos, "
                    }
                  }
                }

                conditional {
                  if (($regras_do_tipo|find:($$.papel == "PROFESSOR" && $$.pode_reservar == true)) != null) {
                    var.update $papeis_texto {
                      value = $papeis_texto ~ "professores, "
                    }
                  }
                }

                var $restricao {
                  value = "Reservável por " ~ $papeis_texto ~ "coordenadores e administradores"
                }

                var $unidade_restrito {
                  value = {}
                    |set:"id":$unidade.id
                    |set:"nome":$unidade.nome
                }

                var $tipo_restrito {
                  value = {}
                    |set:"id":$tipo.id
                    |set:"nome":$tipo.nome
                }

                var $item_restrito {
                  value = {}
                    |set:"id":$espaco.id
                    |set:"nome":$espaco.nome
                    |set:"codigo":$espaco.codigo
                    |set:"unidade":$unidade_restrito
                    |set:"tipo":$tipo_restrito
                    |set:"capacidade":$espaco.capacidade
                    |set:"localizacao":$espaco.localizacao
                    |set:"restrito":true
                    |set:"restricao":$restricao
                    |set:"foto_url":$foto_url
                }

                var.update $resultado {
                  value = $resultado|push:$item_restrito
                }
              }

              elseif ($incluir) {
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

                var $avaliacoes_do_espaco {
                  value = $avaliacoes_por_espaco|find:$$.espaco_id == $espaco.id
                }

                var $total_avaliacoes {
                  value = $avaliacoes_do_espaco.total|first_notnull:0
                }

                var.update $item {
                  value = $item
                    |set:"restrito":false
                    |set:"media_avaliacoes":$avaliacoes_do_espaco.media
                    |set:"total_avaliacoes":$total_avaliacoes
                    |set:"foto_url":$foto_url
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

                    var $bloqueado {
                      value = $ids_bloqueados|in:$espaco.id
                    }

                    var $ocupado {
                      value = $ocupado_por_reserva || $retido || $bloqueado
                    }

                    // C8 (D7): só o ocupado e dentro das regras pode ser deslocável; a vaga retida
                    // nunca é deslocável (C9, D9), nem o bloqueio (C11)
                    var $deslocavel {
                      value = false
                    }

                    var $deslocaria {
                      value = 0
                    }

                    conditional {
                      if ($ocupado && $validacao.dentro_das_regras && !$retido && !$bloqueado) {
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
                      if ($ocupado && $validacao.dentro_das_regras && !$deslocavel && !$na_fila && !$bloqueado) {
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
                        |set:"bloqueado":$bloqueado
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