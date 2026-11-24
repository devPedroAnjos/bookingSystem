// Edição dos parâmetros pelo admin principal (spec parametros; design.md da C3, D9 e da C5, D8).
// Limites inteiros >= 1, inclusive o prazo de cancelamento (C6, D12) e o prazo para deslocar por
// prioridade (C8, D9) e os três parâmetros da fila de espera (C9, D2 e D12: corte, prazo para
// confirmar e tempo mínimo útil) e os cinco de check-in e penalidade (C10, D1) e o prazo para avaliar (espaco-feed-avaliacoes, D8); ao menos 1 domínio, sem @ nem espaço, sem repetição, em minúsculas;
// granularidade divisora de 60 e compatível com as regras dos tipos (conferido na trava);
// dias de funcionamento de 1 a 7, sem repetição, ao menos um.
// Reduzir um limite não remove ninguém. Se algo for inválido, nada é gravado.
// Grava os parâmetros, dentro da trava de governança
query parametros verb=POST {
  api_group = "contas"
  auth = "usuario"

  input {
    text[]? dominios_email?
    int? max_coordenadores_unidade?
    int? max_unidades_coordenador?
    int? max_pedidos_cadastro?
    int? max_admins?
    int? prazo_cancelamento_minutos?
    int? prazo_deslocamento_minutos?
    int? prazo_fila_minutos?
    int? prazo_confirmacao_fila_minutos?
    int? tempo_minimo_fila_minutos?
    int? checkin_antes_minutos?
    int? checkin_depois_minutos?
    int? faltas_para_penalidade?
    int? janela_faltas_dias?
    int? duracao_penalidade_dias?
    int? prazo_avaliacao_dias?
    int? foto_tamanho_max_kb?
    int? granularidade_minutos?
    json? dias_funcionamento?
  }

  stack {
    var $dominios {
      value = ($input.dominios_email|first_notnull:[])|map:($$|trim|to_lower)
    }
  
    precondition (($dominios|count) > 0) {
      error_type = "inputerror"
      error = "Informe ao menos um domínio de e-mail."
    }
  
    precondition (!($dominios|some:(($$|strlen) == 0 || ($$|contains:"@") || ($$|contains:" ")))) {
      error_type = "inputerror"
      error = "Domínio inválido: informe só a parte após o @, sem espaços."
    }
  
    precondition (($dominios|unique|count) == ($dominios|count)) {
      error_type = "inputerror"
      error = "Há domínios repetidos."
    }
  
    var $limites {
      value = {
        max_coordenadores_unidade : $input.max_coordenadores_unidade,
        max_unidades_coordenador  : $input.max_unidades_coordenador,
        max_pedidos_cadastro      : $input.max_pedidos_cadastro,
        max_admins                : $input.max_admins,
        prazo_cancelamento_minutos: $input.prazo_cancelamento_minutos,
        prazo_deslocamento_minutos: $input.prazo_deslocamento_minutos,
        prazo_fila_minutos        : $input.prazo_fila_minutos,
        prazo_confirmacao_fila_minutos: $input.prazo_confirmacao_fila_minutos,
        tempo_minimo_fila_minutos : $input.tempo_minimo_fila_minutos,
        checkin_antes_minutos     : $input.checkin_antes_minutos,
        checkin_depois_minutos    : $input.checkin_depois_minutos,
        faltas_para_penalidade    : $input.faltas_para_penalidade,
        janela_faltas_dias        : $input.janela_faltas_dias,
        duracao_penalidade_dias   : $input.duracao_penalidade_dias,
        prazo_avaliacao_dias      : $input.prazo_avaliacao_dias,
        foto_tamanho_max_kb       : $input.foto_tamanho_max_kb
      }
    }
  
    foreach ($limites|keys) {
      each as $limite {
        precondition ((($limites|get:$limite)|first_notnull:0) >= 1) {
          error_type = "inputerror"
          error = "O parâmetro " ~ $limite ~ " deve ser um número inteiro a partir de 1."
        }
      }
    }
  
    precondition ([1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60]|in:($input.granularidade_minutos|first_notnull:0)) {
      error_type = "inputerror"
      error = "A granularidade deve ser um divisor de 60: 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30 ou 60 minutos."
    }
  
    var $dias {
      value = ($input.dias_funcionamento|first_notnull:[])|map:($$|to_int)
    }
  
    precondition (($dias|count) > 0) {
      error_type = "inputerror"
      error = "Informe ao menos um dia de funcionamento."
    }
  
    precondition ($dias|every:($$ >= 1 && $$ <= 7) && ($dias|unique|count) == ($dias|count)) {
      error_type = "inputerror"
      error = "Os dias de funcionamento vão de 1 (segunda) a 7 (domingo), sem repetição."
    }
  
    db.transaction {
      stack {
        function.run travar_governanca as $trava
        function.run exigir_principal {
          input = {
            usuario_id: $auth.id
            emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
          }
        } as $ator
      
        function.run obter_configuracao as $antes
      
        // Nova granularidade não pode deixar tipo com regras fora dela (spec parametros)
        conditional {
          if ($antes.granularidade_minutos != $input.granularidade_minutos) {
            var $granularidade {
              value = $input.granularidade_minutos
            }
          
            db.query tipo_espaco {
              where = $db.tipo_espaco.duracao_min_minutos != null
              return = {type: "list"}
            } as $tipos_com_regras
          
            var $incompativeis {
              value = $tipos_com_regras|filter:($$.duracao_min_minutos % $granularidade != 0 || $$.duracao_max_minutos % $granularidade != 0 || $$.hora_abertura_minutos % $granularidade != 0 || $$.hora_fechamento_minutos % $granularidade != 0 || $$.duracao_min_minutos < $granularidade)
            }
          
            precondition (($incompativeis|count) == 0) {
              error_type = "inputerror"
              error = "A granularidade de " ~ $granularidade ~ " minutos é incompatível com as regras destes tipos: " ~ ($incompativeis|map:$$.nome|join:", ") ~ "."
            }
          }
        }
      
        db.patch configuracao_geral {
          field_name = "id"
          field_value = $antes.id
          data = $limites
            |set:"dominios_email":$dominios
            |set:"granularidade_minutos":$input.granularidade_minutos
            |set:"dias_funcionamento":$dias
        } as $depois
      
        function.run registrar_auditoria {
          input = {
            ator_id     : $ator.id
            acao        : "ALTERAR_PARAMETROS"
            entidade    : "configuracao_geral"
            entidade_id : $antes.id
            dados_antes : {
            dominios_email            : $antes.dominios_email
            max_coordenadores_unidade : $antes.max_coordenadores_unidade
            max_unidades_coordenador  : $antes.max_unidades_coordenador
            max_pedidos_cadastro      : $antes.max_pedidos_cadastro
            max_admins                : $antes.max_admins
            prazo_cancelamento_minutos: $antes.prazo_cancelamento_minutos
            prazo_deslocamento_minutos: $antes.prazo_deslocamento_minutos
            prazo_fila_minutos        : $antes.prazo_fila_minutos
            prazo_confirmacao_fila_minutos: $antes.prazo_confirmacao_fila_minutos
            tempo_minimo_fila_minutos : $antes.tempo_minimo_fila_minutos
            checkin_antes_minutos     : $antes.checkin_antes_minutos
            checkin_depois_minutos    : $antes.checkin_depois_minutos
            faltas_para_penalidade    : $antes.faltas_para_penalidade
            janela_faltas_dias        : $antes.janela_faltas_dias
            duracao_penalidade_dias   : $antes.duracao_penalidade_dias
            prazo_avaliacao_dias      : $antes.prazo_avaliacao_dias
            foto_tamanho_max_kb       : $antes.foto_tamanho_max_kb
            granularidade_minutos     : $antes.granularidade_minutos
            dias_funcionamento        : $antes.dias_funcionamento
          }
            dados_depois: {
            dominios_email            : $depois.dominios_email
            max_coordenadores_unidade : $depois.max_coordenadores_unidade
            max_unidades_coordenador  : $depois.max_unidades_coordenador
            max_pedidos_cadastro      : $depois.max_pedidos_cadastro
            max_admins                : $depois.max_admins
            prazo_cancelamento_minutos: $depois.prazo_cancelamento_minutos
            prazo_deslocamento_minutos: $depois.prazo_deslocamento_minutos
            prazo_fila_minutos        : $depois.prazo_fila_minutos
            prazo_confirmacao_fila_minutos: $depois.prazo_confirmacao_fila_minutos
            tempo_minimo_fila_minutos : $depois.tempo_minimo_fila_minutos
            checkin_antes_minutos     : $depois.checkin_antes_minutos
            checkin_depois_minutos    : $depois.checkin_depois_minutos
            faltas_para_penalidade    : $depois.faltas_para_penalidade
            janela_faltas_dias        : $depois.janela_faltas_dias
            duracao_penalidade_dias   : $depois.duracao_penalidade_dias
            prazo_avaliacao_dias      : $depois.prazo_avaliacao_dias
            foto_tamanho_max_kb       : $depois.foto_tamanho_max_kb
            granularidade_minutos     : $depois.granularidade_minutos
            dias_funcionamento        : $depois.dias_funcionamento
          }
          }
        } as $registro_auditoria
      }
    }
  }

  response = {mensagem: "Parâmetros atualizados."}
  guid = "BXHSzuDMXhxXjpaSYGMa7TvzDyc"
}