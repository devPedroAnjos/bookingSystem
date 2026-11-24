# Especificação: Auditoria

## Purpose

Garantir a rastreabilidade das ações sensíveis do sistema por meio de um registro imutável em `LogAuditoria`. O registro informa quem fez o quê, sobre qual entidade, quando e com quais dados. Cada change acrescenta as ações que implementar; esta começa pela criação de conta.

## Requirements

### Requirement: Conteúdo do registro de auditoria
Cada registro de auditoria DEVE (MUST) conter:
- ator (usuário que executou a ação, ou vazio quando a ação é do sistema);
- ação;
- entidade afetada e seu identificador;
- unidade, quando aplicável;
- dados antes e dados depois, quando aplicável;
- data/hora gravada pelo backend, com fuso.

#### Scenario: Registro completo
- **WHEN** uma ação sensível é registrada
- **THEN** o registro contém ação, entidade, identificador e data/hora preenchidos pelo backend
- **AND** o ator está preenchido, ou vazio quando a ação é do sistema

### Requirement: Registro imutável e restrito
Registros de auditoria DEVEM (MUST) ser apenas inseridos. Nenhuma rota da API PODE (MUST NOT) alterar ou excluir registros de auditoria, nem expô-los a usuários que não sejam administradores.

#### Scenario: Tentativa de alteração ou exclusão
- **WHEN** qualquer usuário, inclusive um administrador, tenta alterar ou excluir um registro de auditoria pela API
- **THEN** não existe rota que permita a operação e o registro permanece inalterado

#### Scenario: Usuário comum não lê o log
- **WHEN** um usuário com papel `ALUNO` ou `PROFESSOR` tenta consultar registros de auditoria
- **THEN** o sistema não devolve nenhum registro

### Requirement: Criação de conta é auditada
A criação de uma conta DEVE (MUST) gerar um registro de auditoria com a ação `CRIAR_CONTA`, a entidade `usuario` e o identificador da conta criada. A conta e o registro DEVEM ser gravados juntos: se o registro falhar, a conta não é criada. Tentativas de cadastro recusadas NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Cadastro bem-sucedido
- **WHEN** Ana se cadastra como `ALUNO` com sucesso
- **THEN** existe um registro `CRIAR_CONTA` com ator = Ana, entidade `usuario` e o id da conta dela
- **AND** os dados depois contêm nome, e-mail, papel e situação, mas não contêm senha nem hash

#### Scenario: Administrador inicial
- **WHEN** o bootstrap cria o administrador inicial
- **THEN** existe um registro `CRIAR_CONTA` com ator vazio (ação do sistema) para a conta criada

#### Scenario: Cadastro recusado
- **WHEN** um cadastro é recusado (domínio inválido, e-mail duplicado ou papel não permitido)
- **THEN** nenhum registro de auditoria é gerado

#### Scenario: Falha ao gravar a auditoria
- **GIVEN** a gravação do registro de auditoria falha durante um cadastro
- **WHEN** o cadastro é processado
- **THEN** a conta não é criada e o visitante recebe um erro genérico

### Requirement: Cadastro, coordenação e unidades são auditados
Cada ação abaixo, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria:

| Ação | Entidade | Ator | Unidade do registro |
|---|---|---|---|
| `APROVAR_CADASTRO` | `usuario` | quem aprovou | unidade pedida |
| `RECUSAR_CADASTRO` | `usuario` | quem recusou | unidade pedida |
| `REENVIAR_CADASTRO` | `usuario` | o próprio titular | nova unidade pedida |
| `ALTERAR_PAPEL` | `usuario` | admin | vazia |
| `TRANSFERIR_PROFESSOR` | `usuario` | admin (ou quem desativou a unidade) | unidade de destino |
| `ATRIBUIR_COORDENACAO` | `coordenacao_unidade` | admin (ou quem aprovou o coordenador) | unidade coordenada |
| `REMOVER_COORDENACAO` | `coordenacao_unidade` | admin | unidade coordenada |
| `CRIAR_UNIDADE` | `unidade` | admin | a própria unidade |
| `EDITAR_UNIDADE` | `unidade` | admin | a própria unidade |
| `DESATIVAR_UNIDADE` | `unidade` | admin | a própria unidade |
| `REATIVAR_UNIDADE` | `unidade` | admin | a própria unidade |

