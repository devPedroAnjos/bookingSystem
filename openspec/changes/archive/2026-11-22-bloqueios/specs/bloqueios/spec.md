# Especificação: Bloqueios

## Purpose

Permitir que a gestão torne um espaço indisponível por um período (manutenção, evento ou feriado), cancelando sem penalidade as reservas e encerrando as filas afetadas, e impedindo novas ocupações no período enquanto o bloqueio estiver ativo.

## ADDED Requirements

### Requirement: Criar bloqueio
O coordenador de uma unidade e o admin DEVEM (MUST) poder bloquear um espaço ativo de unidade que gerem, informando o tipo (`MANUTENCAO`, `EVENTO` ou `FERIADO`), o motivo (de 1 a 500 caracteres) e o início e o fim, cada um com data (AAAA-MM-DD) e hora (HH:MM) em America/Sao_Paulo. O bloqueio nasce `ATIVO`, com quem o criou e o instante registrado pelo backend.

#### Scenario: Coordenador bloqueia um espaço da própria unidade
- **GIVEN** Rui coordena "Paulista" e "LAB-01" é um espaço ativo de "Paulista"
- **WHEN** Rui bloqueia "LAB-01" de 10/12 às 08h00 a 12/12 às 18h00, tipo `MANUTENCAO`, motivo "Troca dos computadores"
- **THEN** o bloqueio é gravado `ATIVO`, com Rui como autor
- **AND** a resposta informa que o espaço foi bloqueado e quantas reservas e entradas de fila foram afetadas

#### Scenario: Admin bloqueia em qualquer unidade
- **WHEN** o admin bloqueia "AUD-01" de "Vila Olímpia" para um evento
- **THEN** o bloqueio é gravado `ATIVO`

#### Scenario: Espaço desativado
- **GIVEN** "LAB-03" está desativado
- **WHEN** o admin tenta bloquear "LAB-03"
- **THEN** o sistema recusa informando que o espaço está desativado, e nada é gravado

#### Scenario: Tipo ou motivo inválido
- **WHEN** alguém informa um tipo fora da lista, um motivo vazio ou um motivo com mais de 500 caracteres
- **THEN** o sistema recusa com a mensagem do campo, e nada é gravado

### Requirement: Período do bloqueio
O início DEVE (MUST) ser anterior ao fim, e o fim DEVE estar no futuro. O bloqueio PODE durar vários dias e PODE ter começado antes da criação. As regras de horário do tipo (horário de funcionamento, dias de funcionamento, granularidade, durações e antecedências) NÃO DEVEM (MUST NOT) ser aplicadas ao bloqueio. Data ou hora em formato inválido ou inexistente DEVE ser recusada.

#### Scenario: Vários dias e fora do horário do tipo
- **WHEN** o admin bloqueia "BIB-01" de 24/12 às 00h00 a 26/12 às 23h59
- **THEN** o bloqueio é gravado, mesmo cobrindo horários antes das 08h00 e depois das 22h40

#### Scenario: Feriado já em curso
- **GIVEN** são 10h00 de 20/11
- **WHEN** o coordenador bloqueia "LAB-01" de 20/11 às 00h00 a 20/11 às 23h59, tipo `FERIADO`
- **THEN** o bloqueio é gravado

#### Scenario: Fim no passado
- **GIVEN** são 10h00 de 20/11
- **WHEN** alguém tenta bloquear de 19/11 às 08h00 a 20/11 às 09h00
- **THEN** o sistema recusa informando que o fim do bloqueio deve estar no futuro

#### Scenario: Fim antes do início
- **WHEN** alguém informa início em 12/12 às 10h00 e fim em 12/12 às 09h00
- **THEN** o sistema recusa informando que o fim deve ser depois do início

#### Scenario: Data inexistente
- **WHEN** alguém informa o início em "2026-02-30"
- **THEN** o sistema recusa informando o formato esperado de data e hora

### Requirement: Reserva em andamento impede o bloqueio
A criação DEVE (MUST) ser recusada, sem gravar nada, quando o espaço tem reserva `CONFIRMADA` em andamento (início já chegou e fim ainda não) sobreposta ao período do bloqueio. A confirmada sem check-in cuja janela de check-in já fechou é não comparecimento e NÃO DEVE (MUST NOT) impedir o bloqueio.

#### Scenario: Reserva em andamento sobreposta
- **GIVEN** são 14h30 e "LAB-01" tem uma reserva `CONFIRMADA` das 14h00 às 16h00 com check-in
- **WHEN** o coordenador tenta bloquear "LAB-01" de hoje às 15h00 até amanhã às 12h00
- **THEN** o sistema recusa informando que há reserva em andamento, até quando ela vai, e nada é gravado

#### Scenario: Reserva em andamento fora do período
- **GIVEN** são 14h30 e "LAB-01" tem uma reserva `CONFIRMADA` em andamento das 14h00 às 16h00
- **WHEN** o coordenador bloqueia "LAB-01" de amanhã às 08h00 a amanhã às 12h00
- **THEN** o bloqueio é gravado, e a reserva em andamento continua

