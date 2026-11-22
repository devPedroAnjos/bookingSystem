# Especificação: Penalidades

## Purpose
Registrar as faltas de quem não comparece ou cancela tarde, transformar o acúmulo de faltas em penalidades encadeadas que impedem novas reservas e filas por um período, e permitir que o admin anule uma penalidade com parecer.

## Requirements

### Requirement: Registro de falta
O sistema DEVE (MUST) registrar uma falta para o dono da reserva quando ela fica `NAO_COMPARECEU` (tipo `NAO_COMPARECIMENTO`, no instante em que a janela de check-in fechou) ou é cancelada com o motivo `USUARIO_TARDIO` (tipo `CANCELAMENTO_TARDIO`, no instante do cancelamento). Uma reserva gera no máximo uma falta. Expiração, recusa, cancelamento da pendente, deslocamento e cancelamentos automáticos NÃO DEVEM (MUST NOT) gerar falta.

#### Scenario: Falta por não comparecimento
- **GIVEN** Ana não fez check-in da reserva das 14h00, cuja janela fechou às 14h15
- **WHEN** o não comparecimento é gravado às 15h30
- **THEN** existe uma falta de Ana do tipo `NAO_COMPARECIMENTO`, ligada a essa reserva, ocorrida às 14h15

#### Scenario: Falta por cancelamento tardio
- **GIVEN** o prazo de cancelamento é de 120 minutos e Ana tem uma reserva `CONFIRMADA` às 14h00
- **WHEN** Ana cancela às 13h00, confirmando que aceita a falta
- **THEN** existe uma falta de Ana do tipo `CANCELAMENTO_TARDIO`, ocorrida às 13h00

#### Scenario: Deslocamento não gera falta
- **WHEN** a reserva de Ana é deslocada por prioridade
- **THEN** nenhuma falta é registrada para Ana

#### Scenario: Cancelamento automático não gera falta
- **WHEN** a reserva futura de Ana é cancelada pela desativação do espaço
- **THEN** nenhuma falta é registrada para Ana

#### Scenario: Pendente expirada não gera falta
- **WHEN** a reserva `PENDENTE` de Ana expira no início sem decisão
- **THEN** nenhuma falta é registrada para Ana

### Requirement: Geração de penalidade
Ao registrar uma falta, o sistema DEVE (MUST) contar as faltas do mesmo usuário ainda sem penalidade, ocorridas desde `janela_faltas_dias` antes dela, inclusive, até ela. Se forem pelo menos `faltas_para_penalidade`, gera uma penalidade `ATIVA` de `duracao_penalidade_dias` e vincula a ela todas essas faltas. Uma falta contribui para uma única penalidade. Faltas cometidas durante uma penalidade contam normalmente.

#### Scenario: Segunda falta em 30 dias
- **GIVEN** os parâmetros são 2 faltas em 30 dias e 7 dias de penalidade, e Ana tem uma falta sem penalidade ocorrida em 01/12 às 10h15
- **WHEN** Ana não comparece a uma reserva e a falta ocorre em 10/12 às 14h15
- **THEN** é gerada uma penalidade de Ana de 10/12 às 14h15 até 17/12 às 14h15, com as duas faltas vinculadas

#### Scenario: Limite exato da janela
- **GIVEN** os parâmetros são 2 faltas em 30 dias e Ana tem uma falta sem penalidade ocorrida em 01/11 às 10h00
- **WHEN** uma nova falta de Ana ocorre em 01/12 às 10h00, exatamente 30 dias depois
- **THEN** é gerada uma penalidade

#### Scenario: Fora da janela
- **GIVEN** os parâmetros são 2 faltas em 30 dias e Ana tem uma falta sem penalidade ocorrida em 01/11 às 10h00
- **WHEN** uma nova falta de Ana ocorre em 01/12 às 10h01
- **THEN** nenhuma penalidade é gerada e as duas faltas continuam sem penalidade

#### Scenario: Falta já usada não conta de novo
- **GIVEN** Ana teve uma penalidade gerada por duas faltas de dezembro
- **WHEN** Ana comete uma terceira falta em dezembro
- **THEN** nenhuma penalidade nova é gerada, porque só uma falta está sem penalidade

#### Scenario: Faltas de outro usuário não contam
- **GIVEN** Ana e Bruno têm uma falta cada um
- **WHEN** Ana comete a segunda falta
- **THEN** só Ana recebe penalidade

#### Scenario: Primeira falta
- **WHEN** Carlos comete a primeira falta
- **THEN** nenhuma penalidade é gerada

