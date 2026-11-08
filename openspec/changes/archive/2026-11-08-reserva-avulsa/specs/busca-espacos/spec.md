## MODIFIED Requirements

### Requirement: Horário pedido na busca
Quando data e horário são informados, cada espaço do resultado DEVE (MUST) indicar se o pedido está **dentro das regras do tipo** (capability `regras-tipo`) e, quando não está, os motivos. Espaços fora das regras continuam no resultado, com os motivos. Cada espaço DEVE indicar também se está **livre** ou **ocupado** no intervalo pedido: ocupado quando há reserva `PENDENTE` ou `CONFIRMADA` sobreposta no espaço (capability `reservas`). A busca NÃO DEVE (MUST NOT) identificar quem ocupa o horário. A indicação é informativa: a reserva verifica tudo de novo no momento da criação.

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

#### Scenario: Intervalo encostado
- **GIVEN** "LAB-01" tem uma reserva das 14h00 às 15h00
- **WHEN** alguém busca para o mesmo dia das 15h00 às 16h00
- **THEN** "LAB-01" aparece livre

#### Scenario: Sem data e horário
- **WHEN** alguém busca sem informar data e horário
- **THEN** os espaços aparecem sem indicação de regras de horário nem de ocupação

### Requirement: Tela de busca
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Buscar espaços", com os filtros, um botão para buscar e a lista de resultados. A busca só é enviada ao clicar no botão. Com data e horário informados, cada resultado mostra "dentro das regras do tipo" ou os motivos de estar fora delas e se o espaço está livre ou ocupado; os espaços livres e dentro das regras oferecem "Reservar". "Reservar" abre uma confirmação com o espaço, a unidade, a data, o horário e se a reserva exigirá aprovação; depois de confirmar, a página mostra se a reserva foi confirmada ou ficou aguardando aprovação, ou mostra a recusa dentro da confirmação, e atualiza o resultado. A página DEVE avisar que a disponibilidade é conferida de novo no momento da reserva.

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
- **WHEN** um resultado aparece ocupado ou fora das regras
- **THEN** a página não oferece "Reservar" para ele

#### Scenario: Nenhum resultado
- **WHEN** a busca não encontra espaços
- **THEN** a página informa que nenhum espaço atende aos filtros
