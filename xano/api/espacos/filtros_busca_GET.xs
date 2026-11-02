// Opções dos filtros da busca para qualquer conta ativa (spec busca-espacos; design D5): os tipos
// ativos, com regras completas, que o papel pode reservar (com exige_aprovacao e as regras de
// horário e duração) e o catálogo de recursos. As listagens de gestão continuam só para gestores.
// Devolve os tipos e recursos que o usuário pode usar na busca
query filtros_busca verb=GET {
  api_group = "espacos"
  auth = "usuario"

  input {
  }

  stack {
    function.run usuario_ativo {
      input = {
        usuario_id: $auth.id
        emitido_em: ($auth.extras|get:"emitido_em")|first_notnull:0
      }
    } as $ator
  
    db.query tipo_espaco {
      where = $db.tipo_espaco.ativo == true
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $tipos
  
    db.query regra_papel {
      return = {type: "list"}
    } as $todas_regras
  
    db.query recurso {
      sort = {nome: "asc"}
      return = {type: "list"}
    } as $recursos
  
    var $tipos_do_papel {
      value = []
    }
  
    foreach ($tipos) {
      each as $tipo {
        var $regras_do_tipo {
          value = $todas_regras|filter:$$.tipo_espaco_id == $tipo.id
        }
      
        function.run tipo_com_regras {
          input = {tipo: $tipo, regras_do_tipo: $regras_do_tipo}
        } as $com_regras
      
        function.run regra_do_papel {
          input = {papel: $ator.papel, regras_do_tipo: $regras_do_tipo}
        } as $regra
      
        conditional {
          if ($com_regras && $regra.pode_reservar) {
            var.update $tipos_do_papel {
              value = $tipos_do_papel
                |push:```
                  {
                    id: $tipo.id,
                    nome: $tipo.nome,
                    exige_aprovacao: $regra.exige_aprovacao,
                    duracao_min_minutos: $tipo.duracao_min_minutos,
                    duracao_max_minutos: $tipo.duracao_max_minutos,
                    hora_abertura_minutos: $tipo.hora_abertura_minutos,
                    hora_fechamento_minutos: $tipo.hora_fechamento_minutos
                  }
                  ```
            }
          }
        }
      }
    }
  }

  response = {
    tipos   : $tipos_do_papel
    recursos: $recursos|map:{id: $$.id, nome: $$.nome}
  }

  guid = "WnU5iryiQeQVQ8CP0nlE4gfe2bU"
}