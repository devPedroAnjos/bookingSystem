## Purpose

Decidir os pedidos de cadastro de professor e de coordenador. A capability cobre quem pode aprovar cada papel, a recusa com motivo, a garantia de uma única decisão por pedido, o reenvio com limite de pedidos e a correção de recusas pelo administrador.

## ADDED Requirements

### Requirement: Listagem de pedidos pendentes
O sistema DEVE (MUST) listar as contas `PENDENTE`, com id, nome, e-mail, papel pedido, unidade pedida, número do pedido, justificativa (se houver) e data de criação, da mais antiga para a mais nova.
- O admin vê todos os pedidos, de professor e de coordenador.
- O coordenador vê só os pedidos de **professor** cuja unidade pedida é uma unidade que ele coordena com conta `ATIVA`.
- Aluno e professor NÃO DEVEM (MUST NOT) acessar a listagem.

#### Scenario: Coordenador vê só professores das próprias unidades
- **GIVEN** Rui coordena apenas "Paulista"
- **AND** há um professor pendente em "Paulista", outro em "Vila Olímpia" e um coordenador pendente em "Paulista"
- **WHEN** Rui consulta os pedidos pendentes
- **THEN** o sistema devolve apenas o professor pendente em "Paulista"

#### Scenario: Admin vê todos
- **WHEN** o admin consulta os pedidos pendentes
- **THEN** o sistema devolve os três pedidos, do mais antigo para o mais novo

#### Scenario: Aluno tenta listar
- **WHEN** um aluno ou professor consulta os pedidos pendentes
- **THEN** o sistema responde com acesso negado

### Requirement: Aprovação de professor
O sistema DEVE (MUST) permitir aprovar um pedido `PENDENTE` de professor:
- ao admin, para qualquer unidade;
- ao coordenador ativo da unidade pedida.

A aprovação DEVE mudar a situação para `ATIVA` e registrar quem aprovou e quando. A unidade pedida passa a ser a unidade do professor e precisa estar ativa no momento da aprovação.

#### Scenario: Coordenador aprova professor da própria unidade
- **GIVEN** Rui coordena "Paulista" e Carlos é professor `PENDENTE` em "Paulista"
- **WHEN** Rui aprova Carlos
- **THEN** a conta de Carlos passa a `ATIVA`, com Rui como aprovador e a data/hora
- **AND** "Paulista" passa a ser a unidade de Carlos
- **AND** Carlos consegue fazer login

#### Scenario: Unidade do pedido desativada
- **GIVEN** Carlos está `RECUSADA` porque a unidade pedida "Paulista" foi desativada
- **WHEN** o admin tenta aprovar a conta de Carlos sem que ele tenha escolhido outra unidade
- **THEN** o sistema recusa informando que a unidade está desativada e a conta não muda

#### Scenario: Coordenador de outra unidade
- **GIVEN** Rui coordena apenas "Paulista" e Beatriz é professora `PENDENTE` em "Vila Olímpia"
- **WHEN** Rui tenta aprovar Beatriz
- **THEN** o sistema responde com acesso negado e a conta continua `PENDENTE`

### Requirement: Aprovação de coordenador
Somente o admin DEVE (MUST) aprovar um pedido `PENDENTE` de coordenador. Na mesma operação, a aprovação DEVE:
- mudar a situação para `ATIVA`;
- registrar quem aprovou e quando;
- criar a coordenação da unidade pedida.

A aprovação DEVE ser recusada, sem alterar nada, se a unidade pedida estiver desativada ou já tiver o número máximo de coordenadores ativos.

#### Scenario: Admin aprova coordenador
- **GIVEN** Ana é coordenadora `PENDENTE` com unidade pedida "Paulista", que tem vaga
- **WHEN** o admin aprova Ana
- **THEN** Ana passa a `ATIVA` e coordena "Paulista"

#### Scenario: Coordenador tenta aprovar coordenador
- **GIVEN** Rui coordena "Paulista" e Ana é coordenadora `PENDENTE` em "Paulista"
- **WHEN** Rui tenta aprovar Ana
- **THEN** o sistema responde com acesso negado

