// Reservas dos espaços no escopo do gestor (spec aprovacao-reservas; design D9). Só leitura, sem
// trava e sem gravação. Admin vê todas as unidades; coordenador, só as que coordena. Unidade ou
// espaço fora do escopo do coordenador: 403 com a mesma mensagem. A situação segue a regra da
// situação efetiva (D2): PENDENTE só as que ainda não começaram; EXPIRADA inclui as vencidas
// ainda não gravadas. Teto técnico de 200 itens, com "limitada". Uma consulta por tabela.
// C10 (D8): CONFIRMADA sem as vencidas; NAO_COMPARECEU e CONCLUIDA também pela situação efetiva;
// check_in_em no item.
// Dos usuários saem só nome e e-mail; no cancelamento por inativação de conta, quem cancelou
// não é exposto (decisions-log 24).
// Lista as reservas da unidade para coordenador e admin
query reservas_unidade verb=GET {
  api_group = "reservas"
  auth = "usuario"

  input {
    int? unidade_id?
    int? espaco_id?
    text? situacao? filters=trim
    text? data_inicial? filters=trim
    text? data_final? filters=trim
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator
  
    precondition ($ator.papel == "ADMIN" || $ator.papel == "COORDENADOR") {
      error_type = "accessdenied"
      error = "Você não tem acesso à gestão de reservas."
    }
  
    // Situação (padrão: pendentes)
    var $situacao {
      value = $input.situacao|first_notnull:""
    }
  
    conditional {
      if (($situacao|strlen) == 0) {
        var.update $situacao {
          value = "PENDENTE"
        }
      }
    }
  
    // Texto com split em vez de lista literal: o Xano tira as vírgulas dos literais ao salvar
    var $situacoes_aceitas {
      value = "PENDENTE,CONFIRMADA,CONCLUIDA,NAO_COMPARECEU,RECUSADA,EXPIRADA,CANCELADA,TODAS"|split:","
    }
  
    precondition ($situacoes_aceitas|in:$situacao) {
      error_type = "inputerror"
      error = "Situação inválida."
    }
  
    // Período em São Paulo: das 00h00 da data inicial às 00h00 do dia seguinte à final
    var $periodo_inicio {
      value = null
    }
  
    var $periodo_fim {
      value = null
    }
  
    conditional {
      if ((($input.data_inicial|first_notnull:"")|strlen) > 0) {
        function.run converter_data_pedido {
          input = {data: $input.data_inicial}
        } as $inicio_inicial
      
        var.update $periodo_inicio {
          value = $inicio_inicial
        }
      }
    }
  
    conditional {
      if ((($input.data_final|first_notnull:"")|strlen) > 0) {
        function.run converter_data_pedido {
          input = {data: $input.data_final}
        } as $inicio_final
      
        var.update $periodo_fim {
          value = $inicio_final|add_secs_to_timestamp:86400
        }
      }
    }
  
    conditional {
      if (!($periodo_inicio|is_null) && !($periodo_fim|is_null)) {
        precondition ($periodo_fim > $periodo_inicio) {
          error_type = "inputerror"
          error = "A data final deve ser igual ou posterior à inicial."
        }
      }
    }
  
    // Espaços no escopo
    var $espacos {
      value = []
    }
  
    var $unidades_do_ator {
      value = []
    }
  
    conditional {
      if ($ator.papel == "ADMIN") {
        db.query espaco {
          return = {type: "list"}
        } as $todos_espacos
      
        var.update $espacos {
          value = $todos_espacos
        }
      }
    
      else {
        function.run unidades_coordenadas {
          input = {usuario_id: $ator.id}
        } as $coordenadas
      
        var.update $unidades_do_ator {
          value = $coordenadas
        }
      
        db.query espaco {
          where = $db.espaco.unidade_id in $coordenadas
          return = {type: "list"}
        } as $espacos_coordenados
      
        var.update $espacos {
          value = $espacos_coordenados
        }
      }
    }
  
    // Filtro de unidade: o coordenador só filtra as que coordena
    conditional {
      if (!($input.unidade_id|is_null)) {
        conditional {
          if ($ator.papel == "COORDENADOR") {
            precondition ($unidades_do_ator|in:$input.unidade_id) {
              error_type = "accessdenied"
              error = "Você não tem acesso a estas reservas."
            }
          }
        }
      
        var.update $espacos {
          value = $espacos|filter:$$.unidade_id == $input.unidade_id
        }
      }
    }
  
    // Filtro de espaço: inexistente ou fora do escopo do coordenador recebe a mesma recusa
    conditional {
      if (!($input.espaco_id|is_null)) {
        var $espaco_pedido {
          value = $espacos|find:$$.id == $input.espaco_id
        }
      
        conditional {
          if ($ator.papel == "COORDENADOR") {
            precondition ($espaco_pedido != null) {
              error_type = "accessdenied"
              error = "Você não tem acesso a estas reservas."
            }
          }
        }
      
        var.update $espacos {
          value = $espacos|filter:$$.id == $input.espaco_id
        }
      }
    }
  
    var $ids_espacos {
      value = $espacos|map:$$.id
    }
  
    var $agora {
      value = now
    }

    // Janela de check-in e marco do comparecimento (C10, D2), com a precondição do bootstrap
    function.run obter_configuracao_comparecimento as $configuracao

    // Início mínimo de uma confirmada sem check-in ainda dentro da janela
    var $inicio_limite {
      value = $agora - $configuracao.depois_ms
    }

    // Uma consulta por situação: a regra da situação efetiva muda a forma do filtro (D2).
    // per_page 201 para saber se havia mais que o teto de 200. Escopo vazio (coordenador sem
    // unidades ou filtro sem espaços) não consulta: nunca um "in" com lista vazia.
    var $encontradas {
      value = []
    }
  
    conditional {
      if (($ids_espacos|count) == 0) {
        var.update $encontradas {
          value = []
        }
      }
    
      elseif ($situacao == "PENDENTE") {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && $db.reserva.status == "PENDENTE" && $db.reserva.inicio > $agora && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "asc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $pendentes
      
        var.update $encontradas {
          value = $pendentes
        }
      }
    
      elseif ($situacao == "EXPIRADA") {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && ($db.reserva.status == "EXPIRADA" || ($db.reserva.status == "PENDENTE" && $db.reserva.inicio <= $agora)) && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $expiradas
      
        var.update $encontradas {
          value = $expiradas
        }
      }
    
      // C10 (D2): as três situações abaixo seguem a situação efetiva, gravada ou não
      elseif ($situacao == "CONFIRMADA") {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && $db.reserva.status == "CONFIRMADA" && ($db.reserva.inicio < $configuracao.comparecimento_desde || ($db.reserva.check_in_em != null && $db.reserva.fim > $agora) || ($db.reserva.check_in_em == null && $db.reserva.inicio >= $inicio_limite && $db.reserva.fim >= $agora)) && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $confirmadas

        var.update $encontradas {
          value = $confirmadas
        }
      }

      elseif ($situacao == "NAO_COMPARECEU") {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && ($db.reserva.status == "NAO_COMPARECEU" || ($db.reserva.status == "CONFIRMADA" && $db.reserva.inicio >= $configuracao.comparecimento_desde && $db.reserva.check_in_em == null && ($db.reserva.inicio < $inicio_limite || $db.reserva.fim < $agora))) && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $nao_compareceram

        var.update $encontradas {
          value = $nao_compareceram
        }
      }

      elseif ($situacao == "CONCLUIDA") {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && ($db.reserva.status == "CONCLUIDA" || ($db.reserva.status == "CONFIRMADA" && $db.reserva.inicio >= $configuracao.comparecimento_desde && $db.reserva.check_in_em != null && $db.reserva.fim <= $agora)) && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $concluidas

        var.update $encontradas {
          value = $concluidas
        }
      }

      elseif ($situacao == "TODAS") {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $todas
      
        var.update $encontradas {
          value = $todas
        }
      }
    
      else {
        db.query reserva {
          where = $db.reserva.espaco_id in $ids_espacos && $db.reserva.status == $situacao && $db.reserva.inicio >=? $periodo_inicio && $db.reserva.inicio <? $periodo_fim
          sort = {inicio: "desc"}
          return = {
            type  : "list"
            paging: {page: 1, per_page: 201, metadata: false}
          }
        } as $na_situacao
      
        var.update $encontradas {
          value = $na_situacao
        }
      }
    }
  
    // conditional em vez de operador no value (lição da C5)
    var $limitada {
      value = false
    }
  
    conditional {
      if (($encontradas|count) > 200) {
        var.update $limitada {
          value = true
        }
      }
    }
  
    var $reservas {
      value = $encontradas|slice:0:200
    }
  
    // Dados relacionados, uma consulta por tabela
    var $ids_donos {
      value = $reservas|map:$$.usuario_id
    }
  
    var $ids_decisores {
      value = $reservas|map:$$.decidido_por_id
    }
  
    var $ids_canceladores {
      value = $reservas|map:$$.cancelado_por_id
    }
  
    // Uma lista só, sem vazios, e consulta só quando há ids
    var $ids_usuarios {
      value = $ids_donos|merge:$ids_decisores|merge:$ids_canceladores|filter:$$ > 0|unique
    }
  
    var $usuarios {
      value = []
    }
  
    conditional {
      if (($ids_usuarios|count) > 0) {
        db.query usuario {
          where = $db.usuario.id in $ids_usuarios
          return = {type: "list"}
        } as $usuarios_envolvidos
      
        var.update $usuarios {
          value = $usuarios_envolvidos
        }
      }
    }
  
    db.query unidade {
      return = {type: "list"}
    } as $unidades
  
    db.query tipo_espaco {
      return = {type: "list"}
    } as $tipos
  
    var $lista {
      value = []
    }
  
    foreach ($reservas) {
      each as $reserva {
        var $espaco {
          value = $espacos|find:$$.id == $reserva.espaco_id
        }
      
        var $unidade {
          value = $unidades|find:$$.id == $espaco.unidade_id
        }
      
        var $tipo {
          value = $tipos|find:$$.id == $espaco.tipo_espaco_id
        }
      
        var $dono {
          value = $usuarios|find:$$.id == $reserva.usuario_id
        }
      
        function.run situacao_efetiva {
          input = {
            status                : $reserva.status
            inicio                : $reserva.inicio
            agora                 : $agora
            fim                   : $reserva.fim
            check_in_em           : $reserva.check_in_em
            checkin_depois_minutos: $configuracao.checkin_depois_minutos
            comparecimento_desde  : $configuracao.comparecimento_desde
          }
        } as $situacao_item
      
        function.run formatar_reserva {
          input = {inicio: $reserva.inicio, fim: $reserva.fim}
        } as $formatada
      
        var $criado_em_texto {
          value = $reserva.criado_em
            |format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
        }
      
        var $decidido_por {
          value = null
        }
      
        var $decidido_em_texto {
          value = null
        }
      
        conditional {
          if (!($reserva.decidido_por_id|is_null)) {
            var $decisor {
              value = $usuarios|find:$$.id == $reserva.decidido_por_id
            }
          
            var.update $decidido_por {
              value = $decisor.nome
            }
          
            var.update $decidido_em_texto {
              value = $reserva.decidido_em
                |format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
            }
          }
        }
      
        // Na inativação de conta, quem cancelou não é exposto (decisions-log 24)
        var $cancelado_por {
          value = null
        }
      
        conditional {
          if (!($reserva.cancelado_por_id|is_null) && $reserva.motivo_cancelamento != "CONTA_INATIVADA") {
            var $cancelador {
              value = $usuarios|find:$$.id == $reserva.cancelado_por_id
            }
          
            var.update $cancelado_por {
              value = $cancelador.nome
            }
          }
        }
      
        // Check-in (C10, D8), em São Paulo
        var $check_in_texto {
          value = null
        }

        conditional {
          if (!($reserva.check_in_em|is_null)) {
            var.update $check_in_texto {
              value = $reserva.check_in_em|format_timestamp:"d/m/Y H:i":"America/Sao_Paulo"
            }
          }
        }

        var $dono_item {
          value = {}
            |set:"nome":$dono.nome
            |set:"email":$dono.email
        }
      
        var $espaco_item {
          value = {}
            |set:"id":$espaco.id
            |set:"nome":$espaco.nome
            |set:"codigo":$espaco.codigo
        }
      
        var $unidade_item {
          value = {}
            |set:"id":$unidade.id
            |set:"nome":$unidade.nome
        }
      
        var $tipo_item {
          value = {}
            |set:"id":$tipo.id
            |set:"nome":$tipo.nome
        }
      
        var $item {
          value = {}
            |set:"id":$reserva.id
            |set:"dono":$dono_item
            |set:"nivel_prioridade":$reserva.nivel_prioridade
            |set:"espaco":$espaco_item
            |set:"unidade":$unidade_item
            |set:"tipo":$tipo_item
            |set:"inicio":$reserva.inicio
            |set:"fim":$reserva.fim
            |set:"data":$formatada.data
            |set:"hora_inicio":$formatada.hora_inicio
            |set:"hora_fim":$formatada.hora_fim
            |set:"status":$situacao_item
            |set:"criado_em":$criado_em_texto
            |set:"decidido_por":$decidido_por
            |set:"decidido_em":$decidido_em_texto
            |set:"motivo_recusa":$reserva.motivo_recusa
            |set:"motivo_cancelamento":$reserva.motivo_cancelamento
            |set:"motivo_detalhe":$reserva.motivo_detalhe
            |set:"motivo_descricao":$reserva.motivo_descricao
            |set:"cancelado_por":$cancelado_por
            |set:"check_in_em":$check_in_texto
        }
      
        var.update $lista {
          value = $lista|push:$item
        }
      }
    }
  
    var $resposta {
      value = {}
        |set:"reservas":$lista
        |set:"limitada":$limitada
    }
  }

  response = $resposta
  guid = "YCaxg1x5k3zBSk7xtQ9Sf-8JbUU"
}