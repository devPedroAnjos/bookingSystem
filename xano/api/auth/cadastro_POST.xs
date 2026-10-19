// Cadastro público de aluno, professor ou coordenador.
// Papel, situação, dados de aprovação e coordenações não são entradas: não podem ser forçados.
// Cria conta de ALUNO (ATIVA) ou PROFESSOR/COORDENADOR (PENDENTE) com e-mail institucional
query cadastro verb=POST {
  api_group = "auth"

  input {
    text nome? filters=trim
    text email? filters=trim|lower {
      sensitive = true
    }
  
    text senha? {
      sensitive = true
    }
  
    text vinculo? filters=trim|upper
    int? unidade_vinculo_id?
  }

  stack {
    var $mensagem_duplicidade {
      value = "Não foi possível concluir o cadastro. Se você já tem conta, faça login."
    }
  
    var $nome {
      value = $input.nome|first_notnull:""
    }
  
    var $email {
      value = $input.email|first_notnull:""
    }
  
    // Campos obrigatórios
    precondition (($nome|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o nome."
    }
  
    precondition (($email|strlen) > 0) {
      error_type = "inputerror"
      error = "Informe o e-mail."
    }
  
    precondition ((($input.senha|first_notnull:"")|strlen) >= 8) {
      error_type = "inputerror"
      error = "A senha deve ter pelo menos 8 caracteres."
    }
  
    // Vínculo: ALUNO, PROFESSOR ou COORDENADOR. ADMIN nunca é obtido pelo cadastro.
    var $pede_aprovacao {
      value = $input.vinculo == "PROFESSOR" || $input.vinculo == "COORDENADOR"
    }
  
    precondition ($input.vinculo == "ALUNO" || $pede_aprovacao) {
      error_type = "inputerror"
      error = "Escolha o vínculo: aluno, professor ou coordenador."
    }
  
    // Domínio: exatamente um dos domínios aceitos em configuracao_geral
    var $partes_email {
      value = $email|split:"@"
    }
  
    var $dominio {
      value = $partes_email|last
    }
  
    db.query configuracao_geral {
      return = {type: "single"}
    } as $configuracao
  
    precondition ($configuracao != null) {
      error = "Não foi possível concluir o cadastro. Tente novamente mais tarde."
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
  
    // Professor e coordenador: unidade pedida existente e ativa. Para aluno, a unidade é ignorada.
    var $unidade_vinculo_id {
      value = null
    }
  
    conditional {
      if ($pede_aprovacao) {
        precondition ($input.unidade_vinculo_id != null) {
          error_type = "inputerror"
          error = "Escolha a unidade."
        }
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_vinculo_id
        } as $unidade
      
        precondition ($unidade != null && $unidade.ativa) {
          error_type = "inputerror"
          error = "Unidade inválida."
        }
      
        var.update $unidade_vinculo_id {
          value = $unidade.id
        }
      }
    }
  
    // E-mail já cadastrado: mensagem genérica, sem confirmar a existência da conta
    db.has usuario {
      field_name = "email"
      field_value = $email
    } as $email_existe
  
    precondition (!$email_existe) {
      error_type = "inputerror"
      error = $mensagem_duplicidade
    }
  
    var $status_conta {
      value = $input.vinculo == "ALUNO" ? "ATIVA" : "PENDENTE"
    }
  
    // Usuário e auditoria na mesma transação. Se dois cadastros simultâneos passarem pela
    // checagem acima, o índice único de email recusa o segundo, que recebe a mesma mensagem genérica.
    try_catch {
      try {
        db.transaction {
          stack {
            db.add usuario {
              data = {
                nome              : $nome
                email             : $email
                senha_hash        : $input.senha
                papel             : $input.vinculo
                status_conta      : $status_conta
                unidade_vinculo_id: $unidade_vinculo_id
                criado_em         : now
                pedidos_cadastro  : 1
              }
            } as $usuario
          
            function.run registrar_auditoria {
              input = {
                ator_id     : $usuario.id
                acao        : "CRIAR_CONTA"
                entidade    : "usuario"
                entidade_id : $usuario.id
                unidade_id  : $unidade_vinculo_id
                dados_depois: {
                nome              : $usuario.nome
                email             : $usuario.email
                papel             : $usuario.papel
                status_conta      : $usuario.status_conta
                unidade_vinculo_id: $usuario.unidade_vinculo_id
                pedidos_cadastro  : $usuario.pedidos_cadastro
              }
              }
            } as $registro_auditoria
          }
        }
      }
    
      catch {
        db.has usuario {
          field_name = "email"
          field_value = $email
        } as $email_existe_apos_falha
      
        precondition (!$email_existe_apos_falha) {
          error_type = "inputerror"
          error = $mensagem_duplicidade
        }
      
        precondition (false) {
          error = "Não foi possível concluir o cadastro. Tente novamente."
        }
      }
    }
  
    var $mensagem {
      value = "Conta criada. Você já pode entrar."
    }
  
    conditional {
      if ($input.vinculo == "PROFESSOR") {
        var.update $mensagem {
          value = "Conta criada. Ela aguarda aprovação da coordenação."
        }
      }
    
      elseif ($input.vinculo == "COORDENADOR") {
        var.update $mensagem {
          value = "Conta criada. Ela aguarda aprovação da administração."
        }
      }
    }
  }

  response = {mensagem: $mensagem, status_conta: $status_conta}
  guid = "cTZAfJMU-8HS7aWbZhQllNySwyc"
}