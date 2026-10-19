// Apaga a coordenação e grava REMOVER_COORDENACAO na mesma transação de quem chama.
// O histórico fica em dados_antes. As validações são responsabilidade de quem chama.
// Remove uma coordenação, com auditoria
function remover_coordenacao {
  input {
    int ator_id
    int coordenacao_id
  }

  stack {
    db.get coordenacao_unidade {
      field_name = "id"
      field_value = $input.coordenacao_id
    } as $coordenacao
  
    precondition ($coordenacao != null) {
      error_type = "notfound"
      error = "Coordenação não encontrada."
    }
  
    db.del coordenacao_unidade {
      field_name = "id"
      field_value = $coordenacao.id
    }
  
    function.run registrar_auditoria {
      input = {
        ator_id    : $input.ator_id
        acao       : "REMOVER_COORDENACAO"
        entidade   : "coordenacao_unidade"
        entidade_id: $coordenacao.id
        unidade_id : $coordenacao.unidade_id
        dados_antes: {
        usuario_id: $coordenacao.usuario_id
        unidade_id: $coordenacao.unidade_id
        desde     : $coordenacao.desde
      }
      }
    } as $registro_auditoria
  }

  response = $coordenacao
  guid = "mON_mSEtZ_PiUj0W7OxDGCdsuY8"
}