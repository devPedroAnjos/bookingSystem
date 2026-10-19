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
