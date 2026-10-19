// Recusa de pedido de cadastro PENDENTE, com motivo obrigatório (spec aprovacao-cadastro; design.md, D6).
// Mesmas permissões da aprovação. A recusa manual consome pedido (recusa_sem_custo = false).
// Recusa um pedido de cadastro dentro da trava de governança
query recusar verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    text motivo? filters=trim
  }

  stack {
    var $motivo {
      value = $input.motivo|first_notnull:""
    }
  
    precondition (($motivo|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o motivo da recusa."
    }
  
    precondition (($motivo|strlen) <= 500) {
      error_type = "inputerror"
      error = "O motivo deve ter no máximo 500 caracteres."
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_pedido_para_decisao {
          input = {
            ator_id          : $auth.id
            usuario_id       : $input.usuario_id
            situacao_esperada: "PENDENTE"
          }
        } as $pedido
      
        var $ator {
          value = $pedido.ator
        }
      
        var $alvo {
          value = $pedido.alvo
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $alvo.id
          data = {
            status_conta          : "RECUSADA"
            aprovado_por_id       : $ator.id
            aprovado_em           : now
            motivo_recusa_cadastro: $motivo
            recusa_sem_custo      : false
          }
        } as $recusado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "RECUSAR_CADASTRO"
            entidade    : "usuario"
            entidade_id : $alvo.id
            unidade_id  : $alvo.unidade_vinculo_id
            dados_antes : {
            status_conta          : $alvo.status_conta
            motivo_recusa_cadastro: $alvo.motivo_recusa_cadastro
          }
            dados_depois: {
            status_conta          : $recusado.status_conta
            motivo_recusa_cadastro: $recusado.motivo_recusa_cadastro
            recusa_sem_custo      : $recusado.recusa_sem_custo
            automatica            : false
          }
          }
        } as $auditoria_recusa
      }
    }
  }

  response = {mensagem: "Cadastro recusado."}
  guid = "UlQZmpWIUxVzHtPOluNNRYmdUNE"
}