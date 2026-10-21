// Redefinição de senha por um admin (spec senha; design.md da C3, D8 e D5):
// qualquer admin para alunos, professores e coordenadores; só o principal para admins
// secundários; ninguém para o principal. A senha vira provisória e as sessões do titular caem.
// Define uma senha provisória para uma conta ativa, dentro da trava de governança
query redefinir_senha verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    text senha_provisoria? {
      sensitive = true
    }
  }

  stack {
    var $senha_provisoria {
      value = $input.senha_provisoria|first_notnull:""
    }
  
    precondition (($senha_provisoria|strlen) >= 8) {
      error_type = "inputerror"
      error = "A senha provisória deve ter pelo menos 8 caracteres."
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
          error = "Só contas ativas têm a senha redefinida."
        }
      
        // Epoch em ms: sessoes_validas_desde é int, e now literal num campo int não é avaliado
        var $agora {
          value = now
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $permissao.alvo.id
          data = {
            senha_hash           : $senha_provisoria
            senha_provisoria     : true
            sessoes_validas_desde: $agora
          }
        } as $atualizado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $permissao.ator.id
            acao        : "REDEFINIR_SENHA"
            entidade    : "usuario"
            entidade_id : $permissao.alvo.id
            dados_antes : {senha_provisoria: $permissao.alvo.senha_provisoria == true}
            dados_depois: {senha_provisoria: true}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {
    mensagem: "Senha redefinida. A pessoa deverá trocá-la no próximo acesso."
  }

  guid = "5gnxOK97Wzh_kBHQbI2GCwCzUAI"
}