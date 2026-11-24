## ADDED Requirements

### Requirement: Espaço bloqueado na busca
Quando data e horário são informados, cada espaço do resultado DEVE (MUST) indicar se está bloqueado: há bloqueio `ATIVO` sobreposto ao intervalo pedido (capability `bloqueios`). O espaço bloqueado aparece ocupado e "Bloqueado", não deslocável, com 0 reservas a deslocar e sem a possibilidade de entrar na fila, e a tela não oferece "Reservar", "Deslocar e reservar" nem "Entrar na fila" para ele. A busca NÃO DEVE (MUST NOT) mostrar o motivo nem quem criou o bloqueio.

#### Scenario: Espaço bloqueado no horário pedido
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO` de 10/12 a 12/12, e "LAB-02" está livre
- **WHEN** um professor busca "Laboratório" em 11/12 das 10h00 às 11h00
- **THEN** "LAB-01" aparece "Bloqueado", não deslocável e sem fila, sem o motivo
- **AND** "LAB-02" aparece livre

#### Scenario: Intervalo encostado ao bloqueio
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO` até 12/12 às 18h00 e nenhuma reserva depois disso
- **WHEN** um professor busca "LAB-01" em 12/12 das 18h00 às 19h00
- **THEN** "LAB-01" aparece livre, sem indicação de bloqueio

#### Scenario: Busca sem horário
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO`
- **WHEN** alguém busca sem informar data e horário
- **THEN** "LAB-01" aparece sem indicação de bloqueio, como os demais espaços sem horário pedido

#### Scenario: Tela mostra o bloqueio
- **WHEN** a busca pela tela devolve "LAB-01" bloqueado no horário pedido
- **THEN** a página mostra "Bloqueado" em "LAB-01" e não oferece nenhuma ação para ele