### Requirement: Encadeamento de penalidades
As penalidades de um usuário NUNCA DEVEM (MUST NOT) se sobrepor. A nova penalidade DEVE (MUST) começar no instante da falta que a gerou ou, se for mais tarde, no fim da última penalidade não anulada do usuário. O fim é o início mais a duração.

#### Scenario: Nova penalidade durante uma em vigor
- **GIVEN** Ana está com uma penalidade de 10/12 às 14h15 até 17/12 às 14h15, e não compareceu a duas reservas confirmadas antes dela, com faltas em 12/12 e 13/12
- **WHEN** a segunda dessas faltas é registrada
- **THEN** é gerada uma penalidade de 17/12 às 14h15 até 24/12 às 14h15

#### Scenario: Falta processada depois do vencimento
- **GIVEN** as faltas de Ana ocorreram em 01/12 e 03/12 às 10h15, e a segunda só foi gravada em 05/12
- **WHEN** a penalidade é gerada em 05/12
- **THEN** ela começa em 03/12 às 10h15, o instante da falta, e termina em 10/12 às 10h15

### Requirement: Penalidade em vigor
Uma penalidade está em vigor quando está `ATIVA` e o instante está entre o início, inclusive, e o fim, exclusive. Com uma penalidade em vigor, o usuário NÃO DEVE (MUST NOT) criar reservas, inclusive com deslocamento, nem entrar numa fila, nem confirmar vaga retida. A recusa informa até quando vão as penalidades encadeadas sem intervalo. Reservas existentes, check-in e cancelamento seguem normais.

#### Scenario: Criação recusada
- **GIVEN** Ana está com uma penalidade em vigor até 17/12 às 14h15
- **WHEN** Ana tenta reservar "BIB-01"
- **THEN** o sistema recusa informando que ela está com penalidade até 17/12 às 14h15 e a reserva não é criada

#### Scenario: Penalidades encadeadas na mensagem
- **GIVEN** Ana está com uma penalidade em vigor até 17/12 às 14h15 e outra encadeada até 24/12 às 14h15
- **WHEN** Ana tenta reservar
- **THEN** o sistema recusa informando que ela está com penalidade até 24/12 às 14h15

#### Scenario: Entrada na fila recusada
- **GIVEN** Ana está com uma penalidade em vigor
- **WHEN** Ana tenta entrar na fila de "BIB-01"
- **THEN** o sistema recusa informando até quando vai a penalidade

#### Scenario: Confirmação da vaga recusada
- **GIVEN** a penalidade de Ana entrou em vigor e, por uma falha anterior, a entrada dela continua `NOTIFICADA`
- **WHEN** Ana tenta confirmar a vaga
- **THEN** o sistema recusa informando até quando vai a penalidade e nenhuma reserva é criada

#### Scenario: Reserva existente mantida
- **GIVEN** Ana tem uma reserva `CONFIRMADA` para 15/12 e recebe uma penalidade de 10/12 a 17/12
- **WHEN** chega 15/12
- **THEN** a reserva continua `CONFIRMADA` e Ana pode fazer check-in ou cancelá-la

#### Scenario: Fim exato da penalidade
- **GIVEN** a penalidade de Ana vai até 17/12 às 14h15
- **WHEN** Ana reserva às 14h15 de 17/12
- **THEN** a reserva é criada

#### Scenario: Penalidade anulada não impede
- **GIVEN** a penalidade em vigor de Ana foi anulada
- **WHEN** Ana reserva "BIB-01"
- **THEN** a reserva é criada

#### Scenario: Falta ainda não gravada
- **GIVEN** Ana tinha 1 falta e a janela de outra reserva dela fechou há 10 minutos sem check-in, ainda sem gravação
- **WHEN** Ana tenta reservar
- **THEN** a falta e a penalidade são gravadas antes da verificação, e a criação é recusada

### Requirement: Fila de quem recebe penalidade
Quando uma penalidade é gerada já em vigor, as entradas `AGUARDANDO` e `NOTIFICADA` do usuário DEVEM (MUST) ficar `ENCERRADA` na mesma operação, e cada vaga retida por elas DEVE passar ao próximo da fila. Uma penalidade gerada já cumprida não encerra entradas. Anular a penalidade NÃO DEVE reabrir as entradas encerradas.

#### Scenario: Entradas encerradas
- **GIVEN** Ana aguarda na fila de "BIB-01" e tem uma vaga retida em "LAB-01", com Bruno logo atrás na fila de "LAB-01"
- **WHEN** Ana recebe uma penalidade em vigor
- **THEN** as duas entradas de Ana ficam `ENCERRADA` e a de Bruno fica `NOTIFICADA` na mesma operação

