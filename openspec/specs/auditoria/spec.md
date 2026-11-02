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
