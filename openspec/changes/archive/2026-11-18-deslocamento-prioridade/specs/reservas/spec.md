## MODIFIED Requirements

### Requirement: Conflito de horário
Uma nova reserva NÃO DEVE (MUST NOT) se sobrepor, no mesmo espaço, a uma reserva `PENDENTE` ou `CONFIRMADA`. Há sobreposição quando o início de cada uma é anterior ao fim da outra; sobreposição parcial também é conflito, e reservas que apenas se encostam (uma termina quando a outra começa) não conflitam. Uma reserva `PENDENTE` cujo início já chegou expirou (capability `aprovacao-reservas`) e não ocupa mais o horário. A verificação do conflito e a gravação DEVEM ser atômicas: requisições simultâneas NUNCA podem gerar reservas sobrepostas. O conflito é recusado sem identificar quem ocupa o horário, exceto quando o solicitante pode deslocar todas as reservas conflitantes e confirma o deslocamento (requisito "Deslocamento por prioridade"); nesse caso, as conflitantes são canceladas e a nova reserva é gravada na mesma operação atômica. A fila de espera é de uma change posterior.

#### Scenario: Sobreposição parcial
- **GIVEN** "LAB-01" tem uma reserva `CONFIRMADA` das 14h00 às 16h00
- **WHEN** Carlos tenta reservar "LAB-01" das 15h00 às 17h00 do mesmo dia
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Reservas encostadas
- **GIVEN** "LAB-01" tem uma reserva das 14h00 às 16h00
- **WHEN** Carlos reserva "LAB-01" das 16h00 às 17h00 do mesmo dia
- **THEN** a reserva é criada

#### Scenario: Pendente ocupa o horário
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" das 14h00 às 15h00
- **WHEN** outro aluno tenta reservar "LAB-01" das 14h30 às 15h30
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Pendente vencida não ocupa
- **GIVEN** a antecedência mínima de "Laboratório" é de 0 minutos, e Ana tem uma reserva `PENDENTE` em "LAB-01" das 14h00 às 16h00, sem decisão, e são 14h20
- **WHEN** Carlos reserva "LAB-01" das 14h30 às 15h30
- **THEN** a reserva de Carlos é criada e a de Ana fica `EXPIRADA`

#### Scenario: Cancelada não ocupa
- **GIVEN** a reserva das 14h00 às 15h00 em "LAB-01" foi cancelada
- **WHEN** Carlos reserva "LAB-01" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Recusada não ocupa
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" das 14h00 às 15h00 foi recusada
- **WHEN** Carlos reserva "LAB-01" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Prioridade maior ainda não desloca
- **GIVEN** Ana, aluna, tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00 da próxima semana
- **WHEN** Carlos, professor, pede o mesmo intervalo sem confirmar o deslocamento
- **THEN** o sistema não grava nada e pede a confirmação do deslocamento, sem dizer de quem é a reserva
- **AND** a reserva de Ana não muda

#### Scenario: Mesmo nível não desloca
- **GIVEN** Carlos, professor, tem uma reserva `CONFIRMADA` em "LAB-01" das 14h00 às 15h00 da próxima semana
- **WHEN** Paula, professora, tenta reservar o mesmo intervalo, com ou sem confirmar deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado, sem oferecer deslocamento, e a reserva de Carlos não muda

#### Scenario: Mesmo horário em outro espaço
- **GIVEN** "LAB-01" está ocupado das 14h00 às 15h00
- **WHEN** Carlos reserva "LAB-02" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Requisições simultâneas
- **WHEN** Ana e Carlos enviam ao mesmo tempo reservas de "LAB-01" para intervalos sobrepostos
- **THEN** só uma reserva é criada e o outro recebe a recusa de horário ocupado ou o pedido de confirmação do deslocamento, sem que nada seja cancelado sem confirmação

#### Scenario: Reserva e desativação simultâneas
- **WHEN** Carlos reserva um horário futuro de "LAB-01" no mesmo instante em que Rui desativa "LAB-01"
- **THEN** ou a reserva não é criada por espaço indisponível, ou ela é criada e logo cancelada pela desativação; nunca fica uma reserva ativa em espaço desativado

## ADDED Requirements

### Requirement: Deslocamento por prioridade
Um pedido que conflita com reservas ativas do espaço DEVE (MUST) poder deslocá-las quando, ao mesmo tempo:
- todas as conflitantes têm nível de prioridade, gravado na criação delas, estritamente menor que o do papel atual do solicitante;
- a nova reserva e cada conflitante começam a mais de `prazo_deslocamento_minutos` de agora;
- a nova reserva nasceria `CONFIRMADA`.

