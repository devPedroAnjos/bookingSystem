## ADDED Requirements

### Requirement: Criação de unidade com coordenador
Somente o admin DEVE (MUST) poder criar uma unidade. Na mesma operação, ele informa:
- nome e endereço, ambos obrigatórios;
- um coordenador `ATIVA` existente;
- se esse coordenador é **movido** de uma unidade de origem ou se a unidade nova é **acrescentada** a ele.

O nome DEVE ser único, sem diferenciar maiúsculas e minúsculas e ignorando espaços nas pontas. As regras de mover e acrescentar da capability `coordenacao` se aplicam. A unidade nasce ativa. Se qualquer regra falhar, nada é criado.

#### Scenario: Criar movendo coordenador
- **GIVEN** "Paulista" tem os coordenadores Rui e Ana
- **WHEN** o admin cria "Centro", movendo Rui de "Paulista"
- **THEN** "Centro" é criada, ativa, com Rui como coordenador
- **AND** "Paulista" fica com Ana

#### Scenario: Criar acrescentando coordenador
- **GIVEN** Rui coordena apenas "Paulista", onde é o único coordenador
- **WHEN** o admin cria "Centro", acrescentando-a a Rui
- **THEN** "Centro" é criada e Rui coordena "Paulista" e "Centro"

#### Scenario: Mover o único coordenador da origem
- **GIVEN** Rui é o único coordenador de "Paulista"
- **WHEN** o admin tenta criar "Centro" movendo Rui
- **THEN** o sistema recusa informando que "Paulista" ficaria sem coordenador, e "Centro" não é criada

#### Scenario: Sem coordenador
- **WHEN** o admin tenta criar uma unidade sem informar coordenador
- **THEN** o sistema recusa informando que a unidade precisa de um coordenador

#### Scenario: Nome repetido
- **GIVEN** existe "Paulista"
- **WHEN** o admin tenta criar " paulista "
- **THEN** o sistema recusa informando que já existe uma unidade com esse nome

#### Scenario: Coordenador tenta criar
- **WHEN** um coordenador tenta criar uma unidade
- **THEN** o sistema responde com acesso negado

### Requirement: Edição de unidade
Qualquer admin DEVE (MUST) poder corrigir o nome e o endereço de uma unidade, com as mesmas validações da criação. A unicidade desconsidera a própria unidade. Coordenações e situação não mudam.

#### Scenario: Corrigir endereço
- **WHEN** o admin altera o endereço de "Paulista" de "Endereço a confirmar" para "Av. Paulista, 1000"
- **THEN** a unidade passa a ter o novo endereço e mantém id, nome, situação e coordenadores

#### Scenario: Renomear para nome existente
- **WHEN** o admin tenta renomear "Paulista" para "vila olímpia", havendo "Vila Olímpia"
- **THEN** o sistema recusa informando que o nome já existe

### Requirement: Desativação de unidade
Somente o admin DEVE (MUST) poder desativar uma unidade ativa. Unidades NÃO DEVEM (MUST NOT) ser excluídas. Na mesma operação:
- cada coordenador que coordena **só** essa unidade DEVE receber uma unidade de destino, ativa e com vaga, informada pelo admin;
- cada coordenador que coordena também outra unidade perde apenas esta;
- cada professor `ATIVA` que pertence a essa unidade DEVE receber uma unidade de destino ativa, informada pelo admin;
- os pedidos pendentes que a escolheram são recusados automaticamente, sem consumir pedido (capability `aprovacao-cadastro`);
- a unidade sai da listagem pública e não pode mais ser escolhida em cadastros nem em reenvios.

Se faltar destino para algum coordenador ou professor, ou se algum destino for inválido, nada muda.

#### Scenario: Desativar com destinos
- **GIVEN** "Paulista" tem os coordenadores Rui (só "Paulista") e Ana ("Paulista" e "Centro") e o professor Carlos
- **WHEN** o admin desativa "Paulista", com destino "Vila Olímpia" para Rui e "Centro" para Carlos
- **THEN** "Paulista" fica desativada, sem coordenadores e sem professores
- **AND** Rui coordena "Vila Olímpia", Ana coordena só "Centro" e Carlos passa a pertencer a "Centro"
- **AND** "Paulista" deixa de aparecer na listagem pública

#### Scenario: Falta destino
- **GIVEN** Rui coordena só "Paulista" e Carlos é professor de "Paulista"
- **WHEN** o admin tenta desativar "Paulista" sem informar destino para Rui ou para Carlos
- **THEN** o sistema recusa indicando quem precisa de uma unidade de destino e nada muda

#### Scenario: Pedido pendente na unidade desativada
- **GIVEN** Beatriz é professora `PENDENTE` em "Paulista"
- **WHEN** "Paulista" é desativada
- **THEN** o pedido de Beatriz é recusado automaticamente com o motivo "Unidade desativada", sem consumir pedido

### Requirement: Reativação de unidade
Somente o admin DEVE (MUST) poder reativar uma unidade desativada. Ela volta à listagem pública sem coordenadores e sem professores, até que o admin acrescente, mova ou transfira alguém, ou que um pedido para ela seja aprovado. Desativar uma unidade já desativada, ou reativar uma ativa, DEVE ser recusado sem gerar auditoria.

#### Scenario: Reativar
- **GIVEN** "Paulista" está desativada
- **WHEN** o admin reativa "Paulista"
- **THEN** ela volta à listagem pública, sem coordenadores ativos, e é destacada na tela de unidades

### Requirement: Listagem de unidades geridas
O sistema DEVE (MUST) devolver as unidades sobre as quais o usuário tem escopo, ordenadas por nome, com id, nome, endereço, situação e coordenadores ativos (id e nome):
- o admin recebe todas;
- o coordenador recebe as que coordena;
- aluno e professor recebem acesso negado.

#### Scenario: Admin lista
- **WHEN** o admin lista as unidades geridas
- **THEN** recebe todas as unidades, ativas e desativadas, com seus coordenadores

#### Scenario: Coordenador lista
- **GIVEN** Rui coordena "Paulista" e "Centro"
- **WHEN** Rui lista as unidades geridas
- **THEN** recebe apenas "Centro" e "Paulista"

### Requirement: Tela de unidades
O frontend DEVE (MUST) oferecer ao admin uma página de unidades para:
- criar unidade, com a escolha do coordenador e de "mover" ou "acrescentar";
- editar nome e endereço;
- desativar, com a escolha de destino para cada coordenador que só tem essa unidade e para cada professor dela, e o aviso de quantos pedidos pendentes serão recusados;
- reativar.

As unidades sem coordenador ativo DEVEM ser destacadas.

#### Scenario: Formulário de desativação
- **GIVEN** "Paulista" tem Rui, que só coordena ela, o professor Carlos e 2 pedidos pendentes
- **WHEN** o admin inicia a desativação de "Paulista"
- **THEN** a página exige escolher uma unidade de destino para Rui e para Carlos antes de confirmar
- **AND** avisa que 2 pedidos pendentes serão recusados automaticamente
