# Especificação: Reservas

## Purpose
Permitir que cada usuário reserve um espaço para si, com a verificação das regras do tipo, da regra do papel, do limite de reservas ativas e do conflito de horário feita de forma atômica no backend. Também define o cancelamento pelo próprio usuário dentro do prazo, os cancelamentos automáticos por inativação de conta e por indisponibilidade do espaço, e a consulta das próprias reservas.

## Requirements

### Requirement: Criação de reserva avulsa
Todo usuário com conta `ATIVA` DEVE (MUST) poder reservar um espaço para si, informando o espaço, a data (AAAA-MM-DD) e as horas de início e de fim (HH:MM), no fuso America/Sao_Paulo. O sistema DEVE recusar a reserva, sem gravar nada, quando:
- o espaço não existe ou não é reservável (capability `espacos`), com a mesma mensagem nos dois casos;
- o papel de quem reserva não pode reservar o tipo do espaço (capability `regras-tipo`);
- o pedido está fora das regras do tipo (dias de funcionamento, horário de abertura e fechamento, granularidade, duração e antecedência), com os motivos;
- o usuário já atingiu o máximo de reservas ativas no tipo;
- o horário está ocupado no espaço.

A reserva aceita DEVE nascer `PENDENTE` quando o tipo exige aprovação para o papel e `CONFIRMADA` caso contrário, com origem direta, o nível de prioridade do papel no momento da criação (aluno 1, professor 2, coordenador e admin 3) e o instante de criação registrado pelo backend. As regras valem no momento da criação: alterar depois as regras do tipo ou o papel do usuário NÃO DEVE (MUST NOT) alterar reservas existentes. As recusas DEVEM ser respostas de validação com a mensagem do motivo, e nunca reservar em nome de outra pessoa.

#### Scenario: Aluno reserva a biblioteca
- **GIVEN** "Biblioteca" não exige aprovação para o aluno
- **WHEN** Ana, aluna, reserva "BIB-01" para a próxima quarta-feira, das 10h00 às 11h00
- **THEN** a reserva é criada `CONFIRMADA`, com nível de prioridade 1

#### Scenario: Aluno reserva laboratório com aprovação
- **GIVEN** "Laboratório" exige aprovação para o aluno
- **WHEN** Ana reserva "LAB-01" para a próxima quarta-feira, das 14h00 às 15h00
- **THEN** a reserva é criada `PENDENTE`

#### Scenario: Coordenador reserva sem aprovação
- **GIVEN** "Auditório" exige aprovação para o professor
- **WHEN** Rui, coordenador, reserva "AUD-01" de qualquer unidade com dois dias de antecedência
- **THEN** a reserva é criada `CONFIRMADA`, com nível de prioridade 3

#### Scenario: Papel sem permissão
- **GIVEN** o aluno não pode reservar "Sala de aula"
- **WHEN** Ana tenta reservar "Sala 12"
- **THEN** o sistema recusa informando que o papel dela não pode reservar esse tipo de espaço e nada é gravado

#### Scenario: Espaço não reservável
- **GIVEN** o tipo "Auditório" está desativado
- **WHEN** Carlos, professor, tenta reservar "AUD-01"
- **THEN** o sistema recusa informando que o espaço não está disponível para reserva

#### Scenario: Espaço inexistente
- **WHEN** alguém tenta reservar um id de espaço que não existe
- **THEN** o sistema recusa com a mesma mensagem de espaço não disponível para reserva

#### Scenario: Término às 22h40
- **GIVEN** "Biblioteca" fecha às 22h40
- **WHEN** Carlos reserva "BIB-01" das 21h40 às 22h40 de um dia de funcionamento
- **THEN** a reserva é criada

#### Scenario: Passando das 22h40
- **WHEN** Carlos tenta reservar "BIB-01" das 22h00 às 22h50
- **THEN** o sistema recusa com o motivo de fim depois do fechamento

#### Scenario: Antes das 08h00
- **WHEN** Carlos tenta reservar "BIB-01" das 07h50 às 08h50
- **THEN** o sistema recusa com o motivo de início antes da abertura

