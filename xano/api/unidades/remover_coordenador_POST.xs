// Remove uma das unidades de um coordenador que coordena mais de uma (spec coordenacao).
// O coordenador nunca fica sem unidade, e a unidade removida não fica sem coordenador ativo.
// Remove uma coordenação, dentro da trava de governança
query remover_coordenador verb=POST {
  api_group = "unidades"
  auth = "usuario"

  input {
    int usuario_id
    int unidade_id
  }

  stack {
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        function.run carregar_coordenador {
          input = {usuario_id: $input.usuario_id}
        } as $carregado
      
        precondition ($carregado.unidades_ids|in:$input.unidade_id) {
          error_type = "inputerror"
          error = $carregado.coordenador.nome ~ " não coordena essa unidade."
        }
      
        precondition (($carregado.unidades_ids|count) > 1) {
          error_type = "inputerror"
          error = "O coordenador precisa de ao menos uma unidade. Para tirá-lo da coordenação, mude o papel dele."
        }
      
        function.run exigir_origem_coberta {
          input = {
            unidade_id: $input.unidade_id
            usuario_id: $input.usuario_id
          }
        } as $origem_coberta
      
        db.query coordenacao_unidade {
          where = $db.coordenacao_unidade.usuario_id == $input.usuario_id && $db.coordenacao_unidade.unidade_id == $input.unidade_id
          return = {type: "single"}
        } as $coordenacao
      
        function.run remover_coordenacao {
          input = {ator_id: $ator.id, coordenacao_id: $coordenacao.id}
        } as $removida
      }
    }
  }

  response = {mensagem: "Coordenação removida."}
  guid = "SAWy0j0egbN71_X616tuqL2ix9o"
}