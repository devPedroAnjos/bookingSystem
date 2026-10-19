# Especificação: Papéis

## Purpose

Permitir que a administração ajuste o papel de alunos, professores e coordenadores depois do cadastro, e transfira professores entre unidades, sem nunca deixar um coordenador sem unidade nem um professor sem unidade. A gestão de papéis de administradores é tratada por uma change posterior.

## Requirements
### Requirement: Mudança de papel pelo admin
Somente o admin DEVE (MUST) poder mudar o papel de uma conta `ATIVA`, apenas nestas direções:
- `ALUNO` → `PROFESSOR`;
- `PROFESSOR` → `COORDENADOR`;
- `COORDENADOR` → `PROFESSOR`.

Mudar qualquer conta para `ALUNO` NÃO DEVE (MUST NOT) ser permitido, e o aluno NÃO DEVE virar `COORDENADOR` diretamente: precisa ser professor antes. Regras:
- contas `PENDENTE` ou `RECUSADA` NÃO DEVEM (MUST NOT) ter o papel mudado: o pedido precisa ser decidido antes;
- contas `ADMIN` e o papel `ADMIN` estão fora desta operação;
- informar o papel atual DEVE ser recusado como alteração vazia;
- a mudança DEVE valer na próxima requisição do usuário afetado.

#### Scenario: Aluno vira professor
- **GIVEN** Ana é `ALUNO` `ATIVA`
- **WHEN** o admin muda o papel de Ana para `PROFESSOR` com a unidade "Paulista"
- **THEN** Ana passa a `PROFESSOR` e pertence a "Paulista"

#### Scenario: Voltar a aluno
- **WHEN** o admin tenta mudar o papel de um professor ou de um coordenador para `ALUNO`
- **THEN** o sistema recusa informando que essa mudança não é permitida e nada muda

#### Scenario: Aluno direto para coordenador
- **GIVEN** Ana é `ALUNO` `ATIVA`
- **WHEN** o admin tenta mudar o papel de Ana para `COORDENADOR`
- **THEN** o sistema recusa informando que ela precisa ser professora antes, e nada muda

#### Scenario: Conta pendente
- **WHEN** o admin tenta mudar o papel de uma conta `PENDENTE`
- **THEN** o sistema recusa informando que o pedido precisa ser decidido antes

#### Scenario: Promover a admin por esta operação
- **WHEN** o admin tenta mudar o papel de alguém para `ADMIN`, ou mudar o papel de um `ADMIN`
- **THEN** o sistema recusa a operação

#### Scenario: Coordenador tenta mudar papel
- **WHEN** um coordenador tenta mudar o papel de qualquer usuário
- **THEN** o sistema responde com acesso negado

### Requirement: Tornar-se coordenador exige unidade
A mudança de papel para `COORDENADOR` DEVE (MUST) informar, na mesma operação, de 1 até o máximo de unidades por coordenador. Todas as unidades precisam estar ativas e ter vaga. O papel e as coordenações DEVEM ser gravados juntos: se qualquer unidade for inválida, nada muda.

#### Scenario: Professor vira coordenador de uma unidade
- **GIVEN** Carlos é `PROFESSOR` `ATIVA` e "Paulista" tem vaga
- **WHEN** o admin muda o papel de Carlos para `COORDENADOR` com a unidade "Paulista"
- **THEN** Carlos passa a `COORDENADOR` e coordena "Paulista"

#### Scenario: Sem unidade
- **WHEN** o admin tenta mudar o papel de alguém para `COORDENADOR` sem informar unidade
- **THEN** o sistema recusa informando que é preciso escolher ao menos uma unidade

#### Scenario: Uma das unidades sem vaga
- **GIVEN** "Paulista" tem vaga e "Centro" está no limite de coordenadores
- **WHEN** o admin muda o papel de Carlos para `COORDENADOR` com "Paulista" e "Centro"
- **THEN** o sistema recusa informando que "Centro" não tem vaga
- **AND** Carlos continua `PROFESSOR`, sem coordenações

