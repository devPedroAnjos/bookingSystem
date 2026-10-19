// Lista os ids das unidades que um usuário coordena
function unidades_coordenadas {
  input {
    int usuario_id
  }

  stack {
    db.query coordenacao_unidade {
      where = $db.coordenacao_unidade.usuario_id == $input.usuario_id
      return = {type: "list"}
    } as $coordenacoes
  
    var $unidades_ids {
      value = $coordenacoes|map:$$.unidade_id
    }
  }

  response = $unidades_ids
  guid = "wAxec359ywtkJPANamK-TCgo8Bw"
}