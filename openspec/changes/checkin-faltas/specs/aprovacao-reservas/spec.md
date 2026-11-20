## MODIFIED Requirements

### Requirement: Filtros de situação e período da listagem
O filtro de situação DEVE (MUST) aceitar pendentes (padrão), confirmadas, concluídas, não compareceu, recusadas, expiradas, canceladas ou todas, e recusar qualquer outro valor. As situações vencidas valem pela situação efetiva, gravadas ou não: expiradas, não compareceu e concluídas. O período DEVE aceitar datas AAAA-MM-DD existentes, com a data final igual ou posterior à inicial, e recusar o resto. As pendentes vêm da mais próxima para a mais distante; as demais situações, inclusive todas, da mais recente para a mais antiga.

#### Scenario: Situação inválida
- **WHEN** Rui filtra a situação "ARQUIVADA"
- **THEN** o sistema recusa informando que a situação é inválida

#### Scenario: Período invertido
- **WHEN** Rui filtra de 2026-11-20 a 2026-11-10
- **THEN** o sistema recusa informando que a data final deve ser igual ou posterior à inicial

#### Scenario: Reserva noturna no período
- **GIVEN** "LAB-01" tem uma reserva de quarta-feira das 21h00 às 22h00 em São Paulo, que em UTC já é quinta-feira
- **WHEN** Rui filtra o período só de quarta-feira, com a situação todas
- **THEN** a reserva aparece

#### Scenario: Não compareceu antes da gravação
- **GIVEN** a janela da reserva `CONFIRMADA` de Ana em "LAB-01" fechou às 14h15 sem check-in, ainda sem gravação
- **WHEN** Rui filtra as reservas de "Paulista" com a situação não compareceu, às 14h30
- **THEN** a reserva de Ana aparece
- **AND** ela não aparece quando Rui filtra as confirmadas

#### Scenario: Concluídas
- **GIVEN** Ana fez check-in da reserva das 14h00 às 15h00 em "LAB-01"
- **WHEN** Rui filtra as concluídas de "Paulista" às 15h30
- **THEN** a reserva de Ana aparece, com o check-in

### Requirement: Dados de cada reserva da unidade
Cada reserva listada DEVE (MUST) trazer: id; dono (nome, e-mail institucional e papel no momento da criação, pelo nível de prioridade); espaço (nome e código), unidade e tipo; data e horas de início e fim em America/Sao_Paulo; situação efetiva; instante de criação; na decisão, quem decidiu, quando e o motivo da recusa; no cancelamento, o motivo e quem cancelou; e o instante do check-in, quando houver.

#### Scenario: Pendente com o dono identificado
- **GIVEN** Ana, aluna, tem uma reserva `PENDENTE` em "LAB-01"
- **WHEN** Rui lista as pendentes de "Paulista"
- **THEN** a reserva traz o nome e o e-mail de Ana, o papel aluno, "LAB-01", a data e o horário em São Paulo

#### Scenario: Recusada com a decisão
- **GIVEN** Rui recusou uma reserva com o motivo "Laboratório em manutenção"
- **WHEN** o admin filtra as recusadas de "Paulista"
- **THEN** a reserva traz Rui como quem decidiu, o instante e o motivo

#### Scenario: Confirmada com check-in
- **GIVEN** Ana fez check-in às 13h55 da reserva `CONFIRMADA` das 14h00 em "LAB-01"
- **WHEN** Rui filtra as confirmadas de "Paulista" às 14h10
- **THEN** a reserva traz o check-in às 13h55

#### Scenario: Cancelada tardiamente
- **GIVEN** Ana cancelou tardiamente a reserva dela em "LAB-01"
- **WHEN** Rui filtra as canceladas de "Paulista"
- **THEN** a reserva traz o motivo de cancelamento tardio e Ana como quem cancelou
