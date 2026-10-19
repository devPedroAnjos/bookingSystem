// Move um coordenador da origem para o destino: ele deixa a origem (spec coordenacao).
// A origem precisa continuar com outro coordenador ativo; o destino precisa estar ativo e ter vaga.
// Move um coordenador ativo entre unidades, dentro da trava de governança
query mover_coordenador verb=POST {
  api_group = "unidades"
  auth = "usuario"

  input {
    int usuario_id
    int origem_id
    int destino_id
  }

  stack {
    precondition ($input.origem_id != $input.destino_id) {
      error_type = "inputerror"
      error = "A origem e o destino precisam ser unidades diferentes."
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_admin {
          input = {usuario_id: $auth.id}
        } as $ator
      
        function.run carregar_coordenador {
          input = {usuario_id: $input.usuario_id}
        } as $carregado
      
        precondition ($carregado.unidades_ids|in:$input.origem_id) {
          error_type = "inputerror"
          error = $carregado.coordenador.nome ~ " não coordena a unidade de origem."
        }
      
        function.run exigir_origem_coberta {
          input = {
            unidade_id: $input.origem_id
            usuario_id: $input.usuario_id
          }
        } as $origem_coberta
      
        function.run validar_destino_coordenador {
          input = {
            unidade_id: $input.destino_id
            usuario_id: $input.usuario_id
          }
        } as $destino
      
        db.query coordenacao_unidade {
          where = $db.coordenacao_unidade.usuario_id == $input.usuario_id && $db.coordenacao_unidade.unidade_id == $input.origem_id
          return = {type: "single"}
        } as $coordenacao_origem
      
        function.run remover_coordenacao {
          input = {
            ator_id       : $ator.id
            coordenacao_id: $coordenacao_origem.id
          }
        } as $removida
      
        function.run atribuir_coordenacao {
          input = {
            ator_id   : $ator.id
            usuario_id: $input.usuario_id
            unidade_id: $destino.id
          }
        } as $atribuida
      }
    }
  }

  response = {mensagem: "Coordenador movido."}
  guid = "tnq8j4nZoKON7Hs5CRVfwe8zNQk"
}