Mover um coordenador gera um `REMOVER_COORDENACAO` (origem) e um `ATRIBUIR_COORDENACAO` (destino). A desativação de unidade gera também:
- um `TRANSFERIR_PROFESSOR` por professor;
- um `RECUSAR_CADASTRO` por pedido pendente, com ator = admin que desativou e indicação de que a recusa foi automática.

Regras dos dados:
- os dados antes e depois contêm apenas os campos alterados, nunca senha ou hash;
- a ação e todos os seus registros DEVEM ser gravados juntos;
- tentativas recusadas (validação, acesso negado, limite, pedido já decidido) NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Aprovação de coordenador auditada
- **WHEN** o admin aprova a coordenadora pendente Ana para "Paulista"
- **THEN** existem um registro `APROVAR_CADASTRO` e um `ATRIBUIR_COORDENACAO`, ambos com ator = admin e unidade "Paulista"

#### Scenario: Reenvio auditado
- **WHEN** Carlos pede nova análise trocando a unidade para "Vila Olímpia"
- **THEN** existe um registro `REENVIAR_CADASTRO` com ator = Carlos, os dados antes com o motivo da recusa e "Paulista", e os dados depois com "Vila Olímpia"

#### Scenario: Mover auditado
- **WHEN** o admin move Rui de "Paulista" para "Vila Olímpia"
- **THEN** existem um `REMOVER_COORDENACAO` de "Paulista" e um `ATRIBUIR_COORDENACAO` de "Vila Olímpia"

#### Scenario: Desativação auditada
- **GIVEN** "Paulista" tem o professor Carlos e o pedido pendente de Beatriz
- **WHEN** o admin desativa "Paulista" com destino "Centro" para Carlos
- **THEN** existem um `DESATIVAR_UNIDADE`, um `TRANSFERIR_PROFESSOR` de Carlos para "Centro" e um `RECUSAR_CADASTRO` automático de Beatriz, todos com ator = admin

#### Scenario: Tentativa recusada
- **WHEN** um coordenador tenta aprovar um professor de outra unidade, ou o admin tenta acrescentar um coordenador a uma unidade cheia
- **THEN** nenhum registro de auditoria é gerado

#### Scenario: Falha ao gravar a auditoria
- **GIVEN** a gravação da auditoria falha durante a desativação de uma unidade
- **WHEN** a desativação é processada
- **THEN** a unidade continua ativa, nenhuma coordenação muda e o admin recebe um erro genérico

### Requirement: Administradores, senha, situação de conta e parâmetros são auditados
Cada ação abaixo, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria com o usuário que a executou como ator:

| Ação | Entidade | Observação |
|---|---|---|
| `PROMOVER_ADMIN` | `usuario` | mais um `REMOVER_COORDENACAO` por unidade perdida |
| `CRIAR_ADMIN` | `usuario` | dados sem a senha |
| `REBAIXAR_ADMIN` | `usuario` | mais um `ATRIBUIR_COORDENACAO` por unidade, se virar coordenador |
| `INATIVAR_CONTA` | `usuario` | com o motivo |
| `REATIVAR_CONTA` | `usuario` | mais os registros de coordenação descartada, atribuída ou da nova unidade do professor |
| `TROCAR_SENHA` | `usuario` | ator = o próprio titular; sem a senha |
| `REDEFINIR_SENHA` | `usuario` | sem a senha |
| `ALTERAR_PARAMETROS` | `configuracao_geral` | valores antigos e novos |

