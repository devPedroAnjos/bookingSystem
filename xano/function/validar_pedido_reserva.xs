// Validações de um pedido de reserva (C9, design D7), extraídas de criar_reserva sem mudar ordem
// nem mensagens: releitura do espaço, da unidade, do tipo e das regras; espaço reservável; regra
// do papel; regras de horário. Usada por criar_reserva, entrar_fila e confirmar_fila, sempre
// dentro da trava de governança de quem chama e com o agora lido dentro dela. Recusas são 400.
// Valida o pedido e devolve o espaço, o tipo e a regra do papel
function validar_pedido_reserva {
  input {
    int espaco_id
    text papel
    int inicio
    int fim

    // Instante lido dentro da trava, em ms
    int agora
  }

  stack {
    // Rótulos dos motivos de validar_horario_reserva (os mesmos da tela de busca). Cadeia de |set
    // em vez de objeto literal: o Xano tira as vírgulas dos literais e eles podem perder chaves
    var $rotulos_horario {
      value = {}
        |set:"TIPO_SEM_REGRAS":"tipo sem regras"
        |set:"FIM_NAO_DEPOIS_DO_INICIO":"o fim deve ser depois do início"
        |set:"DIAS_DIFERENTES":"início e fim em dias diferentes"
        |set:"DIA_SEM_FUNCIONAMENTO":"dia sem funcionamento"
        |set:"FORA_DA_GRANULARIDADE":"horário fora da granularidade"
        |set:"ANTES_DA_ABERTURA":"início antes da abertura"
        |set:"DEPOIS_DO_FECHAMENTO":"fim depois do fechamento"
        |set:"DURACAO_ABAIXO_DA_MINIMA":"duração abaixo da mínima"
        |set:"DURACAO_ACIMA_DA_MAXIMA":"duração acima da máxima"
        |set:"ANTECEDENCIA_MINIMA":"antecedência menor que a mínima"
        |set:"ANTECEDENCIA_MAXIMA":"antecedência maior que a máxima"
    }

    // Releitura dentro da trava (corrida com desativação, C4 D13)
    db.get espaco {
      field_name = "id"
      field_value = $input.espaco_id
    } as $espaco

    // Espaço inexistente tem a mesma recusa de espaço não reservável
    precondition ($espaco != null) {
      error_type = "inputerror"
      error = "Este espaço não está disponível para reserva."
    }

    db.get unidade {
      field_name = "id"
      field_value = $espaco.unidade_id
    } as $unidade

    db.get tipo_espaco {
      field_name = "id"
      field_value = $espaco.tipo_espaco_id
    } as $tipo

    db.query regra_papel {
      where = $db.regra_papel.tipo_espaco_id == $espaco.tipo_espaco_id
      return = {type: "list"}
    } as $regras_do_tipo

    function.run obter_configuracao_horario as $configuracao
    function.run tipo_com_regras {
      input = {tipo: $tipo, regras_do_tipo: $regras_do_tipo}
    } as $com_regras

    // Espaço reservável
    function.run disponibilidade_espaco {
      input = {
        espaco_ativo   : $espaco.ativo
        unidade_ativa  : $unidade.ativa
        tipo_ativo     : $tipo.ativo
        tipo_com_regras: $com_regras
      }
    } as $disponibilidade

    precondition ($disponibilidade.reservavel) {
      error_type = "inputerror"
      error = "Este espaço não está disponível para reserva."
    }

    // Regra do papel
    function.run regra_do_papel {
      input = {papel: $input.papel, regras_do_tipo: $regras_do_tipo}
    } as $regra

    precondition ($regra.pode_reservar) {
      error_type = "inputerror"
      error = "Seu papel não pode reservar este tipo de espaço."
    }

    // Regras de horário
    function.run validar_horario_reserva {
      input = {
        tipo            : $tipo
        regras_completas: $com_regras
        configuracao    : $configuracao
        inicio          : $input.inicio
        fim             : $input.fim
        agora           : $input.agora
      }
    } as $validacao

    var $motivos_horario {
      value = $validacao.motivos|map:($rotulos_horario|get:$$)|join:"; "
    }

    precondition ($validacao.dentro_das_regras) {
      error_type = "inputerror"
      error = "Horário fora das regras do tipo: " ~ $motivos_horario ~ "."
    }

    var $resultado {
      value = {}
        |set:"espaco":$espaco
        |set:"tipo":$tipo
        |set:"regra":$regra
    }
  }

  response = $resultado
  guid = "5BdMSxN3Gi8WMg-Bk2yCQvCMp5A"
}
