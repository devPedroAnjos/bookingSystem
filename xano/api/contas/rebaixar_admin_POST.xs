// Rebaixamento de admin secundário, só pelo principal e só a COORDENADOR (spec administradores).
// Exige de 1 até o máximo de unidades (ativas e com vaga), escolhidas no mesmo ato. Para virar
// professor, o ex-admin usa depois a mudança de papel da C2.
// Rebaixa um admin secundário a coordenador, dentro da trava de governança
query rebaixar_admin verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    int[]? unidades_ids?
  }

  stack {
    var $unidades_ids {
      value = ($input.unidades_ids|first_notnull:[])|unique
    }
  
    precondition (($unidades_ids|count) > 0) {
      error_type = "inputerror"
      error = "Escolha ao menos uma unidade para o coordenador."
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
      
        precondition ($permissao.alvo.papel == "ADMIN") {
          error_type = "inputerror"
          error = "Só administradores são rebaixados por esta operação."
        }
      
        function.run obter_configuracao as $configuracao
        precondition (($unidades_ids|count) <= $configuracao.max_unidades_coordenador) {
          error_type = "inputerror"
          error = "Um coordenador pode ter no máximo " ~ ($configuracao.max_unidades_coordenador|to_text) ~ " unidades."
        }
      
        foreach ($unidades_ids) {
          each as $unidade_id {
            function.run validar_destino_coordenador {
              input = {unidade_id: $unidade_id, usuario_id: $permissao.alvo.id}
            } as $destino
          }
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $permissao.alvo.id
          data = {papel: "COORDENADOR", unidade_vinculo_id: null}
        } as $rebaixado
      
        foreach ($unidades_ids) {
          each as $unidade_id {
            function.run atribuir_coordenacao {
              input = {
                ator_id   : $permissao.ator.id
                usuario_id: $permissao.alvo.id
                unidade_id: $unidade_id
              }
            } as $atribuida
          }
        }
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $permissao.ator.id
            acao        : "REBAIXAR_ADMIN"
            entidade    : "usuario"
            entidade_id : $permissao.alvo.id
            dados_antes : {papel: $permissao.alvo.papel}
            dados_depois: {papel: $rebaixado.papel}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Administrador rebaixado a coordenador."}
  guid = "WhGZAmhBioAd1uZ-wXad6h3cOIo"
}