#### Scenario: Unidade cheia
- **GIVEN** o limite é de 4 coordenadores por unidade e "Paulista" já tem 4 coordenadores ativos
- **WHEN** o admin tenta aprovar uma coordenadora pendente em "Paulista"
- **THEN** o sistema recusa informando que a unidade não tem vaga
- **AND** a conta continua `PENDENTE` e nenhuma coordenação é criada

#### Scenario: Unidade desativada
- **GIVEN** Ana está `RECUSADA` porque a unidade pedida foi desativada
- **WHEN** o admin tenta aprovar Ana sem que ela tenha escolhido outra unidade
- **THEN** o sistema recusa informando que a unidade está desativada e a conta não muda

### Requirement: Recusa com motivo
O sistema DEVE (MUST) permitir recusar um pedido `PENDENTE`, com as mesmas permissões da aprovação do respectivo papel. A recusa DEVE exigir um motivo não vazio, de até 500 caracteres. Ela muda a situação para `RECUSADA` e registra quem recusou, quando e o motivo.

#### Scenario: Recusa com motivo
- **WHEN** o coordenador de "Paulista" recusa o professor pendente Carlos com o motivo "Unidade incorreta"
- **THEN** a conta de Carlos passa a `RECUSADA`, com o motivo, o responsável e a data/hora

#### Scenario: Recusa sem motivo
- **WHEN** alguém tenta recusar um pedido com o motivo vazio ou só com espaços
- **THEN** o sistema recusa a operação pedindo o motivo e a conta continua `PENDENTE`

### Requirement: Decisão única por pedido
Cada pedido pendente DEVE (MUST) receber no máximo uma decisão. Se duas decisões forem enviadas ao mesmo tempo para a mesma conta, só a primeira gravada vale. A outra DEVE ser recusada com a mensagem de que o pedido já foi decidido, sem alterar nada e sem gerar auditoria. Uma decisão sobre uma conta que não está na situação esperada também DEVE ser recusada.

#### Scenario: Aprovação e recusa simultâneas
- **GIVEN** Carlos é professor `PENDENTE` em "Paulista"
- **WHEN** o admin aprova e o coordenador de "Paulista" recusa Carlos ao mesmo tempo
- **THEN** a conta termina em exatamente uma situação, `ATIVA` ou `RECUSADA`
- **AND** existe exatamente um registro de auditoria de decisão desse pedido
- **AND** quem perdeu recebe a mensagem de que o pedido já foi decidido

#### Scenario: Conta já ativa
- **WHEN** alguém tenta aprovar ou recusar uma conta `ATIVA`
- **THEN** o sistema recusa informando que não há pedido pendente

### Requirement: Reenvio do pedido
O titular de uma conta `RECUSADA` DEVE (MUST) poder pedir nova análise, sem token, informando e-mail e senha corretos, enquanto o número de pedidos já enviados for menor que o limite definido em `ConfiguracaoGeral` (padrão: 3), ou quando a última recusa foi automática por desativação da unidade. No reenvio, ele PODE:
- trocar a unidade pedida, que precisa estar ativa;
- trocar o papel pedido entre `PROFESSOR` e `COORDENADOR`;
- escrever uma justificativa opcional, de até 500 caracteres.

O reenvio DEVE:
- voltar a conta para `PENDENTE`;
- somar 1 ao número de pedidos, **exceto** quando a última recusa foi automática por desativação da unidade;
- limpar o motivo da recusa anterior, que continua na auditoria.

Senha errada DEVE produzir a resposta genérica do login.

#### Scenario: Reenvio com troca de unidade
- **GIVEN** o pedido de Carlos para "Paulista" foi recusado com o motivo "Unidade incorreta", e ele enviou 1 de 3 pedidos
- **WHEN** Carlos pede nova análise com a unidade "Vila Olímpia" e a justificativa "Leciono na Vila Olímpia"
- **THEN** a conta volta a `PENDENTE`, com unidade pedida "Vila Olímpia", justificativa registrada e 2 pedidos contabilizados
- **AND** o pedido aparece para o admin e para os coordenadores de "Vila Olímpia"

