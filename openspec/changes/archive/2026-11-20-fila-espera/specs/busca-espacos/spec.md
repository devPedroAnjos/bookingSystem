## MODIFIED Requirements

### Requirement: Horário pedido na busca
Quando data e horário são informados, cada espaço do resultado DEVE (MUST) indicar se o pedido está **dentro das regras do tipo** (capability `regras-tipo`) e, quando não está, os motivos. Espaços fora das regras continuam no resultado, com os motivos. Cada espaço DEVE indicar também se está **livre** ou **ocupado** no intervalo pedido: ocupado quando há reserva `PENDENTE` ou `CONFIRMADA` sobreposta no espaço (capability `reservas`), sem contar a pendente cujo início já chegou, que expirou (capability `aprovacao-reservas`), ou quando há vaga retida pela fila sobreposta, sem contar a retenção cujo prazo já venceu (capability `fila-espera`). Cada espaço ocupado e dentro das regras DEVE indicar ainda se quem busca poderia deslocar a ocupação, pelas condições do deslocamento por prioridade (capability `reservas`), e quantas reservas seriam deslocadas; espaços livres ou fora das regras aparecem não deslocáveis, com 0 reservas a deslocar, e a vaga retida torna o espaço não deslocável. Cada espaço DEVE indicar também se quem busca já está na fila desse intervalo e, quando não está, se pode entrar nela: ocupado, dentro das regras, não deslocável e antes do fechamento da fila (o corte menos o tempo mínimo útil, capability `fila-espera`). A busca NÃO DEVE (MUST NOT) identificar quem ocupa o horário nem quem está na fila. As indicações são informativas: a reserva e a entrada na fila verificam tudo de novo.

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
- **THEN** os espaços aparecem sem indicação de regras de horário, de ocupação, de deslocamento nem de fila

#### Scenario: Ocupado e deslocável
- **GIVEN** "LAB-01" tem reservas de dois alunos sobrepostas ao intervalo pedido, que começa depois de amanhã
- **WHEN** um professor busca "Laboratório" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e deslocável, com 2 reservas a deslocar, sem indicação de quem reservou, e sem oferta de fila

#### Scenario: Ocupado e não deslocável
- **GIVEN** "LAB-01" tem uma reserva de um professor sobreposta ao intervalo pedido, que começa depois de amanhã
- **WHEN** outro professor busca "Laboratório" para esse intervalo
- **THEN** "LAB-01" aparece ocupado, não deslocável e com a possibilidade de entrar na fila

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
- **THEN** "BIB-01" aparece fora das regras, ocupado e não deslocável, com 0 reservas a deslocar e sem a possibilidade de entrar na fila

#### Scenario: Espaço livre não tem o que deslocar
- **WHEN** um espaço aparece livre no intervalo pedido
- **THEN** ele aparece não deslocável, com 0 reservas a deslocar e sem a possibilidade de entrar na fila

#### Scenario: Vaga retida ocupa o espaço
- **GIVEN** a vaga de "LAB-01" das 14h00 às 15h00 de depois de amanhã está retida para uma aluna, no prazo
- **WHEN** um professor busca "LAB-01" para esse intervalo
- **THEN** "LAB-01" aparece ocupado, não deslocável e com a possibilidade de entrar na fila, sem indicação de quem retém a vaga

#### Scenario: Vaga retida vencida não ocupa
- **GIVEN** o prazo da vaga retida em "BIB-01" das 14h00 às 15h00 venceu e não há outra ocupação no intervalo
- **WHEN** alguém busca "BIB-01" para esse intervalo
- **THEN** "BIB-01" aparece livre

#### Scenario: Fila depois do fechamento
- **GIVEN** o corte da fila é de 120 minutos, o tempo mínimo útil é de 30 minutos e "BIB-01" tem uma reserva de professor que começa daqui a 140 minutos
- **WHEN** uma aluna busca "BIB-01" para esse intervalo
- **THEN** "BIB-01" aparece ocupado e sem a possibilidade de entrar na fila

#### Scenario: Já na fila
- **GIVEN** Ana aguarda na fila de "BIB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana busca "BIB-01" para esse intervalo
- **THEN** "BIB-01" aparece ocupado, com a indicação de que ela já está na fila, e sem a possibilidade de entrar de novo

### Requirement: Tela de busca
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Buscar espaços", com os filtros, um botão para buscar e a lista de resultados. A busca só é enviada ao clicar no botão. Com data e horário informados, cada resultado mostra "dentro das regras do tipo" ou os motivos de estar fora delas e se o espaço está livre ou ocupado; os espaços livres e dentro das regras oferecem "Reservar", os ocupados, deslocáveis e dentro das regras oferecem "Deslocar e reservar", e os que permitem entrar na fila oferecem "Entrar na fila". O espaço em cuja fila o usuário já está mostra essa indicação. "Reservar" abre uma confirmação com o espaço, a unidade, a data, o horário e se a reserva exigirá aprovação. "Deslocar e reservar" abre a mesma confirmação, com o aviso de quantas reservas de prioridade menor serão canceladas. Se a criação pedir a confirmação do deslocamento de um espaço que parecia livre, a confirmação passa a mostrar esse aviso e pede uma nova confirmação. "Entrar na fila" abre uma confirmação com o espaço, a unidade, a data, o horário e o aviso de que a vaga liberada aparece no sistema e precisa ser confirmada dentro do prazo da fila. Depois de confirmar, a página mostra o resultado (reserva confirmada, aguardando aprovação ou entrada na fila) ou a recusa dentro da confirmação, e atualiza o resultado. A página DEVE avisar que a disponibilidade é conferida de novo no momento da reserva.

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
- **WHEN** um resultado aparece ocupado, não deslocável e sem a possibilidade de entrar na fila, ou fora das regras
- **THEN** a página não oferece "Reservar", "Deslocar e reservar" nem "Entrar na fila" para ele

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

#### Scenario: Entrar na fila pela busca
- **GIVEN** "BIB-01" aparece ocupado, não deslocável e com a possibilidade de entrar na fila para Ana
- **WHEN** Ana escolhe "Entrar na fila" em "BIB-01" e confirma
- **THEN** a página informa que ela entrou na fila e, ao atualizar o resultado, "BIB-01" mostra que ela já está na fila

#### Scenario: Espaço liberado antes de entrar na fila
- **GIVEN** "BIB-01" apareceu ocupado para Ana, e a reserva foi cancelada em seguida, sem ninguém na fila desse intervalo
- **WHEN** Ana confirma "Entrar na fila" em "BIB-01"
- **THEN** a confirmação mostra a recusa de que o horário está livre, sem fechar

#### Scenario: Nenhum resultado
- **WHEN** a busca não encontra espaços
- **THEN** a página informa que nenhum espaço atende aos filtros
