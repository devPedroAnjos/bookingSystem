## MODIFIED Requirements

### Requirement: Disponibilidade do espaço para reserva
Um espaço DEVE (MUST) ser considerado reservável somente quando o próprio espaço, a unidade dele e o tipo dele estão ativos e o tipo tem regras completas (capability `regras-tipo`). Espaços não reserváveis NÃO DEVEM (MUST NOT) aparecer na busca nem aceitar novas reservas, regra que as changes de busca e de reserva aplicam. Desativar ou reativar uma unidade ou um tipo, ou definir as regras de um tipo, NÃO DEVE alterar a situação dos espaços; muda apenas se eles são reserváveis.

#### Scenario: Unidade desativada
- **GIVEN** "Sala 12" está ativo e é de "Paulista"
- **WHEN** o admin desativa "Paulista"
- **THEN** "Sala 12" continua ativo, mas deixa de ser reservável, com o motivo "unidade desativada"

#### Scenario: Unidade reativada
- **GIVEN** "Paulista" está desativada e "Sala 12", ativo e de tipo ativo com regras completas, pertence a ela
- **WHEN** o admin reativa "Paulista"
- **THEN** "Sala 12" volta a ser reservável sem nenhuma ação sobre o espaço

#### Scenario: Tipo sem regras
- **GIVEN** "Refeitório 1" está ativo, numa unidade ativa, e o tipo "Refeitório" está ativo, mas sem regras
- **WHEN** a listagem de gestão é consultada
- **THEN** "Refeitório 1" aparece como não reservável, com o motivo "tipo sem regras"

#### Scenario: Vários motivos
- **GIVEN** "Sala 1" está desativado, a unidade dele está desativada e o tipo dele também, sem regras
- **WHEN** a listagem de gestão é consultada
- **THEN** "Sala 1" aparece como não reservável, com os motivos "espaço desativado", "unidade desativada", "tipo desativado" e "tipo sem regras"
