// Carga inicial idempotente: configuração geral (com os parâmetros de coordenação, cadastro e
// administradores), unidades iniciais, tipos de espaço iniciais, administrador inicial (principal),
// marca de principal no admin já existente, linha de trava e pedidos_cadastro das contas antigas.
// Executada manualmente depois do push. As credenciais do administrador vêm de variáveis
// de ambiente do Xano e nunca são versionadas.
// Cria a configuração, as unidades, os tipos de espaço e as regras iniciais e o primeiro ADMIN, sem duplicar nada
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
        configuracao_criada : false,
        parametros_ajustados: [],
        unidades_criadas    : [],
        tipos_criados       : [],
        regras_carregadas   : [],
        admin_criado        : false,
        trava_criada        : false,
        contas_com_pedido_1 : 0,
        principal_marcado   : false
      }
    }
  
    // Valores padrão dos parâmetros (domain-model.md, §2.18)
    var $parametros_padrao {
      value = {
        max_coordenadores_unidade : 4,
        max_unidades_coordenador  : 2,
        max_pedidos_cadastro      : 3,
        max_admins                : 3,
        granularidade_minutos     : 10,
        dias_funcionamento        : [1, 2, 3, 4, 5],
        prazo_cancelamento_minutos: 120,
        prazo_deslocamento_minutos: 120,
        prazo_fila_minutos        : 120,
        prazo_confirmacao_fila_minutos: 720,
        tempo_minimo_fila_minutos : 30
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
                dominios_email            : ["aluno.impacta.edu.br", "impacta.edu.br"]
                max_coordenadores_unidade : $parametros_padrao.max_coordenadores_unidade
                max_unidades_coordenador  : $parametros_padrao.max_unidades_coordenador
                max_pedidos_cadastro      : $parametros_padrao.max_pedidos_cadastro
                max_admins                : $parametros_padrao.max_admins
                granularidade_minutos     : $parametros_padrao.granularidade_minutos
                dias_funcionamento        : $parametros_padrao.dias_funcionamento
                prazo_cancelamento_minutos: $parametros_padrao.prazo_cancelamento_minutos
                prazo_deslocamento_minutos: $parametros_padrao.prazo_deslocamento_minutos
                prazo_fila_minutos        : $parametros_padrao.prazo_fila_minutos
                prazo_confirmacao_fila_minutos: $parametros_padrao.prazo_confirmacao_fila_minutos
                tempo_minimo_fila_minutos : $parametros_padrao.tempo_minimo_fila_minutos
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
                var $valor_atual {
                  value = $configuracao|get:$parametro
                }
              
                // Lista vazia conta como vazio: a coluna int[] pode voltar [] em vez de null
                conditional {
                  if ($valor_atual == null || ($parametro == "dias_funcionamento" && ($valor_atual|count) == 0)) {
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
      
        // Tipos iniciais só com a tabela vazia, para não recriar um tipo renomeado (design D9)
        db.query tipo_espaco {
          return = {type: "count"}
        } as $total_tipos
      
        conditional {
          if ($total_tipos == 0) {
            var $tipos_iniciais {
              value = [
                {nome: "Sala de aula", descricao: "Aulas e atividades em turma"}
                {nome: "Laboratório", descricao: "Aulas práticas com equipamentos"}
                {nome: "Biblioteca", descricao: "Estudo individual ou em grupo"}
                {nome: "Auditório", descricao: "Palestras e eventos"}
              ]
            }
          
            foreach ($tipos_iniciais) {
              each as $tipo {
                db.add tipo_espaco {
                  data = {
                    nome     : $tipo.nome
                    descricao: $tipo.descricao
                    ativo    : true
                  }
                } as $tipo_criado
              
                var.update $resultado.tipos_criados {
                  value = $resultado.tipos_criados|push:$tipo.nome
                }
              }
            }
          }
        }
      
        // Regras iniciais (C5, design D9): carga única, só com regra_papel vazia. O nome é usado
        // só aqui; um tipo renomeado antes da carga fica sem regras (falha segura).
        // Valores aprovados no explore (spec regras-tipo); 0 e false gravados explicitamente.
        db.query regra_papel {
          return = {type: "count"}
        } as $total_regras_papel
      
        conditional {
          if ($total_regras_papel == 0) {
            var $regras_iniciais {
              value = [
                {
                  nome: "Sala de aula",
                  duracao_min: 50,
                  duracao_max: 300,
                  antecedencia_min: 0,
                  antecedencia_max_dias: 30,
                  max_ativas: 10,
                  recorrencia: true,
                  aluno_pode: false,
                  aluno_aprovacao: false,
                  professor_pode: true,
                  professor_aprovacao: false
                },
                {
                  nome: "Laboratório",
                  duracao_min: 30,
                  duracao_max: 240,
                  antecedencia_min: 0,
                  antecedencia_max_dias: 14,
                  max_ativas: 3,
                  recorrencia: false,
                  aluno_pode: true,
                  aluno_aprovacao: true,
                  professor_pode: true,
                  professor_aprovacao: false
                },
                {
                  nome: "Biblioteca",
                  duracao_min: 30,
                  duracao_max: 180,
                  antecedencia_min: 0,
                  antecedencia_max_dias: 7,
                  max_ativas: 2,
                  recorrencia: false,
                  aluno_pode: true,
                  aluno_aprovacao: false,
                  professor_pode: true,
                  professor_aprovacao: false
                },
                {
                  nome: "Auditório",
                  duracao_min: 50,
                  duracao_max: 480,
                  antecedencia_min: 1440,
                  antecedencia_max_dias: 60,
                  max_ativas: 2,
                  recorrencia: false,
                  aluno_pode: false,
                  aluno_aprovacao: false,
                  professor_pode: true,
                  professor_aprovacao: true
                }
              ]
            }
          
            foreach ($regras_iniciais) {
              each as $regra {
                db.query tipo_espaco {
                  where = $db.tipo_espaco.nome == $regra.nome
                  return = {type: "single"}
                } as $tipo_inicial
              
                conditional {
                  if ($tipo_inicial != null) {
                    // Horário 480 a 1360 minutos (08h00 a 22h40), padrão dos tipos iniciais
                    db.edit tipo_espaco {
                      field_name = "id"
                      field_value = $tipo_inicial.id
                      data = {
                        duracao_min_minutos        : $regra.duracao_min
                        duracao_max_minutos        : $regra.duracao_max
                        antecedencia_min_minutos   : $regra.antecedencia_min
                        antecedencia_max_dias      : $regra.antecedencia_max_dias
                        max_reservas_ativas_usuario: $regra.max_ativas
                        hora_abertura_minutos      : 480
                        hora_fechamento_minutos    : 1360
                        permite_recorrencia        : $regra.recorrencia
                      }
                    } as $tipo_regrado
                  
                    db.add regra_papel {
                      data = {
                        tipo_espaco_id : $tipo_inicial.id
                        papel          : "ALUNO"
                        pode_reservar  : $regra.aluno_pode
                        exige_aprovacao: $regra.aluno_aprovacao
                      }
                    } as $regra_aluno
                  
                    db.add regra_papel {
                      data = {
                        tipo_espaco_id : $tipo_inicial.id
                        papel          : "PROFESSOR"
                        pode_reservar  : $regra.professor_pode
                        exige_aprovacao: $regra.professor_aprovacao
                      }
                    } as $regra_professor
                  
                    var.update $resultado.regras_carregadas {
                      value = $resultado.regras_carregadas|push:$regra.nome
                    }
                  }
                }
              }
            }
          }
        }
      
        conditional {
          if (!$admin_existe) {
            db.add usuario {
              data = {
                nome           : $admin_nome
                email          : $admin_email
                senha_hash     : $admin_senha
                papel          : "ADMIN"
                status_conta   : "ATIVA"
                criado_em      : now
                admin_principal: true
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
        
          else {
            // Admin já existente (C1) sem marca de principal: marca o admin ativo mais antigo
            db.query usuario {
              where = $db.usuario.papel == "ADMIN" && $db.usuario.admin_principal == true
              return = {type: "exists"}
            } as $principal_existe
          
            conditional {
              if (!$principal_existe) {
                db.query usuario {
                  where = $db.usuario.papel == "ADMIN" && $db.usuario.status_conta == "ATIVA"
                  sort = {id: "asc"}
                  return = {type: "single"}
                } as $mais_antigo
              
                db.edit usuario {
                  field_name = "id"
                  field_value = $mais_antigo.id
                  data = {admin_principal: true}
                } as $principal
              
                function.run registrar_auditoria {
                  input = {
                    ator_id     : null
                    acao        : "MARCAR_ADMIN_PRINCIPAL"
                    entidade    : "usuario"
                    entidade_id : $principal.id
                    dados_antes : {admin_principal: false}
                    dados_depois: {admin_principal: true}
                  }
                } as $registro_principal
              
                var.update $resultado.principal_marcado {
                  value = true
                }
              }
            }
          }
        }
      }
    }
  }

  response = $resultado
  guid = "9S1nbXN2luMiAH_9x1FZwv-xFEk"
}