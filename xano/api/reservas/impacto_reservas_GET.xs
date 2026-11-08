// Impacto de uma ação de gestão sobre as reservas (spec reservas; design D8). Só leitura, sem trava:
// o número é informativo e a ação recalcula tudo dentro da trava. Exatamente um alvo:
// - espaco_id: gestor com escopo na unidade do espaço (carregar_espaco_gerido; para o
//   coordenador, espaço inexistente recebe o mesmo 403 de espaço de outra unidade);
// - tipo_espaco_id e unidade_id: admin; todos os espaços do tipo ou da unidade, ativos ou não;
// - usuario_id: as mesmas regras de quem pode inativar (autorizar_sobre_conta).
// Usa a mesma seleção do cancelamento em lote (modo conta para usuario_id, espaço para os demais).
// Devolve quantas reservas seriam canceladas e até que horas vai a última confirmada em andamento
query impacto_reservas verb=GET {
  api_group = "reservas"
  auth = "usuario"

  input {
    int? espaco_id?
    int? tipo_espaco_id?
    int? unidade_id?
    int? usuario_id?
  }

  stack {
    var $alvos {
      value = 0
    }
  
    conditional {
      if (!($input.espaco_id|is_null)) {
        var.update $alvos {
          value = $alvos + 1
        }
      }
    }
  
    conditional {
      if (!($input.tipo_espaco_id|is_null)) {
        var.update $alvos {
          value = $alvos + 1
        }
      }
    }
  
    conditional {
      if (!($input.unidade_id|is_null)) {
        var.update $alvos {
          value = $alvos + 1
        }
      }
    }
  
    conditional {
      if (!($input.usuario_id|is_null)) {
        var.update $alvos {
          value = $alvos + 1
        }
      }
    }
  
    precondition ($alvos == 1) {
      error_type = "inputerror"
      error = "Indique exatamente um alvo: espaço, tipo de espaço, unidade ou conta."
    }
  
    var $emitido_em {
      value = ($auth.extras|get:"emitido_em")|first_notnull:0
    }
  
    var $modo {
      value = "espaco"
    }
  
    var $espacos_ids {
      value = []
    }
  
    conditional {
      if (!($input.espaco_id|is_null)) {
        function.run carregar_espaco_gerido {
          input = {
            ator_id   : $auth.id
            espaco_id : $input.espaco_id
            emitido_em: $emitido_em
          }
        } as $gerido
      
        var.update $espacos_ids {
          value = [$gerido.espaco.id]
        }
      }
    
      elseif (!($input.tipo_espaco_id|is_null)) {
        function.run exigir_admin {
          input = {usuario_id: $auth.id, emitido_em: $emitido_em}
        } as $admin_tipo
      
        db.get tipo_espaco {
          field_name = "id"
          field_value = $input.tipo_espaco_id
        } as $tipo
      
        precondition ($tipo != null) {
          error_type = "notfound"
          error = "Tipo de espaço não encontrado."
        }
      
        db.query espaco {
          where = $db.espaco.tipo_espaco_id == $tipo.id
          return = {type: "list"}
        } as $espacos_do_tipo
      
        var.update $espacos_ids {
          value = $espacos_do_tipo|map:$$.id
        }
      }
    
      elseif (!($input.unidade_id|is_null)) {
        function.run exigir_admin {
          input = {usuario_id: $auth.id, emitido_em: $emitido_em}
        } as $admin_unidade
      
        db.get unidade {
          field_name = "id"
          field_value = $input.unidade_id
        } as $unidade
      
        precondition ($unidade != null) {
          error_type = "notfound"
          error = "Unidade não encontrada."
        }
      
        db.query espaco {
          where = $db.espaco.unidade_id == $unidade.id
          return = {type: "list"}
        } as $espacos_da_unidade
      
        var.update $espacos_ids {
          value = $espacos_da_unidade|map:$$.id
        }
      }
    
      else {
        function.run autorizar_sobre_conta {
          input = {
            ator_id   : $auth.id
            alvo_id   : $input.usuario_id
            emitido_em: $emitido_em
          }
        } as $permissao
      
        var.update $modo {
          value = "conta"
        }
      }
    }
  
    var $agora {
      value = now
    }
  
    function.run selecionar_reservas_a_cancelar {
      input = {
        modo       : $modo
        usuario_id : $input.usuario_id
        espacos_ids: $espacos_ids
        agora      : $agora
      }
    } as $selecao
  
    var $quantidade {
      value = $selecao.reservas|count
    }
  
    var $em_andamento_ate {
      value = null
    }
  
    conditional {
      if (!($selecao.em_andamento_ate|is_null)) {
        var.update $em_andamento_ate {
          value = $selecao.em_andamento_ate
            |format_timestamp:"H:i":"America/Sao_Paulo"
        }
      }
    }
  
    var $impacto {
      value = {}
        |set:"reservas":$quantidade
        |set:"em_andamento":$selecao.em_andamento
        |set:"em_andamento_ate":$em_andamento_ate
    }
  }

  response = $impacto
  guid = "uZj21VYPG99CSTk8jzMKP1CPL38"
}