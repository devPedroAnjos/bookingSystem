# Especificação: Interface web

## Purpose
Dar ao frontend uma identidade visual única, a do design system do projeto, com navegação no topo, tela de boas-vindas e o atalho da próxima reserva na Início.

## Requirements

### Requirement: Identidade visual
Todas as páginas DEVEM (MUST) usar o tema claro do design system do projeto: as cores, a tipografia (Inter), os raios e as sombras definidos no Figma, e ícones Lucide. O nome "Booking System" DEVE aparecer como o logotipo com o livro na barra do "t", sempre com B e S maiúsculos, e o favicon DEVE ser o símbolo t-livro. As páginas existentes herdam o tema sem mudar o comportamento.

#### Scenario: Página antiga herda o tema
- **WHEN** um admin abre a página "Recursos", que não foi redesenhada
- **THEN** a página usa as cores e a fonte do tema e continua com as mesmas ações

#### Scenario: Logotipo e favicon
- **WHEN** qualquer página é aberta
- **THEN** a aba do navegador mostra o símbolo t-livro e a barra de navegação mostra o logotipo "Booking System"

### Requirement: Barra de navegação
As páginas autenticadas DEVEM (MUST) ter uma barra no topo com o logotipo, que leva à Início, os itens de menu do papel (capability `autorizacao`) e, à direita, o nome e o papel do usuário com "Trocar senha" e "Sair". Os itens de gestão ficam num menu "Gestão", que só aparece para quem tem algum deles.

#### Scenario: Barra do aluno
- **WHEN** um aluno abre a Início
- **THEN** a barra mostra o logotipo, "Início" e "Minhas reservas", sem o menu "Gestão"

#### Scenario: Barra do coordenador
- **WHEN** um coordenador abre a Início
- **THEN** a barra mostra também o menu "Gestão", com os itens de gestão do papel dele

### Requirement: Tela de boas-vindas
Quem abre o sistema sem sessão DEVE (MUST) ver uma tela de boas-vindas com o logotipo, uma frase sobre o sistema e as opções "Entrar" e "Criar conta", que levam aos formulários de login e de cadastro. Os formulários mantêm os campos, as validações e as mensagens das capabilities `autenticacao` e `aprovacao-cadastro`.

#### Scenario: Entrar pela boas-vindas
- **WHEN** um visitante abre o sistema e escolhe "Entrar"
- **THEN** a página mostra o formulário de login

#### Scenario: Criar conta pela boas-vindas
- **WHEN** um visitante escolhe "Criar conta"
- **THEN** a página mostra o formulário de cadastro com os mesmos campos de antes

### Requirement: Próxima reserva na Início
A Início DEVE (MUST) mostrar, acima do feed, um cartão com a próxima reserva do usuário: a de situação efetiva `PENDENTE` ou `CONFIRMADA` que ainda não terminou e tem o menor início (empate: a criada antes), indicada pelo backend. O cartão mostra espaço, unidade, data, horário e situação e, quando o check-in é possível (capability `comparecimento`), o horário limite e "Fazer check-in". Sem reserva assim, o cartão não aparece.

#### Scenario: Check-in pela Início
- **GIVEN** Ana tem uma reserva confirmada de "BIB-01" que começa daqui a 10 minutos, e a janela de check-in abre 15 minutos antes
- **WHEN** Ana abre a Início e escolhe "Fazer check-in"
- **THEN** o check-in é registrado e o cartão passa a mostrar o horário do check-in

#### Scenario: Janela fechada
- **GIVEN** a próxima reserva de Ana começa amanhã
- **WHEN** Ana abre a Início
- **THEN** o cartão mostra a reserva sem "Fazer check-in"

#### Scenario: Reserva em andamento
- **GIVEN** Ana fez check-in numa reserva que vai até 16h00 e tem outra amanhã, e são 15h00
- **WHEN** Ana abre a Início
- **THEN** o cartão mostra a reserva em andamento, com o horário do check-in

#### Scenario: Não comparecimento já ocorrido
- **GIVEN** a janela de check-in da reserva de Ana fechou sem check-in, e ela tem outra reserva amanhã
- **WHEN** Ana abre a Início
- **THEN** o cartão mostra a reserva de amanhã

#### Scenario: Sem reservas futuras
- **WHEN** um usuário sem reservas pendentes ou confirmadas abre a Início
- **THEN** a Início mostra só o feed
