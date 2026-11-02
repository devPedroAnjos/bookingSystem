// Tipos de espaço para gestores (spec tipos-espaco): todos, ativos e desativados, por nome, com a
// indicação de regras completas (C5). Para o admin, cada tipo traz também quantos espaços ativos
// tem e em quantas unidades (aviso da desativação) e as regras atuais (diálogo "Regras").
// ALUNO e PROFESSOR recebem 403.
// Lista os tipos de espaço
query tipos verb=GET {
  api_group = "espacos"
  auth = "usuario"

  input {
  }

  stack {
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
  
    var $e_admin {
      value = $ator.papel == "ADMIN"
    }
  
    db.query tipo_espaco {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $tipos
  
    db.query regra_papel {
      return = {type: "list"}
    } as $todas_regras
  
    var $espacos_ativos {
      value = []
    }
  
    conditional {
      if ($e_admin) {
        db.query espaco {
          where = $db.espaco.ativo == true
          return = {type: "list"}
        } as $ativos
      
        var.update $espacos_ativos {
          value = $ativos
        }
      }
    }
  
    var $resultado {
      value = []
    }
  
    foreach ($tipos) {
      each as $tipo {
        var $regras_do_tipo {
          value = $todas_regras|filter:$$.tipo_espaco_id == $tipo.id
        }
      
        function.run tipo_com_regras {
          input = {tipo: $tipo, regras_do_tipo: $regras_do_tipo}
        } as $com_regras
      
        var $item {
          value = {
            id        : $tipo.id
            nome      : $tipo.nome
            descricao : $tipo.descricao
            ativo     : $tipo.ativo == true
            com_regras: $com_regras
          }
        }
      
        conditional {
          if ($e_admin) {
            var $do_tipo {
              value = $espacos_ativos|filter:$$.tipo_espaco_id == $tipo.id
            }
          
            // Tipo sem regras não tem linhas de papel: {} e get evitam ler campo de nulo
            var $aluno {
              value = ($regras_do_tipo|find:$$.papel == "ALUNO")|first_notnull:{}
            }
          
            var $professor {
              value = ($regras_do_tipo|find:$$.papel == "PROFESSOR")|first_notnull:{}
            }
          
            // Cadeia de set em vez de literal: dentro de bloco de expressão, get devolvia a linha inteira
            var $regras_atuais {
              value = {}
                |set:"duracao_min_minutos":$tipo.duracao_min_minutos
                |set:"duracao_max_minutos":$tipo.duracao_max_minutos
                |set:"antecedencia_min_minutos":$tipo.antecedencia_min_minutos
                |set:"antecedencia_max_dias":$tipo.antecedencia_max_dias
                |set:"max_reservas_ativas_usuario":$tipo.max_reservas_ativas_usuario
                |set:"hora_abertura_minutos":$tipo.hora_abertura_minutos
                |set:"hora_fechamento_minutos":$tipo.hora_fechamento_minutos
                |set:"permite_recorrencia":$tipo.permite_recorrencia
                |set:"aluno_pode_reservar":($aluno|get:"pode_reservar")
                |set:"aluno_exige_aprovacao":($aluno|get:"exige_aprovacao")
                |set:"professor_pode_reservar":($professor|get:"pode_reservar")
                |set:"professor_exige_aprovacao":($professor|get:"exige_aprovacao")
            }

            var.update $item {
              value = $item
                |set:"espacos_ativos":($do_tipo|count)
                |set:"unidades":(($do_tipo|map:$$.unidade_id)|unique|count)
                |set:"regras":$regras_atuais
            }
          }
        }
      
        var.update $resultado {
          value = $resultado|push:$item
        }
      }
    }
  }

  response = $resultado
  guid = "ouJO39qex3QdVjMlntzagp-lTUQ"
}