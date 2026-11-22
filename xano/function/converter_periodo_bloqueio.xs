// Conversão do período de um bloqueio (C11, design D2): data AAAA-MM-DD e hora HH:MM do início e do
// fim, no fuso America/Sao_Paulo, podendo cobrir vários dias. Mesmas regex, mesma volta da data e
// mesmas mensagens de converter_horario_pedido, que só aceita uma data (fim no mesmo dia).
// Devolve os instantes de início e de fim, em ms
function converter_periodo_bloqueio {
  input {
    text? data_inicio? filters=trim
    text? hora_inicio? filters=trim
    text? data_fim? filters=trim
    text? hora_fim? filters=trim
  }

  stack {
    var $data_inicio {
      value = $input.data_inicio|first_notnull:""
    }

    var $hora_inicio {
      value = $input.hora_inicio|first_notnull:""
    }

    var $data_fim {
      value = $input.data_fim|first_notnull:""
    }

    var $hora_fim {
      value = $input.hora_fim|first_notnull:""
    }

    precondition (($data_inicio|strlen) > 0 && ($hora_inicio|strlen) > 0 && ($data_fim|strlen) > 0 && ($hora_fim|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe a data e a hora de início e a data e a hora de fim do bloqueio."
    }

    var $formato_data {
      value = "/^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/"
    }

    var $formato_hora {
      value = "/^([01][0-9]|2[0-3]):[0-5][0-9]$/"
    }

    precondition (($formato_data|regex_matches:$data_inicio) && ($formato_data|regex_matches:$data_fim) && ($formato_hora|regex_matches:$hora_inicio) && ($formato_hora|regex_matches:$hora_fim)) {
      error_type = "inputerror"
      error = "Informe a data no formato AAAA-MM-DD e as horas no formato HH:MM, com valores existentes."
    }

    var $inicio {
      value = ($data_inicio ~ " " ~ $hora_inicio)|to_timestamp:"America/Sao_Paulo"
    }

    var $fim {
      value = ($data_fim ~ " " ~ $hora_fim)|to_timestamp:"America/Sao_Paulo"
    }

    // Data inexistente (2026-02-30) volta diferente do texto informado
    precondition (($inicio|format_timestamp:"Y-m-d":"America/Sao_Paulo") == $data_inicio && ($fim|format_timestamp:"Y-m-d":"America/Sao_Paulo") == $data_fim) {
      error_type = "inputerror"
      error = "Informe a data no formato AAAA-MM-DD e as horas no formato HH:MM, com valores existentes."
    }

    precondition ($fim > $inicio) {
      error_type = "inputerror"
      error = "O fim do bloqueio deve ser depois do início."
    }
  }

  response = {inicio: $inicio, fim: $fim}
  guid = "3T77Ni39UTi7q5pojZXJmr6mgV0"
}
