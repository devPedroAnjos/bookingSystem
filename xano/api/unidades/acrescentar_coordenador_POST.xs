// Acrescenta uma unidade a um coordenador, que continua nas que já tinha (spec coordenacao).
// O destino precisa estar ativo, ter vaga e não ser dele; o coordenador não pode passar do limite.
// Acrescenta uma unidade a um coordenador ativo, dentro da trava de governança
query acrescentar_coordenador verb=POST {
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
          input = {usuario_id: $auth.id}
        } as $ator
      
        function.run carregar_coordenador {
          input = {usuario_id: $input.usuario_id}
        } as $carregado
      
        function.run obter_configuracao as $configuracao
        precondition (($carregado.unidades_ids|count) < $configuracao.max_unidades_coordenador) {
          error_type = "inputerror"
          error = $carregado.coordenador.nome ~ " já coordena o máximo de unidades."
        }
      
        function.run validar_destino_coordenador {
          input = {
            unidade_id: $input.unidade_id
            usuario_id: $input.usuario_id
          }
        } as $destino
      
        function.run atribuir_coordenacao {
          input = {
            ator_id   : $ator.id
            usuario_id: $input.usuario_id
            unidade_id: $destino.id
          }
        } as $coordenacao
      }
    }
  }

  response = {mensagem: "Unidade acrescentada ao coordenador."}
  guid = "weR6qfPSO5iuw7XGTgmLXhrHCmk"
}