#### Scenario: Penalidade já cumprida
- **GIVEN** as faltas de Ana só foram gravadas depois do fim da penalidade que geraram
- **WHEN** a penalidade é gerada já cumprida
- **THEN** as entradas de Ana na fila continuam ativas

#### Scenario: Penalidade que entra em vigor com o tempo
- **GIVEN** uma anulação deixou a próxima penalidade de Ana para começar às 13h00, e Ana entrou na fila de "BIB-01" às 12h30, quando não estava com penalidade
- **WHEN** chegam as 13h00
- **THEN** a entrada de Ana continua `AGUARDANDO`, e a confirmação de uma vaga para ela é recusada enquanto a penalidade estiver em vigor

#### Scenario: Anulação não reabre
- **GIVEN** as entradas de Ana foram encerradas pela penalidade
- **WHEN** o admin anula a penalidade
- **THEN** as entradas continuam `ENCERRADA`

### Requirement: Cumprimento da penalidade
Uma penalidade `ATIVA` cujo fim chegou DEVE (MUST) passar a `CUMPRIDA`. A situação vale em todas as consultas a partir do fim, mesmo antes de ser gravada, e é gravada nas mesmas operações que gravam os vencimentos.

#### Scenario: Penalidade terminada
- **GIVEN** a penalidade de Ana terminou em 17/12 às 14h15
- **WHEN** Ana consulta as próprias penalidades às 15h00
- **THEN** a penalidade aparece cumprida

### Requirement: Anulação de penalidade pelo admin
Só um admin DEVE (MUST) poder anular uma penalidade, e só uma `ATIVA`, em vigor ou ainda por começar. A anulação exige um parecer de 1 a 500 caracteres e grava `ANULADA`, quem anulou e quando. Ninguém anula a própria penalidade. As faltas continuam vinculadas e não voltam a contar. Coordenadores e demais papéis DEVEM receber acesso negado.

#### Scenario: Admin anula com parecer
- **GIVEN** Ana está com uma penalidade em vigor
- **WHEN** o admin anula a penalidade com o parecer "Falha do sistema de check-in no dia 10/12"
- **THEN** a penalidade fica `ANULADA`, com o admin, o instante e o parecer, e Ana volta a poder reservar

#### Scenario: Sem parecer
- **WHEN** o admin tenta anular uma penalidade sem parecer, ou com mais de 500 caracteres
- **THEN** o sistema recusa informando que o parecer é obrigatório, com até 500 caracteres, e nada muda

#### Scenario: Penalidade cumprida
- **GIVEN** a penalidade de Ana terminou ontem
- **WHEN** o admin tenta anulá-la
- **THEN** o sistema recusa informando que só uma penalidade ativa pode ser anulada

#### Scenario: Penalidade já anulada
- **WHEN** o admin tenta anular uma penalidade `ANULADA`
- **THEN** o sistema recusa informando que só uma penalidade ativa pode ser anulada

#### Scenario: Própria penalidade
- **GIVEN** o admin Paulo está com uma penalidade em vigor
- **WHEN** Paulo tenta anulá-la
- **THEN** o sistema recusa informando que ninguém anula a própria penalidade

#### Scenario: Faltas não voltam a contar
- **GIVEN** a penalidade de Ana, gerada por duas faltas de dezembro, foi anulada
- **WHEN** Ana comete uma terceira falta em dezembro
- **THEN** nenhuma penalidade nova é gerada

#### Scenario: Coordenador tenta anular
- **WHEN** Rui, coordenador, tenta anular uma penalidade
- **THEN** o sistema responde com acesso negado

#### Scenario: Anulações simultâneas
- **WHEN** dois admins anulam a mesma penalidade ao mesmo tempo
- **THEN** só uma anulação é gravada e a outra é recusada porque a penalidade não está mais ativa

### Requirement: Antecipação das penalidades encadeadas
Ao anular uma penalidade, o sistema DEVE (MUST) recalcular, na mesma operação e em ordem, as penalidades `ATIVA` do usuário que começam depois dela. Cada uma passa a começar no instante da falta que a gerou ou, se for mais tarde, no fim da anterior não anulada, e mantém a duração que tinha.

#### Scenario: Encadeada antecipada
- **GIVEN** Ana tem uma penalidade de 10/12 a 17/12, em vigor, e uma encadeada de 17/12 a 24/12, gerada por uma falta de 13/12
- **WHEN** o admin anula a primeira em 14/12
- **THEN** a segunda passa a ir de 13/12 a 20/12, a partir do instante da falta que a gerou, e já está em vigor

