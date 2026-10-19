// Carga inicial idempotente: configuração geral (com os parâmetros de coordenação e cadastro),
// unidades iniciais, administrador inicial, linha de trava e pedidos_cadastro das contas antigas.
// Executada manualmente depois do push. As credenciais do administrador vêm de variáveis
// de ambiente do Xano e nunca são versionadas.
// Cria a configuração, as unidades iniciais e o primeiro ADMIN, sem duplicar nada
function bootstrap {
  input {
  }

  stack {
    db.query usuario {
      where = $db.usuario.papel == "ADMIN"
      return = {type: "exists"}
    } as $admin_existe
  
    var $admin_nome {
      value = $env.ADMIN_INICIAL_NOME|first_notnull:""|trim
    }
  
    var $admin_email {
      value = $env.ADMIN_INICIAL_EMAIL
        |first_notnull:""
        |trim
        |to_lower
    }
  
    var $admin_senha {
      value = $env.ADMIN_INICIAL_SENHA|first_notnull:""
    }
  
    // Sem administrador, as variáveis são exigidas antes de qualquer gravação
    conditional {
      if (!$admin_existe) {
        precondition (($admin_nome|strlen) > 0 && ($admin_email|strlen) > 0 && ($admin_senha|strlen) >= 8) {
          error = "Defina ADMIN_INICIAL_NOME, ADMIN_INICIAL_EMAIL e ADMIN_INICIAL_SENHA (mínimo de 8 caracteres) antes de executar o bootstrap."
        }
      }
    }
  
    var $resultado {
      value = {
        configuracao_criada : false
        parametros_ajustados: []
        unidades_criadas    : []
        admin_criado        : false
        trava_criada        : false
        contas_com_pedido_1 : 0
      }
    }
  
    // Valores padrão dos parâmetros (domain-model.md, §2.18)
    var $parametros_padrao {
      value = {
        max_coordenadores_unidade: 4
        max_unidades_coordenador : 2
        max_pedidos_cadastro     : 3
      }
    }
  
    db.transaction {
      stack {
        db.query configuracao_geral {
          return = {type: "single"}
        } as $configuracao
      
        conditional {
          if ($configuracao == null) {
            db.add configuracao_geral {
              data = {
                dominios_email           : ["aluno.impacta.edu.br", "impacta.edu.br"]
                max_coordenadores_unidade: $parametros_padrao.max_coordenadores_unidade
                max_unidades_coordenador : $parametros_padrao.max_unidades_coordenador
                max_pedidos_cadastro     : $parametros_padrao.max_pedidos_cadastro
              }
            } as $configuracao_criada
          
            var.update $resultado.configuracao_criada {
              value = true
            }
          }
        
          else {
            // Preenche só os parâmetros vazios, sem alterar valores já definidos
            var $ajustes {
              value = {}
            }
          
            foreach ($parametros_padrao|keys) {
              each as $parametro {
                conditional {
                  if (($configuracao|get:$parametro) == null) {
                    var.update $ajustes {
                      value = $ajustes
                        |set:$parametro:($parametros_padrao|get:$parametro)
                    }
                  }
                }
              }
            }
          
            conditional {
              if (($ajustes|keys|count) > 0) {
                db.patch configuracao_geral {
                  field_name = "id"
                  field_value = $configuracao.id
                  data = $ajustes
                } as $configuracao_ajustada
              
                var.update $resultado.parametros_ajustados {
                  value = $ajustes|keys
                }
              }
            }
          }
        }
      
        // Linha usada pela trava de governança (design.md, D3)
        db.has trava {
          field_name = "nome"
          field_value = "governanca"
        } as $trava_existe
      
        conditional {
          if (!$trava_existe) {
            db.add trava {
              data = {nome: "governanca", usado_em: now}
            } as $trava_criada
          
            var.update $resultado.trava_criada {
              value = true
            }
          }
        }
      
        // Contas criadas antes do campo pedidos_cadastro contam como 1 pedido
        db.query usuario {
          where = $db.usuario.pedidos_cadastro == null
          return = {type: "list"}
        } as $contas_sem_pedido
      
        foreach ($contas_sem_pedido) {
          each as $conta {
            db.edit usuario {
              field_name = "id"
              field_value = $conta.id
              data = {pedidos_cadastro: 1}
            } as $conta_ajustada
          }
        }
      
        var.update $resultado.contas_com_pedido_1 {
          value = $contas_sem_pedido|count
        }
      
        // Nomes e endereços provisórios até a equipe confirmar (design.md, Open Questions)
        var $unidades_iniciais {
          value = [
            {nome: "Paulista", endereco: "Endereço a confirmar"}
            {nome: "Vila Olímpia", endereco: "Endereço a confirmar"}
          ]
        }
      
        foreach ($unidades_iniciais) {
          each as $unidade {
            db.has unidade {
              field_name = "nome"
              field_value = $unidade.nome
            } as $unidade_existe
          
            conditional {
              if (!$unidade_existe) {
                db.add unidade {
                  data = {
                    nome    : $unidade.nome
                    endereco: $unidade.endereco
                    ativa   : true
                  }
                } as $unidade_criada
              
                var.update $resultado.unidades_criadas {
                  value = $resultado.unidades_criadas|push:$unidade.nome
                }
              }
            }
          }
        }
      
        conditional {
          if (!$admin_existe) {
            db.add usuario {
              data = {
                nome        : $admin_nome
                email       : $admin_email
                senha_hash  : $admin_senha
                papel       : "ADMIN"
                status_conta: "ATIVA"
                criado_em   : now
              }
            } as $admin
          
            function.run registrar_auditoria {
              input = {
                ator_id     : null
                acao        : "CRIAR_CONTA"
                entidade    : "usuario"
                entidade_id : $admin.id
                dados_depois: {
                nome        : $admin.nome
                email       : $admin.email
                papel       : $admin.papel
                status_conta: $admin.status_conta
              }
              }
            } as $registro_auditoria
          
            var.update $resultado.admin_criado {
              value = true
            }
          }
        }
      }
    }
  }

  response = $resultado
  guid = "9S1nbXN2luMiAH_9x1FZwv-xFEk"
}