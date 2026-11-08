# Especificação: Unidades

## Purpose

Representar as unidades (campus ou prédio) da instituição. Nesta etapa, a capability fornece a carga inicial de unidades e a listagem pública usada no cadastro de professor. A gestão completa (criar, editar e inativar unidades e atribuir coordenadores) é acrescentada por uma change posterior.

## Requirements
### Requirement: Carga inicial de unidades
O sistema DEVE (MUST) ser implantado com um conjunto inicial de unidades ativas, sem exigir cadastro manual pela interface.

#### Scenario: Unidades disponíveis após a implantação
- **WHEN** o backend é implantado pela primeira vez no ambiente
- **THEN** existe ao menos uma unidade ativa, com nome e endereço

#### Scenario: Carga repetida
- **GIVEN** a carga inicial já foi aplicada
- **WHEN** a carga é aplicada novamente
- **THEN** nenhuma unidade é duplicada

### Requirement: Listagem pública de unidades ativas
O sistema DEVE (MUST) oferecer, sem autenticação, a listagem das unidades ativas ordenada por nome. Cada item contém **somente** `id` e `nome`. Unidades inativas NÃO DEVEM (MUST NOT) aparecer.

#### Scenario: Visitante lista unidades
- **GIVEN** existem as unidades ativas "Vila Olímpia" e "Paulista" e a unidade inativa "Centro"
- **WHEN** um visitante sem token chama a listagem pública
- **THEN** o sistema devolve "Paulista" e "Vila Olímpia", nessa ordem, cada uma só com `id` e `nome`
- **AND** "Centro" não aparece

#### Scenario: Dados além de id e nome não são expostos
- **WHEN** a listagem pública é chamada
- **THEN** a resposta não contém endereço, situação, coordenadores nem qualquer outro campo

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
Somente o admin DEVE (MUST) poder desativar uma unidade ativa, escolhendo um motivo da lista de desativação, a mesma da capability `espacos`, com descrição obrigatória para "Outro". Unidades NÃO DEVEM (MUST NOT) ser excluídas. Na mesma operação:
- cada coordenador que coordena **só** essa unidade DEVE receber uma unidade de destino, ativa e com vaga, informada pelo admin;
- cada coordenador que coordena também outra unidade perde apenas esta;
- cada professor `ATIVA` que pertence a essa unidade DEVE receber uma unidade de destino ativa, informada pelo admin;
- os pedidos pendentes que a escolheram são recusados automaticamente, sem consumir pedido (capability `aprovacao-cadastro`);
- as reservas dos espaços da unidade que ainda não terminaram são canceladas, levando o motivo da desativação (capability `reservas`), e a resposta informa quantas;
- a unidade sai da listagem pública e não pode mais ser escolhida em cadastros nem em reenvios.

Se faltar o motivo ou destino para algum coordenador ou professor, se algum destino for inválido, ou se algum espaço da unidade tiver reserva confirmada em andamento, nada muda; no último caso, a recusa informa até que horas vai a última reserva em andamento. A reativação da unidade não restaura reservas.

#### Scenario: Desativar com destinos
- **GIVEN** "Paulista" tem os coordenadores Rui (só "Paulista") e Ana ("Paulista" e "Centro") e o professor Carlos
- **WHEN** o admin desativa "Paulista", com destino "Vila Olímpia" para Rui e "Centro" para Carlos
- **THEN** "Paulista" fica desativada, sem coordenadores e sem professores
- **AND** Rui coordena "Vila Olímpia", Ana coordena só "Centro" e Carlos passa a pertencer a "Centro"
- **AND** "Paulista" deixa de aparecer na listagem pública

#### Scenario: Desativar unidade com reservas
- **GIVEN** os espaços de "Paulista" têm 5 reservas futuras e nenhuma em andamento
- **WHEN** o admin desativa "Paulista", com todos os destinos informados
- **THEN** as 5 reservas ficam canceladas com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Desativar unidade sem motivo
- **WHEN** o admin tenta desativar "Paulista", com todos os destinos, mas sem escolher o motivo
- **THEN** o sistema recusa pedindo o motivo e nada muda

#### Scenario: Unidade com espaço em uso
- **GIVEN** um espaço de "Paulista" tem reserva confirmada em andamento até 18h00
- **WHEN** o admin tenta desativar "Paulista", com todos os destinos informados
- **THEN** o sistema recusa informando que há reserva em andamento até 18h00 e nada muda, inclusive coordenadores, professores, pedidos e reservas

#### Scenario: Falta destino
- **GIVEN** Rui coordena só "Paulista" e Carlos é professor de "Paulista"
- **WHEN** o admin tenta desativar "Paulista" sem informar destino para Rui ou para Carlos
- **THEN** o sistema recusa indicando quem precisa de uma unidade de destino e nada muda, inclusive as reservas

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
- desativar, com a escolha do motivo (caixa de seleção, e descrição para "Outro"), a escolha de destino para cada coordenador que só tem essa unidade e para cada professor dela, o aviso de quantos pedidos pendentes serão recusados e o aviso de quantas reservas serão canceladas ou, se houver reserva confirmada em andamento, de que a desativação será recusada até o horário de término dela;
- reativar.

As unidades sem coordenador ativo DEVEM ser destacadas.

#### Scenario: Formulário de desativação
- **GIVEN** "Paulista" tem Rui, que só coordena ela, o professor Carlos, 2 pedidos pendentes e 5 reservas futuras, sem reserva em andamento
- **WHEN** o admin inicia a desativação de "Paulista"
- **THEN** a página exige escolher uma unidade de destino para Rui e para Carlos antes de confirmar
- **AND** avisa que 2 pedidos pendentes serão recusados automaticamente e que 5 reservas serão canceladas
