# Especificação: Avaliações

## Purpose
Permitir que quem usou um espaço registre uma nota de 1 a 5 e um comentário sobre o uso, e que os demais usuários vejam essas avaliações e a média de cada espaço.

## Requirements

### Requirement: Quem avalia e quando
O dono de uma reserva DEVE (MUST) poder avaliá-la quando a situação efetiva dela é `CONCLUIDA` (capability `comparecimento`) e ainda não passaram `prazo_avaliacao_dias` × 24 horas desde o término, com o limite incluído. O prazo usa o valor atual do parâmetro. Reserva de outra pessoa, ou inexistente, DEVE ser recusada com a mesma mensagem de reserva não encontrada.

#### Scenario: Avaliar reserva concluída
- **GIVEN** Ana fez check-in na reserva de "BIB-01" de ontem das 14h00 às 15h00, e o prazo de avaliação é de 7 dias
- **WHEN** Ana avalia essa reserva com nota 4
- **THEN** a avaliação é gravada com a nota 4

#### Scenario: Conclusão ainda não gravada
- **GIVEN** a reserva de Ana terminou há 10 minutos, com check-in, e ainda está gravada como `CONFIRMADA`
- **WHEN** Ana avalia a reserva
- **THEN** a reserva é gravada como `CONCLUIDA` e a avaliação é aceita

#### Scenario: Reserva não concluída
- **GIVEN** Ana tem uma reserva `NAO_COMPARECEU`, uma `CANCELADA` e uma `CONFIRMADA` que ainda não terminou
- **WHEN** Ana tenta avaliar cada uma delas
- **THEN** o sistema recusa, informando que só reservas concluídas podem ser avaliadas

#### Scenario: Limite do prazo
- **GIVEN** o prazo de avaliação é de 7 dias e a reserva de Ana terminou em 01/12 às 15h00, horário de São Paulo
- **WHEN** Ana avalia em 08/12 às 15h00
- **THEN** a avaliação é aceita
- **AND** se ela tentasse em 08/12 às 15h01, o sistema recusaria informando que o prazo para avaliar terminou

#### Scenario: Reserva de outra pessoa
- **WHEN** Bruno tenta avaliar uma reserva concluída de Ana
- **THEN** o sistema recusa com a mensagem de reserva não encontrada, sem revelar que a reserva existe

#### Scenario: Reserva anterior ao comparecimento
- **GIVEN** a reserva de Ana começou antes de a regra de comparecimento entrar em uso e continua `CONFIRMADA` (capability `comparecimento`)
- **WHEN** Ana tenta avaliá-la
- **THEN** o sistema recusa, informando que só reservas concluídas podem ser avaliadas

#### Scenario: Espaço desativado depois do uso
- **GIVEN** Ana concluiu uma reserva de "LAB-01" ontem, e hoje "LAB-01" foi desativado
- **WHEN** Ana avalia a reserva dentro do prazo
- **THEN** a avaliação é aceita, e aparece quando "LAB-01" voltar a ser reservável

#### Scenario: Sem autenticação
- **WHEN** a avaliação é enviada sem token ou com conta inativa
- **THEN** o sistema responde com não autenticado

#### Scenario: Senha provisória
- **GIVEN** Ana está com senha provisória
- **WHEN** Ana envia uma avaliação
- **THEN** o sistema recusa com "Troque sua senha para continuar." (capability `senha`)

### Requirement: Uma avaliação por reserva
Cada reserva DEVE (MUST) ter no máximo uma avaliação. Uma segunda avaliação da mesma reserva DEVE ser recusada sem alterar a primeira, inclusive quando as duas chegam ao mesmo tempo. A avaliação NÃO DEVE (MUST NOT) ser editada nem excluída.

#### Scenario: Segunda avaliação
- **GIVEN** Ana já avaliou a reserva com nota 4
- **WHEN** Ana envia nova avaliação da mesma reserva com nota 2
- **THEN** o sistema recusa informando que a reserva já foi avaliada, e a nota continua 4

#### Scenario: Envio duplicado simultâneo
- **WHEN** duas avaliações da mesma reserva chegam ao mesmo tempo
- **THEN** só uma é gravada e a outra é recusada

### Requirement: Nota e comentário
A nota DEVE (MUST) ser um número inteiro de 1 a 5. O comentário é opcional, com espaços nas pontas removidos e até 500 caracteres; comentário vazio é gravado como ausente. Valores inválidos DEVEM ser recusados sem gravar nada.

