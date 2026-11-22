# Especificação: Comparecimento

## Purpose
Registrar se o dono de uma reserva confirmada de fato usou o espaço: check-in numa janela em torno do início, não comparecimento quando a janela fecha sem check-in e conclusão no fim, com os efeitos dessas situações sobre a ocupação do horário e a gravação delas sem tarefa agendada.

## Requirements

### Requirement: Check-in pelo próprio usuário
O dono de uma reserva `CONFIRMADA` DEVE (MUST) poder fazer check-in dela durante a janela de check-in. O check-in registra o instante, uma única vez. O sistema DEVE recusar o check-in, sem alterar a reserva, quando a reserva não está `CONFIRMADA`, quando o instante está fora da janela ou quando o check-in já foi feito. Reserva de outra pessoa, ou inexistente, DEVE ser recusada com a mesma mensagem de reserva não encontrada.

#### Scenario: Check-in no início
- **GIVEN** Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00 e a janela é de 15 minutos antes até 15 minutos depois
- **WHEN** Ana faz check-in às 14h00
- **THEN** o check-in é registrado às 14h00 e a reserva continua `CONFIRMADA`

#### Scenario: Pendente não tem check-in
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" às 14h00, ainda sem decisão
- **WHEN** Ana tenta fazer check-in às 13h50
- **THEN** o sistema recusa informando que a reserva aguarda aprovação e a reserva não muda

#### Scenario: Aprovada a minutos do início
- **GIVEN** Rui aprovou às 13h55 a reserva `PENDENTE` de Ana em "LAB-01" às 14h00
- **WHEN** Ana faz check-in às 13h58
- **THEN** o check-in é registrado

#### Scenario: Check-in repetido
- **GIVEN** Ana fez check-in da reserva das 14h00 às 13h50
- **WHEN** Ana tenta fazer check-in de novo às 13h55
- **THEN** o sistema recusa informando que o check-in já foi feito, e o instante registrado continua 13h50

#### Scenario: Reserva cancelada
- **GIVEN** a reserva de Ana foi cancelada
- **WHEN** Ana tenta fazer check-in
- **THEN** o sistema recusa informando que a reserva não está confirmada

#### Scenario: Reserva de outra pessoa
- **WHEN** Carlos tenta fazer check-in da reserva de Ana
- **THEN** o sistema recusa informando que a reserva não foi encontrada, a mesma resposta de uma reserva inexistente, e nada muda

#### Scenario: Sem autenticação
- **WHEN** alguém sem sessão tenta fazer check-in
- **THEN** o sistema responde como não autenticado

### Requirement: Janela de check-in
A janela de check-in DEVE (MUST) ir de `checkin_antes_minutos` antes do início até `checkin_depois_minutos` depois do início, sem passar do fim da reserva, com os dois limites incluídos. Os parâmetros valem pelo valor atual no momento da verificação, e não pelo valor da criação da reserva. Os horários são avaliados em America/Sao_Paulo.

#### Scenario: Abertura exata
- **GIVEN** a reserva de Ana em "BIB-01" começa às 14h00 e a janela abre 15 minutos antes
- **WHEN** Ana faz check-in às 13h45
- **THEN** o check-in é registrado

#### Scenario: Antes da abertura
- **GIVEN** a reserva de Ana em "BIB-01" começa às 14h00 e a janela abre 15 minutos antes
- **WHEN** Ana tenta fazer check-in às 13h44
- **THEN** o sistema recusa informando que o check-in abre às 13h45

#### Scenario: Fechamento exato
- **GIVEN** a reserva de Ana em "BIB-01" vai das 14h00 às 15h00 e a janela fecha 15 minutos depois do início
- **WHEN** Ana faz check-in às 14h15
- **THEN** o check-in é registrado

#### Scenario: Depois do fechamento
- **GIVEN** a reserva de Ana em "BIB-01" vai das 14h00 às 15h00 e a janela fecha 15 minutos depois do início
- **WHEN** Ana tenta fazer check-in às 14h16
- **THEN** o sistema recusa informando que a janela de check-in terminou

#### Scenario: Reserva mais curta que a janela
- **GIVEN** o admin configurou um tipo com duração mínima de 10 minutos, e a reserva de Ana vai das 14h00 às 14h10, com a janela fechando 15 minutos depois do início
- **WHEN** Ana tenta fazer check-in às 14h12
- **THEN** o sistema recusa informando que a janela de check-in terminou, porque a janela fecha no fim da reserva, às 14h10

#### Scenario: Primeira reserva do dia
- **GIVEN** a reserva de Ana em "BIB-01" começa às 08h00, horário de abertura do tipo
- **WHEN** Ana faz check-in às 07h45
- **THEN** o check-in é registrado, porque a janela não depende do horário de funcionamento

#### Scenario: Última reserva do dia
- **GIVEN** a reserva de Ana em "BIB-01" vai das 22h00 às 22h40, horário de fechamento do tipo
- **WHEN** Ana faz check-in às 22h15
- **THEN** o check-in é registrado

