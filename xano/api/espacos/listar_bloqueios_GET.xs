// Bloqueios ativos que ainda não terminaram, das unidades sob o escopo do usuário (spec bloqueios;
// C11, design D5): ADMIN vê todas, COORDENADOR só as que coordena; ALUNO e PROFESSOR recebem 403.
// Filtro opcional por unidade, com 403 fora do escopo. Uma consulta por tabela e junção em memória.
// Ordem: início. Horários formatados em America/Sao_Paulo.
// Lista os bloqueios ativos do escopo do usuário
query listar_bloqueios verb=GET {
  api_group = "espacos"
  auth = "usuario"

  input {
    int? unidade_id?
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator

    precondition ($ator.papel == "ADMIN" || $ator.papel == "COORDENADOR") {
      error_type = "accessdenied"
      error = "Você não tem acesso à gestão de espaços."
    }

    db.query unidade {
      return = {type: "list"}
    } as $todas_unidades

    var $unidades {
      value = $todas_unidades
    }

    conditional {
      if ($ator.papel != "ADMIN") {
        function.run unidades_coordenadas {
          input = {usuario_id: $ator.id}
        } as $coordenadas

        var.update $unidades {
          value = $todas_unidades|filter:($coordenadas|in:$$.id)
        }
      }
    }

    conditional {
      if (!($input.unidade_id|is_null)) {
        var $no_escopo {
          value = $unidades|filter:$$.id == $input.unidade_id
        }

        precondition (($no_escopo|count) > 0) {
          error_type = "accessdenied"
          error = "Você não tem acesso a esta unidade."
        }

        var.update $unidades {
          value = $no_escopo
        }
      }
    }

    var $ids_unidades {
      value = $unidades|map:$$.id
    }

    var $resultado {
      value = []
    }

    conditional {
      if (($ids_unidades|count) > 0) {
        db.query espaco {
          where = $db.espaco.unidade_id in $ids_unidades
          return = {type: "list"}
        } as $espacos

        var $ids_espacos {
          value = $espacos|map:$$.id
        }

        var $agora {
          value = now
        }

        conditional {
          if (($ids_espacos|count) > 0) {
            db.query bloqueio {
              where = $db.bloqueio.espaco_id in $ids_espacos && $db.bloqueio.status == "ATIVO" && $db.bloqueio.fim > $agora
              sort = {inicio: "asc"}
              return = {type: "list"}
            } as $bloqueios

            var $ids_autores {
              value = $bloqueios|map:$$.criado_por_id|unique
            }

            var $autores {
              value = []
            }

            conditional {
              if (($ids_autores|count) > 0) {
                db.query usuario {
                  where = $db.usuario.id in $ids_autores
                  return = {type: "list"}
                } as $usuarios

                var.update $autores {
                  value = $usuarios
                }
              }
            }

            foreach ($bloqueios) {
              each as $bloqueio {
                var $espaco {
                  value = $espacos|find:$$.id == $bloqueio.espaco_id
                }

                var $unidade {
                  value = $unidades|find:$$.id == $espaco.unidade_id
                }

                var $autor {
                  value = $autores|find:$$.id == $bloqueio.criado_por_id
                }

                var $inicio_texto {
                  value = $bloqueio.inicio|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
                }

                var $fim_texto {
                  value = $bloqueio.fim|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
                }

                var $item {
                  value = {}
                    |set:"id":$bloqueio.id
                    |set:"espaco_id":$espaco.id
                    |set:"espaco_codigo":$espaco.codigo
                    |set:"espaco_nome":$espaco.nome
                    |set:"unidade_id":$unidade.id
                    |set:"unidade":$unidade.nome
                    |set:"tipo":$bloqueio.tipo
                    |set:"motivo":$bloqueio.motivo
                    |set:"inicio":$inicio_texto
                    |set:"fim":$fim_texto
                    |set:"criado_por":$autor.nome
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
  guid = "3LGvTTwOnY48BtC4uNsapANzAOA"
}