#### Scenario: Nota fora da faixa
- **WHEN** alguém avalia com nota 0, 6 ou 4,5
- **THEN** o sistema recusa informando que a nota deve ser um número inteiro de 1 a 5

#### Scenario: Comentário longo
- **WHEN** alguém avalia com um comentário de 501 caracteres
- **THEN** o sistema recusa informando o limite de 500 caracteres

#### Scenario: Sem comentário
- **WHEN** Ana avalia com nota 5 e comentário só com espaços
- **THEN** a avaliação é gravada com a nota 5 e sem comentário

### Requirement: Avaliações do espaço
O sistema DEVE (MUST) oferecer, para um espaço que quem pede pode ver (capability `pagina-espaco`), a média das notas com uma casa decimal, a quantidade de avaliações e a lista delas, da mais recente para a mais antiga. Cada avaliação traz a nota, o comentário, a data e o autor como primeiro nome e papel atual. O sistema NÃO DEVE (MUST NOT) mostrar o nome completo, o e-mail nem a reserva do autor.

#### Scenario: Média e lista
- **GIVEN** "BIB-01" tem avaliações de nota 5, 4 e 4
- **WHEN** um aluno consulta as avaliações de "BIB-01"
- **THEN** recebe a média 4,3, a quantidade 3 e as três avaliações, da mais recente para a mais antiga

#### Scenario: Autor exibido
- **GIVEN** a professora Maria Clara Souza avaliou "LAB-01"
- **WHEN** alguém consulta as avaliações de "LAB-01"
- **THEN** o autor aparece como "Maria · Professor", sem o sobrenome nem o e-mail

#### Scenario: Espaço sem avaliações
- **WHEN** alguém consulta um espaço sem avaliações
- **THEN** recebe a quantidade 0, sem média, e a lista vazia

#### Scenario: Conta do autor inativada
- **GIVEN** Ana avaliou "BIB-01" e depois teve a conta inativada
- **WHEN** alguém consulta as avaliações de "BIB-01"
- **THEN** a avaliação de Ana continua na lista e na média

### Requirement: Avaliação nas reservas do usuário
A listagem das reservas do próprio usuário DEVE (MUST) indicar, em cada reserva, se ela pode ser avaliada agora (pela mesma regra do requisito "Quem avalia e quando"), a data e a hora limite para avaliar, em America/Sao_Paulo, quando a reserva está concluída, e a nota quando já foi avaliada. A indicação é informativa: a avaliação verifica tudo de novo.

#### Scenario: Reserva avaliável
- **GIVEN** a reserva de Ana terminou em 01/12 às 15h00, com check-in, e o prazo é de 7 dias
- **WHEN** Ana consulta as próprias reservas em 03/12
- **THEN** a reserva vem avaliável, com o limite 08/12 às 15h00

#### Scenario: Reserva já avaliada
- **GIVEN** Ana avaliou a reserva com nota 4
- **WHEN** Ana consulta as próprias reservas
- **THEN** a reserva vem não avaliável, com a nota 4

#### Scenario: Reserva não concluída
- **WHEN** Ana consulta uma reserva `CONFIRMADA` futura
- **THEN** a reserva vem não avaliável, sem limite e sem nota

### Requirement: Avaliar pela tela
"Minhas reservas" DEVE (MUST) oferecer "Avaliar" em cada reserva que o usuário ainda pode avaliar, com a data limite, e mostrar a nota nas já avaliadas. "Avaliar" abre um diálogo com cinco estrelas e o comentário opcional; o envio só é possível com uma nota escolhida. A recusa aparece no diálogo, sem fechá-lo, e o sucesso atualiza a lista.

#### Scenario: Avaliar pela tela
- **GIVEN** Ana tem uma reserva concluída ontem, ainda não avaliada
- **WHEN** Ana abre "Minhas reservas", escolhe "Avaliar", marca 4 estrelas e envia
- **THEN** a página informa que a avaliação foi registrada e a reserva passa a mostrar a nota 4, sem "Avaliar"

#### Scenario: Sem nota escolhida
- **WHEN** Ana abre o diálogo de avaliação e não marca nenhuma estrela
- **THEN** o envio fica indisponível

#### Scenario: Reserva fora do prazo
- **GIVEN** a reserva concluída de Ana terminou há mais tempo que o prazo de avaliação
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a reserva não oferece "Avaliar"

#### Scenario: Recusa no diálogo
- **GIVEN** o admin reduziu o prazo de avaliação depois que Ana abriu "Minhas reservas"
- **WHEN** Ana envia a avaliação de uma reserva que saiu do prazo
- **THEN** o diálogo mostra a recusa de prazo encerrado, sem fechar
