// Remoção de bloqueio (spec bloqueios; C11, design D5) por quem gere o espaço dele. Só bloqueio
// ATIVO que ainda não terminou; passa a REMOVIDO e não é excluído. Não restaura reservas canceladas
// nem entradas de fila encerradas. Sem edição: para mudar o período, remove-se e cria-se outro.
// Remove um bloqueio, dentro da trava de governança
query remover_bloqueio verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int bloqueio_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
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

        db.get bloqueio {
          field_name = "id"
          field_value = $input.bloqueio_id
        } as $bloqueio

        // Bloqueio inexistente: para o coordenador, 403 como espaço fora do escopo
        conditional {
          if ($bloqueio == null && $ator.papel == "ADMIN") {
            precondition (false) {
              error_type = "notfound"
              error = "Bloqueio não encontrado."
            }
          }

          elseif ($bloqueio == null) {
            precondition (false) {
              error_type = "accessdenied"
              error = "Você não tem acesso a este espaço."
            }
          }
        }

        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $bloqueio.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $carregado

        precondition ($bloqueio.status == "ATIVO") {
          error_type = "inputerror"
          error = "Este bloqueio já foi removido."
        }

        var $agora {
          value = now
        }

        precondition ($bloqueio.fim > $agora) {
          error_type = "inputerror"
          error = "Este bloqueio já terminou."
        }

        db.edit bloqueio {
          field_name = "id"
          field_value = $bloqueio.id
          data = {status: "REMOVIDO"}
        } as $removido

        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "REMOVER_BLOQUEIO"
            entidade    : "bloqueio"
            entidade_id : $bloqueio.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : {status: "ATIVO"}
            dados_depois: {status: "REMOVIDO"}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Bloqueio removido."}
  guid = "W9mK46IZLaIlLfyiqqEJwHBYcwI"
}
