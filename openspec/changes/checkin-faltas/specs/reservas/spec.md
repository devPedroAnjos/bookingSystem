## MODIFIED Requirements

### Requirement: Cancelamento pelo próprio usuário
O usuário DEVE (MUST) poder cancelar uma reserva própria `PENDENTE` ou `CONFIRMADA` antes do início dela. Quando falta, até o início, pelo menos o prazo de cancelamento (parâmetro, padrão 120 minutos), inclusive exatamente no limite, a reserva passa a `CANCELADA` com o motivo `USUARIO`, quem cancelou e quando, e não gera falta. A `PENDENTE` é cancelada assim, com o motivo `USUARIO` e sem falta, a qualquer momento antes do início. A `CONFIRMADA` com menos que o prazo até o início é cancelada com o motivo `USUARIO_TARDIO` e gera falta (capability `penalidades`), mas só quando o usuário confirma que aceita a falta: sem essa confirmação, o sistema NÃO DEVE (MUST NOT) alterar a reserva nem registrar falta ou auditoria do cancelamento, e DEVE responder, como resultado distinto de uma recusa, que o cancelamento gera falta. A partir do início, e em reserva com check-in feito, o cancelamento DEVE ser recusado. Uma pendente cujo início já chegou expirou e é recusada como reserva não ativa. Uma reserva de outra pessoa, ou inexistente, DEVE ser recusada com a mesma mensagem de reserva não encontrada.

#### Scenario: Cancelar com antecedência
- **GIVEN** Ana tem uma reserva `CONFIRMADA` para amanhã às 10h00
- **WHEN** Ana cancela a reserva
- **THEN** a reserva fica `CANCELADA` com o motivo `USUARIO` e o horário volta a ficar livre

#### Scenario: Exatamente no limite
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva às 14h00
- **WHEN** Ana cancela às 12h00
- **THEN** o cancelamento é aceito com o motivo `USUARIO`, sem falta

#### Scenario: Depois do prazo
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva `CONFIRMADA` às 14h00
- **WHEN** Ana tenta cancelar às 12h01 sem confirmar que aceita a falta
- **THEN** o sistema responde que o cancelamento a menos de 120 minutos do início gera falta e pede a confirmação
- **AND** a reserva continua ativa, sem falta, e nenhum registro do cancelamento é gerado
- **AND** vencimentos já devidos de outras reservas de Ana podem ter sido gravados antes, como em qualquer operação

#### Scenario: Cancelamento tardio confirmado
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva `CONFIRMADA` às 14h00
- **WHEN** Ana cancela às 12h01 confirmando que aceita a falta
- **THEN** a reserva fica `CANCELADA` com o motivo `USUARIO_TARDIO`, o horário volta a ficar livre e é registrada uma falta de cancelamento tardio

#### Scenario: Confirmação com o prazo ainda valendo
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva `CONFIRMADA` às 14h00
- **WHEN** Ana cancela às 11h00 confirmando que aceita a falta
- **THEN** a reserva fica `CANCELADA` com o motivo `USUARIO`, sem falta

#### Scenario: Prazo vence entre o aviso e o clique
- **GIVEN** o prazo é de 120 minutos, Ana tem uma reserva `CONFIRMADA` às 14h00 e "Minhas reservas" mostrou às 11h59 que o cancelamento era sem falta
- **WHEN** o pedido de cancelamento de Ana, sem confirmação de falta, chega às 12h01
- **THEN** o sistema não grava nada e responde que o cancelamento agora gera falta, pedindo a confirmação

#### Scenario: Cancelar pendente
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" para depois de amanhã
- **WHEN** Ana cancela a reserva
- **THEN** a reserva fica `CANCELADA`

#### Scenario: Pendente depois do prazo
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva `PENDENTE` em "LAB-01" às 14h00
- **WHEN** Ana cancela às 13h30, sem confirmar falta
- **THEN** a reserva fica `CANCELADA` com o motivo `USUARIO` e nenhuma falta é registrada

#### Scenario: Depois do início
- **GIVEN** Ana tem uma reserva `CONFIRMADA` das 14h00 às 15h00, sem check-in
- **WHEN** Ana tenta cancelar às 14h00, confirmando ou não a falta
- **THEN** o sistema recusa informando que a reserva já começou e nada muda

#### Scenario: Depois do check-in
- **GIVEN** Ana fez check-in às 13h50 da reserva das 14h00
- **WHEN** Ana tenta cancelar às 13h55
- **THEN** o sistema recusa informando que a reserva com check-in não pode ser cancelada

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

#### Scenario: Cancelamento tardio e desativação simultâneos
- **WHEN** Ana confirma o cancelamento tardio da reserva dela em "LAB-01" no mesmo instante em que Rui desativa "LAB-01"
- **THEN** a reserva termina `CANCELADA` uma única vez, com o motivo da operação que chegou primeiro, e a falta só existe se o cancelamento de Ana chegou primeiro

