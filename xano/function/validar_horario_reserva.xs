// Pedido de horário dentro das regras do tipo (spec regras-tipo; design D4b). Não consulta o banco
// e não verifica ocupação: a busca (C5) e a reserva (C6) chamam esta mesma função, e a C6
// acrescenta o conflito. Instantes em ms; avaliação no fuso America/Sao_Paulo; agora vem do
// backend (var $agora { value = now }) ou é fixado nos testes. Acumula todos os motivos.
// As checagens de regra do tipo só rodam com regras completas (sem elas, TIPO_SEM_REGRAS).
// Devolve dentro_das_regras e a lista de motivos
function validar_horario_reserva {
  input {
    json tipo
    bool? regras_completas
    json configuracao
    int inicio
    int fim
    int agora
  }

  stack {
    var $motivos {
      value = []
    }
  
    // Data, dia da semana ISO (1 = segunda) e minutos desde a meia-noite em São Paulo.
    // format_timestamp devolve texto, por isso to_int antes de comparar (design D4b, passo 4).
    var $data_inicio {
      value = $input.inicio
        |format_timestamp:"Y-m-d":"America/Sao_Paulo"
    }
  
    var $data_fim {
      value = $input.fim
        |format_timestamp:"Y-m-d":"America/Sao_Paulo"
    }
  
    var $dia_semana {
      value = ($input.inicio|format_timestamp:"N":"America/Sao_Paulo")|to_int
    }
  
    var $minuto_inicio {
      value = (($input.inicio|format_timestamp:"H":"America/Sao_Paulo")|to_int) * 60 + (($input.inicio|format_timestamp:"i":"America/Sao_Paulo")|to_int)
    }
  
    var $minuto_fim {
      value = (($input.fim|format_timestamp:"H":"America/Sao_Paulo")|to_int) * 60 + (($input.fim|format_timestamp:"i":"America/Sao_Paulo")|to_int)
    }
  
    var $granularidade {
      value = $input.configuracao.granularidade_minutos
    }
  
    var $dias_funcionamento {
      value = ($input.configuracao.dias_funcionamento|first_notnull:[])|map:($$|to_int)
    }
  
    conditional {
      if ($input.regras_completas != true) {
        var.update $motivos {
          value = $motivos|push:"TIPO_SEM_REGRAS"
        }
      }
    }
  
    conditional {
      if ($input.fim <= $input.inicio) {
        var.update $motivos {
          value = $motivos|push:"FIM_NAO_DEPOIS_DO_INICIO"
        }
      }
    }
  
    conditional {
      if ($data_inicio != $data_fim) {
        var.update $motivos {
          value = $motivos|push:"DIAS_DIFERENTES"
        }
      }
    }
  
    conditional {
      if (!($dias_funcionamento|in:$dia_semana)) {
        var.update $motivos {
          value = $motivos|push:"DIA_SEM_FUNCIONAMENTO"
        }
      }
    }
  
    // Minutos fora da granularidade, ou segundos e milissegundos diferentes de zero
    conditional {
      if ($minuto_inicio % $granularidade != 0 || $minuto_fim % $granularidade != 0 || $input.inicio % 60000 != 0 || $input.fim % 60000 != 0) {
        var.update $motivos {
          value = $motivos|push:"FORA_DA_GRANULARIDADE"
        }
      }
    }
  
    conditional {
      if ($input.regras_completas) {
        conditional {
          if ($minuto_inicio < $input.tipo.hora_abertura_minutos) {
            var.update $motivos {
              value = $motivos|push:"ANTES_DA_ABERTURA"
            }
          }
        }
      
        conditional {
          if ($data_inicio == $data_fim && $minuto_fim > $input.tipo.hora_fechamento_minutos) {
            var.update $motivos {
              value = $motivos|push:"DEPOIS_DO_FECHAMENTO"
            }
          }
        }
      
        conditional {
          if ($input.fim > $input.inicio) {
            var $duracao {
              value = ($input.fim - $input.inicio) / 60000
            }
          
            conditional {
              if ($duracao < $input.tipo.duracao_min_minutos) {
                var.update $motivos {
                  value = $motivos|push:"DURACAO_ABAIXO_DA_MINIMA"
                }
              }
            }
          
            conditional {
              if ($duracao > $input.tipo.duracao_max_minutos) {
                var.update $motivos {
                  value = $motivos|push:"DURACAO_ACIMA_DA_MAXIMA"
                }
              }
            }
          }
        }
      
        // Antecedência mínima também cobre horário no passado (mínima >= 0)
        conditional {
          if ($input.inicio < $input.agora + ($input.tipo.antecedencia_min_minutos * 60000)) {
            var.update $motivos {
              value = $motivos|push:"ANTECEDENCIA_MINIMA"
            }
          }
        }
      
        conditional {
          if ($input.inicio > $input.agora + ($input.tipo.antecedencia_max_dias * 86400000)) {
            var.update $motivos {
              value = $motivos|push:"ANTECEDENCIA_MAXIMA"
            }
          }
        }
      }
    }
  }

  response = {
    dentro_das_regras: ($motivos|count) == 0
    motivos          : $motivos
  }

  guid = "ot-WyBdvVw53ggv2udngwHCdag0"
}