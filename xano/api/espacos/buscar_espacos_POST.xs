// Busca de espaços para qualquer conta ativa (spec busca-espacos; design D7). Espaços de todas as
// unidades, só reserváveis e só de tipos que o papel pode reservar. Filtros opcionais: unidade,
// tipo, capacidade mínima, recursos (todos) e data com hora de início e fim (juntos). Com horário,
// cada espaço diz se o pedido está dentro das regras do tipo e os motivos, e se está ocupado por
// reserva PENDENTE ou CONFIRMADA sobreposta (C6, D13), sem dizer quem ocupa. É informativo: a
// reserva confere tudo de novo. Bloqueios entram na C10. POST para receber listas no corpo (D5).
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
        // Ocupam a confirmada e a pendente que ainda não começou (C7, D2); a busca não grava nada.
        db.query reserva {
          where = ($db.reserva.status == "CONFIRMADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora)) && $db.reserva.inicio < $fim && $db.reserva.fim > $inicio
          return = {type: "list"}
        } as $sobrepostas

        var.update $ids_ocupados {
          value = $sobrepostas|map:$$.espaco_id|unique
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
                  
                    var $ocupado {
                      value = $ids_ocupados|in:$espaco.id
                    }

                    var.update $item {
                      value = $item
                        |set:"dentro_das_regras":$validacao.dentro_das_regras
                        |set:"motivos":$validacao.motivos
                        |set:"ocupado":$ocupado
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