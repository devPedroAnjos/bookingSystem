# Especificação: Autenticação

## Purpose

Identificar quem usa o BookingSystem. Esta capability cobre o cadastro com e-mail institucional, a situação da conta, o login com token, a consulta do usuário atual e a sessão no frontend. Ela é a base de toda autorização por papel e por unidade.

## Requirements

### Requirement: Cadastro com e-mail institucional
O sistema DEVE (MUST) aceitar cadastro apenas com e-mail cujo domínio (a parte após `@`) seja exatamente um dos domínios aceitos configurados em `ConfiguracaoGeral`. A comparação ignora maiúsculas e minúsculas. O e-mail DEVE ser normalizado (sem espaços nas pontas e em minúsculas) antes de validar e gravar. São obrigatórios: nome, e-mail, senha (mínimo de 8 caracteres) e tipo de vínculo (`ALUNO`, `PROFESSOR` ou `COORDENADOR`).

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
O cadastro público DEVE (MUST) aceitar somente os vínculos `ALUNO`, `PROFESSOR` e `COORDENADOR`. O papel `ADMIN` NÃO DEVE (MUST NOT) ser obtido pelo cadastro. Nenhum campo enviado pelo visitante, como papel, situação, dados de aprovação ou coordenações, PODE (MUST NOT) tornar a conta `ATIVA` sem aprovação ou criar vínculo de coordenação.

#### Scenario: Tentativa de se cadastrar como administrador
- **WHEN** um visitante envia o cadastro com vínculo `ADMIN`
- **THEN** o sistema recusa o cadastro
- **AND** nenhuma conta é criada

#### Scenario: Tentativa de forçar situação ativa
- **WHEN** um visitante se cadastra como `PROFESSOR` ou `COORDENADOR` e envia também `status_conta = ATIVA`
- **THEN** o campo extra é ignorado e a conta nasce `PENDENTE`
- **AND** nenhuma coordenação de unidade é criada

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
O sistema DEVE (MUST) emitir um token de autenticação somente para uma conta `ATIVA` com e-mail e senha corretos. O e-mail é normalizado antes da comparação. Um e-mail inexistente e uma senha errada DEVEM produzir a mesma resposta genérica. Para contas que não estão `ATIVA`, a situação só é revelada quando a senha está correta. Para uma conta `RECUSADA` com senha correta, a resposta DEVE incluir o motivo da última recusa. Para uma conta com senha provisória, o token é emitido e a resposta DEVE indicar que a senha precisa ser trocada. O token DEVE registrar o momento da emissão, para que trocas de senha posteriores o invalidem.

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
- **GIVEN** o cadastro de `carlos@impacta.edu.br` foi recusado com o motivo "Unidade incorreta"
- **AND** existe outra conta com situação `INATIVA`
- **WHEN** cada titular faz login com a senha correta
- **THEN** Carlos recebe a resposta de que o cadastro foi recusado, com o motivo "Unidade incorreta"
- **AND** o titular da conta inativa recebe a resposta de que o acesso não está liberado para essa conta
- **AND** nenhum token é emitido

#### Scenario: Conta recusada com senha errada
- **GIVEN** a conta de `carlos@impacta.edu.br` está `RECUSADA`
- **WHEN** alguém faz login com esse e-mail e a senha errada
- **THEN** o sistema responde "E-mail ou senha inválidos.", sem revelar a situação nem o motivo

#### Scenario: Conta com senha provisória
- **GIVEN** Lia é admin com senha provisória
- **WHEN** ela faz login com a senha provisória correta
- **THEN** o sistema devolve o token e indica que a senha precisa ser trocada

### Requirement: Consulta do usuário atual
O sistema DEVE (MUST) devolver os dados do usuário autenticado (id, nome, e-mail, papel, situação da conta, unidade de vínculo, se é o admin principal e se a senha é provisória) a partir de um token válido. As rotas que exigem autenticação DEVEM recusar requisições sem token, com token inválido, com token expirado ou com token emitido antes da última troca ou redefinição de senha da conta.

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

#### Scenario: Token anterior à troca de senha
- **GIVEN** Ana tem um token emitido antes de trocar a senha
- **WHEN** a rota do usuário atual é chamada com esse token
- **THEN** o sistema responde com erro de não autenticado

### Requirement: Administrador inicial
O sistema DEVE (MUST) oferecer um procedimento de bootstrap que cria a primeira conta `ADMIN` (`ATIVA`) com e-mail, nome e senha vindos de variáveis de ambiente do backend, marcada como **admin principal**. Se já existir um admin sem nenhum principal marcado, o bootstrap DEVE marcar como principal o admin mais antigo. O procedimento DEVE ser idempotente e as credenciais NÃO DEVEM (MUST NOT) ser versionadas.

