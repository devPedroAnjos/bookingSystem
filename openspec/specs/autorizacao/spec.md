# Especificação: Autorização

## Purpose

Definir quem pode executar ações de gestão e sobre quais unidades. A regra vale para todas as rotas restritas do backend: o admin age em todas as unidades, o coordenador só nas que coordena e os demais papéis não têm ações de gestão. Também orienta o frontend a exibir só o que o papel do usuário pode usar.

## Requirements
### Requirement: Autorização sempre verificada no backend
Toda rota restrita DEVE (MUST) verificar no backend, a cada requisição:
1. se o token é válido e a conta está `ATIVA` (senão, não autenticado);
2. se o papel atual, lido do banco e não do token, permite a ação (senão, acesso negado);
3. quando a ação é sobre uma unidade, se a conta tem escopo sobre ela (senão, acesso negado).

Esconder botões ou páginas no frontend NÃO DEVE (MUST NOT) ser tratado como controle de acesso.

#### Scenario: Chamada direta sem permissão
- **GIVEN** Ana tem papel `ALUNO` e token válido
- **WHEN** Ana chama diretamente uma rota de gestão de unidades
- **THEN** o sistema responde com acesso negado e nada é alterado

#### Scenario: Sem token
- **WHEN** uma rota restrita é chamada sem token ou com token inválido
- **THEN** o sistema responde com não autenticado

### Requirement: Escopo de unidade por papel
O escopo de unidade DEVE (MUST) ser:
- `ADMIN`: todas as unidades, ativas ou desativadas;
- `COORDENADOR`: somente as unidades que coordena no momento da requisição;
- `ALUNO` e `PROFESSOR`: nenhuma.

#### Scenario: Coordenador na própria unidade
- **GIVEN** Rui coordena "Paulista"
- **WHEN** Rui age sobre um pedido de professor de "Paulista"
- **THEN** o sistema autoriza a ação

#### Scenario: Coordenador em outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui age sobre um pedido de professor de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado

#### Scenario: Admin em qualquer unidade
- **WHEN** o admin age sobre qualquer unidade
- **THEN** o sistema autoriza a ação

### Requirement: Mudanças valem imediatamente
Mudanças de papel, de situação da conta ou de coordenação DEVEM (MUST) valer na próxima requisição do usuário afetado, sem novo login.

#### Scenario: Coordenador movido
- **GIVEN** Rui coordenava "Paulista" e foi movido pelo admin para "Vila Olímpia"
- **WHEN** Rui, com o mesmo token, tenta aprovar um professor de "Paulista"
- **THEN** o sistema responde com acesso negado

### Requirement: Navegação por papel no frontend
As páginas autenticadas DEVEM (MUST) exibir um menu só com as áreas permitidas ao papel:
- todos: "Início", "Buscar espaços", "Minhas reservas" e "Trocar senha";
- admin e coordenador: "Aprovações", "Reservas da unidade" e "Espaços";
- só admin: "Usuários", "Unidades", "Tipos de espaço" e "Recursos";
- só o admin principal: "Administradores" e "Parâmetros".

Com senha provisória, o menu segue a capability `senha` e mostra apenas "Trocar senha" e "Sair". Quem abre diretamente o endereço de uma área não permitida DEVE ser levado para "Início". Isso é usabilidade; a segurança é do backend.

#### Scenario: Menu do aluno
- **WHEN** um aluno faz login
- **THEN** o menu mostra "Início", "Buscar espaços", "Minhas reservas" e "Trocar senha"

#### Scenario: Menu do coordenador
- **WHEN** um coordenador faz login
- **THEN** o menu mostra "Início", "Buscar espaços", "Minhas reservas", "Aprovações", "Reservas da unidade", "Espaços" e "Trocar senha"
- **AND** não mostra "Usuários", "Unidades", "Tipos de espaço", "Recursos", "Administradores" nem "Parâmetros"

#### Scenario: Menu do admin secundário
- **WHEN** um admin secundário faz login
- **THEN** o menu mostra "Início", "Buscar espaços", "Minhas reservas", "Aprovações", "Reservas da unidade", "Espaços", "Usuários", "Unidades", "Tipos de espaço", "Recursos" e "Trocar senha"
- **AND** não mostra "Administradores" nem "Parâmetros"

#### Scenario: Endereço digitado
- **GIVEN** Ana está logada como `ALUNO`
- **WHEN** Ana abre diretamente o endereço da página de unidades, de espaços ou de reservas da unidade
- **THEN** ela é levada para "Início"

#### Scenario: Coordenador abre a página de tipos
- **GIVEN** Rui está logado como coordenador
- **WHEN** Rui abre diretamente o endereço da página de tipos de espaço
- **THEN** ele é levado para "Início"

#### Scenario: Papel alterado durante a sessão
- **GIVEN** Rui está logado como coordenador e o admin mudou o papel dele para `PROFESSOR`
- **WHEN** Rui navega para outra página
- **THEN** o menu passa a mostrar apenas "Início", "Buscar espaços", "Minhas reservas" e "Trocar senha"
