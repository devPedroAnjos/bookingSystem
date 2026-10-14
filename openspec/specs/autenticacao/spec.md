# Especificação: Autenticação

## Purpose

Identificar quem usa o BookingSystem. Esta capability cobre o cadastro com e-mail institucional, a situação da conta, o login com token, a consulta do usuário atual e a sessão no frontend. Ela é a base de toda autorização por papel e por unidade.

## Requirements
### Requirement: Cadastro com e-mail institucional
O sistema DEVE (MUST) aceitar cadastro apenas com e-mail cujo domínio (a parte após `@`) seja exatamente um dos domínios aceitos configurados em `ConfiguracaoGeral`. A comparação ignora maiúsculas e minúsculas. O e-mail DEVE ser normalizado (sem espaços nas pontas e em minúsculas) antes de validar e gravar. São obrigatórios: nome, e-mail, senha (mínimo de 8 caracteres) e tipo de vínculo (`ALUNO` ou `PROFESSOR`).

#### Scenario: Aluno se cadastra com domínio aceito
- **GIVEN** os domínios aceitos são `aluno.impacta.edu.br` e `impacta.edu.br`
- **WHEN** um visitante se cadastra como `ALUNO` com o e-mail `Ana.Souza@Aluno.Impacta.edu.br`, nome e senha válidos
- **THEN** o sistema cria a conta com e-mail `ana.souza@aluno.impacta.edu.br`, papel `ALUNO` e situação `ATIVA`
- **AND** responde com sucesso, sem devolver token

#### Scenario: Domínio não aceito
- **GIVEN** os domínios aceitos são `aluno.impacta.edu.br` e `impacta.edu.br`
- **WHEN** um visitante se cadastra com o e-mail `ana@gmail.com`
- **THEN** o sistema recusa o cadastro com uma mensagem pedindo o e-mail institucional
- **AND** nenhuma conta é criada

#### Scenario: Subdomínio não listado
- **GIVEN** os domínios aceitos são `aluno.impacta.edu.br` e `impacta.edu.br`
- **WHEN** um visitante se cadastra com o e-mail `ana@ti.impacta.edu.br`
- **THEN** o sistema recusa o cadastro, porque `ti.impacta.edu.br` não é exatamente um domínio aceito

#### Scenario: Domínio aceito é parâmetro
- **GIVEN** o administrador alterou os domínios aceitos para incluir `parceiro.edu.br`
- **WHEN** um visitante se cadastra com o e-mail `joao@parceiro.edu.br`
- **THEN** o cadastro é aceito, sem nenhuma mudança de código

#### Scenario: Campos obrigatórios ou senha curta
- **WHEN** um visitante envia o cadastro sem nome, ou com senha de menos de 8 caracteres
- **THEN** o sistema recusa o cadastro indicando o campo inválido
- **AND** nenhuma conta é criada

### Requirement: Cadastro de professor fica pendente
O cadastro com vínculo `PROFESSOR` DEVE (MUST) informar uma unidade de vínculo existente e ativa. A conta DEVE nascer com papel `PROFESSOR` e situação `PENDENTE`.

#### Scenario: Professor se cadastra com unidade válida
- **GIVEN** existe a unidade ativa "Paulista"
- **WHEN** um visitante se cadastra como `PROFESSOR` com e-mail aceito e unidade de vínculo "Paulista"
- **THEN** o sistema cria a conta com papel `PROFESSOR`, situação `PENDENTE` e unidade de vínculo "Paulista"
- **AND** responde informando que a conta aguarda aprovação

#### Scenario: Professor sem unidade de vínculo
- **WHEN** um visitante se cadastra como `PROFESSOR` sem informar a unidade de vínculo
- **THEN** o sistema recusa o cadastro indicando que a unidade é obrigatória

#### Scenario: Unidade inexistente ou inativa
- **WHEN** um visitante se cadastra como `PROFESSOR` informando uma unidade que não existe ou está inativa
- **THEN** o sistema recusa o cadastro
- **AND** nenhuma conta é criada

