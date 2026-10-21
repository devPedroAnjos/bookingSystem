// Regra única de disponibilidade (spec espacos; design D8): o espaço só é reservável quando ele,
// a unidade dele e o tipo dele estão ativos. Não consulta o banco: quem chama passa a situação já
// carregada (na reserva, relida dentro da trava). Usada pela listagem de gestão, pela busca (C5)
// e pela reserva (C6).
// Devolve reservavel e a lista de motivos quando não é reservável
function disponibilidade_espaco {
  input {
    // Nulo conta como inativo: a regra nega quando falta o dado
    bool? espaco_ativo
  
    bool? unidade_ativa
    bool? tipo_ativo
  }

  stack {
    var $motivos {
      value = []
    }
  
    conditional {
      if ($input.espaco_ativo != true) {
        var.update $motivos {
          value = $motivos|push:"ESPACO_DESATIVADO"
        }
      }
    }
  
    conditional {
      if ($input.unidade_ativa != true) {
        var.update $motivos {
          value = $motivos|push:"UNIDADE_DESATIVADA"
        }
      }
    }
  
    conditional {
      if ($input.tipo_ativo != true) {
        var.update $motivos {
          value = $motivos|push:"TIPO_DESATIVADO"
        }
      }
    }
  }

  response = {reservavel: ($motivos|count) == 0, motivos: $motivos}
  guid = "zhwUL00532d1hXflC2SQ7z-QQf8"
}