#### Scenario: Fora da granularidade
- **GIVEN** a granularidade é de 10 minutos
- **WHEN** Carlos tenta reservar "BIB-01" das 10h05 às 11h05
- **THEN** o sistema recusa com o motivo de horário fora da granularidade

#### Scenario: Antecedência máxima
- **GIVEN** "Biblioteca" aceita reservas com até 7 dias de antecedência
- **WHEN** Ana tenta reservar "BIB-01" para daqui a 10 dias
- **THEN** o sistema recusa com o motivo de antecedência maior que a máxima

#### Scenario: Antecedência mínima
- **GIVEN** "Auditório" exige 1440 minutos de antecedência
- **WHEN** Carlos tenta reservar "AUD-01" para daqui a 3 horas
- **THEN** o sistema recusa com o motivo de antecedência menor que a mínima

#### Scenario: Dia sem funcionamento
- **GIVEN** os dias de funcionamento são de segunda a sexta
- **WHEN** Ana tenta reservar "BIB-01" num sábado
- **THEN** o sistema recusa com o motivo de dia sem funcionamento

#### Scenario: Horário noturno em São Paulo
- **WHEN** Carlos reserva "BIB-01" das 21h00 às 22h00 de uma quarta-feira em São Paulo, intervalo que em UTC já é a quinta-feira
- **THEN** a reserva é criada como sendo de quarta-feira, no mesmo dia

#### Scenario: Data inexistente
- **WHEN** alguém tenta reservar para a data 2026-02-30
- **THEN** o sistema recusa informando o formato e os valores aceitos

#### Scenario: Regras alteradas depois
- **GIVEN** Ana tem uma reserva `CONFIRMADA` de 180 minutos em "BIB-01"
- **WHEN** o admin reduz a duração máxima de "Biblioteca" para 120 minutos
- **THEN** a reserva de Ana continua `CONFIRMADA`

#### Scenario: Conta inativa
- **GIVEN** a conta de Ana foi inativada
- **WHEN** Ana tenta reservar
- **THEN** o sistema responde como não autenticado

### Requirement: Conflito de horário
Uma nova reserva NÃO DEVE (MUST NOT) se sobrepor, no mesmo espaço, a uma reserva `PENDENTE` ou `CONFIRMADA`, nem a uma vaga retida pela fila de espera (entrada `NOTIFICADA` no prazo, capability `fila-espera`), exceto a reserva gerada pela confirmação da própria entrada. Há sobreposição quando o início de cada uma é anterior ao fim da outra; sobreposição parcial também é conflito, e reservas que apenas se encostam (uma termina quando a outra começa) não conflitam. Uma reserva `PENDENTE` cujo início já chegou expirou (capability `aprovacao-reservas`) e não ocupa mais o horário, assim como a vaga retida cujo prazo já venceu. A verificação do conflito e a gravação DEVEM ser atômicas: requisições simultâneas NUNCA podem gerar ocupações sobrepostas. O conflito é recusado sem identificar quem ocupa o horário, exceto quando o solicitante pode deslocar todas as reservas conflitantes e confirma o deslocamento (requisito "Deslocamento por prioridade"); nesse caso, as conflitantes são canceladas e a nova reserva é gravada na mesma operação atômica. A vaga retida nunca é deslocável: com ela no intervalo, o pedido é recusado como horário ocupado, e quem não pode deslocar pode entrar na fila (capability `fila-espera`).

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
- **GIVEN** Ana, aluna, tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00 da próxima semana
- **WHEN** Carlos, professor, pede o mesmo intervalo sem confirmar o deslocamento
- **THEN** o sistema não grava nada e pede a confirmação do deslocamento, sem dizer de quem é a reserva
- **AND** a reserva de Ana não muda

#### Scenario: Mesmo nível não desloca
- **GIVEN** Carlos, professor, tem uma reserva `CONFIRMADA` em "LAB-01" das 14h00 às 15h00 da próxima semana
- **WHEN** Paula, professora, tenta reservar o mesmo intervalo, com ou sem confirmar deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado, sem oferecer deslocamento, e a reserva de Carlos não muda

#### Scenario: Vaga retida ocupa o horário
- **GIVEN** a vaga de "BIB-01" das 14h00 às 15h00 de depois de amanhã está retida para Ana, no prazo
- **WHEN** Bruno, aluno, tenta reservar "BIB-01" das 14h30 às 15h30 do mesmo dia
- **THEN** o sistema recusa informando que o horário está ocupado, sem dizer quem retém a vaga

