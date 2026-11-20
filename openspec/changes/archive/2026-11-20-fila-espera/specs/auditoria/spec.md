## ADDED Requirements

### Requirement: Ações do usuário na fila são auditadas
Entrar na fila, confirmar a vaga retida e desistir DEVEM (MUST) gerar, junto com a ação, um registro `ENTRAR_FILA`, `CONFIRMAR_FILA` ou `DESISTIR_FILA`, com a entidade `entrada_fila`, o dono como ator, a unidade atual do espaço, a situação anterior nos dados antes e a nova nos dados depois; na confirmação, também a reserva gerada, que tem o próprio `CRIAR_RESERVA`. Tentativas recusadas e consultas NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Entrada auditada
- **WHEN** Ana entra na fila de "BIB-01" de "Paulista"
- **THEN** existe um registro `ENTRAR_FILA` com Ana como ator, a unidade "Paulista" e a entrada `AGUARDANDO` nos dados depois

#### Scenario: Confirmação auditada
- **WHEN** Ana confirma a vaga retida
- **THEN** existem um registro `CONFIRMAR_FILA` com Ana como ator e a reserva gerada nos dados depois, e um registro `CRIAR_RESERVA` dessa reserva

#### Scenario: Desistência auditada
- **WHEN** Ana desiste da entrada `AGUARDANDO`
- **THEN** existe um registro `DESISTIR_FILA` com Ana como ator, `AGUARDANDO` nos dados antes e `DESISTIU` nos dados depois

#### Scenario: Entrada recusada não é auditada
- **WHEN** Ana tenta entrar na fila de um intervalo livre
- **THEN** nenhum registro de auditoria é gerado

### Requirement: Transições automáticas da fila são auditadas
O aviso, a expiração e o encerramento de entradas DEVEM (MUST) gerar, junto com a gravação, um registro `NOTIFICAR_FILA` (com o prazo), `EXPIRAR_FILA` (com o instante do prazo) ou `ENCERRAR_FILA`, com a entidade `entrada_fila` e a unidade atual do espaço. O ator é vazio no aviso, na expiração e no encerramento pelo fechamento da fila, registrado com o motivo `CORTE` e o instante do fechamento; no encerramento por gestão ou inativação de conta, o ator é quem executou a ação, com o motivo.

#### Scenario: Aviso e expiração pelo sistema
- **GIVEN** a reserva da frente foi cancelada às 10h00 e Ana era a primeira da fila, com prazo para confirmar de 720 minutos e o corte do intervalo bem depois disso
- **WHEN** Ana não confirma e uma operação processa a fila às 22h30
- **THEN** existem um registro `NOTIFICAR_FILA` com ator vazio e prazo 22h00 nos dados depois, e um registro `EXPIRAR_FILA` com ator vazio e 22h00 como instante do vencimento

#### Scenario: Encerramento pelo fechamento
- **GIVEN** o corte da fila é de 120 minutos, o tempo mínimo útil é de 30 minutos e Ana aguarda na fila de "BIB-01" das 14h00
- **WHEN** uma operação processa a fila às 11h50
- **THEN** existe um registro `ENCERRAR_FILA` com ator vazio, o motivo `CORTE` e 11h30 como instante do fechamento

#### Scenario: Encerramento pela desativação
- **GIVEN** Ana aguarda na fila de "LAB-01"
- **WHEN** Rui desativa "LAB-01"
- **THEN** existem o registro `DESATIVAR_ESPACO` e um registro `ENCERRAR_FILA` com Rui como ator e o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Encerramento pela inativação da conta
- **GIVEN** Carlos aguarda na fila de "LAB-02"
- **WHEN** o admin inativa Carlos
- **THEN** existem o registro `INATIVAR_CONTA` e um registro `ENCERRAR_FILA` com o admin como ator e o motivo `CONTA_INATIVADA`
