// Coordenadores com conta ATIVA e papel COORDENADOR de uma unidade (id e nome).
// É a base das contagens de limite: só contam coordenadores ativos (spec coordenacao).
// Lista os coordenadores ativos de uma unidade
function coordenadores_ativos {
  input {
    int unidade_id
  }

  stack {
    db.query coordenacao_unidade {
      join = {
        usuario: {
          table: "usuario"
          where: $db.coordenacao_unidade.usuario_id == $db.usuario.id
        }
      }
    
      where = $db.coordenacao_unidade.unidade_id == $input.unidade_id && $db.usuario.status_conta == "ATIVA" && $db.usuario.papel == "COORDENADOR"
      sort = {usuario_nome: "asc"}
      eval = {usuario_nome: $db.usuario.nome}
      return = {type: "list"}
    } as $coordenacoes
  
    var $coordenadores {
      value = $coordenacoes|map:{id: $$.usuario_id, nome: $$.usuario_nome}
    }
  }

  response = $coordenadores
  guid = "zlec28hJhvo9ECKBi9EAjO916Kg"
}