Nenhum registro PODE (MUST NOT) conter senha, hash ou token. A ação e seus registros DEVEM ser gravados juntos. Tentativas recusadas NÃO DEVEM gerar registro.

#### Scenario: Troca de senha auditada sem a senha
- **WHEN** Ana troca a própria senha
- **THEN** existe um registro `TROCAR_SENHA` com ator = Ana
- **AND** o registro não contém a senha antiga, a nova nem o hash

#### Scenario: Promoção auditada
- **GIVEN** Rui coordena "Paulista"
- **WHEN** o principal promove Rui a admin
- **THEN** existem um `PROMOVER_ADMIN` e um `REMOVER_COORDENACAO` de "Paulista", com ator = principal

#### Scenario: Parâmetros auditados
- **WHEN** o principal altera o máximo de admins de 3 para 2
- **THEN** existe um `ALTERAR_PARAMETROS` com 3 nos dados antes e 2 nos dados depois

#### Scenario: Tentativa recusada
- **WHEN** um admin secundário tenta inativar outro admin
- **THEN** nenhum registro de auditoria é gerado

### Requirement: Tipos de espaço, espaços e recursos são auditados
Cada ação abaixo, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria com o usuário que a executou como ator:

| Ação | Entidade | Unidade do registro | Observação |
|---|---|---|---|
| `CRIAR_TIPO_ESPACO` | `tipo_espaco` | vazia | |
| `EDITAR_TIPO_ESPACO` | `tipo_espaco` | vazia | |
| `DESATIVAR_TIPO_ESPACO` | `tipo_espaco` | vazia | |
| `REATIVAR_TIPO_ESPACO` | `tipo_espaco` | vazia | |
| `CRIAR_RECURSO` | `recurso` | vazia | |
| `EDITAR_RECURSO` | `recurso` | vazia | |
| `EXCLUIR_RECURSO` | `recurso` | vazia | o nome do recurso excluído nos dados antes |
| `CRIAR_ESPACO` | `espaco` | unidade do espaço | |
| `EDITAR_ESPACO` | `espaco` | unidade do espaço | |
| `ALTERAR_RECURSOS_ESPACO` | `espaco` | unidade do espaço | lista de recursos e quantidades antes e depois |
| `DESATIVAR_ESPACO` | `espaco` | unidade do espaço | |
| `REATIVAR_ESPACO` | `espaco` | unidade do espaço | |
| `MOVER_ESPACO` | `espaco` | unidade de destino | unidade de origem nos dados antes |

A carga inicial dos tipos de espaço NÃO DEVE (MUST NOT) gerar registro. Os dados antes e depois contêm apenas os campos alterados. A ação e seu registro DEVEM ser gravados juntos. Tentativas recusadas (validação, acesso negado, código ou nome repetido, recurso em uso, situação já atingida) NÃO DEVEM gerar registro.

#### Scenario: Criação de espaço auditada
- **WHEN** Rui, coordenador de "Paulista", cria o espaço "Laboratório de Redes"
- **THEN** existe um registro `CRIAR_ESPACO` com ator = Rui, entidade `espaco`, o id do espaço e unidade "Paulista"

#### Scenario: Mudança de unidade auditada
- **WHEN** o admin move "Sala 12" de "Paulista" para "Vila Olímpia"
- **THEN** existe um registro `MOVER_ESPACO` com unidade "Vila Olímpia", "Paulista" nos dados antes e "Vila Olímpia" nos dados depois

#### Scenario: Recursos do espaço auditados
- **GIVEN** "Sala 12" tem 1 "Projetor"
- **WHEN** Rui define para "Sala 12" 1 "Projetor" e 1 "Ar-condicionado"
- **THEN** existe um registro `ALTERAR_RECURSOS_ESPACO` com a lista anterior nos dados antes e a nova nos dados depois