#### Scenario: Não comparecimento não impede
- **GIVEN** são 14h30, a janela de check-in fecha 15 minutos depois do início, e "LAB-01" tem uma reserva `CONFIRMADA` das 14h00 às 16h00 sem check-in
- **WHEN** o coordenador bloqueia "LAB-01" de hoje às 14h40 até amanhã
- **THEN** o bloqueio é gravado, e a reserva continua sendo um não comparecimento, com a falta

### Requirement: Cancelamento das reservas sobrepostas
Ao criar o bloqueio, na mesma operação, o sistema DEVE (MUST) cancelar inteiras as reservas `PENDENTE` e `CONFIRMADA` do espaço que se sobrepõem ao período e ainda não começaram, com o motivo `BLOQUEIO`, o bloqueio que as causou, quem criou o bloqueio como autor e sem falta nem penalidade. Intervalo encostado não é sobreposição. A pendente cujo início já chegou expirou e não é cancelada.

#### Scenario: Sobreposição parcial cancela a reserva inteira
- **GIVEN** "LAB-01" tem uma reserva `CONFIRMADA` de Ana em 10/12 das 07h00 às 09h00
- **WHEN** o coordenador bloqueia "LAB-01" de 10/12 às 08h00 a 12/12 às 18h00
- **THEN** a reserva de Ana fica `CANCELADA` com o motivo `BLOQUEIO`, ligada ao bloqueio
- **AND** Ana não recebe falta

#### Scenario: Pendente cancelada
- **GIVEN** "LAB-01" tem uma reserva `PENDENTE` de Ana em 11/12 das 10h00 às 11h00
- **WHEN** o coordenador bloqueia "LAB-01" de 10/12 a 12/12
- **THEN** a reserva fica `CANCELADA` com o motivo `BLOQUEIO`

#### Scenario: Intervalo encostado não é cancelado
- **GIVEN** "LAB-01" tem uma reserva em 12/12 das 18h00 às 19h00
- **WHEN** o coordenador bloqueia "LAB-01" até 12/12 às 18h00
- **THEN** essa reserva continua ativa

#### Scenario: Outras reservas do espaço continuam
- **GIVEN** "LAB-01" tem uma reserva em 15/12, fora do período bloqueado, e "LAB-02" tem uma reserva em 11/12
- **WHEN** o coordenador bloqueia "LAB-01" de 10/12 a 12/12
- **THEN** as duas reservas continuam ativas

#### Scenario: Pendente vencida não é cancelada
- **GIVEN** são 10h20 e "LAB-01" tem uma reserva `PENDENTE` das 10h00 às 11h00, sem decisão
- **WHEN** o coordenador bloqueia "LAB-01" de hoje às 10h30 até amanhã
- **THEN** a reserva aparece como `EXPIRADA`, não como cancelada por bloqueio

### Requirement: Encerramento das filas sobrepostas
Ao criar o bloqueio, na mesma operação, as entradas de fila `AGUARDANDO` e `NOTIFICADA` do espaço cujo intervalo se sobrepõe ao período DEVEM (MUST) ficar `ENCERRADA`. A vaga retida sobreposta deixa de existir. Os trechos liberados por cancelamentos fora do período do bloqueio DEVEM ser oferecidos às filas não sobrepostas, como em qualquer liberação.

#### Scenario: Fila sobreposta encerrada
- **GIVEN** Ana aguarda na fila de "BIB-01" de 11/12 das 14h00 às 15h00, e Bia tem a vaga retida de 11/12 das 16h00 às 17h00
- **WHEN** o coordenador bloqueia "BIB-01" de 10/12 a 12/12
- **THEN** as entradas de Ana e de Bia ficam `ENCERRADA`

#### Scenario: Fila fora do período continua
- **GIVEN** Ana aguarda na fila de "BIB-01" de 15/12 das 14h00 às 15h00
- **WHEN** o coordenador bloqueia "BIB-01" de 10/12 a 12/12
- **THEN** a entrada de Ana continua `AGUARDANDO`

#### Scenario: Trecho liberado fora do bloqueio
- **GIVEN** "BIB-01" tem uma reserva de Carlos em 12/12 das 17h00 às 19h00 e Ana aguarda na fila de 12/12 das 18h00 às 19h00
- **WHEN** o coordenador bloqueia "BIB-01" até 12/12 às 18h00
- **THEN** a reserva de Carlos é cancelada por bloqueio
- **AND** a entrada de Ana passa a `NOTIFICADA` e retém a vaga das 18h00 às 19h00

### Requirement: Bloqueio é atômico com reservas e filas
A criação e a remoção de bloqueio DEVEM (MUST) ser atômicas em relação à criação de reservas e às operações da fila do mesmo espaço: uma reserva ou uma entrada de fila feita ao mesmo tempo que o bloqueio, para intervalo sobreposto, ou é recusada pelo bloqueio, ou é gravada antes e então cancelada ou encerrada por ele.

