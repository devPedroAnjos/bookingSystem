// Mudança de papel pelo admin (spec papeis; design.md, D8). Direções permitidas:
// ALUNO -> PROFESSOR, PROFESSOR -> COORDENADOR, COORDENADOR -> PROFESSOR. Nunca para ALUNO,
// nunca ALUNO -> COORDENADOR, nunca envolvendo ADMIN.
// Virar PROFESSOR exige unidade_id; virar COORDENADOR exige unidades_ids (1 até o limite).
// Deixar de ser COORDENADOR remove todas as coordenações, mesmo esvaziando uma unidade.
// Muda o papel de uma conta ativa, dentro da trava de governança
query alterar_papel verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    text papel filters=trim|upper
    int[]? unidades_ids?
    int? unidade_id?
  }

  stack {
    precondition ($input.papel == "PROFESSOR" || $input.papel == "COORDENADOR") {
      error_type = "inputerror"
      error = "Papel de destino inválido."
    }
  
    var $unidades_ids {
      value = ($input.unidades_ids|first_notnull:[])|unique
    }
  
    conditional {
      if ($input.papel == "PROFESSOR") {
        precondition ($input.unidade_id != null) {
          error_type = "inputerror"
          error = "Escolha a unidade do professor."
        }
      }
    
      else {
        precondition (($unidades_ids|count) > 0) {
          error_type = "inputerror"
          error = "Escolha ao menos uma unidade para o coordenador."
        }
      }
    }
  
    var $coordenacoes_removidas {
      value = []
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {usuario_id: $auth.id}
        } as $ator
      
        db.get usuario {
          field_name = "id"
          field_value = $input.usuario_id
        } as $alvo
      
        precondition ($alvo != null) {
          error_type = "notfound"
          error = "Conta não encontrada."
        }
      
        precondition ($alvo.papel != "ADMIN") {
          error_type = "inputerror"
          error = "O papel de administradores não é alterado por esta operação."
        }
      
        precondition ($alvo.status_conta == "ATIVA") {
          error_type = "inputerror"
          error = "Só contas ativas têm o papel alterado. Se houver pedido de cadastro, decida-o antes."
        }
      
        precondition ($alvo.papel != $input.papel) {
          error_type = "inputerror"
          error = "A conta já tem esse papel."
        }
      
        var $direcao {
          value = $alvo.papel ~ ">" ~ $input.papel
        }
      
        precondition ($direcao == "ALUNO>PROFESSOR" || $direcao == "PROFESSOR>COORDENADOR" || $direcao == "COORDENADOR>PROFESSOR") {
          error_type = "inputerror"
          error = "Mudança de papel não permitida. A sequência é aluno, professor e coordenador, e ninguém volta a ser aluno."
        }
      
        var $nova_unidade_professor {
          value = null
        }
      
        conditional {
          if ($input.papel == "PROFESSOR") {
            db.get unidade {
              field_name = "id"
              field_value = $input.unidade_id
            } as $unidade_professor
          
            precondition ($unidade_professor != null && $unidade_professor.ativa) {
              error_type = "inputerror"
              error = "A unidade do professor precisa existir e estar ativa."
            }
          
            var.update $nova_unidade_professor {
              value = $unidade_professor.id
            }
          }
        
          else {
            function.run obter_configuracao as $configuracao
            precondition (($unidades_ids|count) <= $configuracao.max_unidades_coordenador) {
              error_type = "inputerror"
              error = "Um coordenador pode ter no máximo " ~ ($configuracao.max_unidades_coordenador|to_text) ~ " unidades."
            }
          
            foreach ($unidades_ids) {
              each as $unidade_id {
                function.run validar_destino_coordenador {
                  input = {unidade_id: $unidade_id, usuario_id: $alvo.id}
                } as $destino
              }
            }
          }
        }
      
        // Saída da coordenação: remove todas as coordenações do coordenador
        conditional {
          if ($alvo.papel == "COORDENADOR") {
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
          }
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $alvo.id
          data = {
            papel             : $input.papel
            unidade_vinculo_id: $nova_unidade_professor
          }
        } as $alterado
      
        conditional {
          if ($input.papel == "COORDENADOR") {
            foreach ($unidades_ids) {
              each as $unidade_id {
                function.run atribuir_coordenacao {
                  input = {
                    ator_id   : $ator.id
                    usuario_id: $alvo.id
                    unidade_id: $unidade_id
                  }
                } as $atribuida
              }
            }
          }
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "ALTERAR_PAPEL"
            entidade    : "usuario"
            entidade_id : $alvo.id
            dados_antes : {
            papel             : $alvo.papel
            unidade_vinculo_id: $alvo.unidade_vinculo_id
          }
            dados_depois: {
            papel             : $alterado.papel
            unidade_vinculo_id: $alterado.unidade_vinculo_id
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem              : "Papel alterado."
    coordenacoes_removidas: $coordenacoes_removidas
  }

  guid = "yW0OoArskqNVwzfFg9qi2lY-rLE"
}