// Carrega o pedido de cadastro e verifica se o ator pode decidi-lo (design.md, D6).
// Deve ser chamada DEPOIS de travar_governanca, dentro da transação.
// - ADMIN decide pedidos de professor e de coordenador, inclusive contas RECUSADA.
// - COORDENADOR decide só pedidos PENDENTE de professor das unidades que coordena.
// - situacao_esperada é a situação que o ator estava vendo; se mudou, o pedido já foi decidido.
// Para o coordenador, um alvo fora do escopo responde 403, nunca 404.
// Devolve o ator e o registro completo do alvo (quem chama não repassa senha_hash)
function carregar_pedido_para_decisao {
  input {
    int ator_id
    int usuario_id
    text situacao_esperada
    int? emitido_em?
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $input.ator_id
        emitido_em: $input.emitido_em
      }
    } as $ator
  
    precondition ($ator.papel == "ADMIN" || $ator.papel == "COORDENADOR") {
      error_type = "accessdenied"
      error = "Você não tem acesso a estes pedidos."
    }
  
    db.get usuario {
      field_name = "id"
      field_value = $input.usuario_id
    } as $alvo
  
    conditional {
      if ($ator.papel == "ADMIN") {
        precondition ($alvo != null) {
          error_type = "notfound"
          error = "Conta não encontrada."
        }
      }
    
      else {
        // Coordenador: só professor, só PENDENTE, só nas unidades que coordena
        var $no_escopo {
          value = false
        }
      
        conditional {
          if ($alvo != null && $alvo.papel == "PROFESSOR" && $input.situacao_esperada == "PENDENTE" && $alvo.unidade_vinculo_id != null) {
            db.query coordenacao_unidade {
              where = $db.coordenacao_unidade.usuario_id == $ator.id && $db.coordenacao_unidade.unidade_id == $alvo.unidade_vinculo_id
              return = {type: "exists"}
            } as $coordena
          
            var.update $no_escopo {
              value = $coordena
            }
          }
        }
      
        precondition ($no_escopo) {
          error_type = "accessdenied"
          error = "Você não tem acesso a este pedido."
        }
      }
    }
  
    precondition ($alvo.status_conta == $input.situacao_esperada && ($alvo.papel == "PROFESSOR" || $alvo.papel == "COORDENADOR")) {
      error_type = "inputerror"
      error = "Este pedido já foi decidido. Atualize a lista."
    }
  }

  response = {ator: $ator, alvo: $alvo}
  guid = "4joS3aGkmRCpKEZqS5eQQ_F7KU8"
}