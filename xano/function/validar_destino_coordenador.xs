// Valida uma unidade de destino para um coordenador (spec coordenacao):
// existe, está ativa, ainda não é coordenada por ele e tem vaga.
// vagas_reservadas conta destinos do mesmo formulário ainda não gravados (desativação).
// Deve ser chamada dentro da trava de governança.
// Devolve a unidade validada, ou 400/404
function validar_destino_coordenador {
  input {
    int unidade_id
    int usuario_id
  
    // O Xano descarta padrões falsos (0, false) ao salvar: o valor vazio é tratado como 0 abaixo
    int? vagas_reservadas?
  }

  stack {
    db.get unidade {
      field_name = "id"
      field_value = $input.unidade_id
    } as $unidade
  
    precondition ($unidade != null) {
      error_type = "notfound"
      error = "Unidade não encontrada."
    }
  
    precondition ($unidade.ativa) {
      error_type = "inputerror"
      error = "A unidade " ~ $unidade.nome ~ " está desativada."
    }
  
    db.query coordenacao_unidade {
      where = $db.coordenacao_unidade.usuario_id == $input.usuario_id && $db.coordenacao_unidade.unidade_id == $unidade.id
      return = {type: "exists"}
    } as $ja_coordena
  
    precondition (!$ja_coordena) {
      error_type = "inputerror"
      error = "O coordenador já coordena a unidade " ~ $unidade.nome ~ "."
    }
  
    function.run obter_configuracao as $configuracao
    function.run coordenadores_ativos {
      input = {unidade_id: $unidade.id}
    } as $coordenadores
  
    var $vagas_reservadas {
      value = $input.vagas_reservadas|first_notnull:0
    }
  
    precondition ((($coordenadores|count) + $vagas_reservadas) < $configuracao.max_coordenadores_unidade) {
      error_type = "inputerror"
      error = "A unidade " ~ $unidade.nome ~ " não tem vaga para outro coordenador."
    }
  }

  response = $unidade
  guid = "GWSj2pUwBHbajjm_5NBT8sYXAAA"
}