## Purpose

Organizar a administração do sistema em um admin principal permanente e até dois admins secundários. A capability define quem pode criar, promover, rebaixar e alterar administradores, e garante que o sistema nunca fique sem quem o administre.

## ADDED Requirements

### Requirement: Admin principal
O sistema DEVE (MUST) ter exatamente um **admin principal**: a conta `ADMIN` criada pelo bootstrap. O admin principal NÃO DEVE (MUST NOT) ter o papel alterado, nem ser inativado, nem ter a senha redefinida por outra pessoa, nem ter a marca de principal transferida. Nenhuma operação PODE tornar outra conta principal.

#### Scenario: Tentativa de rebaixar o principal
- **WHEN** qualquer admin tenta rebaixar, inativar ou redefinir a senha do admin principal
- **THEN** o sistema recusa a operação e nada muda

#### Scenario: Principal visível na listagem
- **WHEN** o admin principal lista os administradores
- **THEN** o principal aparece identificado como principal

### Requirement: Limite de admins ativos
O número de contas `ADMIN` com situação `ATIVA`, incluindo o principal, NÃO DEVE (MUST NOT) ultrapassar o parâmetro `max_admins` de `ConfiguracaoGeral` (padrão: 3). Admins inativos não contam. Toda operação que acrescenta um admin ativo (promover, criar ou reativar) DEVE ser recusada se o limite já foi atingido, inclusive sob operações simultâneas.

#### Scenario: Limite atingido
- **GIVEN** existem 3 admins ativos e o limite é 3
- **WHEN** o principal tenta promover um coordenador ou criar um admin
- **THEN** o sistema recusa informando que o limite de administradores foi atingido

#### Scenario: Admin inativo libera vaga
- **GIVEN** existem 3 admins, um deles inativo, e o limite é 3
- **WHEN** o principal promove um coordenador a admin
- **THEN** a promoção é aceita

#### Scenario: Promoções simultâneas
- **GIVEN** existem 2 admins ativos e o limite é 3
- **WHEN** o principal envia duas promoções ao mesmo tempo
- **THEN** no máximo uma é aceita e o sistema termina com no máximo 3 admins ativos

### Requirement: Só o principal altera administradores
Somente o admin principal DEVE (MUST) poder promover, criar, rebaixar, inativar, reativar e redefinir a senha de admins. Admins secundários NÃO DEVEM (MUST NOT) executar nenhuma dessas operações sobre admins, mas mantêm as demais permissões de administrador.

#### Scenario: Secundário tenta promover
- **WHEN** um admin secundário tenta promover um coordenador a admin
- **THEN** o sistema responde com acesso negado

#### Scenario: Secundário tenta inativar outro admin
- **WHEN** um admin secundário tenta inativar outro admin secundário
- **THEN** o sistema responde com acesso negado e nada muda

#### Scenario: Secundário aprova cadastro
- **WHEN** um admin secundário aprova um pedido de professor
- **THEN** a aprovação é aceita normalmente

### Requirement: Promoção de coordenador a admin
O principal DEVE (MUST) poder promover a admin uma conta `COORDENADOR` `ATIVA`. Na mesma operação, todas as coordenações dela DEVEM ser removidas, mesmo que alguma unidade fique sem coordenador ativo. A resposta lista as unidades que deixaram de ser coordenadas. Somente coordenadores podem ser promovidos a admin.

#### Scenario: Coordenador vira admin
- **GIVEN** Rui é coordenador ativo de "Paulista" e há vaga de admin
- **WHEN** o principal promove Rui a admin
- **THEN** Rui passa a `ADMIN` secundário e deixa de coordenar "Paulista"
- **AND** "Paulista" fica sem coordenador ativo, se Rui era o único

#### Scenario: Professor não pode ser promovido a admin
- **WHEN** o principal tenta promover um professor ou um aluno a admin
- **THEN** o sistema recusa informando que só coordenadores são promovidos a admin

### Requirement: Criação de admin do zero
O principal DEVE (MUST) poder criar uma conta `ADMIN` `ATIVA` informando nome, e-mail institucional (domínio aceito em `ConfiguracaoGeral`, único) e uma senha provisória de no mínimo 8 caracteres. A conta nasce com senha provisória e é obrigada a trocá-la no primeiro acesso (capability `senha`). E-mail já existente DEVE ser recusado.

#### Scenario: Criar admin
- **GIVEN** há vaga de admin
- **WHEN** o principal cria o admin "Lia" com e-mail `lia@impacta.edu.br` e uma senha provisória
- **THEN** a conta é criada `ADMIN` e `ATIVA`, com senha provisória
- **AND** no primeiro login, Lia só consegue trocar a senha

#### Scenario: E-mail fora do domínio ou repetido
- **WHEN** o principal tenta criar um admin com e-mail de domínio não aceito, ou com um e-mail já cadastrado
- **THEN** o sistema recusa e nenhuma conta é criada

### Requirement: Rebaixamento de admin secundário
O principal DEVE (MUST) poder rebaixar um admin secundário `ATIVA` ou `INATIVA` **somente a `COORDENADOR`**, informando no mesmo ato de 1 até o máximo de unidades por coordenador (unidades ativas e com vaga). O rebaixamento direto para `PROFESSOR` ou `ALUNO` NÃO DEVE (MUST NOT) ser permitido. Para virar professor, o ex-admin segue depois a mudança de papel `COORDENADOR` → `PROFESSOR` (capability `papeis`). Se qualquer unidade for inválida, nada muda. A outra forma de retirar um admin secundário é a inativação pelo principal (capability `situacao-conta`).

#### Scenario: Admin vira coordenador
- **GIVEN** Lia é admin secundária e "Paulista" tem vaga
- **WHEN** o principal rebaixa Lia a `COORDENADOR` com a unidade "Paulista"
- **THEN** Lia passa a coordenadora de "Paulista"

#### Scenario: Admin vira coordenador sem unidade
- **WHEN** o principal tenta rebaixar um admin a `COORDENADOR` sem informar unidade
- **THEN** o sistema recusa e nada muda

#### Scenario: Rebaixar direto para professor ou aluno
- **WHEN** o principal tenta rebaixar um admin a `PROFESSOR` ou a `ALUNO`
- **THEN** o sistema recusa informando que o admin só pode ser rebaixado a coordenador

#### Scenario: Ex-admin vira professor depois
- **GIVEN** Lia foi rebaixada a coordenadora de "Paulista"
- **WHEN** um admin muda o papel de Lia para `PROFESSOR` com a unidade "Paulista"
- **THEN** Lia passa a professora de "Paulista"

### Requirement: Tela de administradores
O frontend DEVE (MUST) oferecer ao admin principal uma página de administradores, com a lista dos admins (principal identificado, situação) e as ações: promover coordenador, criar admin, rebaixar a coordenador (com a escolha de unidades), inativar, reativar e redefinir senha. Admins secundários NÃO DEVEM ver essa página no menu.

#### Scenario: Menu do secundário
- **WHEN** um admin secundário faz login
- **THEN** o menu não mostra "Administradores" nem "Parâmetros"
- **AND** ao abrir diretamente o endereço da página, ele é levado para "Início"
