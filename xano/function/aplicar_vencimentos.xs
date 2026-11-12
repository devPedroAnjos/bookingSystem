// Faxina de vencimentos em transação própria (C7, design D3). As rotas que gravam reservas
// (criar, cancelar, aprovar, recusar) a chamam depois de validar o formato da entrada e ANTES da
// transação principal: assim a expiração fica gravada mesmo que a operação seja recusada depois
// (um precondition dentro da transação principal desfaria tudo). Falha da faxina não bloqueia a
// operação: o erro vai para o log, e a correção vem da situação efetiva (D2). Se o plano do Xano
// passar a ter tarefas agendadas, uma task chama esta mesma função (D4).
// Abre a transação, pega a trava e grava os vencimentos; devolve quantos gravou
function aplicar_vencimentos {
  input {
  }

  stack {
    var $quantidade {
      value = 0
    }

    try_catch {
      try {
        db.transaction {
          stack {
            function.run travar_governanca as $trava

            var $agora {
              value = now
            }

            function.run processar_vencimentos {
              input = {agora: $agora}
            } as $processadas

            var.update $quantidade {
              value = $processadas
            }
          }
        }
      }

      catch {
        debug.log {
          value = "aplicar_vencimentos: a faxina falhou e a operação seguiu sem ela: " ~ $error.message
        }
      }
    }
  }

  response = $quantidade
  guid = "UyqCR1XgY01ll4cP_K-HsfRbm3U"
}
