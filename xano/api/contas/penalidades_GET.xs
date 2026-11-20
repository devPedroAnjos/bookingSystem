// Penalidades de todos os usuários para os admins (spec penalidades; C10, design D6 e D8). Só
// leitura, sem trava. A penalidade é do usuário, não de uma unidade, então não há escopo de unidade:
// só admin (principal ou secundário). Filtros: situação (EM_VIGOR, o padrão; ATIVA; CUMPRIDA;
// ANULADA; TODAS), pela situação efetiva, e busca por nome ou e-mail. Teto de 200, com "limitada".
// Cada penalidade traz o usuário (nome e e-mail), início e fim em São Paulo, a situação efetiva, as
// faltas com a reserva e, se anulada, quem anulou, quando e o parecer. pode_anular segue a regra da
// anulação (ATIVA não cumprida e de outra pessoa), só para usabilidade.
// Lista as penalidades para o admin
query penalidades verb=GET {
  api_group = "contas"
  auth = "usuario"

  input {
    text? situacao? filters=trim|upper
    text? busca? filters=trim|lower
  }

  stack {
    function.run exigir_admin {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator

    var $situacao {
      value = $input.situacao|first_notnull:""
    }

    conditional {
      if (($situacao|strlen) == 0) {
        var.update $situacao {
          value = "EM_VIGOR"
        }
      }
    }

    // Texto com split em vez de lista literal: o Xano tira as vírgulas dos literais ao salvar
    var $situacoes_aceitas {
      value = "EM_VIGOR,ATIVA,CUMPRIDA,ANULADA,TODAS"|split:","
    }

    precondition ($situacoes_aceitas|in:$situacao) {
      error_type = "inputerror"
      error = "Situação inválida."
    }

    var $agora {
      value = now
    }

    // Busca por nome ou e-mail, como em usuarios (filtro em memória, sem diferenciar maiúsculas)
    var $busca {
      value = $input.busca|first_notnull:""
    }

    var $ids_buscados {
      value = null
    }

    conditional {
      if (($busca|strlen) > 0) {
        db.query usuario {
          return = {type: "list"}
        } as $todos_usuarios

        var $encontrados {
          value = $todos_usuarios|filter:((($$.nome|to_lower)|contains:$busca) || (($$.email|to_lower)|contains:$busca))
        }

        var.update $ids_buscados {
          value = $encontrados|map:$$.id
        }
      }
    }

    var $encontradas {
      value = []
    }

    conditional {
      // Busca sem resultado: nada a consultar (nunca um "in" com lista vazia)
      if (!($ids_buscados|is_null) && ($ids_buscados|count) == 0) {
        var.update $encontradas {
          value = []
        }
      }

      elseif ($situacao == "EM_VIGOR") {
        db.query penalidade {
          where = $db.penalidade.usuario_id in? $ids_buscados && $db.penalidade.status == "ATIVA" && $db.penalidade.inicio <= $agora && $db.penalidade.fim > $agora
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $em_vigor

        var.update $encontradas {
          value = $em_vigor
        }
      }

      elseif ($situacao == "ATIVA") {
        db.query penalidade {
          where = $db.penalidade.usuario_id in? $ids_buscados && $db.penalidade.status == "ATIVA" && $db.penalidade.fim > $agora
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $ativas

        var.update $encontradas {
          value = $ativas
        }
      }

      elseif ($situacao == "CUMPRIDA") {
        db.query penalidade {
          where = $db.penalidade.usuario_id in? $ids_buscados && ($db.penalidade.status == "CUMPRIDA" || ($db.penalidade.status == "ATIVA" && $db.penalidade.fim <= $agora))
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $cumpridas

        var.update $encontradas {
          value = $cumpridas
        }
      }

      elseif ($situacao == "ANULADA") {
        db.query penalidade {
          where = $db.penalidade.usuario_id in? $ids_buscados && $db.penalidade.status == "ANULADA"
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $anuladas

        var.update $encontradas {
          value = $anuladas
        }
      }

      else {
        db.query penalidade {
          where = $db.penalidade.usuario_id in? $ids_buscados
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $todas

        var.update $encontradas {
          value = $todas
        }
      }
    }

    var $limitada {
      value = false
    }

    conditional {
      if (($encontradas|count) > 200) {
        var.update $limitada {
          value = true
        }
      }
    }

    var $penalidades {
      value = $encontradas|slice:0:200
    }

    var $lista {
      value = []
    }

    conditional {
      if (($penalidades|count) > 0) {
        var $ids_penalidades {
          value = $penalidades|map:$$.id
        }

        var $ids_donos {
          value = $penalidades|map:$$.usuario_id
        }

        var $ids_anuladores {
          value = $penalidades|map:$$.anulada_por_id
        }

        // Uma lista só, sem vazios (como em reservas_unidade)
        var $ids_usuarios {
          value = $ids_donos|merge:$ids_anuladores|filter:$$ > 0|unique
        }

        db.query usuario {
          where = $db.usuario.id in $ids_usuarios
          return = {type: "list"}
        } as $usuarios

        db.query falta {
          where = $db.falta.penalidade_id in $ids_penalidades
          sort = {ocorrida_em: "asc"}
          return = {type: "list"}
        } as $faltas

        var $ids_reservas {
          value = $faltas|map:$$.reserva_id
        }

        var $reservas {
          value = []
        }

        var $espacos {
          value = []
        }

        conditional {
          if (($ids_reservas|count) > 0) {
            db.query reserva {
              where = $db.reserva.id in $ids_reservas
              return = {type: "list"}
            } as $reservas_das_faltas

            var.update $reservas {
              value = $reservas_das_faltas
            }

            var $ids_espacos {
              value = $reservas_das_faltas|map:$$.espaco_id|unique
            }

            db.query espaco {
              where = $db.espaco.id in $ids_espacos
              return = {type: "list"}
            } as $espacos_das_faltas

            var.update $espacos {
              value = $espacos_das_faltas
            }
          }
        }

        foreach ($penalidades) {
          each as $penalidade {
            var $dono {
              value = $usuarios|find:$$.id == $penalidade.usuario_id
            }

            var $situacao_item {
              value = $penalidade.status
            }

            conditional {
              if ($penalidade.status == "ATIVA" && $penalidade.fim <= $agora) {
                var.update $situacao_item {
                  value = "CUMPRIDA"
                }
              }
            }

            var $em_vigor_item {
              value = false
            }

            conditional {
              if ($situacao_item == "ATIVA" && $penalidade.inicio <= $agora) {
                var.update $em_vigor_item {
                  value = true
                }
              }
            }

            var $pode_anular {
              value = false
            }

            conditional {
              if ($situacao_item == "ATIVA" && $penalidade.usuario_id != $ator.id) {
                var.update $pode_anular {
                  value = true
                }
              }
            }

            var $faltas_item {
              value = []
            }

            var $da_penalidade {
              value = $faltas|filter:($$.penalidade_id == $penalidade.id)
            }

            foreach ($da_penalidade) {
              each as $falta {
                var $reserva {
                  value = $reservas|find:$$.id == $falta.reserva_id
                }

                var $espaco {
                  value = $espacos|find:$$.id == $reserva.espaco_id
                }

                function.run formatar_reserva {
                  input = {inicio: $reserva.inicio, fim: $reserva.fim}
                } as $formatada

                var $ocorrida_texto {
                  value = $falta.ocorrida_em|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
                }

                var $falta_item {
                  value = {}
                    |set:"tipo":$falta.tipo
                    |set:"ocorrida_em":$ocorrida_texto
                    |set:"espaco_codigo":$espaco.codigo
                    |set:"espaco_nome":$espaco.nome
                    |set:"data":$formatada.data
                    |set:"hora_inicio":$formatada.hora_inicio
                    |set:"hora_fim":$formatada.hora_fim
                }

                var.update $faltas_item {
                  value = $faltas_item|push:$falta_item
                }
              }
            }

            var $anulada_por {
              value = null
            }

            var $anulada_em_texto {
              value = null
            }

            conditional {
              if ($penalidade.status == "ANULADA") {
                var $anulador {
                  value = $usuarios|find:$$.id == $penalidade.anulada_por_id
                }

                var.update $anulada_por {
                  value = $anulador.nome
                }

                var.update $anulada_em_texto {
                  value = $penalidade.anulada_em|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
                }
              }
            }

            var $inicio_texto {
              value = $penalidade.inicio|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
            }

            var $fim_texto {
              value = $penalidade.fim|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
            }

            var $usuario_item {
              value = {}
                |set:"id":$dono.id
                |set:"nome":$dono.nome
                |set:"email":$dono.email
            }

            var $item {
              value = {}
                |set:"id":$penalidade.id
                |set:"usuario":$usuario_item
                |set:"inicio":$inicio_texto
                |set:"fim":$fim_texto
                |set:"status":$situacao_item
                |set:"em_vigor":$em_vigor_item
                |set:"pode_anular":$pode_anular
                |set:"faltas":$faltas_item
                |set:"anulada_por":$anulada_por
                |set:"anulada_em":$anulada_em_texto
                |set:"parecer":$penalidade.parecer
            }

            var.update $lista {
              value = $lista|push:$item
            }
          }
        }
      }
    }

    var $resposta {
      value = {}
        |set:"penalidades":$lista
        |set:"limitada":$limitada
    }
  }

  response = $resposta
  guid = "cA3-I4-trp4Nk572BUw7LhC4al4"
}
