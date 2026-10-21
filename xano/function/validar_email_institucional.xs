// O domínio do e-mail (parte após o @) precisa ser exatamente um dos domínios aceitos em
// configuracao_geral, sem diferenciar maiúsculas e minúsculas (spec autenticacao).
// Usada pelo cadastro público e pela criação de admin. O e-mail chega já normalizado.
// Falha com 400 "Use seu e-mail institucional." quando o domínio não é aceito
function validar_email_institucional {
  input {
    text email
  }

  stack {
    var $partes_email {
      value = $input.email|split:"@"
    }
  
    var $dominio {
      value = $partes_email|last
    }
  
    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao
  
    precondition ($configuracao != null) {
      error = "Não foi possível concluir a operação. Tente novamente mais tarde."
    }
  
    var $dominios_aceitos {
      value = ($configuracao.dominios_email|join:",")|to_lower|split:","
    }
  
    var $dominio_aceito {
      value = $dominios_aceitos|some:$$ == $dominio
    }
  
    precondition (($partes_email|count) == 2 && (($partes_email|first)|strlen) > 0 && $dominio_aceito) {
      error_type = "inputerror"
      error = "Use seu e-mail institucional."
    }
  }

  response = true
  guid = "F2oTT_7oyO7YC0o1VeYC4kr6t6E"
}