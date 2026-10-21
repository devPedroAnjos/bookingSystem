// Inativação de conta ATIVA com motivo obrigatório (spec situacao-conta; design.md da C3, D7).
// Permissões de D5: qualquer admin para não-admins, só o principal para admins secundários,
// ninguém para o principal. As coordenações não são tocadas; o motivo fica só na auditoria.
// Inativa uma conta ativa, dentro da trava de governança
query inativar verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    int usuario_id
    text motivo? filters=trim
  }

  stack {
    var $motivo {
      value = $input.motivo|first_notnull:""
    }
  
    precondition (($motivo|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o motivo da inativação."
    }
  
    precondition (($motivo|strlen) <= 500) {
      error_type = "inputerror"
      error = "O motivo deve ter no máximo 500 caracteres."
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
      
        precondition ($permissao.alvo.status_conta == "ATIVA") {
          error_type = "inputerror"
          error = "Só contas ativas são inativadas."
        }
      
        db.edit usuario {
          field_name = "id"
          field_value = $permissao.alvo.id
          data = {status_conta: "INATIVA"}
        } as $inativado
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $permissao.ator.id
            acao        : "INATIVAR_CONTA"
            entidade    : "usuario"
            entidade_id : $permissao.alvo.id
            dados_antes : {status_conta: $permissao.alvo.status_conta}
            dados_depois: {status_conta: $inativado.status_conta, motivo: $motivo}
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Conta inativada."}
  guid = "nb1p7H5O-GMJqHrBeyaVy8XS81E"
}