### Requirement: Tornar-se professor exige unidade
A mudança de papel para `PROFESSOR` DEVE (MUST) informar, na mesma operação, uma unidade ativa, que passa a ser a unidade do professor. A mudança para `COORDENADOR` DEVE limpar a unidade de professor da conta, porque o coordenador é definido pelas suas coordenações.

#### Scenario: Sem unidade
- **WHEN** o admin tenta mudar o papel de alguém para `PROFESSOR` sem informar unidade, ou com uma unidade desativada
- **THEN** o sistema recusa e nada muda

#### Scenario: Professor vira coordenador
- **GIVEN** Carlos é `PROFESSOR` de "Paulista"
- **WHEN** o admin muda o papel de Carlos para `COORDENADOR` com a unidade "Vila Olímpia"
- **THEN** Carlos coordena "Vila Olímpia" e deixa de ter unidade de professor

### Requirement: Deixar de ser coordenador remove as coordenações
Quando o papel de um `COORDENADOR` mudar para `PROFESSOR`, o sistema DEVE (MUST) remover, na mesma operação, todas as coordenações dele, mesmo que alguma unidade fique sem coordenador ativo. A resposta DEVE listar as unidades que deixaram de ser coordenadas. A unidade dele como professor é a informada na operação, que pode ser uma das que coordenava.

#### Scenario: Coordenador de duas unidades vira professor
- **GIVEN** Rui coordena "Paulista" e "Vila Olímpia"
- **WHEN** o admin muda o papel de Rui para `PROFESSOR` com a unidade "Paulista"
- **THEN** Rui passa a `PROFESSOR` de "Paulista" e deixa de coordenar as duas unidades
- **AND** a resposta lista "Paulista" e "Vila Olímpia"

### Requirement: Transferência de professor
Somente o admin DEVE (MUST) poder transferir um professor `ATIVA` para outra unidade ativa. O pedido de transferência acontece fora do sistema. A transferência muda apenas a unidade do professor; papel, situação e reservas não mudam. Transferir para a unidade atual DEVE ser recusado como alteração vazia.

#### Scenario: Transferir professor
- **GIVEN** Carlos é `PROFESSOR` de "Paulista"
- **WHEN** o admin transfere Carlos para "Vila Olímpia"
- **THEN** Carlos passa a pertencer a "Vila Olímpia"

#### Scenario: Destino inválido
- **WHEN** o admin tenta transferir um professor para uma unidade desativada, ou para a unidade em que ele já está
- **THEN** o sistema recusa e nada muda

#### Scenario: Coordenador tenta transferir
- **WHEN** um coordenador tenta transferir qualquer professor
- **THEN** o sistema responde com acesso negado

#### Scenario: Alvo não é professor
- **WHEN** o admin tenta transferir um aluno ou um coordenador
- **THEN** o sistema recusa informando que só professores são transferidos

### Requirement: Tela de usuários
O frontend DEVE (MUST) oferecer ao admin uma página de usuários, com filtros por papel, situação e texto no nome ou no e-mail. Cada usuário mostra a unidade de professor ou as unidades que coordena. Regras da página:
- oferecer só as mudanças de papel permitidas para o papel atual (nunca `ALUNO`);
- ao escolher o papel `COORDENADOR`, pedir 1 ou 2 unidades;
- ao escolher o papel `PROFESSOR`, pedir a unidade;
- ao tirar alguém do papel de coordenador, avisar quais unidades serão perdidas e pedir confirmação;
- oferecer "Transferir" para professores, com a escolha da unidade de destino.

#### Scenario: Aviso de perda de coordenação
- **GIVEN** Rui coordena "Paulista"
- **WHEN** o admin escolhe o papel `PROFESSOR` para Rui
- **THEN** a página avisa que Rui deixará de coordenar "Paulista" e pede confirmação antes de enviar

#### Scenario: Escolha de unidades
- **WHEN** o admin escolhe o papel `COORDENADOR` para um professor
- **THEN** a página exige escolher ao menos 1 e no máximo 2 unidades antes de enviar

#### Scenario: Transferir pela página
- **GIVEN** Carlos é professor de "Paulista"
- **WHEN** o admin escolhe "Transferir" para Carlos e seleciona "Vila Olímpia"
- **THEN** a lista passa a mostrar Carlos em "Vila Olímpia"
