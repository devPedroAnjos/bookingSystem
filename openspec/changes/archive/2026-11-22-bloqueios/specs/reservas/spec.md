## ADDED Requirements

### Requirement: Reserva não sobrepõe bloqueio
Uma nova reserva NÃO DEVE (MUST NOT) se sobrepor, no mesmo espaço, a um bloqueio `ATIVO` (capability `bloqueios`). O pedido sobreposto DEVE ser recusado informando que o espaço está bloqueado no período, com o tipo do bloqueio, antes da verificação de conflito e de deslocamento: um bloqueio nunca é deslocado. Intervalo encostado não é sobreposição, e bloqueio `REMOVIDO` não impede a reserva.

#### Scenario: Pedido sobreposto a bloqueio
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO` de 10/12 às 08h00 a 12/12 às 18h00
- **WHEN** Ana pede "LAB-01" em 11/12 das 10h00 às 11h00
- **THEN** o sistema recusa informando que o espaço está bloqueado no período, e nada é gravado

#### Scenario: Sobreposição parcial
- **GIVEN** o mesmo bloqueio
- **WHEN** Ana pede "LAB-01" em 12/12 das 17h30 às 18h30
- **THEN** o sistema recusa informando que o espaço está bloqueado no período

#### Scenario: Intervalo encostado
- **GIVEN** o mesmo bloqueio
- **WHEN** Ana pede "LAB-01" em 12/12 das 18h00 às 19h00
- **THEN** o bloqueio não impede a reserva

#### Scenario: Bloqueio não é deslocado
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO` em 11/12
- **WHEN** o professor Carlos, que poderia deslocar reservas de alunos, pede "LAB-01" em 11/12 confirmando o deslocamento
- **THEN** o sistema recusa informando que o espaço está bloqueado no período, e nenhuma reserva é deslocada

#### Scenario: Bloqueio removido
- **GIVEN** o bloqueio de "LAB-01" em 11/12 foi removido
- **WHEN** Ana pede "LAB-01" em 11/12 das 10h00 às 11h00, sem outra ocupação
- **THEN** o bloqueio não impede a reserva
