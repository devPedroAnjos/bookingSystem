// Desativação de tipo de espaço por qualquer admin (spec tipos-espaco). Os espaços do tipo não
// mudam de situação, mas deixam de ser reserváveis (disponibilidade derivada, design D8).
// Motivo obrigatório da lista de desativação (C6, D17). Recusada, sem alterar nada, se algum
// espaço do tipo, em qualquer unidade, tiver reserva confirmada em andamento; senão cancela as
// reservas dos espaços do tipo (ativos ou não) que ainda não terminaram, levando o motivo (C6, D10).
// Desativa um tipo de espaço ativo, dentro da trava de governança
query desativar_tipo verb=POST {
  api_group = "espacos"
  auth = "usuario"

  input {
    int tipo_espaco_id
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
        function.run exigir_admin {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator

        db.get tipo_espaco {
          field_name = "id"
          field_value = $input.tipo_espaco_id
        } as $tipo

        precondition ($tipo != null) {
          error_type = "notfound"
          error = "Tipo de espaço não encontrado."
        }

        precondition ($tipo.ativo) {
          error_type = "inputerror"
          error = "O tipo de espaço já está desativado."
        }

        db.query espaco {
          where = $db.espaco.tipo_espaco_id == $tipo.id
          return = {type: "list"}
        } as $espacos_do_tipo

        var $espacos_ids {
          value = $espacos_do_tipo|map:$$.id
        }

        var $agora {
          value = now
        }

        function.run exigir_sem_reserva_em_andamento {
          input = {
            espacos_ids   : $espacos_ids
            agora         : $agora
            varios_espacos: true
          }
        } as $sem_reserva_em_uso

        function.run cancelar_reservas {
          input = {
            modo            : "espaco"
            espacos_ids     : $espacos_ids
            motivo          : "ESPACO_INDISPONIVEL"
            motivo_detalhe  : $motivo.codigo
            motivo_descricao: $motivo.descricao
            ator_id         : $ator.id
            agora           : $agora
          }
        } as $cancelamento

        var.update $texto_cancelamento {
          value = $cancelamento.texto
        }

        db.edit tipo_espaco {
          field_name = "id"
          field_value = $tipo.id
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
            ator_id     : $ator.id
            acao        : "DESATIVAR_TIPO_ESPACO"
            entidade    : "tipo_espaco"
            entidade_id : $tipo.id
            dados_antes : {ativo: true}
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
      }
    }

    var $mensagem {
      value = "Tipo de espaço desativado." ~ $texto_cancelamento
    }
  }

  response = {mensagem: $mensagem}
  guid = "keRDFe5AlCPuecBMGD0REByXbd4"
}
