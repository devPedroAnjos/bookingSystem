## Purpose

Garantir a rastreabilidade das ações sensíveis do sistema por meio de um registro imutável em `LogAuditoria`. O registro informa quem fez o quê, sobre qual entidade, quando e com quais dados. Cada change acrescenta as ações que implementar; esta começa pela criação de conta.

## ADDED Requirements

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
