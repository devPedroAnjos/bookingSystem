// Tipo com regras completas (spec regras-tipo; design D3): as oito regras de uso preenchidas e
// uma regra por papel para ALUNO e para PROFESSOR. Não consulta o banco. Usa is_null, porque
// 0 (antecedência mínima) e false (recorrência) são regras válidas e o != do Xano é frouxo.
// Devolve true quando o tipo tem regras completas
function tipo_com_regras {
  input {
    json tipo
    json? regras_do_tipo?
  }

  stack {
    var $regras {
      value = $input.regras_do_tipo|first_notnull:[]
    }
  
    // is_null é estrito: no Xano, 0 != null e false != null dão falso (comparação frouxa)
    var $campos_completos {
      value = ["duracao_min_minutos", "duracao_max_minutos", "antecedencia_min_minutos", "antecedencia_max_dias", "max_reservas_ativas_usuario", "hora_abertura_minutos", "hora_fechamento_minutos", "permite_recorrencia"]|every:(!(($input.tipo|get:$$)|is_null))
    }
  
    var $papeis_completos {
      value = !(($regras|find:$$.papel == "ALUNO")|is_null) && !(($regras|find:$$.papel == "PROFESSOR")|is_null)
    }
  }

  response = $campos_completos && $papeis_completos
  guid = "7DXiZd0sWFbwVyQ7NjkPyqDjQQU"
}