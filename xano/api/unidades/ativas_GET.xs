// Rota pública usada no formulário de cadastro: expõe somente id e nome das unidades ativas.
// Lista as unidades ativas (id e nome), ordenadas por nome
query ativas verb=GET {
  api_group = "unidades"

  input {
  }

  stack {
    db.query unidade {
      where = $db.unidade.ativa == true
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $unidades
  
    var $unidades_publicas {
      value = $unidades|map:{id: $$.id, nome: $$.nome}
    }
  }

  response = $unidades_publicas
  guid = "pndiD68NGyHItodHFBLgGiTtu_4"
}