#### Scenario: Exclusão de recurso auditada
- **WHEN** o admin exclui o recurso sem uso "Lousa digital"
- **THEN** existe um registro `EXCLUIR_RECURSO` com "Lousa digital" nos dados antes e a unidade vazia

#### Scenario: Tentativa recusada
- **WHEN** um coordenador tenta criar um espaço em unidade que não coordena, ou o admin tenta excluir um recurso em uso
- **THEN** nenhum registro de auditoria é gerado

#### Scenario: Falha ao gravar a auditoria
- **GIVEN** a gravação da auditoria falha durante a desativação de um tipo de espaço
- **WHEN** a desativação é processada
- **THEN** o tipo continua ativo e o admin recebe um erro genérico

### Requirement: Regras de tipo de espaço são auditadas
Cada alteração das regras de um tipo de espaço, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria com a ação `ALTERAR_REGRAS_TIPO_ESPACO`, a entidade `tipo_espaco`, o identificador do tipo, o admin como ator e a unidade vazia. Os dados antes e depois contêm apenas as regras alteradas, incluindo as regras por papel. Uma alteração que não muda nenhuma regra DEVE ser recusada sem gerar registro. A alteração dos novos parâmetros (granularidade e dias de funcionamento) é auditada pela ação `ALTERAR_PARAMETROS` já existente. A carga inicial das regras e a busca de espaços NÃO DEVEM (MUST NOT) gerar registro. A ação e seu registro DEVEM ser gravados juntos, e tentativas recusadas NÃO DEVEM gerar registro.

#### Scenario: Regras alteradas
- **WHEN** o admin muda a duração máxima de "Laboratório" de 240 para 180 minutos e passa a exigir aprovação do professor
- **THEN** existe um registro `ALTERAR_REGRAS_TIPO_ESPACO` com 240 e a regra anterior do professor nos dados antes, e 180 e a nova regra nos dados depois

#### Scenario: Nada mudou
- **WHEN** o admin salva as regras de "Biblioteca" sem alterar nenhum valor
- **THEN** o sistema recusa informando que nenhuma regra foi alterada e nenhum registro é gerado

#### Scenario: Novo parâmetro auditado
- **WHEN** o principal muda a granularidade de 10 para 5 minutos
- **THEN** existe um registro `ALTERAR_PARAMETROS` com 10 nos dados antes e 5 nos dados depois

#### Scenario: Busca não é auditada
- **WHEN** um aluno busca espaços
- **THEN** nenhum registro de auditoria é gerado

### Requirement: Reservas são auditadas
Cada ação abaixo, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria, gravado junto com a ação:

| Ação | Entidade | Ator | Unidade do registro | Dados |
|---|---|---|---|---|
| `CRIAR_RESERVA` | `reserva` | o dono da reserva | unidade do espaço | espaço, início, fim e situação inicial nos dados depois e, quando houve deslocamento, a lista das reservas deslocadas |
| `CANCELAR_RESERVA` | `reserva` | quem cancelou | unidade do espaço no momento do cancelamento (na mudança de unidade, a de origem) | situação anterior nos dados antes; `CANCELADA` e o motivo nos dados depois e, no deslocamento, a reserva que deslocou |

O cancelamento pelo próprio usuário gera um `CANCELAR_RESERVA` com o motivo `USUARIO`. Os cancelamentos automáticos geram um `CANCELAR_RESERVA` **por reserva cancelada**, com o motivo `CONTA_INATIVADA` ou `ESPACO_INDISPONIVEL` e, como ator, quem executou a inativação ou a ação sobre o espaço, o tipo ou a unidade, além do registro da própria ação. O deslocamento por prioridade gera um `CANCELAR_RESERVA` **por reserva deslocada**, com o motivo `PRIORIDADE`, a reserva nova que a deslocou e, como ator, quem criou a reserva nova, além do `CRIAR_RESERVA` dela. Tentativas recusadas, o pedido de confirmação do deslocamento, a listagem "Minhas reservas", a busca e a consulta de impacto NÃO DEVEM (MUST NOT) gerar registro.

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