### Requirement: Minhas reservas
Todo usuário com conta `ATIVA` DEVE (MUST) poder listar as próprias reservas, e somente as próprias. Cada reserva DEVE trazer: id, espaço (nome e código), unidade, tipo, data e horas de início e fim no fuso America/Sao_Paulo, situação efetiva (a pendente cujo início já chegou aparece como `EXPIRADA`, a confirmada sem check-in depois da janela como `NAO_COMPARECEU` e a confirmada com check-in depois do fim como `CONCLUIDA`, mesmo antes da gravação), motivo do cancelamento quando houver (com o motivo da desativação e a descrição de "Outro" quando o espaço ficou indisponível por desativação), motivo da recusa quando houver, se ainda pode ser cancelada e se o cancelamento agora geraria falta, o instante do check-in quando houver, a janela de check-in (abertura e fechamento) e se o check-in pode ser feito agora, e a falta gerada pela reserva, quando houver. Nas reservas canceladas por inativação de conta, o motivo da inativação NÃO DEVE (MUST NOT) aparecer.

#### Scenario: Usuário lista as próprias reservas
- **GIVEN** Ana tem uma reserva futura e uma cancelada, e Carlos tem outras reservas
- **WHEN** Ana lista as próprias reservas
- **THEN** recebe só as duas reservas dela, cada uma com a situação e o motivo do cancelamento quando houver

#### Scenario: Indicação de cancelamento possível
- **GIVEN** o prazo é de 120 minutos e Ana tem reservas `CONFIRMADA` para daqui a 1 hora e para amanhã
- **WHEN** Ana lista as próprias reservas
- **THEN** as duas aparecem canceláveis, e só a de daqui a 1 hora indica que o cancelamento geraria falta

#### Scenario: Pendente perto do início
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva `PENDENTE` para daqui a 1 hora
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece cancelável, sem indicação de falta

#### Scenario: Recusada com motivo
- **GIVEN** a reserva `PENDENTE` de Ana foi recusada com o motivo "Laboratório em manutenção"
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece `RECUSADA` com o motivo "Laboratório em manutenção"

#### Scenario: Pendente vencida
- **GIVEN** a reserva `PENDENTE` de Ana começou há 10 minutos sem decisão e ainda não foi gravada como expirada
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece `EXPIRADA` e não cancelável

#### Scenario: Check-in disponível
- **GIVEN** Ana tem uma reserva `CONFIRMADA` às 14h00, sem check-in, e são 13h50
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva indica que o check-in pode ser feito agora, com a janela das 13h45 às 14h15

#### Scenario: Não compareceu com falta
- **GIVEN** a janela da reserva de Ana fechou às 14h15 sem check-in, ainda sem gravação
- **WHEN** Ana lista as próprias reservas às 14h30
- **THEN** a reserva aparece `NAO_COMPARECEU`, com a falta de não comparecimento, não cancelável e sem check-in possível

#### Scenario: Concluída com check-in
- **GIVEN** Ana fez check-in às 13h55 da reserva das 14h00 às 15h00
- **WHEN** Ana lista as próprias reservas às 15h10
- **THEN** a reserva aparece `CONCLUIDA`, com o check-in às 13h55

### Requirement: Tela de minhas reservas
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Minhas reservas", com as reservas próximas (pendentes e confirmadas que ainda não terminaram nem ficaram sem comparecimento, da mais próxima para a mais distante) e o histórico (as demais). Cada reserva mostra o código e o nome do espaço, a unidade, a data, o horário e a situação; as canceladas mostram o motivo do cancelamento, as recusadas o motivo da recusa e as que geraram falta indicam a falta. As reservas com check-in possível oferecem "Fazer check-in", e as que já têm check-in mostram o horário dele. As reservas canceláveis oferecem "Cancelar", com confirmação; quando o cancelamento gera falta, a confirmação avisa disso antes.

#### Scenario: Cancelar pela página
- **GIVEN** Ana tem uma reserva para amanhã
- **WHEN** Ana abre "Minhas reservas", escolhe "Cancelar" e confirma
- **THEN** a página mostra a confirmação e a reserva passa ao histórico como cancelada pelo usuário

#### Scenario: Cancelamento tardio pela página
- **GIVEN** o prazo é de 120 minutos e Ana tem uma reserva `CONFIRMADA` para daqui a 1 hora
- **WHEN** Ana escolhe "Cancelar"
- **THEN** a confirmação avisa que o cancelamento gera falta
- **AND** ao confirmar, a reserva passa ao histórico como cancelada tardiamente, com a falta

#### Scenario: Aviso de falta que surge no envio
- **GIVEN** a página de Ana mostrou o cancelamento sem falta, e o prazo venceu antes do envio
- **WHEN** Ana confirma o cancelamento comum
- **THEN** a página mostra que o cancelamento agora gera falta e pede a nova confirmação, sem cancelar

#### Scenario: Fazer check-in pela página
- **GIVEN** Ana tem uma reserva `CONFIRMADA` às 14h00 e são 13h50
- **WHEN** Ana abre "Minhas reservas" e escolhe "Fazer check-in"
- **THEN** a página mostra a confirmação e a reserva passa a mostrar o check-in às 13h50, sem "Fazer check-in" nem "Cancelar"

#### Scenario: Check-in recusado pela página
- **GIVEN** a página de Ana mostrou "Fazer check-in" às 14h14, e ela só clicou às 14h16
- **WHEN** Ana escolhe "Fazer check-in"
- **THEN** a página mostra a recusa da janela encerrada e atualiza a lista

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

#### Scenario: Não compareceu no histórico
- **GIVEN** Ana não fez check-in da reserva das 14h00 até as 14h15
- **WHEN** Ana abre "Minhas reservas" às 14h20
- **THEN** a reserva aparece no histórico como não compareceu, com a indicação da falta
