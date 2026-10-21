## MODIFIED Requirements

### Requirement: Navegação por papel no frontend
As páginas autenticadas DEVEM (MUST) exibir um menu só com as áreas permitidas ao papel:
- todos: "Início" e "Trocar senha";
- admin e coordenador: "Aprovações" e "Espaços";
- só admin: "Usuários", "Unidades", "Tipos de espaço" e "Recursos";
- só o admin principal: "Administradores" e "Parâmetros".

Com senha provisória, o menu segue a capability `senha` e mostra apenas "Trocar senha" e "Sair". Quem abre diretamente o endereço de uma área não permitida DEVE ser levado para "Início". Isso é usabilidade; a segurança é do backend.

#### Scenario: Menu do coordenador
- **WHEN** um coordenador faz login
- **THEN** o menu mostra "Início", "Aprovações", "Espaços" e "Trocar senha"
- **AND** não mostra "Usuários", "Unidades", "Tipos de espaço", "Recursos", "Administradores" nem "Parâmetros"

#### Scenario: Menu do admin secundário
- **WHEN** um admin secundário faz login
- **THEN** o menu mostra "Início", "Aprovações", "Espaços", "Usuários", "Unidades", "Tipos de espaço", "Recursos" e "Trocar senha"
- **AND** não mostra "Administradores" nem "Parâmetros"

#### Scenario: Endereço digitado
- **GIVEN** Ana está logada como `ALUNO`
- **WHEN** Ana abre diretamente o endereço da página de unidades ou da página de espaços
- **THEN** ela é levada para "Início"

#### Scenario: Coordenador abre a página de tipos
- **GIVEN** Rui está logado como coordenador
- **WHEN** Rui abre diretamente o endereço da página de tipos de espaço
- **THEN** ele é levado para "Início"

#### Scenario: Papel alterado durante a sessão
- **GIVEN** Rui está logado como coordenador e o admin mudou o papel dele para `PROFESSOR`
- **WHEN** Rui navega para outra página
- **THEN** o menu passa a mostrar apenas "Início" e "Trocar senha"