#### Scenario: Vaga retida não é deslocável
- **GIVEN** a vaga de "LAB-01" das 14h00 às 15h00 de depois de amanhã está retida para Ana, aluna, e o pedido de Rui, coordenador, nasceria confirmado
- **WHEN** Rui pede o mesmo intervalo e confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado, nada é cancelado e a vaga continua retida para Ana

#### Scenario: Reserva e vaga retida no mesmo pedido
- **GIVEN** Bruno, aluno, tem uma reserva em "LAB-01" das 14h00 às 15h00 de depois de amanhã, e a vaga das 15h00 às 16h00 está retida para Ana, aluna
- **WHEN** Carlos, professor, pede das 14h30 às 15h30 e confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Bruno não muda

#### Scenario: Vaga retida vencida não ocupa
- **GIVEN** o prazo da vaga retida para Ana em "BIB-01" das 14h00 às 15h00 venceu, e ninguém mais está na fila
- **WHEN** Bruno reserva "BIB-01" das 14h00 às 15h00
- **THEN** a reserva de Bruno é criada e a entrada de Ana fica `EXPIRADA`

#### Scenario: Mesmo horário em outro espaço
- **GIVEN** "LAB-01" está ocupado das 14h00 às 15h00
- **WHEN** Carlos reserva "LAB-02" das 14h00 às 15h00
- **THEN** a reserva é criada

#### Scenario: Requisições simultâneas
- **WHEN** Ana e Carlos enviam ao mesmo tempo reservas de "LAB-01" para intervalos sobrepostos
- **THEN** só uma reserva é criada e o outro recebe a recusa de horário ocupado ou o pedido de confirmação do deslocamento, sem que nada seja cancelado sem confirmação

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

### Requirement: Cancelamento por inativação de conta
Ao inativar uma conta (capability `situacao-conta`), o sistema DEVE (MUST) cancelar, na mesma operação, as reservas `PENDENTE` e `CONFIRMADA` da conta que ainda não começaram, com o motivo `CONTA_INATIVADA`, o admin que inativou como autor do cancelamento e sem falta. A reserva que já está em andamento NÃO DEVE (MUST NOT) ser cancelada. Reativar a conta NÃO DEVE restaurar reservas canceladas.

#### Scenario: Inativar conta com reservas futuras
- **GIVEN** Carlos tem 3 reservas futuras
- **WHEN** um admin inativa Carlos
- **THEN** as 3 reservas ficam `CANCELADA` com o motivo `CONTA_INATIVADA`

#### Scenario: Reserva em andamento continua
- **GIVEN** Carlos está usando "LAB-01" das 14h00 às 16h00 e são 15h00
- **WHEN** um admin inativa Carlos
- **THEN** a reserva das 14h00 continua ativa e as futuras são canceladas

#### Scenario: Reativar não restaura
- **GIVEN** as reservas de Carlos foram canceladas pela inativação
- **WHEN** um admin reativa Carlos
- **THEN** as reservas continuam `CANCELADA`

### Requirement: Cancelamento por indisponibilidade do espaço
As ações abaixo afetam reservas dos espaços envolvidos:
- desativar um espaço;
- trocar o tipo de um espaço;
- mover um espaço para outra unidade;
- desativar um tipo de espaço (todos os espaços dele);
- desativar uma unidade (todos os espaços dela).

Enquanto algum dos espaços afetados tiver uma reserva `CONFIRMADA` **em andamento** (já começou e ainda não terminou), a ação DEVE (MUST) ser recusada sem alterar nada, informando até que horas vai a reserva em andamento (a que termina por último, quando houver mais de uma). Nenhum papel, nem admin nem coordenador, encerra uma reserva em uso. Sem reserva confirmada em andamento, a ação DEVE cancelar, na mesma operação, as reservas `PENDENTE` e `CONFIRMADA` dos espaços afetados que ainda não terminaram, com o motivo `ESPACO_INDISPONIVEL`, quem executou a ação como autor do cancelamento e sem falta. Nas desativações, cada reserva cancelada DEVE guardar também o motivo escolhido para a desativação e, em "Outro", a descrição; mover o espaço e trocar o tipo não têm motivo próprio. Uma reserva `PENDENTE` cujo início já passou não impede a ação e é cancelada junto. Admin e coordenador seguem a mesma regra, cada um no escopo que a ação já exige. Reservas que já terminaram NÃO DEVEM (MUST NOT) ser alteradas. Editar um espaço sem trocar o tipo NÃO DEVE ser recusado nem cancelar reservas. Reativar o espaço, o tipo ou a unidade NÃO DEVE restaurar reservas canceladas.