#### Scenario: Aluno com unidade informada
- **WHEN** um visitante se cadastra como `ALUNO` e envia também uma unidade de vínculo
- **THEN** a conta é criada como `ALUNO` e `ATIVA`, sem unidade de vínculo

### Requirement: Cadastro não atribui papéis privilegiados
O cadastro público DEVE (MUST) aceitar somente os vínculos `ALUNO` e `PROFESSOR`. Os papéis `COORDENADOR` e `ADMIN` NÃO DEVEM (MUST NOT) ser obtidos pelo cadastro, nem por nenhum campo enviado pelo visitante, como papel, situação ou dados de aprovação.

#### Scenario: Tentativa de se cadastrar como administrador
- **WHEN** um visitante envia o cadastro com vínculo `ADMIN` ou `COORDENADOR`
- **THEN** o sistema recusa o cadastro
- **AND** nenhuma conta é criada

#### Scenario: Tentativa de forçar situação ativa
- **WHEN** um visitante se cadastra como `PROFESSOR` e envia também `status_conta = ATIVA`
- **THEN** o campo extra é ignorado e a conta nasce `PENDENTE`

### Requirement: E-mail duplicado não é revelado
O cadastro com um e-mail já existente DEVE (MUST) ser recusado com uma mensagem genérica, que não confirma a existência da conta. A conta existente NÃO DEVE (MUST NOT) ser alterada.

#### Scenario: E-mail já cadastrado
- **GIVEN** existe uma conta com o e-mail `ana@aluno.impacta.edu.br`
- **WHEN** um visitante tenta se cadastrar com `ANA@aluno.impacta.edu.br`
- **THEN** o sistema responde "Não foi possível concluir o cadastro. Se você já tem conta, faça login."
- **AND** a conta existente permanece inalterada

### Requirement: Senha armazenada apenas como hash
A senha DEVE (MUST) ser armazenada apenas como hash. Nenhuma resposta da API, nenhum registro de auditoria e nenhum log PODE (MUST NOT) conter a senha ou o hash.

#### Scenario: Resposta do cadastro e do usuário atual
- **WHEN** uma conta é criada ou o usuário atual é consultado
- **THEN** a resposta não contém a senha nem o hash dela

### Requirement: Login com token
O sistema DEVE (MUST) emitir um token de autenticação somente para uma conta `ATIVA` com e-mail e senha corretos. O e-mail é normalizado antes da comparação. Um e-mail inexistente e uma senha errada DEVEM produzir a mesma resposta genérica. Para contas que não estão `ATIVA`, a situação só é revelada quando a senha está correta.

#### Scenario: Login bem-sucedido
- **GIVEN** existe a conta `ATIVA` de `ana@aluno.impacta.edu.br`
- **WHEN** ela faz login com `Ana@aluno.impacta.edu.br` e a senha correta
- **THEN** o sistema devolve um token e os dados básicos do usuário (id, nome, e-mail, papel)

#### Scenario: Senha errada ou e-mail inexistente
- **WHEN** alguém faz login com a senha errada de uma conta existente, ou com um e-mail não cadastrado
- **THEN** o sistema responde "E-mail ou senha inválidos." nos dois casos, com o mesmo código de erro
- **AND** nenhum token é emitido

#### Scenario: Professor pendente com senha correta
- **GIVEN** existe a conta `PENDENTE` do professor `carlos@impacta.edu.br`
- **WHEN** ele faz login com a senha correta
- **THEN** o sistema responde que a conta aguarda aprovação
- **AND** nenhum token é emitido

#### Scenario: Professor pendente com senha errada
- **GIVEN** existe a conta `PENDENTE` do professor `carlos@impacta.edu.br`
- **WHEN** alguém faz login com esse e-mail e a senha errada
- **THEN** o sistema responde "E-mail ou senha inválidos.", sem revelar a situação da conta

#### Scenario: Conta recusada ou inativa com senha correta
- **GIVEN** existe uma conta com situação `RECUSADA` ou `INATIVA`
- **WHEN** o titular faz login com a senha correta
- **THEN** o sistema responde que o acesso não está liberado para essa conta
- **AND** nenhum token é emitido

