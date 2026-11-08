// Motivo escolhido numa lista fixa (C6, design D17). Lista "desativacao" (espaço, tipo e unidade)
// ou "conta" (inativação). OUTRO exige descrição de até 500 caracteres; nos demais códigos a
// descrição é ignorada. Só depende da entrada: é chamada fora da trava. O Reflex traduz os
// códigos em rótulos, e as duas listas mudam juntas.
// Devolve o código e a descrição (nula quando o código não é OUTRO)
function validar_motivo {
  input {
    text lista
    text? codigo? filters=trim
    text? descricao? filters=trim
  }

  stack {
    precondition ($input.lista == "desativacao" || $input.lista == "conta") {
      error = "Lista de motivos inválida."
    }
  
    // Listas em variáveis separadas, sem objeto literal: o Xano tira as vírgulas dos literais
    // ao salvar, e um literal sem vírgulas pode perder chaves em execução (memória do projeto)
    var $codigos {
      value = [
        "MANUTENCAO_REFORMA"
        "INFRAESTRUTURA"
        "SEGURANCA_INTERDICAO"
        "EQUIPAMENTOS_INDISPONIVEIS"
        "MUDANCA_DE_USO"
        "BAIXA_UTILIZACAO"
        "ENCERRAMENTO_ATIVIDADES"
        "OUTRO"
      ]
    }
  
    conditional {
      if ($input.lista == "conta") {
        var.update $codigos {
          value = [
            "DESLIGAMENTO_INSTITUICAO"
            "CONCLUSAO_CURSO"
            "TRANCAMENTO_AFASTAMENTO"
            "USO_INDEVIDO"
            "CONTA_DUPLICADA"
            "PEDIDO_TITULAR"
            "OUTRO"
          ]
        }
      }
    }
  
    var $codigo {
      value = $input.codigo|first_notnull:""
    }
  
    var $descricao {
      value = $input.descricao|first_notnull:""
    }
  
    precondition (($codigo|strlen) > 0) {
      error_type = "inputerror"
      error = "Escolha o motivo."
    }
  
    precondition ($codigos|in:$codigo) {
      error_type = "inputerror"
      error = "Motivo inválido."
    }
  
    var $descricao_gravada {
      value = null
    }
  
    conditional {
      if ($codigo == "OUTRO") {
        precondition (($descricao|strlen) > 0) {
          error_type = "inputerror"
          error = "Descreva o motivo."
        }
      
        precondition (($descricao|strlen) <= 500) {
          error_type = "inputerror"
          error = "A descrição do motivo deve ter no máximo 500 caracteres."
        }
      
        var.update $descricao_gravada {
          value = $descricao
        }
      }
    }
  
    var $motivo {
      value = {}
        |set:"codigo":$codigo
        |set:"descricao":$descricao_gravada
    }
  }

  response = $motivo
  guid = "F41Jso8o6jZ3cRlb8OcIAETmwWs"
}