#### Scenario: Espaço em uso recusa a desativação
- **GIVEN** "LAB-01" tem uma reserva `CONFIRMADA` das 13h00 às 14h00 e outra das 15h00 às 16h00, e são 13h58
- **WHEN** Rui, coordenador da unidade, tenta desativar "LAB-01"
- **THEN** o sistema recusa informando que há reserva em andamento até 14h00
- **AND** "LAB-01" continua ativo e as duas reservas continuam ativas

#### Scenario: Admin também espera
- **GIVEN** "LAB-01" tem uma reserva `CONFIRMADA` em andamento até 14h00
- **WHEN** o admin tenta desativar "LAB-01"
- **THEN** o sistema recusa informando que há reserva em andamento até 14h00 e nada muda

#### Scenario: Depois que a reserva termina
- **GIVEN** "LAB-01" teve uma reserva das 13h00 às 14h00 e tem outra das 15h00 às 16h00, e são 14h01
- **WHEN** Rui desativa "LAB-01"
- **THEN** "LAB-01" fica desativado e a reserva das 15h00 fica `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`
- **AND** a reserva das 13h00 não é alterada

#### Scenario: Pendente já iniciada não impede
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" que começou às 13h00 e são 13h30
- **WHEN** Rui desativa "LAB-01"
- **THEN** "LAB-01" fica desativado e a reserva de Ana fica `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Unidade com algum espaço em uso
- **GIVEN** "Paulista" tem "LAB-01" com reserva `CONFIRMADA` em andamento até 15h00 e "BIB-01" com reserva `CONFIRMADA` em andamento até 16h00
- **WHEN** o admin tenta desativar "Paulista"
- **THEN** o sistema recusa informando que há 2 reservas em andamento e a última termina às 16h00, e nada muda, inclusive coordenadores, professores e pedidos

#### Scenario: Trocar o tipo com espaço em uso
- **GIVEN** "Sala 12" tem uma reserva `CONFIRMADA` em andamento
- **WHEN** Rui tenta trocar o tipo de "Sala 12"
- **THEN** o sistema recusa informando que há reserva em andamento e nada muda, inclusive os demais campos enviados

#### Scenario: Trocar o tipo cancela
- **GIVEN** "Sala 12" é de "Sala de aula" e tem 2 reservas futuras
- **WHEN** Rui troca o tipo de "Sala 12" para "Laboratório"
- **THEN** as 2 reservas ficam `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Editar sem trocar o tipo
- **GIVEN** "Sala 12" tem reservas futuras
- **WHEN** Rui altera só a capacidade de "Sala 12"
- **THEN** as reservas continuam ativas

#### Scenario: Mover espaço cancela
- **GIVEN** "Sala 12" de "Paulista" tem reservas futuras
- **WHEN** o admin move "Sala 12" para "Vila Olímpia"
- **THEN** as reservas de "Sala 12" ficam `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Desativar tipo cancela em todas as unidades
- **GIVEN** "Auditório" tem espaços com reservas futuras em "Paulista" e em "Vila Olímpia"
- **WHEN** o admin desativa "Auditório"
- **THEN** as reservas desses espaços, nas duas unidades, ficam `CANCELADA`

#### Scenario: Desativar unidade cancela
- **GIVEN** os espaços de "Paulista" têm reservas futuras
- **WHEN** o admin desativa "Paulista"
- **THEN** as reservas dos espaços de "Paulista" ficam `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Reativar não restaura
- **GIVEN** as reservas de "LAB-01" foram canceladas pela desativação
- **WHEN** Rui reativa "LAB-01"
- **THEN** as reservas continuam `CANCELADA` e o horário fica livre para novas reservas

