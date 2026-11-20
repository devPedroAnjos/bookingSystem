## MODIFIED Requirements

### Requirement: Conflito de horário
Uma nova reserva NÃO DEVE (MUST NOT) se sobrepor, no mesmo espaço, a uma reserva `PENDENTE` ou `CONFIRMADA`, nem a uma vaga retida pela fila de espera (entrada `NOTIFICADA` no prazo, capability `fila-espera`), exceto a reserva gerada pela confirmação da própria entrada. Há sobreposição quando o início de cada uma é anterior ao fim da outra; sobreposição parcial também é conflito, e reservas que apenas se encostam (uma termina quando a outra começa) não conflitam. Uma reserva `PENDENTE` cujo início já chegou expirou (capability `aprovacao-reservas`) e não ocupa mais o horário, assim como a vaga retida cujo prazo já venceu. A verificação do conflito e a gravação DEVEM ser atômicas: requisições simultâneas NUNCA podem gerar ocupações sobrepostas. O conflito é recusado sem identificar quem ocupa o horário, exceto quando o solicitante pode deslocar todas as reservas conflitantes e confirma o deslocamento (requisito "Deslocamento por prioridade"); nesse caso, as conflitantes são canceladas e a nova reserva é gravada na mesma operação atômica. A vaga retida nunca é deslocável: com ela no intervalo, o pedido é recusado como horário ocupado, e quem não pode deslocar pode entrar na fila (capability `fila-espera`).

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

#### Scenario: Vaga retida ocupa o horário
- **GIVEN** a vaga de "BIB-01" das 14h00 às 15h00 de depois de amanhã está retida para Ana, no prazo
- **WHEN** Bruno, aluno, tenta reservar "BIB-01" das 14h30 às 15h30 do mesmo dia
- **THEN** o sistema recusa informando que o horário está ocupado, sem dizer quem retém a vaga

#### Scenario: Vaga retida não é deslocável
- **GIVEN** a vaga de "LAB-01" das 14h00 às 15h00 de depois de amanhã está retida para Ana, aluna, e o pedido de Rui, coordenador, nasceria confirmado
- **WHEN** Rui pede o mesmo intervalo e confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado, nada é cancelado e a vaga continua retida para Ana

#### Scenario: Reserva e vaga retida no mesmo pedido
- **GIVEN** Bruno, aluno, tem uma reserva em "LAB-01" das 14h00 às 15h00 de depois de amanhã, e a vaga das 15h00 às 16h00 está retida para Ana, aluna
- **WHEN** Carlos, professor, pede das 14h30 às 15h30 e confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Bruno não muda

#### Scenario: Vaga retida vencida não ocupa
- **GIVEN** o prazo da vaga retida para Ana em "BIB-01" das 14h00 às 15h00 venceu, e ninguém mais está na fila
- **WHEN** Bruno reserva "BIB-01" das 14h00 às 15h00
- **THEN** a reserva de Bruno é criada e a entrada de Ana fica `EXPIRADA`

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
