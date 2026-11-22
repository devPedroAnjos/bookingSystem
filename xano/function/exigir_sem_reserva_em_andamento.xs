// Recusa por reserva confirmada em andamento (C6, design D10): desativar, mover ou trocar o tipo
// de um espaço e desativar tipo ou unidade são recusados, sem alterar nada, enquanto algum espaço
// afetado tiver reserva CONFIRMADA em andamento. Ninguém, nem admin nem coordenador, encerra uma
// reserva em uso. Deve ser chamada dentro da trava, antes de qualquer gravação da rota.
// varios_espacos escolhe a mensagem: um espaço, ou os espaços de um tipo ou unidade.
// C11 (design D3): com inicio e fim (criação de bloqueio), só conta a reserva em andamento
// sobreposta a esse período (modo bloqueio da seleção).
// Recusa com o horário de término da última reserva em andamento, ou devolve true
function exigir_sem_reserva_em_andamento {
  input {
    json espacos_ids
    int agora
    bool? varios_espacos?
    int? inicio?
    int? fim?
  }

  stack {
    var $modo {
      value = "espaco"
    }

    conditional {
      if (!($input.inicio|is_null) && !($input.fim|is_null)) {
        var.update $modo {
          value = "bloqueio"
        }
      }
    }

    function.run selecionar_reservas_a_cancelar {
      input = {
        modo       : $modo
        espacos_ids: $input.espacos_ids
        inicio     : $input.inicio
        fim        : $input.fim
        agora      : $input.agora
      }
    } as $selecao
  
    var $quantidade {
      value = $selecao.em_andamento
    }
  
    conditional {
      if ($quantidade > 0) {
        var $ate {
          value = $selecao.em_andamento_ate
            |format_timestamp:"H:i":"America/Sao_Paulo"
        }
      
        var $mensagem {
          value = "Há uma reserva em andamento neste espaço até " ~ $ate ~ ". Tente depois que ela terminar."
        }
      
        conditional {
          if ($input.varios_espacos && $quantidade == 1) {
            var.update $mensagem {
              value = "Há uma reserva em andamento nos espaços afetados até " ~ $ate ~ ". Tente depois que ela terminar."
            }
          }
        
          elseif ($input.varios_espacos) {
            var.update $mensagem {
              value = "Há " ~ $quantidade ~ " reservas em andamento nos espaços afetados; a última termina às " ~ $ate ~ ". Tente depois que elas terminarem."
            }
          }
        }
      
        precondition (false) {
          error_type = "inputerror"
          error = $mensagem
        }
      }
    }
  }

  response = true
  guid = "HxK4zVXM9Q9mvieMn_Zz75kmWAE"
}