### Requirement: Impacto das ações sobre reservas
Antes de desativar um espaço, um tipo ou uma unidade, de mover um espaço, de trocar o tipo de um espaço ou de inativar uma conta, o sistema DEVE (MUST) informar a quem pode executar a ação quantas reservas ela cancelaria e, para as ações sobre espaços, tipos e unidades, se há reserva confirmada em andamento que hoje impediria a ação e até que horas. A consulta exige a mesma autorização da ação correspondente, aplica as mesmas regras da ação e não altera nada; a própria ação recalcula tudo no momento em que é executada. A consulta DEVE indicar exatamente um alvo (espaço, tipo, unidade ou conta); sem alvo, ou com mais de um, ela é recusada. Para o coordenador, um espaço inexistente recebe a mesma recusa de acesso negado de um espaço de outra unidade.

#### Scenario: Impacto de desativar espaço
- **GIVEN** "LAB-01" tem 2 reservas futuras e nenhuma em andamento
- **WHEN** Rui consulta o impacto de desativar "LAB-01"
- **THEN** o sistema informa 2 reservas, sem reserva em andamento

#### Scenario: Impacto com espaço em uso
- **GIVEN** "LAB-01" tem uma reserva `CONFIRMADA` em andamento até 14h00 e 2 reservas futuras
- **WHEN** Rui consulta o impacto de desativar "LAB-01"
- **THEN** o sistema informa que há reserva em andamento até 14h00, o que hoje impediria a desativação, e 2 reservas futuras

#### Scenario: Impacto de inativar conta
- **GIVEN** Carlos tem 2 reservas futuras e uma em andamento
- **WHEN** o admin consulta o impacto de inativar Carlos
- **THEN** o sistema informa 2 reservas, sem reserva em andamento a cancelar

#### Scenario: Coordenador de outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui consulta o impacto de desativar um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado

#### Scenario: Coordenador e tipo de espaço
- **WHEN** Rui consulta o impacto de desativar o tipo "Auditório"
- **THEN** o sistema responde com acesso negado

#### Scenario: Espaço inexistente para o coordenador
- **WHEN** Rui consulta o impacto de um id de espaço que não existe
- **THEN** o sistema responde com acesso negado, com a mesma mensagem de um espaço de outra unidade

#### Scenario: Alvo ausente ou duplicado
- **WHEN** o admin consulta o impacto sem informar alvo, ou informando um espaço e uma unidade ao mesmo tempo
- **THEN** o sistema recusa informando que é preciso indicar exatamente um alvo

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

### Requirement: Deslocamento por prioridade
Um pedido que conflita com reservas ativas do espaço DEVE (MUST) poder deslocá-las quando, ao mesmo tempo:
- todas as conflitantes têm nível de prioridade, gravado na criação delas, estritamente menor que o do papel atual do solicitante;
- a nova reserva e cada conflitante começam a mais de `prazo_deslocamento_minutos` de agora;
- a nova reserva nasceria `CONFIRMADA`.

Se qualquer condição falhar, o pedido é recusado como horário ocupado.

#### Scenario: Professor desloca aluno
- **GIVEN** Ana, aluna, tem uma reserva aprovada, `CONFIRMADA`, em "LAB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma o deslocamento
- **THEN** a reserva de Carlos é criada `CONFIRMADA` e a de Ana fica `CANCELADA` com o motivo `PRIORIDADE`

#### Scenario: Coordenador desloca professor
- **GIVEN** Carlos, professor, tem uma reserva aprovada, `CONFIRMADA`, em "AUD-01" de daqui a 3 dias
- **WHEN** Rui, coordenador de outra unidade, reserva um intervalo sobreposto de "AUD-01" e confirma
- **THEN** a reserva de Rui é criada e a de Carlos é deslocada

#### Scenario: Pendente de nível menor é deslocável
- **GIVEN** Ana, aluna, tem uma reserva `PENDENTE` em "LAB-01" para depois de amanhã
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma
- **THEN** a pendente de Ana fica `CANCELADA` com o motivo `PRIORIDADE` e a reserva de Carlos é criada

