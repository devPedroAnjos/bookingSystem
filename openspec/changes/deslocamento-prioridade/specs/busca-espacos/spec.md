## MODIFIED Requirements

### Requirement: Horário pedido na busca
Quando data e horário são informados, cada espaço do resultado DEVE (MUST) indicar se o pedido está **dentro das regras do tipo** (capability `regras-tipo`) e, quando não está, os motivos. Espaços fora das regras continuam no resultado, com os motivos. Cada espaço DEVE indicar também se está **livre** ou **ocupado** no intervalo pedido: ocupado quando há reserva `PENDENTE` ou `CONFIRMADA` sobreposta no espaço (capability `reservas`), sem contar a pendente cujo início já chegou, que expirou (capability `aprovacao-reservas`). Cada espaço ocupado e dentro das regras DEVE indicar ainda se quem busca poderia deslocar a ocupação, pelas condições do deslocamento por prioridade (capability `reservas`), e quantas reservas seriam deslocadas; espaços livres ou fora das regras aparecem não deslocáveis, com 0 reservas a deslocar. A busca NÃO DEVE (MUST NOT) identificar quem ocupa o horário. As indicações são informativas: a reserva verifica tudo de novo no momento da criação.

#### Scenario: Dentro e fora das regras
- **GIVEN** "Biblioteca" aceita até 180 minutos e "Laboratório" até 240 minutos
- **WHEN** um professor busca para uma quarta-feira das 09h00 às 12h20 (200 minutos)
- **THEN** os espaços de "Laboratório" aparecem dentro das regras
- **AND** os de "Biblioteca" aparecem fora das regras, com o motivo de duração acima da máxima

#### Scenario: Espaço ocupado
- **GIVEN** "LAB-01" tem uma reserva `PENDENTE` das 14h00 às 15h00 de uma quarta-feira
- **WHEN** um professor busca "Laboratório" para essa quarta-feira das 14h30 às 15h30
- **THEN** "LAB-01" aparece ocupado, sem indicação de quem reservou
- **AND** os demais laboratórios sem reserva no intervalo aparecem livres

#### Scenario: Pendente vencida não ocupa
- **GIVEN** "LAB-01" tem uma reserva `PENDENTE` das 14h00 às 16h00 de hoje, sem decisão, e são 14h20
- **WHEN** um professor busca "Laboratório" para hoje das 14h30 às 15h30
- **THEN** "LAB-01" aparece livre

#### Scenario: Intervalo encostado
- **GIVEN** "LAB-01" tem uma reserva das 14h00 às 15h00
- **WHEN** alguém busca para o mesmo dia das 15h00 às 16h00
- **THEN** "LAB-01" aparece livre

#### Scenario: Sem data e horário
- **WHEN** alguém busca sem informar data e horário
- **THEN** os espaços aparecem sem indicação de regras de horário, de ocupação nem de deslocamento

#### Scenario: Ocupado e deslocável
- **GIVEN** "LAB-01" tem reservas de dois alunos sobrepostas ao intervalo pedido, que começa depois de amanhã
- **WHEN** um professor busca "Laboratório" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e deslocável, com 2 reservas a deslocar, sem indicação de quem reservou

#### Scenario: Ocupado e não deslocável
- **GIVEN** "LAB-01" tem uma reserva de um professor sobreposta ao intervalo pedido
- **WHEN** outro professor busca "Laboratório" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e não deslocável

#### Scenario: Deslocamento fora do prazo
- **GIVEN** o prazo para deslocar é de 120 minutos e "LAB-01" tem uma reserva de aluno que começa daqui a 1 hora
- **WHEN** um professor busca "LAB-01" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e não deslocável

#### Scenario: Nova reserva exigiria aprovação
- **GIVEN** o admin configurou "Laboratório" para exigir aprovação do professor, e "LAB-01" tem uma reserva de aluno que começa depois de amanhã
- **WHEN** um professor busca "LAB-01" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e não deslocável

