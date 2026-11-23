// Remoção da foto de capa (spec espacos; change espaco-feed-avaliacoes, design D7). Quem gere o
// espaço; espaço sem foto é recusado sem auditoria. Zera o campo e audita na transação, e só
// depois apaga o arquivo do armazenamento, para a URL antiga deixar de abrir.
// Remove a foto de capa de um espaço gerido
query remover_foto_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
  }

  stack {
    var $anterior {
      value = null
    }

    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $carregado

        precondition (!($carregado.espaco.foto_capa|is_null)) {
          error_type = "inputerror"
          error = "O espaço não tem foto de capa."
        }

        var.update $anterior {
          value = $carregado.espaco.foto_capa
        }

        db.edit espaco {
          field_name = "id"
          field_value = $carregado.espaco.id
          data = {foto_capa: null}
        } as $editado

        var $nome_anterior {
          value = $anterior|get:"name"
        }

        var $tamanho_anterior {
          value = $anterior|get:"size"
        }

        var $path_anterior {
          value = $anterior|get:"path"
        }

        var $dados_antes {
          value = {}
            |set:"nome":$nome_anterior
            |set:"tamanho":$tamanho_anterior
            |set:"path":$path_anterior
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "REMOVER_FOTO_ESPACO"
            entidade    : "espaco"
            entidade_id : $carregado.espaco.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : $dados_antes
          }
        } as $registro
      }
    }

    try_catch {
      try {
        storage.delete_file {
          pathname = $anterior.path
        }
      }

      catch {
        debug.log {
          value = "Foto removida não apagada: " ~ $anterior.path
        }
      }
    }
  }

  response = {mensagem: "Foto removida."}
  guid = "wvxWd4QP4gZBmWImkfUMRTiBR28"
}