#### Scenario: Primeira execução
- **GIVEN** não existe nenhuma conta `ADMIN`
- **AND** as variáveis de ambiente do administrador inicial estão definidas
- **WHEN** o bootstrap é executado
- **THEN** é criada uma conta `ADMIN` e `ATIVA` com esses dados, marcada como principal
- **AND** o administrador consegue fazer login

#### Scenario: Execução repetida
- **GIVEN** já existe uma conta `ADMIN` marcada como principal
- **WHEN** o bootstrap é executado novamente
- **THEN** nenhuma conta é criada ou alterada

#### Scenario: Variáveis ausentes
- **GIVEN** não existe nenhuma conta `ADMIN`
- **WHEN** o bootstrap é executado sem as variáveis de ambiente definidas
- **THEN** o procedimento falha com uma mensagem clara e nenhuma conta é criada

#### Scenario: Admin existente sem marca de principal
- **GIVEN** existe o admin criado na C1, ainda sem a marca de principal
- **WHEN** o bootstrap é executado
- **THEN** esse admin passa a ser o principal e nenhuma conta é criada

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

### Requirement: Cadastro de coordenador fica pendente
O cadastro com vínculo `COORDENADOR` DEVE (MUST) informar uma unidade existente e ativa, que é a unidade que a pessoa pede para coordenar. A conta DEVE nascer com papel `COORDENADOR`, situação `PENDENTE`, sem nenhuma coordenação de unidade, e com 1 pedido de cadastro contabilizado. O cadastro de professor também contabiliza 1 pedido.

#### Scenario: Coordenador se cadastra
- **GIVEN** existe a unidade ativa "Paulista"
- **WHEN** um visitante se cadastra como `COORDENADOR` com e-mail aceito e unidade "Paulista"
- **THEN** o sistema cria a conta com papel `COORDENADOR`, situação `PENDENTE`, unidade pedida "Paulista" e 1 pedido contabilizado
- **AND** a conta ainda não coordena nenhuma unidade
- **AND** a resposta informa que a conta aguarda aprovação da administração

#### Scenario: Coordenador sem unidade
- **WHEN** um visitante se cadastra como `COORDENADOR` sem informar a unidade, ou com uma unidade inexistente ou inativa
- **THEN** o sistema recusa o cadastro e nenhuma conta é criada

### Requirement: Consulta da situação do pedido
O sistema DEVE (MUST) oferecer, sem token, a consulta da situação do próprio pedido de cadastro mediante e-mail e senha. Para conta `PENDENTE` ou `RECUSADA` com senha correta, a resposta traz:
- situação;
- papel pedido;
- unidade pedida;
- motivo da última recusa, se houver;
- quantos pedidos ainda podem ser enviados.

Para senha errada, e-mail inexistente ou conta em outra situação, a resposta DEVE ser a mesma mensagem genérica do login.

#### Scenario: Recusado consulta o pedido
- **GIVEN** Carlos teve 1 pedido recusado com o motivo "Unidade incorreta" e o limite é de 3 pedidos
- **WHEN** ele consulta a situação com a senha correta
- **THEN** o sistema informa `RECUSADA`, o motivo "Unidade incorreta" e que ainda pode enviar 2 pedidos

#### Scenario: Senha errada
- **WHEN** alguém consulta a situação de um pedido com a senha errada
- **THEN** o sistema responde "E-mail ou senha inválidos." e não revela nada sobre a conta

#### Scenario: Conta ativa
- **WHEN** o titular de uma conta `ATIVA` consulta a situação do pedido com a senha correta
- **THEN** o sistema responde com a mensagem genérica, sem dados da conta

### Requirement: Telas de cadastro e login com pedido
A página de cadastro DEVE (MUST) oferecer a opção "Coordenador", com a escolha da unidade. Quando o login for recusado por conta `RECUSADA`, a página DEVE mostrar o motivo. Se ainda houver pedidos disponíveis, a página DEVE oferecer "Pedir nova análise", com a escolha de unidade, de papel (professor ou coordenador) e uma justificativa opcional. Se não houver, a página DEVE informar que é preciso procurar a administração.

#### Scenario: Recusado pede nova análise pela página
- **GIVEN** o cadastro de Carlos foi recusado e ele ainda tem pedidos disponíveis
- **WHEN** ele tenta entrar com a senha correta
- **THEN** a página mostra o motivo e a opção "Pedir nova análise"

#### Scenario: Sem pedidos disponíveis
- **GIVEN** Carlos já usou os 3 pedidos e foi recusado
- **WHEN** ele tenta entrar com a senha correta
- **THEN** a página mostra o motivo e informa que é preciso procurar a administração, sem a opção de novo pedido