#### Scenario: Deslocamento auditado
- **GIVEN** Ana e Bruno, alunos, têm reservas em "LAB-01" sobrepostas ao pedido de Carlos, professor
- **WHEN** Carlos reserva e confirma o deslocamento
- **THEN** existem um `CRIAR_RESERVA` com Carlos como ator e as duas reservas deslocadas nos dados depois, e dois `CANCELAR_RESERVA` com Carlos como ator, o motivo `PRIORIDADE` e a reserva de Carlos nos dados depois

#### Scenario: Pedido de confirmação sem registro
- **WHEN** Carlos pede um intervalo deslocável sem confirmar o deslocamento
- **THEN** nenhum registro de auditoria é gerado

### Requirement: Motivo nas desativações e na inativação de conta
Os registros `DESATIVAR_ESPACO`, `DESATIVAR_TIPO_ESPACO`, `DESATIVAR_UNIDADE` e `INATIVAR_CONTA` DEVEM (MUST) conter, nos dados depois, o código do motivo escolhido e, quando o motivo é "Outro", a descrição digitada. Os demais dados desses registros não mudam.

#### Scenario: Motivo da desativação
- **WHEN** Rui desativa "LAB-01" com o motivo "Problema de infraestrutura"
- **THEN** o registro `DESATIVAR_ESPACO` traz o código desse motivo nos dados depois

#### Scenario: Outro na inativação
- **WHEN** o admin inativa Carlos com o motivo "Outro" e a descrição "Transferido para outra instituição parceira"
- **THEN** o registro `INATIVAR_CONTA` traz o código "Outro" e essa descrição nos dados depois

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

### Requirement: Avaliações são auditadas
A avaliação de uma reserva DEVE (MUST) gerar um registro `AVALIAR_RESERVA`, com a entidade `avaliacao`, o autor como ator, a unidade do espaço e, nos dados depois, a reserva, o espaço, a nota e se há comentário. Recusas e as consultas de avaliações NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Avaliação auditada
- **GIVEN** a reserva concluída de Ana é de "BIB-01", de "Paulista"
- **WHEN** Ana avalia a reserva com nota 4 e um comentário
- **THEN** existe um registro `AVALIAR_RESERVA` com Ana como ator, a unidade "Paulista" e a reserva, o espaço, a nota 4 e a indicação de comentário nos dados depois

#### Scenario: Recusa não auditada
- **WHEN** Ana tenta avaliar de novo uma reserva já avaliada
- **THEN** nenhum novo registro `AVALIAR_RESERVA` é gerado

### Requirement: Foto de capa é auditada
O envio da foto de capa DEVE (MUST) gerar um registro `DEFINIR_FOTO_ESPACO`, e a remoção um `REMOVER_FOTO_ESPACO`, com a entidade `espaco`, quem agiu como ator, a unidade do espaço e o nome e o tamanho do arquivo nos dados antes e depois, sem o conteúdo da imagem. Recusas NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Troca de foto auditada
- **GIVEN** "LAB-01", de "Paulista", tem a foto "lab1.jpg"
- **WHEN** Rui envia a foto "lab1-nova.png"
- **THEN** existe um registro `DEFINIR_FOTO_ESPACO` com Rui como ator, a unidade "Paulista", "lab1.jpg" nos dados antes e "lab1-nova.png" nos dados depois

#### Scenario: Remoção auditada
- **WHEN** o admin remove a foto de "LAB-01"
- **THEN** existe um registro `REMOVER_FOTO_ESPACO` com o admin como ator e a foto anterior nos dados antes

#### Scenario: Recusa de foto não auditada
- **WHEN** Rui envia uma foto maior que o tamanho máximo
- **THEN** nenhum registro `DEFINIR_FOTO_ESPACO` é gerado
