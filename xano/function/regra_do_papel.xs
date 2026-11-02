// Regra por papel de um tipo (spec regras-tipo; design D4). Não consulta o banco: recebe as
// linhas de regra_papel do tipo já carregadas. COORDENADOR e ADMIN têm regra fixa (reservam
// todos os tipos, sem aprovação); ALUNO e PROFESSOR seguem a linha do papel; sem linha, não reservam.
// Devolve pode_reservar e exige_aprovacao do papel
function regra_do_papel {
  input {
    text papel
    json? regras_do_tipo?
  }

  stack {
    var $regra {
      value = {pode_reservar: false, exige_aprovacao: false}
    }
  
    conditional {
      if ($input.papel == "COORDENADOR" || $input.papel == "ADMIN") {
        var.update $regra {
          value = {pode_reservar: true, exige_aprovacao: false}
        }
      }
    
      else {
        var $linha {
          value = ($input.regras_do_tipo|first_notnull:[])|find:$$.papel == $input.papel
        }
      
        conditional {
          if ($linha != null) {
            // Valores calculados antes: o Xano não avalia operadores dentro de literal de objeto,
            // e && no value de uma variável devolve null; por isso exige vem de um conditional
            var $pode {
              value = $linha.pode_reservar == true
            }
          
            var $exige {
              value = false
            }
          
            conditional {
              if ($pode && $linha.exige_aprovacao) {
                var.update $exige {
                  value = true
                }
              }
            }
          
            var.update $regra {
              value = {}
                |set:"pode_reservar":$pode
                |set:"exige_aprovacao":$exige
            }
          }
        }
      }
    }
  }

  response = $regra
  guid = "yNFK7dAZ3NXmPU6NgbsmGUyA_Z0"
}