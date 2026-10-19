## ADDED Requirements

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