#### Scenario: Nível gravado na criação
- **GIVEN** Ana criou uma reserva em "LAB-01" quando era aluna e depois foi promovida a professora
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma
- **THEN** a reserva de Ana é deslocada, porque foi criada com nível 1

#### Scenario: Conflitantes com níveis mistos
- **GIVEN** "LAB-01" tem uma reserva de Ana, aluna, das 14h00 às 15h00 e uma de Paula, professora, das 15h00 às 16h00
- **WHEN** Carlos, professor, tenta reservar das 14h30 às 15h30 e confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado e nenhuma das duas reservas muda

#### Scenario: Empate no nível 3
- **GIVEN** Rui, coordenador, tem uma reserva em "AUD-01" para daqui a 3 dias
- **WHEN** o admin, ou outro coordenador, tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Rui não muda

#### Scenario: Fora das regras antes do deslocamento
- **GIVEN** Ana, aluna, tem uma reserva em "BIB-01" das 21h40 às 22h40 de depois de amanhã
- **WHEN** Carlos, professor, tenta reservar "BIB-01" das 22h00 às 22h50 e confirma
- **THEN** o sistema recusa com o motivo de fim depois do fechamento e a reserva de Ana não muda

#### Scenario: Aluno nunca desloca
- **GIVEN** Bruno, aluno, tem uma reserva em "BIB-01" para depois de amanhã
- **WHEN** Ana, aluna, tenta reservar o mesmo intervalo
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Prazo exatamente no limite
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "LAB-01" às 14h00 e são 12h00
- **WHEN** Carlos, professor, tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana não muda

#### Scenario: Um minuto além do prazo
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "LAB-01" às 14h00 e são 11h59
- **WHEN** Carlos, professor, reserva o mesmo intervalo e confirma
- **THEN** a reserva de Ana é deslocada e a de Carlos é criada

#### Scenario: Reserva em andamento não é deslocada
- **GIVEN** Ana, aluna, está usando "LAB-01" das 08h00 às 12h00, com a reserva aprovada, e são 08h30
- **WHEN** Carlos, professor, tenta reservar "LAB-01" das 11h00 às 12h00 e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana continua ativa

#### Scenario: Nova reserva perto demais
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" das 11h30 às 12h00 e são 09h00
- **WHEN** Carlos, professor, tenta reservar "LAB-01" das 10h00 às 12h00 e confirma
- **THEN** o sistema recusa informando que o horário está ocupado, porque a reserva de Carlos começaria a menos do prazo

#### Scenario: Nova reserva exatamente no limite
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "BIB-01" das 15h00 às 16h00 e são 12h00
- **WHEN** Carlos, professor, tenta reservar "BIB-01" das 14h00 às 15h30 e confirma
- **THEN** o sistema recusa informando que o horário está ocupado, porque a reserva de Carlos começa exatamente no prazo

#### Scenario: Nova reserva um minuto além do limite
- **GIVEN** o prazo para deslocar é de 120 minutos, Ana, aluna, tem uma reserva em "BIB-01" das 15h00 às 16h00 e são 11h59
- **WHEN** Carlos, professor, reserva "BIB-01" das 14h00 às 15h30 e confirma
- **THEN** a reserva de Ana é deslocada e a de Carlos é criada

#### Scenario: Nova reserva exigiria aprovação
- **GIVEN** o admin configurou "Laboratório" para exigir aprovação do professor, e Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos, professor, tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando que o horário está ocupado e a reserva de Ana não muda

#### Scenario: Limite de ativas do solicitante
- **GIVEN** Carlos, professor, já tem o máximo de reservas ativas de "Laboratório", e Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos tenta reservar o mesmo intervalo e confirma
- **THEN** o sistema recusa informando o limite de reservas ativas e a reserva de Ana não muda

#### Scenario: Pendente vencida não entra no deslocamento
- **GIVEN** Ana, aluna, tem uma reserva `PENDENTE` vencida em "LAB-01", e Bruno, aluno, tem uma reserva `CONFIRMADA` sobreposta ao mesmo pedido
- **WHEN** Carlos, professor, reserva e confirma
- **THEN** só a reserva de Bruno é deslocada, e a de Ana fica `EXPIRADA`

