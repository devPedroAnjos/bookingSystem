// Carga inicial idempotente: configuração geral, unidades iniciais e administrador inicial.
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
        configuracao_criada: false
        unidades_criadas   : []
        admin_criado       : false
      }
    }
  
    db.transaction {
      stack {
        db.query configuracao_geral {
          return = {type: "exists"}
        } as $configuracao_existe
      
        conditional {
          if (!$configuracao_existe) {
            db.add configuracao_geral {
              data = {
                dominios_email: ["aluno.impacta.edu.br", "impacta.edu.br"]
              }
            } as $configuracao
          
            var.update $resultado.configuracao_criada {
              value = true
            }
          }
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