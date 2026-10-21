## Purpose

Cadastrar os espaços físicos reserváveis de cada unidade, com tipo, capacidade e recursos, sob a autorização por papel e por unidade. Também define quando um espaço está disponível para reserva, regra que a busca e a reserva das próximas changes usam.

## ADDED Requirements

### Requirement: Criação de espaço
Admins (em qualquer unidade) e coordenadores (só nas unidades que coordenam) DEVEM (MUST) poder criar espaços. Na criação são informados:
- unidade, obrigatória e ativa;
- tipo de espaço, obrigatório e ativo;
- nome, obrigatório;
- código, obrigatório e único **dentro da unidade**, sem diferenciar maiúsculas e minúsculas e ignorando espaços nas pontas;
- capacidade, número inteiro maior ou igual a 1;
- localização e descrição, opcionais.

O espaço nasce ativo e sem recursos. Alunos e professores NÃO DEVEM (MUST NOT) criar espaços. Se qualquer regra falhar, nada é criado.

#### Scenario: Coordenador cria na própria unidade
- **GIVEN** Rui coordena "Paulista"
- **WHEN** Rui cria o espaço "Laboratório de Redes", código "LAB-01", tipo "Laboratório", capacidade 30, em "Paulista"
- **THEN** o espaço é criado, ativo, em "Paulista"

#### Scenario: Coordenador em outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta criar um espaço em "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e nada é criado

#### Scenario: Professor tenta criar
- **WHEN** um professor tenta criar um espaço
- **THEN** o sistema responde com acesso negado

#### Scenario: Mesmo código em outra unidade
- **GIVEN** "Paulista" tem o espaço de código "101"
- **WHEN** o admin cria em "Vila Olímpia" um espaço de código "101"
- **THEN** o espaço é criado

#### Scenario: Código repetido na mesma unidade
- **GIVEN** "Paulista" tem o espaço desativado de código "LAB-01"
- **WHEN** o admin tenta criar em "Paulista" um espaço de código " lab-01 "
- **THEN** o sistema recusa informando que a unidade já tem um espaço com esse código

#### Scenario: Unidade desativada
- **GIVEN** "Centro" está desativada
- **WHEN** o admin tenta criar um espaço em "Centro"
- **THEN** o sistema recusa informando que a unidade está desativada

#### Scenario: Tipo desativado
- **GIVEN** o tipo "Auditório" está desativado
- **WHEN** o admin tenta criar um espaço do tipo "Auditório"
- **THEN** o sistema recusa informando que o tipo está desativado

#### Scenario: Capacidade inválida
- **WHEN** alguém tenta criar um espaço com capacidade 0
- **THEN** o sistema recusa informando que a capacidade deve ser de pelo menos 1

#### Scenario: Criações simultâneas com o mesmo código
- **WHEN** dois gestores criam ao mesmo tempo, em "Paulista", espaços de código "101"
- **THEN** só um espaço é criado e o outro gestor recebe a recusa de código repetido

### Requirement: Edição de espaço
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder alterar nome, código, tipo, capacidade, localização e descrição, com as mesmas validações da criação. A unicidade do código desconsidera o próprio espaço. A exigência de tipo ativo vale **somente** quando o tipo muda: um espaço cujo tipo atual está desativado pode ter os outros campos editados. A edição NÃO DEVE (MUST NOT) mudar a unidade nem a situação do espaço. Como a desativação de uma unidade remove as coordenações dela, só o admin edita espaços de unidade desativada.

#### Scenario: Trocar o tipo
- **GIVEN** "Sala 12" de "Paulista" é do tipo "Sala de aula"
- **WHEN** Rui, coordenador de "Paulista", troca o tipo para "Laboratório", que está ativo
- **THEN** "Sala 12" passa a ser do tipo "Laboratório"

#### Scenario: Trocar para tipo desativado
- **GIVEN** o tipo "Auditório" está desativado
- **WHEN** Rui tenta trocar o tipo de "Sala 12" para "Auditório"
- **THEN** o sistema recusa informando que o tipo está desativado e nada muda

#### Scenario: Editar espaço de tipo desativado
- **GIVEN** "Auditório Principal" é do tipo "Auditório", que está desativado
- **WHEN** o admin altera a capacidade de "Auditório Principal" sem trocar o tipo
- **THEN** a nova capacidade é gravada

#### Scenario: Código repetido na edição
- **GIVEN** "Paulista" tem os espaços de código "LAB-01" e "LAB-02"
- **WHEN** Rui muda o código de "LAB-02" para "lab-01"
- **THEN** o sistema recusa informando que a unidade já tem um espaço com esse código e nada muda

