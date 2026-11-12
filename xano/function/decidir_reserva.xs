// Parte comum de aprovar_reserva e recusar_reserva (C7, design D5, D6 e D8). Deve ser chamada
// DEPOIS de travar_governanca, dentro da transação, e depois de aplicar_vencimentos (fora dela).
// Ordem das recusas: autorização (carregar_reserva_gerida), própria reserva, prazo (inclui a
// EXPIRADA já gravada e a PENDENTE vencida ainda não gravada) e situação. Não confere de novo as
// regras do tipo, o limite nem o conflito: as regras valem na criação e a pendente já ocupa.
// O motivo chega validado pela rota de recusa.
// Aprova ou recusa uma reserva pendente e devolve a nova situação
function decidir_reserva {
  input {
    int ator_id
    int? emitido_em?
    int reserva_id

    // "APROVAR" ou "RECUSAR"
    text decisao

    text? motivo? filters=trim
  }

  stack {
    precondition ($input.decisao == "APROVAR" || $input.decisao == "RECUSAR") {
      error = "Decisão desconhecida."
    }

    function.run carregar_reserva_gerida {
      input = {
        ator_id   : $input.ator_id
        reserva_id: $input.reserva_id
        emitido_em: $input.emitido_em
      }
    } as $carregada

    var $ator {
      value = $carregada.ator
    }

    var $reserva {
      value = $carregada.reserva
    }

    var $espaco {
      value = $carregada.espaco
    }

    precondition ($reserva.usuario_id != $ator.id) {
      error_type = "inputerror"
      error = "Sua própria reserva é decidida por outro coordenador da unidade ou por um administrador."
    }

    var $agora {
      value = now
    }

    // Início igual ao agora já encerra o prazo (aprovar exige inicio > agora, estrito)
    var $prazo_terminou {
      value = false
    }

    conditional {
      if ($reserva.status == "EXPIRADA") {
        var.update $prazo_terminou {
          value = true
        }
      }

      elseif ($reserva.status == "PENDENTE" && $reserva.inicio <= $agora) {
        var.update $prazo_terminou {
          value = true
        }
      }
    }

    precondition (!$prazo_terminou) {
      error_type = "inputerror"
      error = "O prazo de decisão terminou: a reserva começou sem aprovação."
    }

    precondition ($reserva.status == "PENDENTE") {
      error_type = "inputerror"
      error = "Esta reserva não está pendente."
    }

    // A inativação já cancela as pendentes futuras do dono; a releitura deixa a regra explícita
    db.get usuario {
      field_name = "id"
      field_value = $reserva.usuario_id
    } as $dono

    precondition ($dono.status_conta == "ATIVA") {
      error_type = "inputerror"
      error = "A conta de quem fez a reserva não está ativa."
    }

    var $status_novo {
      value = "CONFIRMADA"
    }

    var $acao {
      value = "APROVAR_RESERVA"
    }

    conditional {
      if ($input.decisao == "RECUSAR") {
        var.update $status_novo {
          value = "RECUSADA"
        }

        var.update $acao {
          value = "RECUSAR_RESERVA"
        }
      }
    }

    var $dados {
      value = {}
        |set:"status":$status_novo
        |set:"decidido_por_id":$ator.id
        |set:"decidido_em":$agora
    }

    var $dados_depois {
      value = {}|set:"status":$status_novo
    }

    conditional {
      if ($input.decisao == "RECUSAR") {
        var.update $dados {
          value = $dados|set:"motivo_recusa":$input.motivo
        }

        var.update $dados_depois {
          value = $dados_depois|set:"motivo_recusa":$input.motivo
        }
      }
    }

    db.patch reserva {
      field_name = "id"
      field_value = $reserva.id
      data = $dados
    } as $decidida

    var $dados_antes {
      value = {}|set:"status":$reserva.status
    }

    function.run registrar_auditoria {
      input = {
        ator_id     : $ator.id
        acao        : $acao
        entidade    : "reserva"
        entidade_id : $reserva.id
        unidade_id  : $espaco.unidade_id
        dados_antes : $dados_antes
        dados_depois: $dados_depois
      }
    } as $registro_auditoria
  }

  response = $decidida.status
  guid = "sdsyK9VDaa0cuh-GYDtUMIMdjIA"
}
