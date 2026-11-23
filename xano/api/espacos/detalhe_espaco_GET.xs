// Detalhe de um espaço para a página do espaço (spec pagina-espaco; change espaco-feed-avaliacoes,
// design D6). Qualquer conta ativa, para espaço reservável de tipo que o papel pode reservar
// (coordenador e admin, todos). Inexistente, não reservável ou restrito ao papel recebem a mesma
// recusa "Espaço não encontrado." (decisão 19). Traz os dados da busca e as avaliações (D3): média
// com uma casa, quantidade e lista da mais recente para a mais antiga, com o autor só como primeiro
// nome e papel atual, sem e-mail, id do autor nem reserva. Não mostra reservas, ocupação nem bloqueios.
// Devolve o detalhe e as avaliações de um espaço
query detalhe_espaco verb=GET {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator

    db.get espaco {
      field_name = "id"
      field_value = $input.espaco_id
    } as $espaco

    precondition ($espaco != null) {
      error_type = "notfound"
      error = "Espaço não encontrado."
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

    var $visivel {
      value = false
    }

    conditional {
      if ($disponibilidade.reservavel && $regra.pode_reservar) {
        var.update $visivel {
          value = true
        }
      }
    }

    precondition ($visivel) {
      error_type = "notfound"
      error = "Espaço não encontrado."
    }

    db.query espaco_recurso {
      where = $db.espaco_recurso.espaco_id == $espaco.id
      return = {type: "list"}
    } as $associacoes

    db.query recurso {
      return = {type: "list"}
    } as $recursos

    var $recursos_do_espaco {
      value = []
    }

    foreach ($associacoes) {
      each as $associacao {
        var $recurso {
          value = $recursos|find:$$.id == $associacao.recurso_id
        }

        var $recurso_item {
          value = {}
            |set:"nome":$recurso.nome
            |set:"quantidade":$associacao.quantidade
        }

        var.update $recursos_do_espaco {
          value = $recursos_do_espaco|push:$recurso_item
        }
      }
    }

    // Avaliações: reservas do espaço e as avaliações delas (D3). Sem filtro de situação: a avaliação
    // pode ter sido aceita pela situação efetiva antes de a conclusão ser gravada
    db.query reserva {
      where = $db.reserva.espaco_id == $espaco.id
      return = {type: "list"}
    } as $reservas_do_espaco

    var $ids_reservas {
      value = $reservas_do_espaco|map:$$.id
    }

    var $avaliacoes {
      value = []
    }

    conditional {
      if (($ids_reservas|count) > 0) {
        db.query avaliacao {
          where = $db.avaliacao.reserva_id in $ids_reservas
          sort = {criado_em: "desc"}
          return = {type: "list"}
        } as $avaliacoes_do_espaco

        var.update $avaliacoes {
          value = $avaliacoes_do_espaco
        }
      }
    }

    var $ids_autores {
      value = $avaliacoes|map:$$.usuario_id|unique
    }

    var $autores {
      value = []
    }

    conditional {
      if (($ids_autores|count) > 0) {
        db.query usuario {
          where = $db.usuario.id in $ids_autores
          return = {type: "list"}
        } as $usuarios_autores

        var.update $autores {
          value = $usuarios_autores
        }
      }
    }

    var $lista_avaliacoes {
      value = []
    }

    foreach ($avaliacoes) {
      each as $avaliacao {
        var $autor {
          value = $autores|find:$$.id == $avaliacao.usuario_id
        }

        var $primeiro_nome {
          value = ($autor.nome|first_notnull:"")|split:" "|first
        }

        var $data {
          value = $avaliacao.criado_em|format_timestamp:"d/m/Y":"America/Sao_Paulo"
        }

        // O campo text volta "" quando gravado vazio; a API devolve null (comentário ausente)
        var $comentario {
          value = null
        }

        conditional {
          if ((($avaliacao.comentario|first_notnull:"")|strlen) > 0) {
            var.update $comentario {
              value = $avaliacao.comentario
            }
          }
        }

        var $avaliacao_item {
          value = {}
            |set:"nota":$avaliacao.nota
            |set:"comentario":$comentario
            |set:"data":$data
            |set:"autor_nome":$primeiro_nome
            |set:"autor_papel":$autor.papel
        }

        var.update $lista_avaliacoes {
          value = $lista_avaliacoes|push:$avaliacao_item
        }
      }
    }

    var $total {
      value = $avaliacoes|count
    }

    var $media {
      value = null
    }

    conditional {
      if ($total > 0) {
        var.update $media {
          value = (($avaliacoes|map:$$.nota|sum) / $total)|round:1
        }
      }
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

    var $recursos_ordenados {
      value = $recursos_do_espaco|sort:"nome":"itext":true
    }

    function.run url_da_foto {
      input = {foto: $espaco.foto_capa}
    } as $foto_url

    var $resposta {
      value = {}
        |set:"foto_url":$foto_url
        |set:"id":$espaco.id
        |set:"nome":$espaco.nome
        |set:"codigo":$espaco.codigo
        |set:"unidade":$unidade_item
        |set:"tipo":$tipo_item
        |set:"capacidade":$espaco.capacidade
        |set:"localizacao":$espaco.localizacao
        |set:"descricao":$espaco.descricao
        |set:"recursos":$recursos_ordenados
        |set:"exige_aprovacao":$regra.exige_aprovacao
        |set:"media_avaliacoes":$media
        |set:"total_avaliacoes":$total
        |set:"avaliacoes":$lista_avaliacoes
    }
  }

  response = $resposta
  guid = "4YTJ87ePgxEdaLNLn4ijU2kpXOQ"
}