#### Scenario: Reserva e bloqueio simultâneos
- **WHEN** Ana reserva "LAB-01" para 11/12 das 10h00 às 11h00 ao mesmo tempo que o coordenador bloqueia "LAB-01" de 10/12 a 12/12
- **THEN** no fim não existe reserva ativa de Ana em "LAB-01" sobreposta ao bloqueio

### Requirement: Remover bloqueio
Quem pode criar bloqueio no espaço DEVE (MUST) poder remover um bloqueio `ATIVO` cujo fim ainda não chegou. O bloqueio passa a `REMOVIDO` e não é excluído. A remoção NÃO DEVE (MUST NOT) restaurar reservas canceladas nem entradas de fila encerradas. Não há edição de bloqueio: para mudar o período, remove-se e cria-se outro.

#### Scenario: Remoção sem restauração
- **GIVEN** o bloqueio de "LAB-01" cancelou a reserva de Ana
- **WHEN** o coordenador remove o bloqueio
- **THEN** o bloqueio fica `REMOVIDO`
- **AND** a reserva de Ana continua `CANCELADA`, e o intervalo volta a aceitar reservas

#### Scenario: Bloqueio já terminado
- **WHEN** alguém tenta remover um bloqueio cujo fim já passou
- **THEN** o sistema recusa informando que o bloqueio já terminou

#### Scenario: Bloqueio já removido
- **WHEN** alguém tenta remover um bloqueio `REMOVIDO`
- **THEN** o sistema recusa informando que o bloqueio já foi removido

### Requirement: Permissão para bloquear
Criar, remover e listar bloqueios DEVE (MUST) ser permitido só ao admin, em qualquer unidade, e ao coordenador, nas unidades que coordena no momento da requisição. Aluno e professor recebem acesso negado. O coordenador que age sobre espaço ou bloqueio de outra unidade recebe acesso negado, e nada é alterado.

#### Scenario: Coordenador em outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta bloquear um espaço de "Vila Olímpia" ou remover um bloqueio de lá
- **THEN** o sistema responde com acesso negado, e nada é alterado

#### Scenario: Professor tenta bloquear
- **WHEN** um professor chama diretamente a criação de bloqueio
- **THEN** o sistema responde com acesso negado

#### Scenario: Sem autenticação
- **WHEN** as rotas de bloqueio são chamadas sem token ou com conta inativa
- **THEN** o sistema responde com não autenticado

### Requirement: Listar bloqueios
A listagem DEVE (MUST) trazer os bloqueios `ATIVO` cujo fim ainda não chegou, das unidades sobre as quais o usuário tem escopo, com filtro opcional por unidade. Cada bloqueio traz: id, espaço (código e nome), unidade, tipo, motivo, início e fim em America/Sao_Paulo e quem criou. A ordem é pelo início.

#### Scenario: Coordenador vê só as próprias unidades
- **GIVEN** há bloqueios ativos em "Paulista" e em "Vila Olímpia", e Rui coordena apenas "Paulista"
- **WHEN** Rui lista os bloqueios
- **THEN** recebe só os de "Paulista"

#### Scenario: Terminados e removidos ficam de fora
- **GIVEN** "LAB-01" tem um bloqueio que terminou ontem e outro removido
- **WHEN** o admin lista os bloqueios
- **THEN** nenhum dos dois aparece

### Requirement: Motivo do bloqueio para o dono da reserva
A listagem das próprias reservas DEVE (MUST) trazer, para a reserva cancelada por bloqueio, o tipo e o motivo do bloqueio, e "Minhas reservas" DEVE mostrá-los no motivo do cancelamento. O nome de quem criou o bloqueio NÃO DEVE (MUST NOT) aparecer para o dono.

#### Scenario: Ana vê o motivo
- **GIVEN** a reserva de Ana em "LAB-01" foi cancelada por um bloqueio `MANUTENCAO` com o motivo "Troca dos computadores"
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a reserva aparece como "Cancelada por bloqueio: Manutenção — Troca dos computadores", sem o nome do coordenador

### Requirement: Página de bloqueios
O frontend DEVE (MUST) oferecer ao coordenador e ao admin uma página "Bloqueios" com a listagem e o filtro por unidade, um formulário para criar (espaço entre os que a pessoa gere, tipo, motivo, data e hora de início e de fim) com o aviso de que reservas e filas sobrepostas serão canceladas ou encerradas sem penalidade, e a remoção com confirmação. Depois de criar, mostra quantas reservas e entradas de fila foram afetadas; recusas aparecem no formulário.

#### Scenario: Criar pela tela
- **WHEN** Rui preenche o formulário de bloqueio de "LAB-01" e confirma
- **THEN** a página informa que o espaço foi bloqueado, com 2 reservas canceladas e 1 entrada de fila encerrada, e o bloqueio aparece na lista

#### Scenario: Recusa no formulário
- **WHEN** Rui tenta bloquear um período com reserva em andamento
- **THEN** o formulário continua aberto e mostra a recusa

#### Scenario: Remover pela tela
- **WHEN** Rui escolhe remover um bloqueio e confirma
- **THEN** a página informa que o bloqueio foi removido e ele sai da lista
