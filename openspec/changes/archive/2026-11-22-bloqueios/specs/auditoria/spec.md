## ADDED Requirements

### Requirement: Bloqueios são auditados
A criação de bloqueio DEVE (MUST) gerar um registro `CRIAR_BLOQUEIO`, e a remoção um `REMOVER_BLOQUEIO`, com a entidade `bloqueio`, quem agiu como ator e a unidade do espaço. Cada reserva cancelada pelo bloqueio gera um `CANCELAR_RESERVA` com o motivo `BLOQUEIO` e o bloqueio nos dados depois, e cada entrada encerrada gera um `ENCERRAR_FILA` com o motivo `BLOQUEIO`. Recusas e a listagem NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Criação auditada com os cancelamentos
- **GIVEN** "LAB-01", de "Paulista", tem uma reserva de Ana e uma entrada de fila de Bia no período
- **WHEN** Rui bloqueia "LAB-01"
- **THEN** existem um registro `CRIAR_BLOQUEIO` com Rui como ator, a unidade "Paulista", o espaço, o tipo, o motivo, o início e o fim nos dados depois
- **AND** um `CANCELAR_RESERVA` da reserva de Ana com Rui como ator, o motivo `BLOQUEIO` e o bloqueio
- **AND** um `ENCERRAR_FILA` da entrada de Bia com o motivo `BLOQUEIO`

#### Scenario: Remoção auditada
- **WHEN** o admin remove um bloqueio de "LAB-01"
- **THEN** existe um registro `REMOVER_BLOQUEIO` com o admin como ator, `ATIVO` nos dados antes e `REMOVIDO` nos dados depois

#### Scenario: Recusa não auditada
- **WHEN** Rui tenta bloquear um período com reserva em andamento
- **THEN** nenhum registro `CRIAR_BLOQUEIO`, `CANCELAR_RESERVA` nem `ENCERRAR_FILA` é gerado por essa tentativa, e só podem existir os registros dos vencimentos já devidos que a operação gravou antes