#### Scenario: Parâmetro alterado depois da criação
- **GIVEN** Ana criou a reserva das 14h00 quando a janela abria 15 minutos antes, e o admin principal mudou o valor para 30 minutos
- **WHEN** Ana faz check-in às 13h35
- **THEN** o check-in é registrado

### Requirement: Não comparecimento
Uma reserva `CONFIRMADA` sem check-in DEVE (MUST) passar a `NAO_COMPARECEU` quando a janela de check-in fecha. O instante real do não comparecimento é o fechamento da janela. A situação vale em todas as consultas a partir desse instante, mesmo antes de ser gravada. Cada não comparecimento gera uma falta (capability `penalidades`).

#### Scenario: Janela fecha sem check-in
- **GIVEN** Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00, sem check-in, e a janela fecha às 14h15
- **WHEN** Ana abre "Minhas reservas" às 14h16
- **THEN** a reserva aparece como não compareceu

#### Scenario: Ainda dentro da janela
- **GIVEN** Ana tem uma reserva `CONFIRMADA` das 14h00 sem check-in
- **WHEN** Ana abre "Minhas reservas" às 14h15
- **THEN** a reserva aparece confirmada, com a possibilidade de fazer check-in

#### Scenario: Pendente expira sem falta
- **GIVEN** a reserva `PENDENTE` de Ana começou às 14h00 sem decisão
- **WHEN** a janela de check-in fecharia, às 14h15
- **THEN** a reserva é `EXPIRADA`, não `NAO_COMPARECEU`, e nenhuma falta é registrada

### Requirement: Conclusão da reserva
Uma reserva `CONFIRMADA` com check-in DEVE (MUST) passar a `CONCLUIDA` quando chega o fim dela. O instante real da conclusão é o fim. A situação vale em todas as consultas a partir desse instante, mesmo antes de ser gravada. A conclusão não gera falta.

#### Scenario: Reserva usada
- **GIVEN** Ana fez check-in da reserva das 14h00 às 15h00
- **WHEN** Ana abre "Minhas reservas" às 15h00
- **THEN** a reserva aparece concluída, no histórico

#### Scenario: Em uso antes do fim
- **GIVEN** Ana fez check-in da reserva das 14h00 às 15h00
- **WHEN** Ana abre "Minhas reservas" às 14h59
- **THEN** a reserva aparece confirmada, com o check-in feito

### Requirement: Horário liberado pelo não comparecimento
A reserva `NAO_COMPARECEU` NÃO DEVE (MUST NOT) ocupar o horário, mesmo antes do fim e antes da gravação. Ela não conta no conflito, na busca, no limite de reservas ativas nem como reserva em andamento das ações de gestão, e não é cancelada por essas ações nem pela inativação da conta. A reserva `CONFIRMADA` sem check-in ocupa o horário até a janela fechar.

#### Scenario: Horário livre depois da janela
- **GIVEN** a antecedência mínima de "Biblioteca" é de 0 minutos, Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 16h00 sem check-in, e são 14h20
- **WHEN** Carlos reserva "BIB-01" das 14h30 às 15h30
- **THEN** a reserva de Carlos é criada e a de Ana é `NAO_COMPARECEU`

#### Scenario: Sobreposição parcial depois da janela
- **GIVEN** a antecedência mínima de "Biblioteca" é de 0 minutos, Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00 sem check-in, e são 14h20
- **WHEN** Carlos reserva "BIB-01" das 14h40 às 15h40
- **THEN** a reserva de Carlos é criada, embora sobreponha parcialmente o horário da reserva de Ana

#### Scenario: Horário liberado não vai para a fila
- **GIVEN** Bruno aguardava na fila de "BIB-01" das 14h00 às 16h00, e Ana, dona da reserva desse intervalo, não fez check-in
- **WHEN** a janela de Ana fecha às 14h15
- **THEN** a entrada de Bruno já estava encerrada pelo fechamento da fila, antes do início, e o horário liberado fica livre para reserva direta

#### Scenario: Ocupado durante a janela
- **GIVEN** a antecedência mínima de "Biblioteca" é de 0 minutos, Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 16h00 sem check-in, e são 14h10
- **WHEN** Carlos tenta reservar "BIB-01" das 14h30 às 15h30
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Busca mostra livre
- **GIVEN** Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 16h00 sem check-in, e são 14h20
- **WHEN** Carlos busca "Biblioteca" para hoje das 14h30 às 15h30
- **THEN** "BIB-01" aparece livre

#### Scenario: Com check-in continua ocupado
- **GIVEN** Ana fez check-in da reserva das 14h00 às 16h00 em "BIB-01", e são 14h20
- **WHEN** Carlos tenta reservar "BIB-01" das 14h30 às 15h30
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Não conta no limite de ativas
- **GIVEN** "Biblioteca" permite 2 reservas ativas, Ana tem uma reserva futura de "Biblioteca" e outra das 14h00 às 16h00 de hoje, sem check-in, e são 14h20
- **WHEN** Ana faz uma nova reserva de "Biblioteca" para amanhã
- **THEN** a reserva é criada

