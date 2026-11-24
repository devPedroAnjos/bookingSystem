## ADDED Requirements

### Requirement: Fila não entra em intervalo bloqueado
A entrada na fila DEVE (MUST) ser recusada quando o intervalo pedido se sobrepõe a um bloqueio `ATIVO` do espaço (capability `bloqueios`), informando que o espaço está bloqueado no período. A confirmação de uma vaga retida DEVE ser recusada pelo mesmo motivo, sem gravar a reserva. Intervalo encostado não é sobreposição.

#### Scenario: Entrada em intervalo bloqueado
- **GIVEN** "BIB-01" tem um bloqueio `ATIVO` de 10/12 a 12/12 e uma reserva de professor em 15/12 das 14h00 às 15h00
- **WHEN** Ana tenta entrar na fila de "BIB-01" em 11/12 das 14h00 às 15h00
- **THEN** o sistema recusa informando que o espaço está bloqueado no período, e nada é gravado

#### Scenario: Entrada fora do bloqueio
- **GIVEN** o mesmo bloqueio
- **WHEN** Ana entra na fila de "BIB-01" em 15/12 das 14h00 às 15h00
- **THEN** o bloqueio não impede a entrada

#### Scenario: Confirmação de vaga em período bloqueado
- **GIVEN** Ana tem a vaga retida de "BIB-01" em 11/12 das 14h00 às 15h00, e por algum motivo existe um bloqueio `ATIVO` sobreposto a ela
- **WHEN** Ana confirma a vaga
- **THEN** o sistema recusa informando que o espaço está bloqueado no período, e nenhuma reserva é gravada
