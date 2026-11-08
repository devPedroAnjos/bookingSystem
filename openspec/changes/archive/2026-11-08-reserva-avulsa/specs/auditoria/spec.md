## ADDED Requirements

### Requirement: Reservas são auditadas
Cada ação abaixo, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria, gravado junto com a ação:

| Ação | Entidade | Ator | Unidade do registro | Dados |
|---|---|---|---|---|
| `CRIAR_RESERVA` | `reserva` | o dono da reserva | unidade do espaço | espaço, início, fim e situação inicial nos dados depois |
| `CANCELAR_RESERVA` | `reserva` | quem cancelou | unidade do espaço no momento do cancelamento (na mudança de unidade, a de origem) | situação anterior nos dados antes; `CANCELADA` e o motivo nos dados depois |

O cancelamento pelo próprio usuário gera um `CANCELAR_RESERVA` com o motivo `USUARIO`. Os cancelamentos automáticos geram um `CANCELAR_RESERVA` **por reserva cancelada**, com o motivo `CONTA_INATIVADA` ou `ESPACO_INDISPONIVEL` e, como ator, quem executou a inativação ou a ação sobre o espaço, o tipo ou a unidade, além do registro da própria ação. Tentativas recusadas, a listagem "Minhas reservas", a busca e a consulta de impacto NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Reserva criada
- **WHEN** Ana cria uma reserva de "BIB-01"
- **THEN** existe um registro `CRIAR_RESERVA` com Ana como ator, a unidade de "BIB-01" e a reserva nos dados depois

#### Scenario: Cancelamento pelo usuário
- **WHEN** Ana cancela a própria reserva dentro do prazo
- **THEN** existe um registro `CANCELAR_RESERVA` com Ana como ator e o motivo `USUARIO`

#### Scenario: Cancelamentos pela desativação
- **GIVEN** "LAB-01" tem 3 reservas futuras e nenhuma em andamento
- **WHEN** Rui desativa "LAB-01"
- **THEN** existem um registro `DESATIVAR_ESPACO` e três registros `CANCELAR_RESERVA`, todos com Rui como ator e os cancelamentos com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Cancelamento na mudança de unidade
- **GIVEN** "Sala 12" de "Paulista" tem uma reserva futura
- **WHEN** o admin move "Sala 12" para "Vila Olímpia"
- **THEN** o registro `CANCELAR_RESERVA` dessa reserva tem "Paulista" como unidade

#### Scenario: Desativação recusada por reserva em andamento
- **WHEN** a desativação de "LAB-01" é recusada porque há reserva em andamento
- **THEN** nenhum registro `DESATIVAR_ESPACO` nem `CANCELAR_RESERVA` é gerado

#### Scenario: Reserva recusada
- **WHEN** Carlos tenta reservar um horário ocupado
- **THEN** nenhum registro de auditoria é gerado

### Requirement: Motivo nas desativações e na inativação de conta
Os registros `DESATIVAR_ESPACO`, `DESATIVAR_TIPO_ESPACO`, `DESATIVAR_UNIDADE` e `INATIVAR_CONTA` DEVEM (MUST) conter, nos dados depois, o código do motivo escolhido e, quando o motivo é "Outro", a descrição digitada. Os demais dados desses registros não mudam.

#### Scenario: Motivo da desativação
- **WHEN** Rui desativa "LAB-01" com o motivo "Problema de infraestrutura"
- **THEN** o registro `DESATIVAR_ESPACO` traz o código desse motivo nos dados depois

#### Scenario: Outro na inativação
- **WHEN** o admin inativa Carlos com o motivo "Outro" e a descrição "Transferido para outra instituição parceira"
- **THEN** o registro `INATIVAR_CONTA` traz o código "Outro" e essa descrição nos dados depois
