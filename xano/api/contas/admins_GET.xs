// Lista os administradores, ativos e inativos, para a página do admin principal.
// Lista os admins com a marca de principal e a situação
query admins verb=GET {
  api_group = "contas"
  auth = "usuario"

  input {
  }

  stack {
    function.run exigir_principal {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator
  
    db.query usuario {
      where = $db.usuario.papel == "ADMIN"
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $contas
  
    var $admins {
      value = ```
        $contas|map:{
                id              : $$.id
                nome            : $$.nome
                email           : $$.email
                status_conta    : $$.status_conta
                admin_principal : $$.admin_principal == true
                senha_provisoria: $$.senha_provisoria == true
              }
        ```
    }
  }

  response = $admins
  guid = "vPgrGcwf3zwvkudIy8kHPEly0xI"
}