#### Scenario: Não impede a desativação
- **GIVEN** Ana tem uma reserva `CONFIRMADA` em "LAB-01" das 14h00 às 16h00 sem check-in, e são 14h20
- **WHEN** Rui desativa "LAB-01"
- **THEN** "LAB-01" fica desativado sem recusa por reserva em andamento
- **AND** a reserva de Ana continua `NAO_COMPARECEU`, com a falta, e não é cancelada

#### Scenario: Em andamento com check-in impede a desativação
- **GIVEN** Ana fez check-in da reserva `CONFIRMADA` em "LAB-01" das 14h00 às 16h00, e são 14h20
- **WHEN** Rui tenta desativar "LAB-01"
- **THEN** o sistema recusa informando que há reserva em andamento até 16h00

#### Scenario: Check-in antes do início não impede o cancelamento automático
- **GIVEN** Ana fez check-in às 13h50 da reserva `CONFIRMADA` em "LAB-01" das 14h00
- **WHEN** Rui desativa "LAB-01" às 13h55
- **THEN** a reserva de Ana fica `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`, sem falta, porque ainda não começou

#### Scenario: Em andamento dentro da janela impede a desativação
- **GIVEN** Ana tem uma reserva `CONFIRMADA` em "LAB-01" das 14h00 às 16h00 sem check-in, e são 14h10
- **WHEN** Rui tenta desativar "LAB-01"
- **THEN** o sistema recusa informando que há reserva em andamento até 16h00

### Requirement: Reservas anteriores ao comparecimento
O check-in, o não comparecimento e a conclusão DEVEM (MUST) valer só para reservas que começam a partir do instante em que esta regra entrou em uso, registrado pelo backend na carga inicial. Reservas que começaram antes dele NÃO DEVEM (MUST NOT) virar `NAO_COMPARECEU` nem `CONCLUIDA`, nem gerar falta. Elas continuam `CONFIRMADA`, como antes, e deixam de ocupar o horário no fim.

#### Scenario: Reserva antiga sem falta
- **GIVEN** a regra entrou em uso em 21/11 às 10h00, e Carlos tinha uma reserva `CONFIRMADA` de 18/11 das 14h00 às 15h00, sem check-in
- **WHEN** qualquer operação grava os vencimentos depois de 21/11
- **THEN** a reserva de Carlos continua `CONFIRMADA` e nenhuma falta é registrada

#### Scenario: Reserva nova segue a regra
- **GIVEN** a regra entrou em uso em 21/11 às 10h00, e Ana tem uma reserva `CONFIRMADA` de 21/11 das 14h00 às 15h00
- **WHEN** a janela fecha às 14h15 sem check-in
- **THEN** a reserva de Ana fica `NAO_COMPARECEU` e gera falta

#### Scenario: Carga inicial repetida
- **GIVEN** a regra entrou em uso em 21/11 às 10h00
- **WHEN** a carga inicial é executada de novo em 25/11
- **THEN** o instante de início da regra continua 21/11 às 10h00

### Requirement: Gravação do comparecimento
As situações `NAO_COMPARECEU` e `CONCLUIDA` DEVEM (MUST) ser gravadas sem ação de pessoa alguma, com o instante real, nas mesmas operações que gravam a expiração das pendentes (capability `aprovacao-reservas`) e no check-in. As de um usuário DEVEM ser gravadas em ordem cronológica e por inteiro antes de gravar uma falta dele ou de verificar a penalidade dele.

#### Scenario: Gravada por outra operação
- **GIVEN** a janela da reserva de Ana fechou às 14h15 sem check-in e nada foi gravado desde então
- **WHEN** Carlos cria uma reserva às 14h40
- **THEN** a reserva de Ana fica `NAO_COMPARECEU`, com 14h15 como instante do não comparecimento, e a falta é registrada com esse instante

#### Scenario: Conclusão gravada depois
- **GIVEN** Ana fez check-in da reserva das 14h00 às 15h00 e nada foi gravado desde as 15h00
- **WHEN** Carlos cancela uma reserva às 16h00
- **THEN** a reserva de Ana fica `CONCLUIDA`, com 15h00 como instante da conclusão

#### Scenario: Faltas do usuário antes da penalidade
- **GIVEN** Ana não compareceu à reserva da manhã, ainda não gravada, e já tinha 1 falta nos últimos 30 dias
- **WHEN** Ana tenta criar uma reserva à tarde
- **THEN** o não comparecimento e a falta são gravados antes da verificação da penalidade, e a criação é recusada pela penalidade em vigor

#### Scenario: Check-in e vencimento simultâneos
- **GIVEN** a janela da reserva de Ana fecha às 14h15
- **WHEN** Ana envia o check-in perto das 14h15 e, no mesmo momento, outra operação grava os vencimentos
- **THEN** a reserva recebe uma única transição, avaliada no instante em que cada operação é atendida: ou o check-in é registrado e não há falta, ou ela fica `NAO_COMPARECEU` com a falta e o check-in é recusado
- **AND** nunca ficam registrados ao mesmo tempo o check-in e o não comparecimento
