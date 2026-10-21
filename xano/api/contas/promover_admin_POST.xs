// Promoção de coordenador a admin secundário, só pelo principal (spec administradores; D6).
// As coordenações dele são removidas na mesma operação, mesmo que uma unidade fique sem
// coordenador ativo. Respeita o limite de admins ativos.
// Promove um coordenador ativo a administrador, dentro da trava de governança
query promover_admin verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
  }

  stack {
    var $coordenacoes_removidas {
      value = []
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_principal {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        db.get usuario {
          field_name = "id"
          field_value = $input.usuario_id
        } as $alvo
      
        precondition ($alvo != null) {
          error_type = "notfound"
          error = "Conta não encontrada."
        }
      
        precondition ($alvo.papel == "COORDENADOR" && $alvo.status_conta == "ATIVA") {
          error_type = "inputerror"
          error = "Só coordenadores ativos são promovidos a administrador."
        }
      
        function.run vaga_de_admin as $vaga
        db.query coordenacao_unidade {
          join = {
            unidade: {
              table: "unidade"
              where: $db.coordenacao_unidade.unidade_id == $db.unidade.id
            }
          }
        
          where = $db.coordenacao_unidade.usuario_id == $alvo.id
          eval = {unidade_nome: $db.unidade.nome}
          return = {type: "list"}
        } as $coordenacoes
      
        foreach ($coordenacoes) {
          each as $coordenacao {
            function.run remover_coordenacao {
              input = {ator_id: $ator.id, coordenacao_id: $coordenacao.id}
            } as $removida
          
            var.update $coordenacoes_removidas {
              value = $coordenacoes_removidas
                |push:{unidade_id: $coordenacao.unidade_id, nome: $coordenacao.unidade_nome}
            }
          }
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $alvo.id
          data = {papel: "ADMIN", unidade_vinculo_id: null}
        } as $promovido
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "PROMOVER_ADMIN"
            entidade    : "usuario"
            entidade_id : $alvo.id
            dados_antes : {papel: $alvo.papel}
            dados_depois: {papel: $promovido.papel}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem              : "Coordenador promovido a administrador."
    coordenacoes_removidas: $coordenacoes_removidas
  }

  guid = "uYO6paxj6HTZNeLyTjLgsgqiCHM"
}