### Requirement: Consulta do usuário atual
O sistema DEVE (MUST) devolver os dados do usuário autenticado (id, nome, e-mail, papel, situação da conta e unidade de vínculo) a partir de um token válido. As rotas que exigem autenticação DEVEM recusar requisições sem token, com token inválido ou com token expirado.

#### Scenario: Token válido
- **GIVEN** Ana fez login e recebeu um token
- **WHEN** a rota do usuário atual é chamada com esse token
- **THEN** o sistema devolve os dados de Ana, sem senha nem hash

#### Scenario: Sem token ou token inválido
- **WHEN** a rota do usuário atual é chamada sem token, com um token adulterado ou com um token expirado
- **THEN** o sistema responde com erro de não autenticado
- **AND** não devolve dados de nenhum usuário

#### Scenario: Conta deixou de estar ativa
- **GIVEN** Ana tem um token ainda válido
- **AND** a conta dela passou a `INATIVA`
- **WHEN** a rota do usuário atual é chamada com esse token
- **THEN** o sistema responde com erro de não autenticado

### Requirement: Administrador inicial
O sistema DEVE (MUST) oferecer um procedimento de bootstrap que cria a primeira conta `ADMIN` (`ATIVA`) com e-mail, nome e senha vindos de variáveis de ambiente do backend. O procedimento DEVE ser idempotente e as credenciais NÃO DEVEM (MUST NOT) ser versionadas.

#### Scenario: Primeira execução
- **GIVEN** não existe nenhuma conta `ADMIN`
- **AND** as variáveis de ambiente do administrador inicial estão definidas
- **WHEN** o bootstrap é executado
- **THEN** é criada uma conta `ADMIN` e `ATIVA` com esses dados
- **AND** o administrador consegue fazer login

#### Scenario: Execução repetida
- **GIVEN** já existe uma conta `ADMIN`
- **WHEN** o bootstrap é executado novamente
- **THEN** nenhuma conta é criada ou alterada

#### Scenario: Variáveis ausentes
- **GIVEN** não existe nenhuma conta `ADMIN`
- **WHEN** o bootstrap é executado sem as variáveis de ambiente definidas
- **THEN** o procedimento falha com uma mensagem clara e nenhuma conta é criada

### Requirement: Sessão no frontend
O frontend DEVE (MUST) manter o token apenas no estado do servidor. O token NÃO DEVE (MUST NOT) ser enviado ao navegador, nem gravado em cookie, `localStorage` ou log. As páginas que exigem sessão DEVEM redirecionar para o login quando não houver sessão. Esse redirecionamento é usabilidade, não segurança.

#### Scenario: Login pela página
- **WHEN** Ana entra com credenciais válidas na página `/login`
- **THEN** ela é levada à página `/inicio`, que mostra o nome e o papel dela

#### Scenario: Página protegida sem sessão
- **WHEN** um visitante sem sessão abre `/inicio`
- **THEN** ele é redirecionado para `/login`

#### Scenario: Token expirado durante o uso
- **GIVEN** Ana está em `/inicio`
- **AND** o token dela expirou
- **WHEN** o frontend recebe da API um erro de não autenticado
- **THEN** a sessão é descartada e Ana é levada para `/login` com o aviso de que a sessão expirou

#### Scenario: Logout
- **WHEN** Ana clica em "Sair"
- **THEN** o token é descartado do estado do servidor e ela é levada para `/login`
- **AND** ao abrir `/inicio` em seguida, ela é redirecionada para `/login`

#### Scenario: Token não chega ao navegador
- **GIVEN** Ana está logada
- **WHEN** inspecionamos cookies, `localStorage`, `sessionStorage` e as mensagens trocadas entre o navegador e o servidor Reflex
- **THEN** o token não aparece em nenhum deles

#### Scenario: Cadastro pela página
- **WHEN** um visitante preenche a página `/cadastro` como `PROFESSOR`
- **THEN** a página oferece a lista de unidades ativas para escolher a unidade de vínculo
- **AND** depois do envio mostra a mensagem devolvida pela API: conta criada, conta aguardando aprovação ou o erro correspondente
