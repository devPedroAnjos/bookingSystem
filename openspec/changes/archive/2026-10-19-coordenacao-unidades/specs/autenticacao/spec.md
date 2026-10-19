## MODIFIED Requirements

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

### Requirement: Login com token
O sistema DEVE (MUST) emitir um token de autenticação somente para uma conta `ATIVA` com e-mail e senha corretos. O e-mail é normalizado antes da comparação. Um e-mail inexistente e uma senha errada DEVEM produzir a mesma resposta genérica. Para contas que não estão `ATIVA`, a situação só é revelada quando a senha está correta. Para uma conta `RECUSADA` com senha correta, a resposta DEVE incluir o motivo da última recusa.

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

## ADDED Requirements

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