#### Scenario: Ocupado e fora das regras
- **GIVEN** "BIB-01" tem uma reserva de aluno das 21h40 às 22h40 de depois de amanhã
- **WHEN** um professor busca "BIB-01" das 22h00 às 22h50
- **THEN** "BIB-01" aparece fora das regras, ocupado e não deslocável, com 0 reservas a deslocar

#### Scenario: Espaço livre não tem o que deslocar
- **WHEN** um espaço aparece livre no intervalo pedido
- **THEN** ele aparece não deslocável, com 0 reservas a deslocar

### Requirement: Tela de busca
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Buscar espaços", com os filtros, um botão para buscar e a lista de resultados. A busca só é enviada ao clicar no botão. Com data e horário informados, cada resultado mostra "dentro das regras do tipo" ou os motivos de estar fora delas e se o espaço está livre ou ocupado; os espaços livres e dentro das regras oferecem "Reservar", e os ocupados, deslocáveis e dentro das regras oferecem "Deslocar e reservar". "Reservar" abre uma confirmação com o espaço, a unidade, a data, o horário e se a reserva exigirá aprovação. "Deslocar e reservar" abre a mesma confirmação, com o aviso de quantas reservas de prioridade menor serão canceladas. Se a criação pedir a confirmação do deslocamento de um espaço que parecia livre, a confirmação passa a mostrar esse aviso e pede uma nova confirmação. Depois de confirmar, a página mostra se a reserva foi confirmada ou ficou aguardando aprovação, ou mostra a recusa dentro da confirmação, e atualiza o resultado. A página DEVE avisar que a disponibilidade é conferida de novo no momento da reserva.

#### Scenario: Buscar pela tela
- **WHEN** um aluno escolhe "Biblioteca", informa uma data e um horário e clica em buscar
- **THEN** a página mostra os espaços de "Biblioteca" com o código, a unidade, se o horário está dentro das regras e se o espaço está livre
- **AND** mostra o aviso de que a disponibilidade é conferida de novo na reserva

#### Scenario: Reservar pela busca
- **GIVEN** "BIB-01" aparece livre e dentro das regras para o horário pedido
- **WHEN** Ana escolhe "Reservar" em "BIB-01" e confirma
- **THEN** a página informa que a reserva foi confirmada
- **AND** ao atualizar o resultado, "BIB-01" aparece ocupado

#### Scenario: Recusa na confirmação
- **GIVEN** outra pessoa reservou "BIB-01" no mesmo horário depois da busca de Ana
- **WHEN** Ana confirma a reserva de "BIB-01"
- **THEN** a confirmação mostra a recusa de horário ocupado, sem fechar

#### Scenario: Espaço ocupado sem botão
- **WHEN** um resultado aparece ocupado e não deslocável, ou fora das regras
- **THEN** a página não oferece "Reservar" nem "Deslocar e reservar" para ele

#### Scenario: Deslocar pela busca
- **GIVEN** "LAB-01" aparece ocupado e deslocável, com 1 reserva a deslocar, para o professor Carlos
- **WHEN** Carlos escolhe "Deslocar e reservar" em "LAB-01"
- **THEN** a confirmação avisa que 1 reserva de prioridade menor será cancelada
- **AND** ao confirmar, a página informa que a reserva foi confirmada e que 1 reserva foi deslocada, e o resultado é atualizado

#### Scenario: Ocupado depois da busca e deslocável
- **GIVEN** "LAB-01" apareceu livre para Carlos, e um aluno o reservou em seguida
- **WHEN** Carlos confirma "Reservar" em "LAB-01"
- **THEN** a confirmação continua aberta, avisa que 1 reserva de prioridade menor será cancelada e pede nova confirmação
- **AND** nada é gravado até Carlos confirmar de novo

#### Scenario: Nenhum resultado
- **WHEN** a busca não encontra espaços
- **THEN** a página informa que nenhum espaço atende aos filtros
