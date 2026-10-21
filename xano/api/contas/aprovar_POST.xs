// Aprovação de pedido de cadastro (spec aprovacao-cadastro; design.md, D6).
// Professor: admin ou coordenador da unidade pedida; a unidade passa a ser a dele.
// Coordenador: só admin; cria a coordenação da unidade pedida, se ela tiver vaga.
// Conta RECUSADA: só admin, com situacao_esperada = "RECUSADA".
// Aprova um pedido de cadastro dentro da trava de governança
query aprovar verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    text situacao_esperada?=PENDENTE filters=trim|upper
  }

  stack {
    precondition ($input.situacao_esperada == "PENDENTE" || $input.situacao_esperada == "RECUSADA") {
      error_type = "inputerror"
      error = "Situação inválida."
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run carregar_pedido_para_decisao {
          input = {
            ator_id          : $auth.id
            emitido_em       : ($auth.extras|get:"emitido_em")|first_notnull:0
            usuario_id       : $input.usuario_id
            situacao_esperada: $input.situacao_esperada
          }
        } as $pedido
      
        var $ator {
          value = $pedido.ator
        }
      
        var $alvo {
          value = $pedido.alvo
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $alvo.unidade_vinculo_id
        } as $unidade
      
        precondition ($unidade != null && $unidade.ativa) {
          error_type = "inputerror"
          error = "A unidade do pedido está desativada. Recuse o pedido para que a pessoa escolha outra unidade."
        }
      
        var $e_coordenador {
          value = $alvo.papel == "COORDENADOR"
        }
      
        conditional {
          if ($e_coordenador) {
            function.run validar_destino_coordenador {
              input = {unidade_id: $unidade.id, usuario_id: $alvo.id}
            } as $destino
          }
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $alvo.id
          data = {
            status_conta          : "ATIVA"
            aprovado_por_id       : $ator.id
            aprovado_em           : now
            motivo_recusa_cadastro: null
            recusa_sem_custo      : false
            unidade_vinculo_id    : $e_coordenador ? null : $unidade.id
          }
        } as $aprovado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "APROVAR_CADASTRO"
            entidade    : "usuario"
            entidade_id : $alvo.id
            unidade_id  : $unidade.id
            dados_antes : {
            status_conta          : $alvo.status_conta
            papel                 : $alvo.papel
            unidade_vinculo_id    : $alvo.unidade_vinculo_id
            motivo_recusa_cadastro: $alvo.motivo_recusa_cadastro
            aprovado_por_id       : $alvo.aprovado_por_id
          }
            dados_depois: {
            status_conta          : $aprovado.status_conta
            papel                 : $aprovado.papel
            unidade_vinculo_id    : $aprovado.unidade_vinculo_id
            motivo_recusa_cadastro: $aprovado.motivo_recusa_cadastro
            aprovado_por_id       : $aprovado.aprovado_por_id
          }
          }
        } as $auditoria_aprovacao
      
        conditional {
          if ($e_coordenador) {
            function.run atribuir_coordenacao {
              input = {
                ator_id   : $ator.id
                usuario_id: $alvo.id
                unidade_id: $unidade.id
              }
            } as $coordenacao
          }
        }
      }
    }
  }

  response = {mensagem: "Cadastro aprovado."}
  guid = "ctaXri03Qt916xg8YIm-Je010OI"
}