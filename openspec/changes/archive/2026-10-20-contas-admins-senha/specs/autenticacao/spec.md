## MODIFIED Requirements

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
