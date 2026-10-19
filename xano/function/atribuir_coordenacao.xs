// Cria a coordenação e grava ATRIBUIR_COORDENACAO na mesma transação de quem chama.
// As validações (papel, limites, destino) são responsabilidade de quem chama.
// Atribui uma unidade a um coordenador, com auditoria
function atribuir_coordenacao {
  input {
    int ator_id
    int usuario_id
    int unidade_id
  }

  stack {
    db.add coordenacao_unidade {
      data = {
        usuario_id: $input.usuario_id
        unidade_id: $input.unidade_id
        desde     : now
      }
    } as $coordenacao
  
    function.run registrar_auditoria {
      input = {
        ator_id     : $input.ator_id
        acao        : "ATRIBUIR_COORDENACAO"
        entidade    : "coordenacao_unidade"
        entidade_id : $coordenacao.id
        unidade_id  : $coordenacao.unidade_id
        dados_depois: {
        usuario_id: $coordenacao.usuario_id
        unidade_id: $coordenacao.unidade_id
        desde     : $coordenacao.desde
      }
      }
    } as $registro_auditoria
  }

  response = $coordenacao
  guid = "5K9PgVMXFNaPHi6AlK4kUBmvfYo"
}