// Conversão do horário pedido (C6, design D3), compartilhada pela busca e pela criação de reserva.
// Data AAAA-MM-DD e horas HH:MM no fuso America/Sao_Paulo. O formato é conferido antes da
// conversão, porque to_timestamp aceita texto livre ("next friday"); a volta da data recusa
// datas inexistentes (2026-02-30). As mensagens são as da busca da C5.
// Devolve os instantes de início e de fim, em ms
function converter_horario_pedido {
  input {
    text? data? filters=trim
    text? hora_inicio? filters=trim
    text? hora_fim? filters=trim
  }

  stack {
    var $data {
      value = $input.data|first_notnull:""
    }

    var $hora_inicio {
      value = $input.hora_inicio|first_notnull:""
    }

    var $hora_fim {
      value = $input.hora_fim|first_notnull:""
    }

    precondition (($data|strlen) > 0 && ($hora_inicio|strlen) > 0 && ($hora_fim|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe a data, a hora de início e a hora de fim juntas."
    }

    // Mês (01 a 12) e dia (01 a 31) na regex: to_timestamp recusa mês 13 com mensagem própria, em
    // inglês (correção feita na C7, decisions-log 33)
    precondition (("/^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/"|regex_matches:$data) && ("/^([01][0-9]|2[0-3]):[0-5][0-9]$/"|regex_matches:$hora_inicio) && ("/^([01][0-9]|2[0-3]):[0-5][0-9]$/"|regex_matches:$hora_fim)) {
      error_type = "inputerror"
      error = "Informe a data no formato AAAA-MM-DD e as horas no formato HH:MM, com valores existentes."
    }

    var $inicio {
      value = ($data ~ " " ~ $hora_inicio)|to_timestamp:"America/Sao_Paulo"
    }

    var $fim {
      value = ($data ~ " " ~ $hora_fim)|to_timestamp:"America/Sao_Paulo"
    }

    // Data inexistente (2026-02-30) volta diferente do texto informado
    precondition (($inicio|format_timestamp:"Y-m-d":"America/Sao_Paulo") == $data) {
      error_type = "inputerror"
      error = "Informe a data no formato AAAA-MM-DD e as horas no formato HH:MM, com valores existentes."
    }

    precondition ($fim > $inicio) {
      error_type = "inputerror"
      error = "A hora de fim deve ser depois da hora de início."
    }
  }

  response = {inicio: $inicio, fim: $fim}
  guid = "FPCWoTGDxv5zjIuYc5lMEx1jFHQ"
}
