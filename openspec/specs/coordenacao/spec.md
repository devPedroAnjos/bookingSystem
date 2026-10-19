# Especificação: Coordenação

## Purpose

Definir o vínculo entre coordenadores e unidades e os limites que o protegem. A capability cobre quantas unidades cada coordenador e quantos coordenadores cada unidade podem ter, como o admin move e acrescenta coordenadores e o que acontece quando uma unidade fica sem coordenador ativo.

## Requirements
### Requirement: Limites da coordenação
O sistema DEVE (MUST) manter estes limites, contando apenas coordenadores com conta `ATIVA`:
- todo coordenador `ATIVA` coordena no mínimo 1 unidade e no máximo o valor de `ConfiguracaoGeral` (padrão: 2);
- toda unidade tem no máximo o número de coordenadores definido em `ConfiguracaoGeral` (padrão: 4), valor que vale para todas as unidades.

Nenhuma operação PODE (MUST NOT) ultrapassar um máximo. Reduzir um parâmetro abaixo da quantidade atual não remove ninguém; só impede novas entradas.

#### Scenario: Unidade no limite
- **GIVEN** o limite é de 4 coordenadores por unidade e "Paulista" tem 4 coordenadores ativos
- **WHEN** o admin tenta acrescentar ou mover outro coordenador para "Paulista"
- **THEN** o sistema recusa informando que a unidade não tem vaga

#### Scenario: Coordenador no limite
- **GIVEN** o limite é de 2 unidades por coordenador e Rui coordena "Paulista" e "Centro"
- **WHEN** o admin tenta acrescentar "Vila Olímpia" a Rui
- **THEN** o sistema recusa informando que Rui já coordena o máximo de unidades

#### Scenario: Limites concorrentes
- **GIVEN** "Paulista" tem 3 coordenadores ativos e o limite é 4
- **WHEN** dois admins acrescentam coordenadores diferentes a "Paulista" ao mesmo tempo
- **THEN** no máximo uma operação é aceita e "Paulista" termina com no máximo 4 coordenadores

### Requirement: Acrescentar unidade a um coordenador
O admin DEVE (MUST) poder acrescentar uma unidade a um coordenador `ATIVA` que ainda não atingiu o máximo de unidades. O coordenador continua coordenando a unidade que já tinha. A unidade de destino precisa estar ativa, ter vaga e não ser uma unidade que ele já coordena.

#### Scenario: Acrescentar segunda unidade
- **GIVEN** Rui coordena apenas "Paulista" e "Vila Olímpia" tem vaga
- **WHEN** o admin acrescenta "Vila Olímpia" a Rui
- **THEN** Rui passa a coordenar "Paulista" e "Vila Olímpia"

#### Scenario: Destino desativado
- **WHEN** o admin tenta acrescentar uma unidade desativada a um coordenador
- **THEN** o sistema recusa informando que a unidade está desativada

### Requirement: Mover coordenador
O admin DEVE (MUST) poder mover um coordenador `ATIVA` de uma unidade de origem para uma unidade de destino. Ele deixa a origem e passa a coordenar o destino. O movimento DEVE ser recusado se:
- a origem ficar sem nenhum coordenador ativo;
- o destino estiver desativado, sem vaga, ou já for coordenado por ele.

#### Scenario: Mover com origem coberta
- **GIVEN** "Paulista" tem os coordenadores Rui e Ana
- **WHEN** o admin move Rui de "Paulista" para "Vila Olímpia"
- **THEN** "Paulista" fica com Ana e Rui passa a coordenar só "Vila Olímpia"

#### Scenario: Mover o único coordenador
- **GIVEN** Rui é o único coordenador ativo de "Paulista"
- **WHEN** o admin tenta mover Rui para outra unidade
- **THEN** o sistema recusa informando que "Paulista" ficaria sem coordenador

### Requirement: Remover uma das unidades
O admin DEVE (MUST) poder remover uma das unidades de um coordenador que coordena duas, mantendo a outra. A remoção DEVE ser recusada se a unidade removida ficar sem nenhum coordenador ativo, ou se o coordenador ficar sem unidade.

#### Scenario: Remover segunda unidade
- **GIVEN** Rui coordena "Paulista" e "Vila Olímpia", e "Vila Olímpia" também é coordenada por Ana
- **WHEN** o admin remove "Vila Olímpia" de Rui
- **THEN** Rui passa a coordenar só "Paulista"

#### Scenario: Remover a única unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** o admin tenta remover "Paulista" de Rui
- **THEN** o sistema recusa informando que o coordenador precisa de ao menos uma unidade

### Requirement: Unidade sem coordenador ativo
O sistema DEVE (MUST) permitir que uma unidade fique sem coordenador ativo apenas:
- antes de o primeiro coordenador ser aprovado ou atribuído;
- depois que o último coordenador sair por mudança de papel;
- depois de ser reativada.

Nesse estado, o admin age sobre a unidade normalmente. A tela de unidades DEVE destacar as unidades sem coordenador ativo.

#### Scenario: Saída do último coordenador
- **GIVEN** Rui é o único coordenador de "Paulista"
- **WHEN** o admin muda o papel de Rui para `PROFESSOR`, com a unidade "Paulista"
- **THEN** a mudança é aceita, Rui passa a ser professor de "Paulista" e "Paulista" fica sem coordenador ativo
- **AND** a tela de unidades destaca "Paulista"

#### Scenario: Pedidos de professor sem coordenador
- **GIVEN** "Paulista" não tem coordenador ativo e há um professor pendente em "Paulista"
- **WHEN** o admin consulta os pedidos pendentes
- **THEN** o pedido aparece e o admin pode decidi-lo

### Requirement: Telas de coordenação
A página de unidades DEVE (MUST) mostrar os coordenadores de cada unidade. Nela o admin acrescenta, move e remove coordenações, escolhendo entre os coordenadores ativos. A página DEVE mostrar a mensagem da API depois de cada ação e recarregar a lista.

#### Scenario: Mover pela página
- **GIVEN** o admin está na página de unidades e "Paulista" tem Rui e Ana
- **WHEN** ele move Rui para "Vila Olímpia"
- **THEN** Rui aparece em "Vila Olímpia" e deixa de aparecer em "Paulista"
