// Data e horas de uma reserva no fuso America/Sao_Paulo (C6, design D9), para o Reflex não
// converter fuso. Recebe os instantes em ms.
// Devolve data (AAAA-MM-DD), hora_inicio e hora_fim (HH:MM)
function formatar_reserva {
  input {
    int inicio
    int fim
  }

  stack {
    var $data {
      value = $input.inicio
        |format_timestamp:"Y-m-d":"America/Sao_Paulo"
    }
  
    var $hora_inicio {
      value = $input.inicio
        |format_timestamp:"H:i":"America/Sao_Paulo"
    }
  
    var $hora_fim {
      value = $input.fim
        |format_timestamp:"H:i":"America/Sao_Paulo"
    }
  
    var $formatado {
      value = {}
        |set:"data":$data
        |set:"hora_inicio":$hora_inicio
        |set:"hora_fim":$hora_fim
    }
  }

  response = $formatado
  guid = "L5SMV_CrAxQE0_EBKHuPJXFtHT4"
}