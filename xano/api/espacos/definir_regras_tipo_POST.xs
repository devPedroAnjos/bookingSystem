// Regras de uso de um tipo de espaço e regra por papel de aluno e professor, gravadas juntas
// por qualquer admin (spec regras-tipo; design D6). Formato e consistência antes da trava;
// granularidade dentro dela (a mesma de parametros). Sem nenhuma mudança: 400, sem auditoria.
// Define as regras de um tipo de espaço, dentro da trava de governança
query definir_regras_tipo verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int tipo_espaco_id
    int? duracao_min_minutos?
    int? duracao_max_minutos?
    int? antecedencia_min_minutos?
    int? antecedencia_max_dias?
    int? max_reservas_ativas_usuario?
    int? hora_abertura_minutos?
    int? hora_fechamento_minutos?
    bool? permite_recorrencia?
    bool? aluno_pode_reservar?
    bool? aluno_exige_aprovacao?
    bool? professor_pode_reservar?
    bool? professor_exige_aprovacao?
  }

  stack {
    var $regras {
      value = {
        duracao_min_minutos        : $input.duracao_min_minutos
        duracao_max_minutos        : $input.duracao_max_minutos
        antecedencia_min_minutos   : $input.antecedencia_min_minutos
        antecedencia_max_dias      : $input.antecedencia_max_dias
        max_reservas_ativas_usuario: $input.max_reservas_ativas_usuario
        hora_abertura_minutos      : $input.hora_abertura_minutos
        hora_fechamento_minutos    : $input.hora_fechamento_minutos
        permite_recorrencia        : $input.permite_recorrencia
      }
    }
  
    var $papeis {
      value = {
        aluno_pode_reservar      : $input.aluno_pode_reservar
        aluno_exige_aprovacao    : $input.aluno_exige_aprovacao
        professor_pode_reservar  : $input.professor_pode_reservar
        professor_exige_aprovacao: $input.professor_exige_aprovacao
      }
    }
  
    foreach ($regras|keys) {
      each as $campo {
        // is_null é estrito: 0 e false são valores válidos (o != do Xano é frouxo)
        precondition (!(($regras|get:$campo)|is_null)) {
          error_type = "inputerror"
          error = "Todas as regras são obrigatórias: informe " ~ $campo ~ "."
        }
      }
    }
  
    foreach ($papeis|keys) {
      each as $campo {
        precondition (!(($papeis|get:$campo)|is_null)) {
          error_type = "inputerror"
          error = "Todas as regras são obrigatórias: informe " ~ $campo ~ "."
        }
      }
    }
  
    precondition ($input.duracao_min_minutos >= 1 && $input.duracao_max_minutos >= $input.duracao_min_minutos) {
      error_type = "inputerror"
      error = "A duração máxima deve ser maior ou igual à mínima, e a mínima de pelo menos 1 minuto."
    }
  
    precondition ($input.hora_abertura_minutos >= 0 && $input.hora_fechamento_minutos < 1440) {
      error_type = "inputerror"
      error = "O horário deve ficar no mesmo dia: abertura a partir de 00:00 e fechamento antes da meia-noite."
    }
  
    precondition ($input.hora_abertura_minutos < $input.hora_fechamento_minutos) {
      error_type = "inputerror"
      error = "A abertura deve ser antes do fechamento."
    }
  
    precondition ($input.duracao_max_minutos <= $input.hora_fechamento_minutos -$input.hora_abertura_minutos) {
      error_type = "inputerror"
      error = "A duração máxima não cabe no horário do tipo."
    }
  
    precondition ($input.antecedencia_min_minutos >= 0 && $input.antecedencia_max_dias >= 1) {
      error_type = "inputerror"
      error = "A antecedência mínima deve ser de 0 minutos ou mais, e a máxima de pelo menos 1 dia."
    }
  
    precondition (($input.antecedencia_max_dias * 1440) > $input.antecedencia_min_minutos) {
      error_type = "inputerror"
      error = "A antecedência máxima deve ser maior que a mínima."
    }
  
    precondition ($input.max_reservas_ativas_usuario >= 1) {
      error_type = "inputerror"
      error = "O máximo de reservas ativas por usuário deve ser de pelo menos 1."
    }
  
    precondition (($input.aluno_pode_reservar || !$input.aluno_exige_aprovacao) && ($input.professor_pode_reservar || !$input.professor_exige_aprovacao)) {
      error_type = "inputerror"
      error = "Só exige aprovação quem pode reservar."
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
      
        db.get tipo_espaco {
          field_name = "id"
          field_value = $input.tipo_espaco_id
        } as $tipo
      
        precondition ($tipo != null) {
          error_type = "notfound"
          error = "Tipo de espaço não encontrado."
        }
      
        function.run obter_configuracao_horario as $configuracao
        var $granularidade {
          value = $configuracao.granularidade_minutos
        }
      
        precondition ($input.duracao_min_minutos >= $granularidade && $input.duracao_min_minutos % $granularidade == 0 && $input.duracao_max_minutos % $granularidade == 0 && $input.hora_abertura_minutos % $granularidade == 0 && $input.hora_fechamento_minutos % $granularidade == 0) {
          error_type = "inputerror"
          error = "Durações e horários devem ser múltiplos de " ~ $granularidade ~ " minutos."
        }
      
        db.query regra_papel {
          where = $db.regra_papel.tipo_espaco_id == $tipo.id
          return = {type: "list"}
        } as $linhas_atuais
      
        // Na primeira definição não há linhas de papel: {} e get evitam ler campo de nulo
        var $aluno_atual {
          value = ($linhas_atuais|find:$$.papel == "ALUNO")|first_notnull:{}
        }
      
        var $professor_atual {
          value = ($linhas_atuais|find:$$.papel == "PROFESSOR")|first_notnull:{}
        }
      
        // Cadeia de set em vez de literal: dentro de bloco de expressão, get devolvia a linha inteira
        var $papeis_atuais {
          value = {}
            |set:"aluno_pode_reservar":($aluno_atual|get:"pode_reservar")
            |set:"aluno_exige_aprovacao":($aluno_atual|get:"exige_aprovacao")
            |set:"professor_pode_reservar":($professor_atual|get:"pode_reservar")
            |set:"professor_exige_aprovacao":($professor_atual|get:"exige_aprovacao")
        }
      
        // Só os campos alterados vão para a auditoria; sem nenhuma mudança, a operação é recusada
        var $antes {
          value = {}
        }
      
        var $depois {
          value = {}
        }
      
        foreach ($regras|keys) {
          each as $campo {
            conditional {
              // Comparação estrita pelo JSON: 0, false e null são textos diferentes
              if ((($tipo|get:$campo)|json_encode) != (($regras|get:$campo)|json_encode)) {
                var.update $antes {
                  value = $antes|set:$campo:($tipo|get:$campo)
                }
              
                var.update $depois {
                  value = $depois|set:$campo:($regras|get:$campo)
                }
              }
            }
          }
        }
      
        foreach ($papeis|keys) {
          each as $campo {
            conditional {
              if ((($papeis_atuais|get:$campo)|json_encode) != (($papeis|get:$campo)|json_encode)) {
                var.update $antes {
                  value = $antes
                    |set:$campo:($papeis_atuais|get:$campo)
                }
              
                var.update $depois {
                  value = $depois|set:$campo:($papeis|get:$campo)
                }
              }
            }
          }
        }
      
        precondition (($depois|keys|count) > 0) {
          error_type = "inputerror"
          error = "Nenhuma regra foi alterada."
        }
      
        db.patch tipo_espaco {
          field_name = "id"
          field_value = $tipo.id
          data = $regras
        } as $tipo_atualizado
      
        // Uma linha por papel: edita a existente ou cria a nova; false gravado explicitamente
        foreach (["ALUNO", "PROFESSOR"]) {
          each as $papel {
            var $prefixo {
              value = $papel|to_lower
            }
          
            // Chaves montadas antes do get: o Xano reescreve get:($a ~ $b) sem os parênteses
            var $chave_pode {
              value = $prefixo ~ "_pode_reservar"
            }

            var $chave_aprovacao {
              value = $prefixo ~ "_exige_aprovacao"
            }

            var $nova_regra {
              value = {
                pode_reservar  : $papeis|get:$chave_pode
                exige_aprovacao: $papeis|get:$chave_aprovacao
              }
            }
          
            var $linha {
              value = $linhas_atuais|find:$$.papel == $papel
            }
          
            conditional {
              if ($linha != null) {
                db.patch regra_papel {
                  field_name = "id"
                  field_value = $linha.id
                  data = $nova_regra
                } as $linha_editada
              }
            
              else {
                db.add regra_papel {
                  data = {
                    tipo_espaco_id : $tipo.id
                    papel          : $papel
                    pode_reservar  : $nova_regra.pode_reservar
                    exige_aprovacao: $nova_regra.exige_aprovacao
                  }
                } as $linha_criada
              }
            }
          }
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "ALTERAR_REGRAS_TIPO_ESPACO"
            entidade    : "tipo_espaco"
            entidade_id : $tipo.id
            dados_antes : $antes
            dados_depois: $depois
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Regras do tipo de espaço atualizadas."}
  guid = "WYjLUV_-4WATM-jdxo_cbdbwars"
}