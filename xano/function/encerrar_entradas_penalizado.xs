// Encerra as entradas ativas de fila de quem recebeu uma penalidade em vigor (C10, design D7;
// decisão 4). Pressupõe que quem chama já segura a trava de governança. Cada entrada AGUARDANDO
// ou NOTIFICADA fica ENCERRADA, com um ENCERRAR_FILA de ator vazio e motivo PENALIDADE. A vaga
// retida é passada ao próximo pelo processar_fila que roda depois, na mesma transação.
// Devolve quantas entradas foram encerradas
function encerrar_entradas_penalizado {
  input {
    int usuario_id
  }

  stack {
    db.query entrada_fila {
      where = $db.entrada_fila.usuario_id == $input.usuario_id && ($db.entrada_fila.status == "AGUARDANDO" || $db.entrada_fila.status == "NOTIFICADA")
      return = {type: "list"}
    } as $ativas

    conditional {
      if (($ativas|count) > 0) {
        var $ids_espacos {
          value = $ativas|map:$$.espaco_id|unique
        }

        db.query espaco {
          where = $db.espaco.id in $ids_espacos
          return = {type: "list"}
        } as $espacos

        foreach ($ativas) {
          each as $entrada {
            db.edit entrada_fila {
              field_name = "id"
              field_value = $entrada.id
              data = {status: "ENCERRADA"}
            } as $encerrada

            var $espaco {
              value = $espacos|find:$$.id == $entrada.espaco_id
            }

            var $dados_antes {
              value = {}|set:"status":$entrada.status
            }

            var $dados_depois {
              value = {}
                |set:"status":$encerrada.status
                |set:"motivo":"PENALIDADE"
            }

            function.run registrar_auditoria {
              input = {
                ator_id     : null
                acao        : "ENCERRAR_FILA"
                entidade    : "entrada_fila"
                entidade_id : $entrada.id
                unidade_id  : $espaco.unidade_id
                dados_antes : $dados_antes
                dados_depois: $dados_depois
              }
            } as $registro
          }
        }
      }
    }

    var $quantidade {
      value = $ativas|count
    }
  }

  response = $quantidade
  guid = "nY-vfp3hQqtZutMCHRCBqQdWYi4"
}
