## MODIFIED Requirements

### Requirement: Unidade sem coordenador ativo
O sistema DEVE (MUST) permitir que uma unidade fique sem coordenador ativo apenas:
- antes de o primeiro coordenador ser aprovado ou atribuído;
- depois que o último coordenador sair por mudança de papel, inclusive pela promoção a admin;
- depois que o último coordenador ativo for inativado;
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

#### Scenario: Último coordenador inativado
- **GIVEN** Rui é o único coordenador ativo de "Paulista"
- **WHEN** um admin inativa a conta de Rui
- **THEN** "Paulista" fica sem coordenador ativo e é destacada na tela de unidades
