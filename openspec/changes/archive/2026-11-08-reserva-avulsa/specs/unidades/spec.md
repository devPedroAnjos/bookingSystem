## MODIFIED Requirements

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
