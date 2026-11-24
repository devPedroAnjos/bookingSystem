// Envio ou troca da foto de capa (spec espacos; change espaco-feed-avaliacoes, design D7). Quem
// gere o espaço (admin em qualquer unidade, coordenador nas que coordena), ativo ou desativado.
// O input é file? (só ele preenche o path do upload). A imagem é gravada com acesso público
// (plano gratuito sem armazenamento privado; exceção do AGENTS.md §8) e depois conferida: só
// JPEG, PNG ou WEBP e até foto_tamanho_max_kb; a recusada é apagada e nada muda no espaço.
// A troca grava a nova e audita na transação, e só depois apaga o arquivo anterior.
// Envia ou troca a foto de capa de um espaço gerido
query definir_foto_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
    file? foto
  }

  stack {
    // Escopo antes de gravar qualquer arquivo
    db.transaction {
      stack {
        function.run travar_governanca as $trava_escopo
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $escopo
      }
    }

    precondition (!($input.foto|is_null)) {
      error_type = "inputerror"
      error = "Escolha uma foto JPEG, PNG ou WEBP."
    }

    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao

    precondition ($configuracao != null && !($configuracao.foto_tamanho_max_kb|is_null)) {
      error = "Configuração da foto incompleta: execute o bootstrap."
    }

    var $limite_bytes {
      value = $configuracao.foto_tamanho_max_kb * 1024
    }

    var $nova {
      value = null
    }

    // storage.create_image recusa o que não é imagem com erro 500: vira a mensagem de formato
    try_catch {
      try {
        storage.create_image {
          value = $input.foto
          access = "public"
          filename = $input.foto.name
        } as $gravada

        var.update $nova {
          value = $gravada
        }
      }

      catch {
        precondition (false) {
          error_type = "inputerror"
          error = "A foto deve ser JPEG, PNG ou WEBP."
        }
      }
    }

    var $mime {
      value = ($nova|get:"mime")|first_notnull:""
    }

    var $tamanho {
      value = ($nova|get:"size")|first_notnull:0
    }

    var $formato_ok {
      value = ["image/jpeg", "image/png", "image/webp"]|in:$mime
    }

    // Calculado num conditional: && no value de uma variável pode devolver null (ver regra_do_papel)
    var $tamanho_ok {
      value = false
    }

    conditional {
      if ($tamanho > 0 && $tamanho <= $limite_bytes) {
        var.update $tamanho_ok {
          value = true
        }
      }
    }

    conditional {
      if (!$formato_ok || !$tamanho_ok) {
        storage.delete_file {
          pathname = $nova.path
        }
      }
    }

    precondition ($formato_ok) {
      error_type = "inputerror"
      error = "A foto deve ser JPEG, PNG ou WEBP."
    }

    precondition ($tamanho_ok) {
      error_type = "inputerror"
      error = "A foto deve ter até " ~ $configuracao.foto_tamanho_max_kb ~ " KB."
    }

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

        var.update $anterior {
          value = $carregado.espaco.foto_capa
        }

        db.edit espaco {
          field_name = "id"
          field_value = $carregado.espaco.id
          data = {foto_capa: $nova}
        } as $editado

        var $dados_antes {
          value = null
        }

        conditional {
          if (!($anterior|is_null)) {
            var $nome_anterior {
              value = $anterior|get:"name"
            }

            var $tamanho_anterior {
              value = $anterior|get:"size"
            }

            var $path_anterior {
              value = $anterior|get:"path"
            }

            var.update $dados_antes {
              value = {}
                |set:"nome":$nome_anterior
                |set:"tamanho":$tamanho_anterior
                |set:"path":$path_anterior
            }
          }
        }

        var $dados_depois {
          value = {}
            |set:"nome":$nova.name
            |set:"tamanho":$nova.size
            |set:"path":$nova.path
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "DEFINIR_FOTO_ESPACO"
            entidade    : "espaco"
            entidade_id : $carregado.espaco.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : $dados_antes
            dados_depois: $dados_depois
          }
        } as $registro
      }
    }

    // Depois do commit: apaga o arquivo anterior; a falha não desfaz a troca (risco aceito, D7)
    conditional {
      if (!($anterior|is_null)) {
        try_catch {
          try {
            storage.delete_file {
              pathname = $anterior.path
            }
          }

          catch {
            debug.log {
              value = "Foto anterior não apagada: " ~ $anterior.path
            }
          }
        }
      }
    }

    function.run url_da_foto {
      input = {foto: $nova}
    } as $foto_url
  }

  response = {mensagem: "Foto salva.", foto_url: $foto_url}
  guid = "eVSBJNalKV8wDuil0gge7vC5Dc8"
}
