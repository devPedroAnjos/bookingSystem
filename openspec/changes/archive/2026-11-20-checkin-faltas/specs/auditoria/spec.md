## ADDED Requirements

### Requirement: Comparecimento é auditado
O check-in DEVE (MUST) gerar um registro `CHECK_IN` com o dono como ator e o instante do check-in nos dados depois. A gravação do não comparecimento e da conclusão DEVE gerar um `MARCAR_NAO_COMPARECEU` ou um `CONCLUIR_RESERVA`, com ator vazio, `CONFIRMADA` nos dados antes e, nos dados depois, a nova situação e o instante real. Todos têm a entidade `reserva` e a unidade atual do espaço. Recusas e consultas NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Check-in auditado
- **WHEN** Ana faz check-in às 13h55 da reserva em "BIB-01" de "Paulista"
- **THEN** existe um registro `CHECK_IN` com Ana como ator, a unidade "Paulista" e 13h55 nos dados depois

#### Scenario: Não comparecimento auditado pelo sistema
- **GIVEN** a janela da reserva de Ana fechou às 14h15 sem check-in
- **WHEN** uma operação grava os vencimentos às 15h00
- **THEN** existe um registro `MARCAR_NAO_COMPARECEU` com ator vazio e 14h15 como instante do não comparecimento

#### Scenario: Conclusão auditada pelo sistema
- **GIVEN** Ana fez check-in da reserva das 14h00 às 15h00
- **WHEN** uma operação grava os vencimentos às 16h00
- **THEN** existe um registro `CONCLUIR_RESERVA` com ator vazio e 15h00 como instante da conclusão

#### Scenario: Check-in recusado não é auditado
- **WHEN** Ana tenta fazer check-in fora da janela
- **THEN** nenhum registro `CHECK_IN` é gerado, e só podem existir os registros dos vencimentos já devidos que a operação gravou antes

### Requirement: Faltas e penalidades são auditadas
Cada ação abaixo DEVE (MUST) gerar um registro junto com a gravação. O cancelamento tardio gera um `CANCELAR_RESERVA` com o motivo `USUARIO_TARDIO` e o dono como ator. Cada falta gera um `REGISTRAR_FALTA`, e cada penalidade gerada gera um `APLICAR_PENALIDADE`. O encerramento de entradas de fila por penalidade gera um `ENCERRAR_FILA` com ator vazio e o motivo `PENALIDADE`. Consultas, o pedido de confirmação do cancelamento tardio e recusas NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Cancelamento tardio auditado
- **WHEN** Ana cancela tardiamente a reserva em "BIB-01" de "Paulista", confirmando a falta
- **THEN** existem um registro `CANCELAR_RESERVA` com Ana como ator, a unidade "Paulista" e o motivo `USUARIO_TARDIO`, e um registro `REGISTRAR_FALTA` com Ana como ator e o tipo `CANCELAMENTO_TARDIO`

#### Scenario: Pedido de confirmação sem registro
- **WHEN** Ana pede o cancelamento tardio sem confirmar a falta
- **THEN** nenhum registro `CANCELAR_RESERVA` nem `REGISTRAR_FALTA` dessa reserva é gerado, e só podem existir os registros dos vencimentos já devidos que a operação gravou antes

#### Scenario: Penalidade aplicada pelo sistema
- **GIVEN** Ana tinha uma falta sem penalidade
- **WHEN** a segunda falta de Ana, de não comparecimento, é gravada
- **THEN** existem um registro `REGISTRAR_FALTA` com ator vazio e o tipo `NAO_COMPARECIMENTO`, e um registro `APLICAR_PENALIDADE` com ator vazio, o início, o fim e as faltas vinculadas nos dados depois

#### Scenario: Entrada encerrada por penalidade
- **GIVEN** Ana aguarda na fila de "BIB-01"
- **WHEN** Ana recebe uma penalidade em vigor
- **THEN** existe um registro `ENCERRAR_FILA` com ator vazio e o motivo `PENALIDADE`

### Requirement: Cumprimento de penalidade é auditado
A gravação de uma penalidade como `CUMPRIDA` DEVE (MUST) gerar, junto com ela, um registro `CUMPRIR_PENALIDADE` com a entidade `penalidade`, ator vazio (ação do sistema), sem unidade, `ATIVA` nos dados antes e, nos dados depois, `CUMPRIDA` e o fim da penalidade como instante real.

#### Scenario: Cumprimento auditado pelo sistema
- **GIVEN** a penalidade de Ana terminou em 17/12 às 14h15
- **WHEN** uma operação grava os vencimentos em 18/12
- **THEN** existe um registro `CUMPRIR_PENALIDADE` com ator vazio e 17/12 às 14h15 como instante do fim

### Requirement: Anulação de penalidade é auditada
A anulação DEVE (MUST) gerar, junto com ela, um registro `ANULAR_PENALIDADE` com a entidade `penalidade`, o admin como ator, sem unidade, `ATIVA` nos dados antes e, nos dados depois, `ANULADA`, o parecer e as penalidades antecipadas, com o início e o fim antigos e novos de cada uma. Tentativas recusadas e a listagem de penalidades NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Anulação auditada com a antecipação
- **GIVEN** Ana tem uma penalidade em vigor e outra encadeada depois dela
- **WHEN** o admin anula a primeira com o parecer "Falha do sistema"
- **THEN** existe um registro `ANULAR_PENALIDADE` com o admin como ator, o parecer e a encadeada com o início e o fim antes e depois da antecipação

#### Scenario: Anulação recusada não é auditada
- **WHEN** o admin tenta anular uma penalidade cumprida
- **THEN** nenhum registro de auditoria é gerado
