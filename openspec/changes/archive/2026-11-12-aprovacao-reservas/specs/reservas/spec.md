## MODIFIED Requirements

### Requirement: Conflito de horário
Uma nova reserva NÃO DEVE (MUST NOT) se sobrepor, no mesmo espaço, a uma reserva `PENDENTE` ou `CONFIRMADA`. Há sobreposição quando o início de cada uma é anterior ao fim da outra; sobreposição parcial também é conflito, e reservas que apenas se encostam (uma termina quando a outra começa) não conflitam. Uma reserva `PENDENTE` cujo início já chegou expirou (capability `aprovacao-reservas`) e não ocupa mais o horário. A verificação do conflito e a gravação DEVEM ser atômicas: requisições simultâneas NUNCA podem gerar reservas sobrepostas. Nesta etapa o conflito é sempre recusado, sem identificar quem ocupa o horário, inclusive quando o solicitante tem prioridade maior; o deslocamento por prioridade e a fila de espera são de uma change posterior.

#### Scenario: Sobreposição parcial
- **GIVEN** "LAB-01" tem uma reserva `CONFIRMADA` das 14h00 às 16h00
- **WHEN** Carlos tenta reservar "LAB-01" das 15h00 às 17h00 do mesmo dia
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Reservas encostadas
- **GIVEN** "LAB-01" tem uma reserva das 14h00 às 16h00
- **WHEN** Carlos reserva "LAB-01" das 16h00 às 17h00 do mesmo dia
- **THEN** a reserva é criada

#### Scenario: Pendente ocupa o horário
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" das 14h00 às 15h00
- **WHEN** outro aluno tenta reservar "LAB-01" das 14h30 às 15h30
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Pendente vencida não ocupa
- **GIVEN** a antecedência mínima de "Laboratório" é de 0 minutos, e Ana tem uma reserva `PENDENTE` em "LAB-01" das 14h00 às 16h00, sem decisão, e são 14h20
- **WHEN** Carlos reserva "LAB-01" das 14h30 às 15h30
- **THEN** a reserva de Carlos é criada e a de Ana fica `EXPIRADA`

#### Scenario: Cancelada não ocupa
- **GIVEN** a reserva das 14h00 às 15h00 em "LAB-01" foi cancelada
- **WHEN** Carlos reserva "LAB-01" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Recusada não ocupa
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" das 14h00 às 15h00 foi recusada
- **WHEN** Carlos reserva "LAB-01" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Prioridade maior ainda não desloca
- **GIVEN** Ana, aluna, tem uma reserva `CONFIRMADA` em "LAB-01" das 14h00 às 15h00 da próxima semana
- **WHEN** Carlos, professor, tenta reservar o mesmo intervalo
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana não muda

#### Scenario: Mesmo horário em outro espaço
- **GIVEN** "LAB-01" está ocupado das 14h00 às 15h00
- **WHEN** Carlos reserva "LAB-02" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Requisições simultâneas
- **WHEN** Ana e Carlos enviam ao mesmo tempo reservas de "LAB-01" para intervalos sobrepostos
- **THEN** só uma reserva é criada e o outro recebe a recusa de horário ocupado

#### Scenario: Reserva e desativação simultâneas
- **WHEN** Carlos reserva um horário futuro de "LAB-01" no mesmo instante em que Rui desativa "LAB-01"
- **THEN** ou a reserva não é criada por espaço indisponível, ou ela é criada e logo cancelada pela desativação; nunca fica uma reserva ativa em espaço desativado

### Requirement: Limite de reservas ativas por tipo
O sistema DEVE (MUST) recusar uma nova reserva quando o usuário já tem, no tipo do espaço pedido, a quantidade máxima de reservas ativas definida no tipo. Contam apenas as reservas `PENDENTE` ou `CONFIRMADA` do próprio usuário, em espaços desse tipo, que ainda não terminaram; a pendente cujo início já chegou expirou e não conta. A verificação DEVE ser feita junto com a gravação, sob as mesmas garantias do conflito.

#### Scenario: Limite atingido
- **GIVEN** "Biblioteca" permite 2 reservas ativas por usuário e Ana tem 2 reservas futuras em espaços de "Biblioteca"
- **WHEN** Ana tenta uma terceira reserva de "Biblioteca"
- **THEN** o sistema recusa informando o máximo de 2 reservas ativas nesse tipo

#### Scenario: Outro tipo não conta
- **GIVEN** Ana tem 2 reservas futuras de "Biblioteca"
- **WHEN** Ana reserva um espaço de "Laboratório"
- **THEN** a reserva é criada

#### Scenario: Reserva terminada não conta
- **GIVEN** Ana tem 1 reserva futura de "Biblioteca" e outra que terminou ontem e continua `CONFIRMADA`
- **WHEN** Ana faz uma nova reserva de "Biblioteca"
- **THEN** a reserva é criada

#### Scenario: Cancelada não conta
- **GIVEN** Ana tinha 2 reservas futuras de "Biblioteca" e cancelou uma
- **WHEN** Ana faz uma nova reserva de "Biblioteca"
- **THEN** a reserva é criada

#### Scenario: Pendente vencida não conta
- **GIVEN** "Laboratório" permite 3 reservas ativas, Ana tem 2 reservas futuras de "Laboratório" e uma `PENDENTE` que começou há 10 minutos sem decisão
- **WHEN** Ana faz uma nova reserva de "Laboratório"
- **THEN** a reserva é criada e a pendente vencida fica `EXPIRADA`

