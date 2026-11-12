// Conversão de uma data AAAA-MM-DD para o início do dia em America/Sao_Paulo (C7, design D9),
// no padrão de converter_horario_pedido: o formato é conferido antes, porque to_timestamp aceita
// texto livre, e a volta da data recusa datas inexistentes (2026-02-30). O mês (01 a 12) e o dia
// (01 a 31) são conferidos na regex: to_timestamp recusa mês 13 com mensagem própria, em inglês.
// Devolve o instante das 00h00 do dia, em ms
function converter_data_pedido {
  input {
    text data filters=trim
  }

  stack {
    precondition ("/^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/"|regex_matches:$input.data) {
      error_type = "inputerror"
      error = "Informe as datas no formato AAAA-MM-DD, com valores existentes."
    }

    var $inicio_do_dia {
      value = ($input.data ~ " 00:00")|to_timestamp:"America/Sao_Paulo"
    }

    precondition (($inicio_do_dia|format_timestamp:"Y-m-d":"America/Sao_Paulo") == $input.data) {
      error_type = "inputerror"
      error = "Informe as datas no formato AAAA-MM-DD, com valores existentes."
    }
  }

  response = $inicio_do_dia
  guid = "K1YUKkDSScaKmy6QcmloF1Px7Ks"
}
