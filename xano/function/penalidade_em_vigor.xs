// Penalidade em vigor de um usuário (C10, design D6): ATIVA com inicio <= agora < fim. Devolve até
// quando vão as penalidades encadeadas sem intervalo a partir da que está em vigor (a próxima
// começa exatamente no fim da anterior), com o texto em America/Sao_Paulo para a mensagem de recusa.
// Pressupõe as faltas do usuário já processadas (processar_vencimentos_usuario).
// Devolve {em_vigor, ate, ate_texto}
function penalidade_em_vigor {
  input {
    int usuario_id

    // Agora da operação, em ms
    int agora
  }

  stack {
    db.query penalidade {
      where = $db.penalidade.usuario_id == $input.usuario_id && $db.penalidade.status == "ATIVA" && $db.penalidade.fim > $input.agora
      sort = {inicio: "asc"}
      return = {type: "list"}
    } as $ativas

    var $em_vigor {
      value = false
    }

    var $ate {
      value = null
    }

    var $ate_texto {
      value = null
    }

    conditional {
      if (($ativas|count) > 0) {
        var $primeira {
          value = $ativas|first
        }

        conditional {
          if ($primeira.inicio <= $input.agora) {
            var.update $em_vigor {
              value = true
            }

            var.update $ate {
              value = $primeira.fim
            }

            // Encadeadas contíguas: as penalidades nunca se sobrepõem, então basta comparar
            foreach ($ativas) {
              each as $penalidade {
                conditional {
                  if ($penalidade.inicio == $ate) {
                    var.update $ate {
                      value = $penalidade.fim
                    }
                  }
                }
              }
            }

            var $data_texto {
              value = $ate|format_timestamp:"d/m/Y":"America/Sao_Paulo"
            }

            var $hora_texto {
              value = $ate|format_timestamp:"H:i":"America/Sao_Paulo"
            }

            var.update $ate_texto {
              value = $data_texto ~ " às " ~ $hora_texto
            }
          }
        }
      }
    }

    var $resultado {
      value = {}
        |set:"em_vigor":$em_vigor
        |set:"ate":$ate
        |set:"ate_texto":$ate_texto
    }
  }

  response = $resultado
  guid = "xK_9j9rAJk9yWV5528raMZzh7FE"
}