### Requirement: Cancelamento pelo próprio usuário
O usuário DEVE (MUST) poder cancelar uma reserva própria `PENDENTE` ou `CONFIRMADA` desde que falte, até o início, pelo menos o prazo de cancelamento (parâmetro, padrão 120 minutos). Exatamente no limite do prazo o cancelamento é aceito. A reserva passa a `CANCELADA`, com o motivo `USUARIO`, quem cancelou e quando, e não gera falta. Depois do prazo, o cancelamento DEVE ser recusado informando o prazo; o cancelamento tardio, que gera falta, é de uma change posterior. Uma pendente cujo início já chegou expirou e é recusada como reserva não ativa. Uma reserva de outra pessoa, ou inexistente, DEVE ser recusada com a mesma mensagem de reserva não encontrada.

#### Scenario: Cancelar com antecedência
- **GIVEN** Ana tem uma reserva `CONFIRMADA` para amanhã às 10h00
- **WHEN** Ana cancela a reserva
- **THEN** a reserva fica `CANCELADA` com o motivo `USUARIO` e o horário volta a ficar livre

#### Scenario: Exatamente no limite
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva às 14h00
- **WHEN** Ana cancela às 12h00
- **THEN** o cancelamento é aceito

#### Scenario: Depois do prazo
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva às 14h00
- **WHEN** Ana tenta cancelar às 12h01
- **THEN** o sistema recusa informando que o cancelamento é permitido até 120 minutos antes do início e a reserva continua ativa

#### Scenario: Cancelar pendente
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" para depois de amanhã
- **WHEN** Ana cancela a reserva
- **THEN** a reserva fica `CANCELADA`

#### Scenario: Pendente já vencida
- **GIVEN** Ana tem uma reserva `PENDENTE` que começou às 14h00 sem decisão
- **WHEN** Ana tenta cancelá-la às 14h10
- **THEN** o sistema recusa informando que a reserva não está ativa e a reserva fica `EXPIRADA`

#### Scenario: Reserva de outra pessoa
- **WHEN** Carlos tenta cancelar uma reserva de Ana
- **THEN** o sistema recusa informando que a reserva não foi encontrada e nada muda

#### Scenario: Reserva já cancelada
- **GIVEN** a reserva de Ana já está `CANCELADA`
- **WHEN** Ana tenta cancelá-la de novo
- **THEN** o sistema recusa informando que a reserva não está ativa

### Requirement: Minhas reservas
Todo usuário com conta `ATIVA` DEVE (MUST) poder listar as próprias reservas, e somente as próprias. Cada reserva DEVE trazer: id, espaço (nome e código), unidade, tipo, data e horas de início e fim no fuso America/Sao_Paulo, situação efetiva (a pendente cujo início já chegou aparece como `EXPIRADA`, mesmo antes da gravação), motivo do cancelamento quando houver (com o motivo da desativação e a descrição de "Outro" quando o espaço ficou indisponível por desativação), motivo da recusa quando houver e se ainda pode ser cancelada pelo usuário dentro do prazo. Nas reservas canceladas por inativação de conta, o motivo da inativação NÃO DEVE (MUST NOT) aparecer.

#### Scenario: Usuário lista as próprias reservas
- **GIVEN** Ana tem uma reserva futura e uma cancelada, e Carlos tem outras reservas
- **WHEN** Ana lista as próprias reservas
- **THEN** recebe só as duas reservas dela, cada uma com a situação e o motivo do cancelamento quando houver

#### Scenario: Indicação de cancelamento possível
- **GIVEN** o prazo é de 120 minutos e Ana tem reservas para daqui a 1 hora e para amanhã
- **WHEN** Ana lista as próprias reservas
- **THEN** só a reserva de amanhã aparece como cancelável

#### Scenario: Recusada com motivo
- **GIVEN** a reserva `PENDENTE` de Ana foi recusada com o motivo "Laboratório em manutenção"
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece `RECUSADA` com o motivo "Laboratório em manutenção"

#### Scenario: Pendente vencida
- **GIVEN** a reserva `PENDENTE` de Ana começou há 10 minutos sem decisão e ainda não foi gravada como expirada
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece `EXPIRADA` e não cancelável

### Requirement: Tela de minhas reservas
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Minhas reservas", com as reservas próximas (pendentes e confirmadas que ainda não terminaram, da mais próxima para a mais distante) e o histórico (as demais). Cada reserva mostra o código e o nome do espaço, a unidade, a data, o horário e a situação; as canceladas mostram o motivo do cancelamento e as recusadas, o motivo da recusa. As reservas canceláveis oferecem "Cancelar", com confirmação.

#### Scenario: Cancelar pela página
- **GIVEN** Ana tem uma reserva para amanhã
- **WHEN** Ana abre "Minhas reservas", escolhe "Cancelar" e confirma
- **THEN** a página mostra a confirmação e a reserva passa ao histórico como cancelada pelo usuário

#### Scenario: Motivo de cancelamento automático
- **GIVEN** uma reserva de Ana foi cancelada pela desativação do espaço com o motivo "Manutenção ou reforma"
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a reserva aparece no histórico como cancelada por espaço indisponível, com "Manutenção ou reforma"

#### Scenario: Motivo descrito em "Outro"
- **GIVEN** uma reserva de Ana foi cancelada pela desativação da unidade com o motivo "Outro" e a descrição "Prédio cedido para a prefeitura"
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a reserva aparece com a descrição "Prédio cedido para a prefeitura"

#### Scenario: Recusada no histórico
- **GIVEN** uma reserva de Ana foi recusada com o motivo "Laboratório em manutenção"
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a reserva aparece no histórico como recusada, com "Laboratório em manutenção"

#### Scenario: Expirada no histórico
- **GIVEN** uma reserva `PENDENTE` de Ana começou sem decisão
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a reserva aparece no histórico como expirada, sem "Cancelar"