#### Scenario: Coordenador em espaço de outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta editar um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e nada muda

#### Scenario: Espaço inexistente para o coordenador
- **WHEN** Rui, coordenador, tenta editar um id de espaço que não existe
- **THEN** o sistema responde com acesso negado, com a mesma mensagem de um espaço de outra unidade, sem indicar se o espaço existe

#### Scenario: Espaço de unidade desativada
- **GIVEN** "Centro" está desativada e tem o espaço "Sala 1"
- **WHEN** o admin altera o nome de "Sala 1"
- **THEN** o novo nome é gravado

### Requirement: Recursos do espaço
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder definir a lista completa de recursos do espaço, com a quantidade de cada um. Cada recurso DEVE existir no catálogo, aparecer no máximo uma vez e ter quantidade inteira maior ou igual a 1. A lista pode ser vazia. A nova lista substitui a anterior por inteiro; se qualquer item for inválido, nada muda.

#### Scenario: Definir recursos
- **WHEN** Rui define para "Laboratório de Redes" 30 "Computadores" e 1 "Projetor"
- **THEN** o espaço passa a ter exatamente esses recursos e quantidades

#### Scenario: Retirar todos os recursos
- **GIVEN** "Sala 12" tem 1 "Projetor"
- **WHEN** Rui define uma lista vazia para "Sala 12"
- **THEN** "Sala 12" fica sem recursos

#### Scenario: Recurso repetido
- **WHEN** Rui envia "Projetor" duas vezes na lista de recursos de um espaço
- **THEN** o sistema recusa informando o recurso repetido e nada muda

#### Scenario: Quantidade inválida
- **WHEN** Rui envia "Computadores" com quantidade 0
- **THEN** o sistema recusa informando que a quantidade deve ser de pelo menos 1 e nada muda

#### Scenario: Recurso inexistente
- **WHEN** Rui envia um recurso que não existe no catálogo
- **THEN** o sistema recusa e nada muda

#### Scenario: Recursos de espaço de outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta definir os recursos de um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Desativação e reativação de espaço
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder desativar um espaço ativo e reativar um espaço desativado. Espaços NÃO DEVEM (MUST NOT) ser excluídos. Reativar um espaço de unidade ou de tipo desativado é permitido: o espaço volta a ser ativo, mas continua não reservável até que a unidade e o tipo estejam ativos. Desativar um espaço já desativado, ou reativar um ativo, DEVE ser recusado sem gerar auditoria.

#### Scenario: Desativar espaço
- **WHEN** Rui desativa "Sala 12" de "Paulista"
- **THEN** "Sala 12" fica desativado e mantém código, tipo e recursos

#### Scenario: Reativar espaço de tipo desativado
- **GIVEN** "Auditório Principal" está desativado e o tipo "Auditório" também
- **WHEN** o admin reativa "Auditório Principal"
- **THEN** o espaço fica ativo, mas não reservável, com o motivo "tipo desativado"

#### Scenario: Desativar espaço já desativado
- **GIVEN** "Sala 12" está desativado
- **WHEN** Rui tenta desativá-lo
- **THEN** o sistema recusa informando que o espaço já está desativado

#### Scenario: Professor tenta desativar
- **WHEN** um professor tenta desativar um espaço
- **THEN** o sistema responde com acesso negado e nada muda

#### Scenario: Não há exclusão
- **WHEN** qualquer usuário, inclusive o admin, tenta excluir um espaço pela API
- **THEN** não existe rota que permita a operação e o espaço permanece

### Requirement: Mudança de unidade do espaço
Somente o admin DEVE (MUST) poder mover um espaço para outra unidade. A unidade de destino DEVE existir, estar ativa e ser diferente da atual, e NÃO DEVE (MUST NOT) ter outro espaço com o mesmo código, sem diferenciar maiúsculas e minúsculas. O espaço mantém tipo, situação, recursos e demais dados. Coordenadores NÃO DEVEM mover espaços, nem entre unidades que coordenam.

#### Scenario: Admin move espaço
- **WHEN** o admin move "Sala 12" de "Paulista" para "Vila Olímpia"
- **THEN** "Sala 12" passa a pertencer a "Vila Olímpia", com o mesmo tipo, situação e recursos

#### Scenario: Código já existe no destino
- **GIVEN** "Vila Olímpia" tem um espaço de código "101"
- **WHEN** o admin tenta mover para "Vila Olímpia" o espaço de código "101" de "Paulista"
- **THEN** o sistema recusa informando que o destino já tem um espaço com esse código e nada muda