Se qualquer condição falhar, o pedido é recusado como horário ocupado.

#### Scenario: Professor desloca aluno
- **GIVEN** Ana, aluna, tem uma reserva aprovada, `CONFIRMADA`, em "LAB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma o deslocamento
- **THEN** a reserva de Carlos é criada `CONFIRMADA` e a de Ana fica `CANCELADA` com o motivo `PRIORIDADE`

#### Scenario: Coordenador desloca professor
- **GIVEN** Carlos, professor, tem uma reserva aprovada, `CONFIRMADA`, em "AUD-01" de daqui a 3 dias
- **WHEN** Rui, coordenador de outra unidade, reserva um intervalo sobreposto de "AUD-01" e confirma
- **THEN** a reserva de Rui é criada e a de Carlos é deslocada

#### Scenario: Pendente de nível menor é deslocável
- **GIVEN** Ana, aluna, tem uma reserva `PENDENTE` em "LAB-01" para depois de amanhã
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma
- **THEN** a pendente de Ana fica `CANCELADA` com o motivo `PRIORIDADE` e a reserva de Carlos é criada

#### Scenario: Nível gravado na criação
- **GIVEN** Ana criou uma reserva em "LAB-01" quando era aluna e depois foi promovida a professora
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma
- **THEN** a reserva de Ana é deslocada, porque foi criada com nível 1

#### Scenario: Conflitantes com níveis mistos
- **GIVEN** "LAB-01" tem uma reserva de Ana, aluna, das 14h00 às 15h00 e uma de Paula, professora, das 15h00 às 16h00
- **WHEN** Carlos, professor, tenta reservar das 14h30 às 15h30 e confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado e nenhuma das duas reservas muda

#### Scenario: Empate no nível 3
- **GIVEN** Rui, coordenador, tem uma reserva em "AUD-01" para daqui a 3 dias
- **WHEN** o admin, ou outro coordenador, tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Rui não muda

#### Scenario: Fora das regras antes do deslocamento
- **GIVEN** Ana, aluna, tem uma reserva em "BIB-01" das 21h40 às 22h40 de depois de amanhã
- **WHEN** Carlos, professor, tenta reservar "BIB-01" das 22h00 às 22h50 e confirma
- **THEN** o sistema recusa com o motivo de fim depois do fechamento e a reserva de Ana não muda

#### Scenario: Aluno nunca desloca
- **GIVEN** Bruno, aluno, tem uma reserva em "BIB-01" para depois de amanhã
- **WHEN** Ana, aluna, tenta reservar o mesmo intervalo
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Prazo exatamente no limite
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "LAB-01" às 14h00 e são 12h00
- **WHEN** Carlos, professor, tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana não muda

#### Scenario: Um minuto além do prazo
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "LAB-01" às 14h00 e são 11h59
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma
- **THEN** a reserva de Ana é deslocada e a de Carlos é criada

#### Scenario: Reserva em andamento não é deslocada
- **GIVEN** Ana, aluna, está usando "LAB-01" das 08h00 às 12h00, com a reserva aprovada, e são 08h30
- **WHEN** Carlos, professor, tenta reservar "LAB-01" das 11h00 às 12h00 e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana continua ativa

#### Scenario: Nova reserva perto demais
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" das 11h30 às 12h00 e são 09h00
- **WHEN** Carlos, professor, tenta reservar "LAB-01" das 10h00 às 12h00 e confirma
- **THEN** o sistema recusa informando que o horário está ocupado, porque a reserva de Carlos começaria a menos do prazo

#### Scenario: Nova reserva exatamente no limite
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "BIB-01" das 15h00 às 16h00 e são 12h00
- **WHEN** Carlos, professor, tenta reservar "BIB-01" das 14h00 às 15h30 e confirma
- **THEN** o sistema recusa informando que o horário está ocupado, porque a reserva de Carlos começa exatamente no prazo

#### Scenario: Nova reserva um minuto além do limite
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "BIB-01" das 15h00 às 16h00 e são 11h59
- **WHEN** Carlos, professor, reserva "BIB-01" das 14h00 às 15h30 e confirma
- **THEN** a reserva de Ana é deslocada e a de Carlos é criada

#### Scenario: Nova reserva exigiria aprovação
- **GIVEN** o admin configurou "Laboratório" para exigir aprovação do professor, e Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos, professor, tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana não muda

#### Scenario: Limite de ativas do solicitante
- **GIVEN** Carlos, professor, já tem o máximo de reservas ativas de "Laboratório", e Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando o limite de reservas ativas e a reserva de Ana não muda

