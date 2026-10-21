// Desativação de unidade pelo admin (spec unidades; design.md, D10). Num único formulário:
// - coordenador que só coordena esta unidade recebe destino (ativo, com vaga, contando o formulário);
// - coordenador que também coordena outra apenas perde esta;
// - cada professor ATIVA da unidade recebe destino ativo;
// - pedidos PENDENTE da unidade são recusados automaticamente, sem consumir pedido.
// Tudo é validado antes de qualquer gravação; se algo falhar, nada muda.
// Desativa uma unidade, redistribuindo coordenadores e professores, dentro da trava de governança
query desativar verb=POST {
  api_group = "unidades"
  auth = "usuario"

  input {
    int unidade_id
    json? destinos_coordenadores?
    json? destinos_professores?
  }

  stack {
    var $destinos_coordenadores {
      value = $input.destinos_coordenadores|first_notnull:[]
    }
  
    var $destinos_professores {
      value = $input.destinos_professores|first_notnull:[]
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_id
        } as $unidade
      
        precondition ($unidade != null) {
          error_type = "notfound"
          error = "Unidade não encontrada."
        }
      
        precondition ($unidade.ativa) {
          error_type = "inputerror"
          error = "A unidade já está desativada."
        }
      
        // 1. Coordenadores que só coordenam esta unidade precisam de destino
        function.run coordenadores_ativos {
          input = {unidade_id: $unidade.id}
        } as $coordenadores
      
        var $precisam_destino {
          value = []
        }
      
        foreach ($coordenadores) {
          each as $coordenador {
            function.run unidades_coordenadas {
              input = {usuario_id: $coordenador.id}
            } as $unidades_do_coordenador
          
            conditional {
              if (($unidades_do_coordenador|count) == 1) {
                var.update $precisam_destino {
                  value = $precisam_destino|push:$coordenador
                }
              }
            }
          }
        }
      
        precondition (($destinos_coordenadores|count) == ($precisam_destino|count) && (($destinos_coordenadores|map:($$.usuario_id|to_int))|unique|count) == ($destinos_coordenadores|count)) {
          error_type = "inputerror"
          error = "Informe exatamente um destino para cada coordenador que só coordena esta unidade."
        }
      
        foreach ($precisam_destino) {
          each as $coordenador {
            precondition ($destinos_coordenadores|some:($$.usuario_id|to_int) == $coordenador.id) {
              error_type = "inputerror"
              error = $coordenador.nome ~ " precisa de uma unidade de destino."
            }
          }
        }
      
        // Vagas: destinos repetidos no mesmo formulário ocupam vaga entre si
        var $destinos_usados {
          value = []
        }
      
        foreach ($destinos_coordenadores) {
          each as $entrada {
            var $destino_id {
              value = $entrada.unidade_id|to_int
            }
          
            function.run validar_destino_coordenador {
              input = {
                unidade_id      : $destino_id
                usuario_id      : $entrada.usuario_id|to_int
                vagas_reservadas: ($destinos_usados|filter:$$ == $destino_id)|count
              }
            } as $destino_validado
          
            var.update $destinos_usados {
              value = $destinos_usados|push:$destino_id
            }
          }
        }
      
        // 2. Professores da unidade precisam de destino ativo
        db.query usuario {
          where = $db.usuario.papel == "PROFESSOR" && $db.usuario.status_conta == "ATIVA" && $db.usuario.unidade_vinculo_id == $unidade.id
          return = {type: "list"}
        } as $professores
      
        precondition (($destinos_professores|count) == ($professores|count) && (($destinos_professores|map:($$.usuario_id|to_int))|unique|count) == ($destinos_professores|count)) {
          error_type = "inputerror"
          error = "Informe exatamente um destino para cada professor da unidade."
        }
      
        foreach ($professores) {
          each as $professor {
            var $entrada_professor {
              value = $destinos_professores|find:($$.usuario_id|to_int) == $professor.id
            }
          
            precondition ($entrada_professor != null) {
              error_type = "inputerror"
              error = $professor.nome ~ " precisa de uma unidade de destino."
            }
          
            db.get unidade {
              field_name = "id"
              field_value = $entrada_professor.unidade_id|to_int
            } as $destino_professor
          
            precondition ($destino_professor != null && $destino_professor.ativa && $destino_professor.id != $unidade.id) {
              error_type = "inputerror"
              error = "O destino de " ~ $professor.nome ~ " precisa ser outra unidade ativa."
            }
          }
        }
      
        // 3. Gravações: coordenações, professores, pedidos pendentes e a unidade
        db.query coordenacao_unidade {
          where = $db.coordenacao_unidade.unidade_id == $unidade.id
          return = {type: "list"}
        } as $coordenacoes_da_unidade
      
        foreach ($coordenacoes_da_unidade) {
          each as $coordenacao {
            function.run remover_coordenacao {
              input = {ator_id: $ator.id, coordenacao_id: $coordenacao.id}
            } as $removida
          }
        }
      
        foreach ($destinos_coordenadores) {
          each as $entrada {
            function.run atribuir_coordenacao {
              input = {
                ator_id   : $ator.id
                usuario_id: $entrada.usuario_id|to_int
                unidade_id: $entrada.unidade_id|to_int
              }
            } as $atribuida
          }
        }
      
        foreach ($professores) {
          each as $professor {
            var $entrada_destino {
              value = $destinos_professores|find:($$.usuario_id|to_int) == $professor.id
            }
          
            var $novo_destino_id {
              value = $entrada_destino.unidade_id|to_int
            }
          
            db.edit usuario {
              field_name = "id"
              field_value = $professor.id
              data = {unidade_vinculo_id: $novo_destino_id}
            } as $professor_transferido
          
            function.run registrar_auditoria {
              input = {
                ator_id     : $ator.id
                acao        : "TRANSFERIR_PROFESSOR"
                entidade    : "usuario"
                entidade_id : $professor.id
                unidade_id  : $novo_destino_id
                dados_antes : {unidade_vinculo_id: $professor.unidade_vinculo_id}
                dados_depois: {unidade_vinculo_id: $novo_destino_id}
              }
            } as $auditoria_transferencia
          }
        }
      
        db.query usuario {
          where = $db.usuario.status_conta == "PENDENTE" && $db.usuario.unidade_vinculo_id == $unidade.id
          return = {type: "list"}
        } as $pendentes
      
        foreach ($pendentes) {
          each as $pendente {
            db.edit usuario {
              field_name = "id"
              field_value = $pendente.id
              data = {
                status_conta          : "RECUSADA"
                motivo_recusa_cadastro: "Unidade desativada"
                recusa_sem_custo      : true
                aprovado_por_id       : $ator.id
                aprovado_em           : now
              }
            } as $recusado
          
            function.run registrar_auditoria {
              input = {
                ator_id     : $ator.id
                acao        : "RECUSAR_CADASTRO"
                entidade    : "usuario"
                entidade_id : $pendente.id
                unidade_id  : $unidade.id
                dados_antes : {
                status_conta          : $pendente.status_conta
                motivo_recusa_cadastro: $pendente.motivo_recusa_cadastro
              }
                dados_depois: {
                status_conta          : $recusado.status_conta
                motivo_recusa_cadastro: $recusado.motivo_recusa_cadastro
                recusa_sem_custo      : $recusado.recusa_sem_custo
                automatica            : true
              }
              }
            } as $auditoria_recusa
          }
        }
      
        db.edit unidade {
          field_name = "id"
          field_value = $unidade.id
          data = {ativa: false}
        } as $desativada
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "DESATIVAR_UNIDADE"
            entidade    : "unidade"
            entidade_id : $unidade.id
            unidade_id  : $unidade.id
            dados_antes : {ativa: $unidade.ativa}
            dados_depois: {ativa: $desativada.ativa}
          }
        } as $auditoria_desativacao
      }
    }
  }

  response = {mensagem: "Unidade desativada."}
  guid = "x1hUuD6hN0QoeahEYdsknHoPMdU"
}