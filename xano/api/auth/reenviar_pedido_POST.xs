// Reenvio público do pedido de cadastro recusado, com e-mail e senha (design.md, D7).
// Pode trocar a unidade e o papel pedido (PROFESSOR ou COORDENADOR) e trazer uma justificativa.
// A recusa por desativação da unidade (recusa_sem_custo) não consome pedido.
// Volta o pedido recusado para análise, respeitando o limite de pedidos
query reenviar_pedido verb=POST {
  api_group = "auth"

  input {
    text email? filters=trim|lower {
      sensitive = true
    }
  
    text senha? {
      sensitive = true
    }
  
    text papel? filters=trim|upper
    int? unidade_vinculo_id?
    text justificativa? filters=trim
  }

  stack {
    // Validações que não dependem de estado concorrente ficam antes da trava
    precondition ($input.papel == "PROFESSOR" || $input.papel == "COORDENADOR") {
      error_type = "inputerror"
      error = "Escolha o papel: professor ou coordenador."
    }
  
    precondition ($input.unidade_vinculo_id != null) {
      error_type = "inputerror"
      error = "Escolha a unidade."
    }
  
    var $justificativa {
      value = $input.justificativa|first_notnull:""
    }
  
    precondition (($justificativa|strlen) <= 500) {
      error_type = "inputerror"
      error = "A justificativa deve ter no máximo 500 caracteres."
    }
  
    function.run conferir_credenciais {
      input = {email: $input.email, senha: $input.senha}
    } as $credenciais
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        db.get usuario {
          field_name = "id"
          field_value = $credenciais.id
        } as $usuario
      
        precondition ($usuario.status_conta == "RECUSADA") {
          error_type = "inputerror"
          error = "Não há pedido recusado para reenviar."
        }
      
        function.run obter_configuracao as $configuracao
        var $pedidos_atuais {
          value = $usuario.pedidos_cadastro|first_notnull:1
        }
      
        precondition ($usuario.recusa_sem_custo || $pedidos_atuais < $configuracao.max_pedidos_cadastro) {
          error_type = "inputerror"
          error = "Os pedidos de cadastro se esgotaram. Procure a administração."
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_vinculo_id
        } as $unidade
      
        precondition ($unidade != null && $unidade.ativa) {
          error_type = "inputerror"
          error = "Unidade inválida."
        }
      
        var $novos_pedidos {
          value = $usuario.recusa_sem_custo ? $pedidos_atuais : $pedidos_atuais + 1
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $usuario.id
          data = {
            status_conta          : "PENDENTE"
            papel                 : $input.papel
            unidade_vinculo_id    : $unidade.id
            justificativa_cadastro: ($justificativa|strlen) > 0 ? $justificativa : null
            pedidos_cadastro      : $novos_pedidos
            motivo_recusa_cadastro: null
            aprovado_por_id       : null
            aprovado_em           : null
            recusa_sem_custo      : false
          }
        } as $atualizado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $usuario.id
            acao        : "REENVIAR_CADASTRO"
            entidade    : "usuario"
            entidade_id : $usuario.id
            unidade_id  : $unidade.id
            dados_antes : {
            status_conta          : $usuario.status_conta
            papel                 : $usuario.papel
            unidade_vinculo_id    : $usuario.unidade_vinculo_id
            motivo_recusa_cadastro: $usuario.motivo_recusa_cadastro
            pedidos_cadastro      : $pedidos_atuais
            justificativa_cadastro: $usuario.justificativa_cadastro
            recusa_sem_custo      : $usuario.recusa_sem_custo
          }
            dados_depois: {
            status_conta          : $atualizado.status_conta
            papel                 : $atualizado.papel
            unidade_vinculo_id    : $atualizado.unidade_vinculo_id
            motivo_recusa_cadastro: $atualizado.motivo_recusa_cadastro
            pedidos_cadastro      : $atualizado.pedidos_cadastro
            justificativa_cadastro: $atualizado.justificativa_cadastro
            recusa_sem_custo      : $atualizado.recusa_sem_custo
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem: "Pedido reenviado. Ele aguarda uma nova análise."
  }

  guid = "5n4LUCT02Az91gXGpgTKs0pEn28"
}