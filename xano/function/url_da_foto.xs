// URL da foto de capa de um espaço (change espaco-feed-avaliacoes, design D7). Devolve a url do
// objeto de imagem, se o Xano a trouxer, ou o path do vault (o cliente completa com a origem da
// instância, sem variável de ambiente nova). Sem foto, devolve null.
// URL ou path público da foto de capa
function url_da_foto {
  input {
    json? foto?
  }

  stack {
    var $url {
      value = null
    }

    conditional {
      if (!($input.foto|is_null)) {
        var $da_imagem {
          value = $input.foto|get:"url"
        }

        var $caminho {
          value = $input.foto|get:"path"
        }

        var $tem_url {
          value = false
        }

        conditional {
          if (!($da_imagem|is_null)) {
            conditional {
              if (($da_imagem|strlen) > 0) {
                var.update $tem_url {
                  value = true
                }
              }
            }
          }
        }

        conditional {
          if ($tem_url) {
            var.update $url {
              value = $da_imagem
            }
          }

          elseif (!($caminho|is_null)) {
            var.update $url {
              value = $caminho
            }
          }
        }
      }
    }
  }

  response = $url
  guid = "t08OxHNvQzNYXH-BNs9Ehj5iB4c"
}