#### Scenario: Pendente vencida não entra no deslocamento
- **GIVEN** Ana, aluna, tem uma reserva `PENDENTE` vencida em "LAB-01", e Bruno, aluno, tem uma reserva `CONFIRMADA` sobreposta ao mesmo pedido
- **WHEN** Carlos, professor, reserva e confirma
- **THEN** só a reserva de Bruno é deslocada, e a de Ana fica `EXPIRADA`

### Requirement: Confirmação do deslocamento
Quando o pedido pode deslocar reservas e o solicitante não confirmou o deslocamento, o sistema NÃO DEVE (MUST NOT) gravar nada e DEVE responder, como resultado distinto de uma recusa, que o pedido deslocaria N reservas, sem identificar donos nem horários delas. Com a confirmação, o sistema DEVE recalcular tudo, cancelar as conflitantes e gravar a nova reserva na mesma operação atômica. A confirmação sem conflito cria a reserva normalmente.

#### Scenario: Pedido sem confirmação
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos, professor, pede o mesmo intervalo sem confirmar o deslocamento
- **THEN** o sistema responde que o pedido deslocaria 1 reserva e pede confirmação, sem dizer de quem
- **AND** nada é gravado e nenhum registro de auditoria é gerado

#### Scenario: Duas reservas deslocadas
- **GIVEN** Ana e Bruno, alunos, têm reservas em "LAB-01" das 14h00 às 15h00 e das 15h00 às 16h00 de depois de amanhã
- **WHEN** Carlos, professor, pede das 14h00 às 16h00 e confirma
- **THEN** as duas reservas ficam `CANCELADA` com o motivo `PRIORIDADE` e a de Carlos é criada

#### Scenario: Conflito sumiu antes da confirmação
- **GIVEN** Carlos recebeu o pedido de confirmação, e Ana cancelou a reserva dela em seguida
- **WHEN** Carlos confirma o deslocamento
- **THEN** a reserva de Carlos é criada e nenhuma reserva é cancelada por prioridade

#### Scenario: Conflito mudou antes da confirmação
- **GIVEN** Carlos recebeu o pedido de confirmação para deslocar a reserva de Ana, e Paula, professora, reservou em seguida outro trecho sobreposto ao pedido de Carlos
- **WHEN** Carlos confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado e nenhuma reserva é cancelada

#### Scenario: Deslocamentos simultâneos
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos e Paula, professores, confirmam ao mesmo tempo o deslocamento para o mesmo intervalo
- **THEN** só uma das duas reservas é criada, a de Ana é cancelada uma única vez e o outro recebe a recusa de horário ocupado

#### Scenario: Deslocamento e cancelamento pelo dono simultâneos
- **WHEN** Carlos confirma o deslocamento da reserva de Ana no mesmo instante em que Ana a cancela
- **THEN** a reserva de Ana termina `CANCELADA` uma única vez, com o motivo da operação que chegou primeiro, e a de Carlos é criada

### Requirement: Reserva deslocada
A reserva deslocada DEVE (MUST) ser cancelada inteira, mesmo quando a sobreposição é parcial, com o motivo `PRIORIDADE`, o solicitante como autor do cancelamento, o instante, a referência à reserva que a deslocou e sem falta. O dono vê em "Minhas reservas" o motivo, sem o nome de quem deslocou. Quem desloca não vê de quem eram as reservas.

#### Scenario: Sobreposição parcial cancela a reserva inteira
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" das 09h00 às 12h00 de depois de amanhã
- **WHEN** Carlos, professor, reserva das 10h00 às 11h00 e confirma
- **THEN** a reserva de Ana fica `CANCELADA` inteira e o horário das 09h00 às 10h00 e das 11h00 às 12h00 fica livre

#### Scenario: Deslocada em minhas reservas
- **GIVEN** a reserva de Ana foi deslocada por Carlos
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece `CANCELADA`, no histórico, com o motivo de substituição por reserva de prioridade maior e sem o nome de Carlos

#### Scenario: Deslocamento não gera falta
- **WHEN** a reserva de Ana é deslocada a 3 horas do início
- **THEN** nenhuma falta é registrada para Ana

#### Scenario: Gestão vê quem deslocou
- **GIVEN** a reserva de Ana em "LAB-01" foi deslocada por Carlos
- **WHEN** Rui, coordenador da unidade de "LAB-01", lista as reservas canceladas da unidade
- **THEN** a reserva de Ana aparece com o motivo `PRIORIDADE` e Carlos como quem cancelou
