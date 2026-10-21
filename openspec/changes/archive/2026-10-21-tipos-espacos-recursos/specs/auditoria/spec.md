## ADDED Requirements

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
