// Inativação de conta ATIVA com motivo obrigatório (spec situacao-conta; design.md da C3, D7).
// Permissões de D5: qualquer admin para não-admins, só o principal para admins secundários,
// ninguém para o principal. As coordenações não são tocadas. O motivo vem da lista de conta
// (C6, D17) e fica só na auditoria. Na mesma operação, as reservas da conta que ainda não
// começaram são canceladas (CONTA_INATIVADA, sem detalhe); a em andamento continua (C6, D10).
// Inativa uma conta ativa, dentro da trava de governança
query inativar verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    text? motivo_codigo? filters=trim
    text? motivo_descricao? filters=trim
  }

  stack {
    function.run validar_motivo {
      input = {
        lista    : "conta"
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
        function.run autorizar_sobre_conta {
          input = {
            ator_id   : $auth.id
            alvo_id   : $input.usuario_id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $permissao

        precondition ($permissao.alvo.status_conta == "ATIVA") {
          error_type = "inputerror"
          error = "Só contas ativas são inativadas."
        }

        var $agora {
          value = now
        }

        // Sem motivo_detalhe: a pessoa inativada não vê o motivo (spec situacao-conta)
        function.run cancelar_reservas {
          input = {
            modo      : "conta"
            usuario_id: $permissao.alvo.id
            motivo    : "CONTA_INATIVADA"
            ator_id   : $permissao.ator.id
            agora     : $agora
          }
        } as $cancelamento

        var.update $texto_cancelamento {
          value = $cancelamento.texto
        }

        db.edit usuario {
          field_name = "id"
          field_value = $permissao.alvo.id
          data = {status_conta: "INATIVA"}
        } as $inativado

        var $dados_depois {
          value = {}
            |set:"status_conta":$inativado.status_conta
            |set:"motivo_codigo":$motivo.codigo
            |set:"motivo_descricao":$motivo.descricao
        }

        function.run registrar_auditoria {
          input = {
            ator_id     : $permissao.ator.id
            acao        : "INATIVAR_CONTA"
            entidade    : "usuario"
            entidade_id : $permissao.alvo.id
            dados_antes : {status_conta: $permissao.alvo.status_conta}
            dados_depois: $dados_depois
          }
        } as $registro_auditoria
      }
    }

    var $mensagem {
      value = "Conta inativada." ~ $texto_cancelamento
    }
  }

  response = {mensagem: $mensagem}
  guid = "nb1p7H5O-GMJqHrBeyaVy8XS81E"
}
