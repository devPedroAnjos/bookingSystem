// Nível de prioridade do papel (domain-model §2.1; C8, design D2): ALUNO 1, PROFESSOR 2,
// COORDENADOR e ADMIN 3. Usado na gravação da reserva (nivel_prioridade) e no deslocamento, pela
// criação e pela busca, para as duas nunca divergirem.
// Devolve o nível de prioridade de um papel
function nivel_do_papel {
  input {
    text papel
  }

  stack {
    var $nivel {
      value = 3
    }

    conditional {
      if ($input.papel == "ALUNO") {
        var.update $nivel {
          value = 1
        }
      }

      elseif ($input.papel == "PROFESSOR") {
        var.update $nivel {
          value = 2
        }
      }
    }
  }

  response = $nivel
  guid = "NWuHBhbQXa3iuKQrNcIqLCSDx7I"
}