#### Scenario: Antecipação limitada pela anterior
- **GIVEN** Ana tem três penalidades encadeadas: de 10/12 a 17/12, de 17/12 a 24/12 e de 24/12 a 31/12, e a terceira foi gerada por uma falta de 14/12
- **WHEN** o admin anula a segunda em 15/12
- **THEN** a primeira não muda e a terceira passa a ir de 17/12 a 24/12

#### Scenario: Duração preservada
- **GIVEN** a penalidade encadeada de Ana foi gerada com 7 dias, e depois o admin principal mudou a duração para 3 dias
- **WHEN** a anterior é anulada
- **THEN** a encadeada é antecipada e continua com 7 dias

### Requirement: Faltas e penalidades do próprio usuário
Todo usuário com conta `ATIVA` DEVE (MUST) poder consultar as próprias faltas e penalidades, e só as próprias: cada falta com o tipo, o instante, a reserva (espaço, data e horário) e se gerou penalidade; cada penalidade com início, fim, situação efetiva e, se anulada, o parecer. A consulta grava antes os vencimentos pendentes do usuário.

#### Scenario: Ana consulta
- **GIVEN** Ana tem duas faltas e uma penalidade em vigor, e Bruno tem uma falta
- **WHEN** Ana consulta as próprias faltas e penalidades
- **THEN** recebe só as duas faltas dela, ligadas à penalidade, e a penalidade em vigor com início e fim em America/Sao_Paulo

#### Scenario: Falta recém-vencida
- **GIVEN** a janela da reserva de Ana fechou há 5 minutos sem check-in, ainda sem gravação
- **WHEN** Ana consulta as próprias faltas
- **THEN** a falta aparece

#### Scenario: Penalidade anulada com parecer
- **GIVEN** a penalidade de Ana foi anulada com o parecer "Falha do sistema"
- **WHEN** Ana consulta as próprias penalidades
- **THEN** a penalidade aparece anulada com "Falha do sistema", sem o nome de quem anulou

### Requirement: Listagem de penalidades pelo admin
Os admins DEVEM (MUST) poder listar as penalidades de todos os usuários, filtrando pela situação (em vigor, que é o padrão, ativas, cumpridas, anuladas ou todas) e por nome ou e-mail. Cada uma traz o usuário (nome e e-mail), início, fim, situação efetiva, as faltas vinculadas com a reserva e, se anulada, quem anulou, quando e o parecer. No máximo 200 por consulta, com a indicação de que havia mais.

#### Scenario: Admin lista as em vigor
- **GIVEN** Ana está com uma penalidade em vigor e Bruno tem uma cumprida
- **WHEN** o admin lista as penalidades sem filtros
- **THEN** recebe só a de Ana, com as faltas vinculadas

#### Scenario: Filtro por e-mail
- **WHEN** o admin filtra as penalidades de todas as situações pelo e-mail de Bruno
- **THEN** recebe só as penalidades de Bruno

#### Scenario: Situação inválida
- **WHEN** o admin filtra a situação "SUSPENSA"
- **THEN** o sistema recusa informando que a situação é inválida

#### Scenario: Coordenador tenta listar
- **WHEN** Rui, coordenador, chama diretamente a listagem de penalidades
- **THEN** o sistema responde com acesso negado

### Requirement: Telas de faltas e penalidades
"Minhas reservas" DEVE (MUST) ter a seção "Faltas e penalidades", com as faltas e penalidades do usuário e, em destaque, a penalidade em vigor e até quando vai. O frontend DEVE oferecer aos admins a página "Penalidades", com os filtros, as faltas de cada penalidade e a ação "Anular", que pede o parecer e mostra a mensagem da API.

#### Scenario: Usuário vê a penalidade em vigor
- **GIVEN** Ana está com uma penalidade em vigor até 17/12 às 14h15
- **WHEN** Ana abre "Minhas reservas"
- **THEN** a seção "Faltas e penalidades" mostra em destaque que ela está com penalidade até 17/12 às 14h15

#### Scenario: Usuário sem faltas
- **WHEN** Carlos, sem faltas, abre "Minhas reservas"
- **THEN** a seção informa que ele não tem faltas nem penalidades

#### Scenario: Anular pela página
- **GIVEN** Ana está com uma penalidade em vigor
- **WHEN** o admin abre "Penalidades", escolhe "Anular" na penalidade de Ana, escreve o parecer e confirma
- **THEN** a página mostra a confirmação e a penalidade aparece anulada

#### Scenario: Anular sem parecer pela página
- **WHEN** o admin tenta confirmar a anulação sem parecer
- **THEN** a página mostra a recusa e não fecha a confirmação
