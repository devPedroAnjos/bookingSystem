// Desativação de espaço por quem tem escopo sobre a unidade dele (spec espacos). Espaços nunca
// são excluídos; mantêm código, tipo e recursos. Motivo obrigatório da lista de desativação (C6,
// D17). Recusada, sem alterar nada, com reserva confirmada em andamento; senão cancela as reservas
// que ainda não terminaram (ESPACO_INDISPONIVEL), levando o motivo, e informa quantas (C6, D10).
// Desativa um espaço ativo, dentro da trava de governança
query desativar_espaco verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int espaco_id
    text? motivo_codigo? filters=trim
    text? motivo_descricao? filters=trim
  }

  stack {
    function.run validar_motivo {
      input = {
        lista    : "desativacao"
        codigo   : $input.motivo_codigo
        descricao: $input.motivo_descricao
      }
    } as $motivo
  
    // Declarada fora da transação, como $unidade_criada_id em unidades/criar
    var $texto_cancelamento {
      value = ""
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $carregado
      
        precondition ($carregado.espaco.ativo) {
          error_type = "inputerror"
          error = "O espaço já está desativado."
        }
      
        var $agora {
          value = now
        }
      
        function.run exigir_sem_reserva_em_andamento {
          input = {espacos_ids: [$carregado.espaco.id], agora: $agora}
        } as $sem_reserva_em_uso
      
        function.run cancelar_reservas {
          input = {
            modo            : "espaco"
            espacos_ids     : [$carregado.espaco.id]
            motivo          : "ESPACO_INDISPONIVEL"
            motivo_detalhe  : $motivo.codigo
            motivo_descricao: $motivo.descricao
            ator_id         : $carregado.ator.id
            agora           : $agora
          }
        } as $cancelamento
      
        var.update $texto_cancelamento {
          value = $cancelamento.texto
        }
      
        db.edit espaco {
          field_name = "id"
          field_value = $carregado.espaco.id
          data = {ativo: false}
        } as $desativado
      
        var $dados_depois {
          value = {}
            |set:"ativo":false
            |set:"motivo_codigo":$motivo.codigo
            |set:"motivo_descricao":$motivo.descricao
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $carregado.ator.id
            acao        : "DESATIVAR_ESPACO"
            entidade    : "espaco"
            entidade_id : $carregado.espaco.id
            unidade_id  : $carregado.espaco.unidade_id
            dados_antes : {ativo: true}
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
      }
    }
  
    var $mensagem {
      value = "Espaço desativado." ~ $texto_cancelamento
    }
  }

  response = {mensagem: $mensagem}
  guid = "o_gJTefS-xtB4-GupUgUi0rotZs"
}