#### Scenario: Destino igual à unidade atual
- **WHEN** o admin tenta mover "Sala 12" de "Paulista" para "Paulista"
- **THEN** o sistema recusa informando que o espaço já pertence a essa unidade

#### Scenario: Destino desativado
- **GIVEN** "Centro" está desativada
- **WHEN** o admin tenta mover um espaço para "Centro"
- **THEN** o sistema recusa informando que a unidade de destino está desativada

#### Scenario: Mover espaço de tipo desativado
- **GIVEN** "Auditório Principal" é do tipo desativado "Auditório"
- **WHEN** o admin move o espaço para "Vila Olímpia", que está ativa
- **THEN** o espaço é movido e continua não reservável pelo tipo desativado

#### Scenario: Coordenador tenta mover
- **GIVEN** Rui coordena "Paulista" e "Centro"
- **WHEN** Rui tenta mover um espaço de "Paulista" para "Centro"
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Disponibilidade do espaço para reserva
Um espaço DEVE (MUST) ser considerado reservável somente quando o próprio espaço, a unidade dele e o tipo dele estão ativos. Espaços não reserváveis NÃO DEVEM (MUST NOT) aparecer na busca nem aceitar novas reservas, regra que as changes de busca e de reserva aplicam. Desativar ou reativar uma unidade ou um tipo NÃO DEVE alterar a situação dos espaços; muda apenas se eles são reserváveis.

#### Scenario: Unidade desativada
- **GIVEN** "Sala 12" está ativo e é de "Paulista"
- **WHEN** o admin desativa "Paulista"
- **THEN** "Sala 12" continua ativo, mas deixa de ser reservável, com o motivo "unidade desativada"

#### Scenario: Unidade reativada
- **GIVEN** "Paulista" está desativada e "Sala 12", ativo e de tipo ativo, pertence a ela
- **WHEN** o admin reativa "Paulista"
- **THEN** "Sala 12" volta a ser reservável sem nenhuma ação sobre o espaço

#### Scenario: Vários motivos
- **GIVEN** "Sala 1" está desativado, a unidade dele está desativada e o tipo dele também
- **WHEN** a listagem de gestão é consultada
- **THEN** "Sala 1" aparece como não reservável, com os motivos "espaço desativado", "unidade desativada" e "tipo desativado"

### Requirement: Listagem de espaços geridos
O sistema DEVE (MUST) devolver os espaços das unidades sobre as quais o usuário tem escopo, ativos e desativados, ordenados por unidade e por código. Cada espaço DEVE trazer id, nome, código, capacidade, localização, descrição, situação, unidade (id, nome e situação), tipo (id, nome e situação), recursos (id, nome e quantidade), se é reservável e os motivos quando não é:
- o admin recebe os espaços de todas as unidades;
- o coordenador recebe os das unidades que coordena;
- aluno e professor recebem acesso negado.

#### Scenario: Coordenador lista
- **GIVEN** Rui coordena "Paulista" e existem espaços em "Paulista" e em "Vila Olímpia"
- **WHEN** Rui lista os espaços geridos
- **THEN** recebe apenas os espaços de "Paulista"

#### Scenario: Admin lista
- **WHEN** o admin lista os espaços geridos
- **THEN** recebe os espaços de todas as unidades, ativas e desativadas, com a indicação de reservável e os motivos

#### Scenario: Aluno tenta listar
- **WHEN** um aluno tenta listar os espaços geridos
- **THEN** o sistema responde com acesso negado

### Requirement: Tela de espaços
O frontend DEVE (MUST) oferecer a admins e coordenadores uma página "Espaços" para:
- listar os espaços do escopo, agrupados ou filtráveis por unidade;
- criar e editar espaços, oferecendo apenas unidades ativas do escopo e tipos ativos; na edição, o tipo atual aparece mesmo desativado;
- definir os recursos e as quantidades de cada espaço;
- desativar e reativar espaços;
- mover um espaço para outra unidade, opção exibida só ao admin.

Os espaços não reserváveis DEVEM ser destacados com o motivo.

#### Scenario: Destaque de espaço não reservável
- **GIVEN** "Auditório Principal" está ativo, mas o tipo "Auditório" está desativado
- **WHEN** o admin abre a página "Espaços"
- **THEN** "Auditório Principal" aparece destacado como não reservável, com o motivo "tipo desativado"

#### Scenario: Coordenador não vê a opção de mover
- **WHEN** um coordenador abre a página "Espaços"
- **THEN** a página não oferece mover espaços entre unidades
