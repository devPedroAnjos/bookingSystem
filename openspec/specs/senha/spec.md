# Especificação: Senha

## Purpose
Permitir que cada usuário troque a própria senha, que o administrador dê uma saída para quem esqueceu a senha e que uma troca de senha encerre as sessões abertas antes dela. A recuperação por e-mail está fora do projeto.

## Requirements

### Requirement: Trocar a própria senha
Todo usuário autenticado DEVE (MUST) poder trocar a própria senha a qualquer momento, informando a senha atual e a nova. A nova senha DEVE ter no mínimo 8 caracteres e ser diferente da atual. A troca DEVE ser gravada como hash, nunca aparecer em resposta, log ou auditoria, e limpar a marca de senha provisória.

#### Scenario: Troca bem-sucedida
- **GIVEN** Ana está logada
- **WHEN** ela informa a senha atual correta e uma nova senha válida
- **THEN** a senha é trocada e Ana recebe uma mensagem de sucesso

#### Scenario: Senha atual errada
- **WHEN** Ana informa a senha atual errada
- **THEN** o sistema recusa a troca e a senha não muda

#### Scenario: Nova senha inválida
- **WHEN** Ana informa uma nova senha com menos de 8 caracteres, ou igual à atual
- **THEN** o sistema recusa a troca indicando o motivo

### Requirement: Troca de senha derruba as outras sessões
Depois de uma troca ou de uma redefinição de senha, todo token emitido **antes** dela DEVE (MUST) ser recusado como não autenticado, mesmo que ainda não tenha expirado. Na troca feita pelo próprio usuário, o frontend DEVE obter um token novo para a sessão atual, de modo que a pessoa continue logada.

#### Scenario: Sessão antiga cai
- **GIVEN** Ana está logada em dois computadores
- **WHEN** ela troca a senha no primeiro computador
- **THEN** o primeiro computador continua logado
- **AND** a próxima requisição do segundo computador é recusada como não autenticada

#### Scenario: Redefinição derruba a sessão do titular
- **GIVEN** Carlos está logado
- **WHEN** um admin redefine a senha de Carlos
- **THEN** a próxima requisição de Carlos é recusada como não autenticada

### Requirement: Senha provisória
Uma conta com senha provisória (criada do zero pelo principal ou com senha redefinida por um admin) DEVE (MUST) conseguir fazer login, mas toda rota autenticada, exceto trocar a própria senha e consultar o usuário atual, DEVE recusar a requisição com a mensagem "Troque sua senha para continuar.". A regra é garantida no backend; chamar a API diretamente não a contorna.

#### Scenario: Primeiro acesso com senha provisória
- **GIVEN** Lia tem senha provisória
- **WHEN** ela faz login
- **THEN** o login é aceito e a resposta indica que a senha precisa ser trocada

#### Scenario: Tentativa de usar o sistema antes de trocar
- **GIVEN** Lia está logada com senha provisória
- **WHEN** ela chama diretamente a rota de pedidos de cadastro
- **THEN** o sistema recusa com "Troque sua senha para continuar."

#### Scenario: Depois da troca
- **GIVEN** Lia trocou a senha provisória
- **WHEN** ela navega pelo sistema
- **THEN** todas as rotas permitidas ao papel dela funcionam normalmente

### Requirement: Redefinição de senha pelo admin
Um admin DEVE (MUST) poder redefinir a senha de uma conta `ATIVA`, informando uma senha provisória de no mínimo 8 caracteres:
- qualquer admin, para alunos, professores e coordenadores;
- só o admin principal, para admins secundários;
- ninguém, para o admin principal, que só troca a própria senha.

A redefinição marca a senha como provisória e derruba as sessões do titular.

#### Scenario: Admin redefine senha de professor
- **WHEN** um admin secundário redefine a senha de Carlos
- **THEN** Carlos passa a ter senha provisória e precisa trocá-la no próximo login

#### Scenario: Secundário tenta redefinir senha de outro admin
- **WHEN** um admin secundário tenta redefinir a senha de outro admin
- **THEN** o sistema responde com acesso negado

#### Scenario: Redefinir senha do principal
- **WHEN** qualquer admin tenta redefinir a senha do admin principal
- **THEN** o sistema recusa a operação

#### Scenario: Não admin tenta redefinir
- **WHEN** um coordenador tenta redefinir a senha de um professor
- **THEN** o sistema responde com acesso negado

### Requirement: Telas de senha
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Trocar senha" (senha atual, nova e confirmação). Quando o login indicar senha provisória, ou quando a API responder "Troque sua senha para continuar.", o frontend DEVE levar a pessoa para essa página e o menu DEVE mostrar apenas ela e "Sair" até a troca.

#### Scenario: Redirecionamento obrigatório
- **GIVEN** Lia tem senha provisória
- **WHEN** ela faz login pela página
- **THEN** ela é levada para "Trocar senha" e não consegue navegar para outras páginas antes de trocar