#### Scenario: Reenvio trocando o papel
- **GIVEN** o pedido de Ana como professora foi recusado
- **WHEN** Ana pede nova análise como `COORDENADOR`
- **THEN** a conta volta a `PENDENTE` com papel pedido `COORDENADOR`, e só o admin pode decidi-la

#### Scenario: Limite de pedidos atingido
- **GIVEN** Carlos já enviou 3 pedidos e o último foi recusado
- **WHEN** ele tenta pedir nova análise
- **THEN** o sistema recusa informando que os pedidos se esgotaram e que é preciso procurar a administração

#### Scenario: Conta não recusada
- **WHEN** o titular de uma conta `PENDENTE` ou `ATIVA` tenta pedir nova análise
- **THEN** o sistema recusa a operação e nada muda

### Requirement: Recusa automática por desativação da unidade
Ao desativar uma unidade, o sistema DEVE (MUST) recusar automaticamente, na mesma operação, todos os pedidos `PENDENTE` (de professor e de coordenador) cuja unidade pedida é essa, com o motivo "Unidade desativada". Essa recusa NÃO DEVE (MUST NOT) consumir pedido: o reenvio seguinte não soma 1 ao número de pedidos. O titular pode reenviar escolhendo uma unidade ativa mesmo que já tenha atingido o limite de pedidos.

#### Scenario: Professor pendente em unidade desativada
- **GIVEN** Carlos é professor `PENDENTE` em "Paulista", com 1 pedido contabilizado
- **WHEN** o admin desativa "Paulista"
- **THEN** a conta de Carlos passa a `RECUSADA` com o motivo "Unidade desativada"
- **AND** ao tentar entrar, Carlos vê o motivo e a opção "Pedir nova análise"

#### Scenario: Reenvio sem consumir pedido
- **GIVEN** Carlos foi recusado automaticamente pela desativação de "Paulista", com 1 pedido contabilizado
- **WHEN** Carlos pede nova análise escolhendo "Vila Olímpia"
- **THEN** a conta volta a `PENDENTE` em "Vila Olímpia" e continua com 1 pedido contabilizado

#### Scenario: Limite atingido e recusa por desativação
- **GIVEN** Ana já enviou 3 pedidos e o terceiro está `PENDENTE` em "Centro"
- **WHEN** "Centro" é desativada e Ana é recusada automaticamente
- **THEN** Ana ainda pode pedir nova análise escolhendo uma unidade ativa

### Requirement: Admin aprova conta recusada
Somente o admin DEVE (MUST) poder aprovar uma conta `RECUSADA`, com ou sem pedidos disponíveis, mudando-a para `ATIVA`, com as mesmas regras da aprovação do papel pedido (unidade ativa, e com vaga no caso de coordenador). O motivo da recusa é limpo e continua na auditoria. O coordenador NÃO DEVE (MUST NOT) aprovar uma conta `RECUSADA`.

#### Scenario: Admin corrige recusa
- **GIVEN** Carlos esgotou os pedidos e está `RECUSADA`
- **WHEN** o admin aprova a conta de Carlos
- **THEN** a conta passa a `ATIVA`, sem motivo de recusa, com o admin como aprovador

#### Scenario: Coordenador tenta aprovar recusada
- **GIVEN** Carlos, professor de "Paulista", está `RECUSADA`, e Rui coordena "Paulista"
- **WHEN** Rui tenta aprovar Carlos
- **THEN** o sistema responde com acesso negado

### Requirement: Tela de aprovações
O frontend DEVE (MUST) oferecer, ao admin e ao coordenador, uma página de pedidos pendentes, com aprovar e recusar. A recusa abre um campo de motivo obrigatório. O admin também vê nessa página as contas `RECUSADA`, para poder aprová-las. Depois de cada ação, a página mostra a mensagem da API e recarrega a lista.

#### Scenario: Recusa sem motivo pela página
- **WHEN** um coordenador tenta confirmar uma recusa sem preencher o motivo
- **THEN** a página pede o motivo e não envia a recusa

#### Scenario: Pedido decidido por outra pessoa
- **GIVEN** o admin está com a lista aberta e outro usuário já decidiu o pedido de Carlos
- **WHEN** o admin tenta decidir Carlos
- **THEN** a página mostra que o pedido já foi decidido e recarrega a lista
