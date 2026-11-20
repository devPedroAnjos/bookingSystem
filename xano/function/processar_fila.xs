// Única porta do processamento da fila de espera (C9, design D5). Grava; pressupõe que quem chama
// já segura a trava de governança. Chamada por processar_vencimentos (depois das expirações de
// reservas), por cancelar_reserva, recusar_reserva e desistir_fila, e por cancelar_reservas.
// Passos: (1) NOTIFICADA vencida -> EXPIRADA, com o prazo como instante; (2) AGUARDANDO no
// fechamento da fila (corte menos o tempo mínimo útil, D12), de espaço não reservável ou de conta
// não ATIVA -> ENCERRADA; (3) AGUARDANDO na ordem
// nivel_prioridade desc, criado_em asc, id asc -> NOTIFICADA quando o intervalo está livre de
// reserva ocupando (C7, D2) e de vaga retida no prazo, inclusive as retidas nesta passada. Esse
// percurso guloso implementa a regra das filas sobrepostas (§7.4). Sai cedo sem entradas ativas.
// Teto técnico de 100 entradas por passo; o resto vai na próxima rodada, coberto pela situação
// efetiva. Auditoria com ator vazio (design D8).
// Processa a fila de todos os espaços e devolve quantas entradas expirou, encerrou e avisou
function processar_fila {
  input {
    // Instante de referência, em ms
    int agora
  }

  stack {
    var $expiradas {
      value = 0
    }

    var $encerradas {
      value = 0
    }

    var $notificadas {
      value = 0
    }

    // Caso comum: nenhuma entrada ativa, nada a ler nem a gravar
    db.query entrada_fila {
      where = $db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA"
      return = {type: "count"}
    } as $ativas

    conditional {
      if ($ativas > 0) {
        // Prazo lido direto da tabela, como os outros prazos (C6, D12)
        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao

        precondition ($configuracao != null && !($configuracao.prazo_fila_minutos|is_null) && !($configuracao.prazo_confirmacao_fila_minutos|is_null) && !($configuracao.tempo_minimo_fila_minutos|is_null)) {
          error = "Configuração de reservas incompleta: execute o bootstrap."
        }

        // Prazo para confirmar, contado do aviso e limitado ao corte (D12)
        var $prazo_ms {
          value = $configuracao.prazo_confirmacao_fila_minutos * 60000
        }

        // Unidades e tipos são poucos: uma consulta de cada
        db.query unidade {
          return = {type: "list"}
        } as $unidades

        db.query tipo_espaco {
          return = {type: "list"}
        } as $tipos

        // 1. Vagas retidas vencidas
        db.query entrada_fila {
          where = $db.entrada_fila.status == "NOTIFICADA" && $db.entrada_fila.prazo_confirmacao < $input.agora
          sort = {prazo_confirmacao: "asc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 100, metadata: false}
          }
        } as $vencidas

        conditional {
          if (($vencidas|count) > 0) {
            var $ids_espacos_vencidas {
              value = $vencidas|map:$$.espaco_id|unique
            }

            db.query espaco {
              where = $db.espaco.id in $ids_espacos_vencidas
              return = {type: "list"}
            } as $espacos_vencidas

            foreach ($vencidas) {
              each as $vencida {
                db.edit entrada_fila {
                  field_name = "id"
                  field_value = $vencida.id
                  data = {status: "EXPIRADA"}
                } as $expirada

                var $espaco_vencida {
                  value = $espacos_vencidas|find:$$.id == $vencida.espaco_id
                }

                var $dados_antes_expiracao {
                  value = {}|set:"status":$vencida.status
                }

                var $dados_depois_expiracao {
                  value = {}
                    |set:"status":$expirada.status
                    |set:"expirou_em":$vencida.prazo_confirmacao
                }

                function.run registrar_auditoria {
                  input = {
                    ator_id     : null
                    acao        : "EXPIRAR_FILA"
                    entidade    : "entrada_fila"
                    entidade_id : $vencida.id
                    unidade_id  : $espaco_vencida.unidade_id
                    dados_antes : $dados_antes_expiracao
                    dados_depois: $dados_depois_expiracao
                  }
                } as $registro_expiracao
              }
            }

            var.update $expiradas {
              value = $vencidas|count
            }
          }
        }

        // 2 e 3 usam as mesmas AGUARDANDO, já na ordem da fila
        db.query entrada_fila {
          where = $db.entrada_fila.status == "AGUARDANDO"
          sort = {nivel_prioridade: "desc", criado_em: "asc", id: "asc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 100, metadata: false}
          }
        } as $aguardando

        conditional {
          if (($aguardando|count) > 0) {
            var $ids_espacos {
              value = $aguardando|map:$$.espaco_id|unique
            }

            var $ids_usuarios {
              value = $aguardando|map:$$.usuario_id|unique
            }

            db.query espaco {
              where = $db.espaco.id in $ids_espacos
              return = {type: "list"}
            } as $espacos

            db.query usuario {
              where = $db.usuario.id in $ids_usuarios
              return = {type: "list"}
            } as $usuarios

            var $ids_tipos {
              value = $espacos|map:$$.tipo_espaco_id|unique
            }

            db.query regra_papel {
              where = $db.regra_papel.tipo_espaco_id in $ids_tipos
              return = {type: "list"}
            } as $regras

            // Ocupação dos espaços com entradas aguardando, lida uma vez (design D5), com o
            // predicado de ocupação da C10 (D2)
            function.run obter_configuracao_comparecimento as $comparecimento

            var $inicio_minimo {
              value = $input.agora - $comparecimento.depois_ms
            }

            db.query reserva {
              where = $db.reserva.espaco_id in $ids_espacos && (($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $input.agora) || ($db.reserva.status == "CONFIRMADA" && $db.reserva.fim > $input.agora && ($db.reserva.check_in_em != null || $db.reserva.inicio >= $inicio_minimo || $db.reserva.inicio < $comparecimento.comparecimento_desde)))
              return = {type: "list"}
            } as $reservas_ocupando

            db.query entrada_fila {
              where = $db.entrada_fila.espaco_id in $ids_espacos && $db.entrada_fila.status == "NOTIFICADA" && $db.entrada_fila.prazo_confirmacao >= $input.agora
              return = {type: "list"}
            } as $retidas_banco

            // Intervalos retidos: os do banco mais as entradas avisadas nesta passada (os registros
            // inteiros, sem objeto literal; só espaco_id, inicio e fim são lidos)
            var $retidas {
              value = $retidas_banco
            }

            foreach ($aguardando) {
              each as $entrada {
                var $espaco {
                  value = $espacos|find:$$.id == $entrada.espaco_id
                }

                var $usuario {
                  value = $usuarios|find:$$.id == $entrada.usuario_id
                }

                var $motivo_encerramento {
                  value = null
                }

                var $corte {
                  value = 0
                }

                var $fechamento {
                  value = 0
                }

                conditional {
                  if ($espaco == null) {
                    var.update $motivo_encerramento {
                      value = "ESPACO_INDISPONIVEL"
                    }
                  }

                  else {
                    var $tipo {
                      value = $tipos|find:$$.id == $espaco.tipo_espaco_id
                    }

                    var $unidade {
                      value = $unidades|find:$$.id == $espaco.unidade_id
                    }

                    var $regras_do_tipo {
                      value = $regras|filter:($$.tipo_espaco_id == $espaco.tipo_espaco_id)
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

                    // Filtro fora do input da função (lição da C5)
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

                    var.update $corte {
                      value = $instantes.corte
                    }

                    var.update $fechamento {
                      value = $instantes.fechamento
                    }

                    conditional {
                      if ($input.agora >= $fechamento) {
                        var.update $motivo_encerramento {
                          value = "CORTE"
                        }
                      }

                      elseif (!$disponibilidade.reservavel) {
                        var.update $motivo_encerramento {
                          value = "ESPACO_INDISPONIVEL"
                        }
                      }

                      elseif ($usuario == null || $usuario.status_conta != "ATIVA") {
                        var.update $motivo_encerramento {
                          value = "CONTA_INATIVADA"
                        }
                      }
                    }
                  }
                }

                conditional {
                  // 2. Encerramento
                  if (!($motivo_encerramento|is_null)) {
                    db.edit entrada_fila {
                      field_name = "id"
                      field_value = $entrada.id
                      data = {status: "ENCERRADA"}
                    } as $encerrada

                    var $dados_depois_encerramento {
                      value = {}
                        |set:"status":$encerrada.status
                        |set:"motivo":$motivo_encerramento
                    }

                    conditional {
                      if ($motivo_encerramento == "CORTE") {
                        var.update $dados_depois_encerramento {
                          value = $dados_depois_encerramento|set:"encerrou_em":$fechamento
                        }
                      }
                    }

                    var $dados_antes_encerramento {
                      value = {}|set:"status":$entrada.status
                    }

                    var $unidade_encerramento {
                      value = null
                    }

                    conditional {
                      if ($espaco != null) {
                        var.update $unidade_encerramento {
                          value = $espaco.unidade_id
                        }
                      }
                    }

                    function.run registrar_auditoria {
                      input = {
                        ator_id     : null
                        acao        : "ENCERRAR_FILA"
                        entidade    : "entrada_fila"
                        entidade_id : $entrada.id
                        unidade_id  : $unidade_encerramento
                        dados_antes : $dados_antes_encerramento
                        dados_depois: $dados_depois_encerramento
                      }
                    } as $registro_encerramento

                    var.update $encerradas {
                      value = $encerradas + 1
                    }
                  }

                  // 3. Aviso, se o intervalo estiver livre
                  else {
                    var $reserva_sobreposta {
                      value = $reservas_ocupando|some:($$.espaco_id == $entrada.espaco_id && $$.inicio < $entrada.fim && $$.fim > $entrada.inicio)
                    }

                    var $retida_sobreposta {
                      value = $retidas|some:($$.espaco_id == $entrada.espaco_id && $$.inicio < $entrada.fim && $$.fim > $entrada.inicio)
                    }

                    conditional {
                      if (!$reserva_sobreposta && !$retida_sobreposta) {
                        // Prazo: prazo_confirmacao_fila_minutos a partir do aviso, limitado ao corte
                        // (D12). Como o aviso só ocorre antes do fechamento, sobra ao menos o
                        // tempo mínimo útil.
                        var $prazo {
                          value = $input.agora + $prazo_ms
                        }

                        conditional {
                          if ($corte < $prazo) {
                            var.update $prazo {
                              value = $corte
                            }
                          }
                        }

                        db.edit entrada_fila {
                          field_name = "id"
                          field_value = $entrada.id
                          data = {
                            status           : "NOTIFICADA"
                            notificado_em    : $input.agora
                            prazo_confirmacao: $prazo
                          }
                        } as $notificada

                        var.update $retidas {
                          value = $retidas|push:$entrada
                        }

                        var $dados_antes_aviso {
                          value = {}|set:"status":$entrada.status
                        }

                        var $dados_depois_aviso {
                          value = {}
                            |set:"status":$notificada.status
                            |set:"prazo_confirmacao":$prazo
                        }

                        function.run registrar_auditoria {
                          input = {
                            ator_id     : null
                            acao        : "NOTIFICAR_FILA"
                            entidade    : "entrada_fila"
                            entidade_id : $entrada.id
                            unidade_id  : $espaco.unidade_id
                            dados_antes : $dados_antes_aviso
                            dados_depois: $dados_depois_aviso
                          }
                        } as $registro_aviso

                        var.update $notificadas {
                          value = $notificadas + 1
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    var $resultado {
      value = {}
        |set:"expiradas":$expiradas
        |set:"encerradas":$encerradas
        |set:"notificadas":$notificadas
    }
  }

  response = $resultado
  guid = "cJKPI-Qy0xUjWkzF7VQxJaiGMXU"
}
