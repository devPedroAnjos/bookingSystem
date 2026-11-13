## MODIFIED Requirements

### Requirement: Horário pedido na busca
Quando data e horário são informados, cada espaço do resultado DEVE (MUST) indicar se o pedido está **dentro das regras do tipo** (capability `regras-tipo`) e, quando não está, os motivos. Espaços fora das regras continuam no resultado, com os motivos. Cada espaço DEVE indicar também se está **livre** ou **ocupado** no intervalo pedido: ocupado quando há reserva `PENDENTE` ou `CONFIRMADA` sobreposta no espaço (capability `reservas`), sem contar a pendente cujo início já chegou, que expirou (capability `aprovacao-reservas`). A busca NÃO DEVE (MUST NOT) identificar quem ocupa o horário. A indicação é informativa: a reserva verifica tudo de novo no momento da criação.

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
- **THEN** os espaços aparecem sem indicação de regras de horário nem de ocupação
