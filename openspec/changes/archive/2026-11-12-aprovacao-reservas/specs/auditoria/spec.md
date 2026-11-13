## ADDED Requirements

### Requirement: Decisão de reservas é auditada
A aprovação e a recusa DEVEM (MUST) gerar, junto com a decisão, um registro `APROVAR_RESERVA` ou `RECUSAR_RESERVA`, com quem decidiu como ator, a unidade atual do espaço, `PENDENTE` nos dados antes e, nos dados depois, a nova situação e, na recusa, o motivo. Tentativas recusadas e a listagem de reservas da unidade NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Aprovação auditada
- **WHEN** Rui aprova a reserva pendente de Ana em "LAB-01" de "Paulista"
- **THEN** existe um registro `APROVAR_RESERVA` com Rui como ator, a unidade "Paulista", `PENDENTE` nos dados antes e `CONFIRMADA` nos dados depois

#### Scenario: Recusa auditada com o motivo
- **WHEN** Rui recusa a reserva pendente de Ana com o motivo "Laboratório em manutenção"
- **THEN** existe um registro `RECUSAR_RESERVA` com Rui como ator e, nos dados depois, `RECUSADA` e o motivo

#### Scenario: Decisão recusada não é auditada
- **WHEN** Rui tenta aprovar uma reserva cujo início já passou
- **THEN** nenhum registro `APROVAR_RESERVA` é gerado

#### Scenario: Listagem não é auditada
- **WHEN** Rui lista as reservas da unidade
- **THEN** nenhum registro de auditoria é gerado

### Requirement: Expiração de reservas é auditada
Cada reserva gravada como `EXPIRADA` DEVE (MUST) gerar, junto com a gravação, um registro `EXPIRAR_RESERVA` com ator vazio (ação do sistema), a unidade atual do espaço, `PENDENTE` nos dados antes e, nos dados depois, `EXPIRADA` e o instante em que a reserva venceu, que é o início dela.

#### Scenario: Expiração auditada pelo sistema
- **GIVEN** as reservas pendentes de Ana e de Bia começaram às 14h00 sem decisão
- **WHEN** Carlos cria uma reserva às 14h20
- **THEN** existem dois registros `EXPIRAR_RESERVA` com ator vazio, um para cada reserva, cada um com 14h00 como instante do vencimento
