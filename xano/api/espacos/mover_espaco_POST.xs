// Mudança de unidade de um espaço, só pelo admin (spec espacos; design D6). O destino precisa
// existir, estar ativo, ser diferente da unidade atual e não ter outro espaço com o mesmo código.
// O espaço mantém tipo, situação e recursos. Recusada, sem alterar nada, com reserva confirmada em
// andamento; senão cancela as reservas que ainda não terminaram (ESPACO_INDISPONIVEL, sem motivo
// próprio) ANTES de gravar a nova unidade, para a auditoria levar a unidade de origem (C6, D10/D11).
// Move um espaço para outra unidade, dentro da trava de governança
query mover_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
    int unidade_id
  }

  stack {
    // Declarada fora da transação, como $unidade_criada_id em unidades/criar
    var $texto_cancelamento {
      value = ""
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
      
        db.get espaco {
          field_name = "id"
          field_value = $input.espaco_id
        } as $espaco
      
        precondition ($espaco != null) {
          error_type = "notfound"
          error = "Espaço não encontrado."
        }
      
        precondition ($input.unidade_id != $espaco.unidade_id) {
          error_type = "inputerror"
          error = "O espaço já pertence a essa unidade."
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_id
        } as $destino
      
        precondition ($destino != null) {
          error_type = "notfound"
          error = "Unidade de destino não encontrada."
        }
      
        precondition ($destino.ativa) {
          error_type = "inputerror"
          error = "A unidade de destino está desativada."
        }
      
        function.run exigir_codigo_livre {
          input = {
            unidade_id: $destino.id
            codigo    : $espaco.codigo
            ignorar_id: $espaco.id
          }
        } as $codigo_livre
      
        var $agora {
          value = now
        }
      
        function.run exigir_sem_reserva_em_andamento {
          input = {espacos_ids: [$espaco.id], agora: $agora}
        } as $sem_reserva_em_uso
      
        // Antes da nova unidade: CANCELAR_RESERVA com a unidade de origem (D11)
        function.run cancelar_reservas {
          input = {
            modo       : "espaco"
            espacos_ids: [$espaco.id]
            motivo     : "ESPACO_INDISPONIVEL"
            ator_id    : $ator.id
            agora      : $agora
          }
        } as $cancelamento
      
        var.update $texto_cancelamento {
          value = $cancelamento.texto
        }
      
        db.edit espaco {
          field_name = "id"
          field_value = $espaco.id
          data = {unidade_id: $destino.id}
        } as $movido
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "MOVER_ESPACO"
            entidade    : "espaco"
            entidade_id : $espaco.id
            unidade_id  : $destino.id
            dados_antes : {unidade_id: $espaco.unidade_id}
            dados_depois: {unidade_id: $movido.unidade_id}
          }
        } as $registro_auditoria
      }
    }
  
    var $mensagem {
      value = "Espaço movido." ~ $texto_cancelamento
    }
  }

  response = {mensagem: $mensagem}
  guid = "Ic7sIIDeM9TSy93tgrh1vDreCek"
}