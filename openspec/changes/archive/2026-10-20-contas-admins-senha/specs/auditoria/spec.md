## ADDED Requirements

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