### Requirement: Confirmação do deslocamento
Quando o pedido pode deslocar reservas e o solicitante não confirmou o deslocamento, o sistema NÃO DEVE (MUST NOT) gravar nada e DEVE responder, como resultado distinto de uma recusa, que o pedido deslocaria N reservas, sem identificar donos nem horários delas. Com a confirmação, o sistema DEVE recalcular tudo, cancelar as conflitantes e gravar a nova reserva na mesma operação atômica. A confirmação sem conflito cria a reserva normalmente.

#### Scenario: Pedido sem confirmação
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos, professor, pede o mesmo intervalo sem confirmar o deslocamento
- **THEN** o sistema responde que o pedido deslocaria 1 reserva e pede confirmação, sem dizer de quem
- **AND** nada é gravado e nenhum registro de auditoria é gerado

#### Scenario: Duas reservas deslocadas
- **GIVEN** Ana e Bruno, alunos, têm reservas em "LAB-01" das 14h00 às 15h00 e das 15h00 às 16h00 de depois de amanhã
- **WHEN** Carlos, professor, pede das 14h00 às 16h00 e confirma
- **THEN** as duas reservas ficam `CANCELADA` com o motivo `PRIORIDADE` e a de Carlos é criada

#### Scenario: Conflito sumiu antes da confirmação
- **GIVEN** Carlos recebeu o pedido de confirmação, e Ana cancelou a reserva dela em seguida
- **WHEN** Carlos confirma o deslocamento
- **THEN** a reserva de Carlos é criada e nenhuma reserva é cancelada por prioridade

#### Scenario: Conflito mudou antes da confirmação
- **GIVEN** Carlos recebeu o pedido de confirmação para deslocar a reserva de Ana, e Paula, professora, reservou em seguida outro trecho sobreposto ao pedido de Carlos
- **WHEN** Carlos confirma o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado e nenhuma reserva é cancelada

#### Scenario: Deslocamentos simultâneos
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" para depois de amanhã
- **WHEN** Carlos e Paula, professores, confirmam ao mesmo tempo o deslocamento para o mesmo intervalo
- **THEN** só uma das duas reservas é criada, a de Ana é cancelada uma única vez e o outro recebe a recusa de horário ocupado

#### Scenario: Deslocamento e cancelamento pelo dono simultâneos
- **WHEN** Carlos confirma o deslocamento da reserva de Ana no mesmo instante em que Ana a cancela
- **THEN** a reserva de Ana termina `CANCELADA` uma única vez, com o motivo da operação que chegou primeiro, e a de Carlos é criada

### Requirement: Reserva deslocada
A reserva deslocada DEVE (MUST) ser cancelada inteira, mesmo quando a sobreposição é parcial, com o motivo `PRIORIDADE`, o solicitante como autor do cancelamento, o instante, a referência à reserva que a deslocou e sem falta. O dono vê em "Minhas reservas" o motivo, sem o nome de quem deslocou. Quem desloca não vê de quem eram as reservas.

#### Scenario: Sobreposição parcial cancela a reserva inteira
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" das 09h00 às 12h00 de depois de amanhã
- **WHEN** Carlos, professor, reserva das 10h00 às 11h00 e confirma
- **THEN** a reserva de Ana fica `CANCELADA` inteira e o horário das 09h00 às 10h00 e das 11h00 às 12h00 fica livre

#### Scenario: Deslocada em minhas reservas
- **GIVEN** a reserva de Ana foi deslocada por Carlos
- **WHEN** Ana lista as próprias reservas
- **THEN** a reserva aparece `CANCELADA`, no histórico, com o motivo de substituição por reserva de prioridade maior e sem o nome de Carlos

#### Scenario: Deslocamento não gera falta
- **WHEN** a reserva de Ana é deslocada a 3 horas do início
- **THEN** nenhuma falta é registrada para Ana

#### Scenario: Gestão vê quem deslocou
- **GIVEN** a reserva de Ana em "LAB-01" foi deslocada por Carlos
- **WHEN** Rui, coordenador da unidade de "LAB-01", lista as reservas canceladas da unidade
- **THEN** a reserva de Ana aparece com o motivo `PRIORIDADE` e Carlos como quem cancelou
