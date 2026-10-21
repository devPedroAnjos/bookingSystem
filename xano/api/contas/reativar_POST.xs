// Reativação de conta INATIVA (spec situacao-conta; design.md da C3, D7). Confere o papel:
// - COORDENADOR: descarta coordenações em unidades desativadas ou sem vaga; se não sobrar
//   nenhuma, exige unidades_ids (1 até o máximo);
// - PROFESSOR: se a unidade dele não estiver ativa, exige unidade_id de uma unidade ativa;
// - ADMIN: exige vaga no limite de admins ativos.
// Permissões de D5. Reativa uma conta inativa, dentro da trava de governança
query reativar verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    int[]? unidades_ids?
    int? unidade_id?
  }

  stack {
    var $coordenacoes_descartadas {
      value = []
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run autorizar_sobre_conta {
          input = {
            ator_id   : $auth.id
            alvo_id   : $input.usuario_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $permissao
      
        var $ator {
          value = $permissao.ator
        }
      
        var $alvo {
          value = $permissao.alvo
        }
      
        precondition ($alvo.status_conta == "INATIVA") {
          error_type = "inputerror"
          error = "Só contas inativas são reativadas."
        }
      
        function.run obter_configuracao as $configuracao
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
              eval = {
                unidade_nome : $db.unidade.nome
                unidade_ativa: $db.unidade.ativa
              }
            
              return = {type: "list"}
            } as $coordenacoes
          
            var $mantidas {
              value = 0
            }
          
            foreach ($coordenacoes) {
              each as $coordenacao {
                // Ele está inativo, então não entra na contagem de coordenadores ativos
                function.run coordenadores_ativos {
                  input = {unidade_id: $coordenacao.unidade_id}
                } as $ativos_na_unidade
              
                conditional {
                  if ($coordenacao.unidade_ativa && ($ativos_na_unidade|count) < $configuracao.max_coordenadores_unidade) {
                    var.update $mantidas {
                      value = $mantidas + 1
                    }
                  }
                
                  else {
                    function.run remover_coordenacao {
                      input = {ator_id: $ator.id, coordenacao_id: $coordenacao.id}
                    } as $removida
                  
                    var.update $coordenacoes_descartadas {
                      value = $coordenacoes_descartadas
                        |push:{unidade_id: $coordenacao.unidade_id, nome: $coordenacao.unidade_nome}
                    }
                  }
                }
              }
            }
          
            conditional {
              if ($mantidas == 0) {
                var $unidades_ids {
                  value = ($input.unidades_ids|first_notnull:[])|unique
                }
              
                precondition (($unidades_ids|count) > 0 && ($unidades_ids|count) <= $configuracao.max_unidades_coordenador) {
                  error_type = "inputerror"
                  error = "Escolha de 1 a " ~ ($configuracao.max_unidades_coordenador|to_text) ~ " unidades para o coordenador."
                }
              
                foreach ($unidades_ids) {
                  each as $unidade_id {
                    function.run validar_destino_coordenador {
                      input = {unidade_id: $unidade_id, usuario_id: $alvo.id}
                    } as $destino
                  
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
          }
        
          elseif ($alvo.papel == "PROFESSOR") {
            db.get unidade {
              field_name = "id"
              field_value = $alvo.unidade_vinculo_id
            } as $unidade_atual
          
            conditional {
              if ($unidade_atual == null || !$unidade_atual.ativa) {
                precondition ($input.unidade_id != null) {
                  error_type = "inputerror"
                  error = "A unidade do professor está desativada. Escolha a nova unidade."
                }
              
                db.get unidade {
                  field_name = "id"
                  field_value = $input.unidade_id
                } as $nova_unidade
              
                precondition ($nova_unidade != null && $nova_unidade.ativa) {
                  error_type = "inputerror"
                  error = "A nova unidade precisa existir e estar ativa."
                }
              
                db.edit usuario {
                  field_name = "id"
                  field_value = $alvo.id
                  data = {unidade_vinculo_id: $nova_unidade.id}
                } as $transferido
              
                function.run registrar_auditoria {
                  input = {
                    ator_id     : $ator.id
                    acao        : "TRANSFERIR_PROFESSOR"
                    entidade    : "usuario"
                    entidade_id : $alvo.id
                    unidade_id  : $nova_unidade.id
                    dados_antes : {unidade_vinculo_id: $alvo.unidade_vinculo_id}
                    dados_depois: {unidade_vinculo_id: $nova_unidade.id}
                  }
                } as $registro_transferencia
              }
            }
          }
        
          elseif ($alvo.papel == "ADMIN") {
            function.run vaga_de_admin as $vaga
          }
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $alvo.id
          data = {status_conta: "ATIVA"}
        } as $reativado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "REATIVAR_CONTA"
            entidade    : "usuario"
            entidade_id : $alvo.id
            dados_antes : {status_conta: $alvo.status_conta}
            dados_depois: {
            status_conta            : $reativado.status_conta
            coordenacoes_descartadas: $coordenacoes_descartadas
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem                : "Conta reativada."
    coordenacoes_descartadas: $coordenacoes_descartadas
  }

  guid = "rsagG_Cr5akl_vlqWpbZ55Vf3TM"
}