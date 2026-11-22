# Especificação: Fila de espera

## Purpose

Permitir que quem pede um horário ocupado, e não pode deslocar quem o ocupa, espere pela vaga daquele espaço e intervalo: a fila é ordenada por prioridade e entrada, retém a vaga liberada para o primeiro colocado durante um prazo de confirmação e gera a reserva quando ele confirma.

## Requirements

### Requirement: Entrada na fila
Todo usuário com conta ativa DEVE (MUST) poder entrar na fila de um espaço para exatamente o intervalo pedido quando o intervalo está ocupado e ele não pode deslocar quem ocupa (capability `reservas`). A entrada passa pelas validações da criação de reserva (espaço reservável, regra do papel, regras de horário), menos o conflito e o limite de reservas ativas. Ela nasce `AGUARDANDO`, com o nível do papel atual e o instante registrado pelo backend.

#### Scenario: Aluno entra na fila
- **GIVEN** Bruno, aluno, tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana, aluna, entra na fila de "BIB-01" das 14h00 às 15h00 do mesmo dia
- **THEN** a entrada de Ana é criada `AGUARDANDO`, com o nível 1

#### Scenario: Intervalo livre
- **GIVEN** "BIB-01" não tem ocupação das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana tenta entrar na fila desse intervalo
- **THEN** o sistema recusa informando que o horário está livre e pode ser reservado diretamente

#### Scenario: Quem pode deslocar não entra na fila
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Carlos, professor, tenta entrar na fila desse intervalo, num tipo em que a reserva dele nasceria confirmada
- **THEN** o sistema recusa informando que ele pode deslocar a ocupação

#### Scenario: Ocupado por vaga retida
- **GIVEN** a vaga de "LAB-01" das 14h00 às 15h00 de depois de amanhã está retida para Paula, professora
- **WHEN** Rui, coordenador, entra na fila desse intervalo
- **THEN** a entrada de Rui é criada `AGUARDANDO`, porque a vaga retida não é deslocável

#### Scenario: Fora das regras do tipo
- **GIVEN** "BIB-01" está ocupado das 22h00 às 22h40 de depois de amanhã
- **WHEN** Ana tenta entrar na fila de "BIB-01" das 22h00 às 22h50
- **THEN** o sistema recusa com o motivo de fim depois do horário de funcionamento do tipo

#### Scenario: Papel que não reserva o tipo
- **WHEN** Ana, aluna, tenta entrar na fila de uma sala de aula ocupada
- **THEN** o sistema recusa informando que o papel dela não pode reservar esse tipo de espaço

#### Scenario: Entrada repetida
- **GIVEN** Ana tem uma entrada `AGUARDANDO` na fila de "BIB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana tenta entrar de novo na fila do mesmo espaço e intervalo
- **THEN** o sistema recusa informando que ela já está nessa fila

#### Scenario: Fila contra a própria reserva
- **GIVEN** Ana tem uma reserva `CONFIRMADA` em "BIB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana tenta entrar na fila de "BIB-01" das 14h30 às 15h30 do mesmo dia
- **THEN** o sistema recusa informando que ela já tem reserva nesse espaço nesse intervalo

#### Scenario: Limite de ativas não impede a entrada
- **GIVEN** Ana já tem o máximo de reservas ativas de "Biblioteca", e "BIB-01" está ocupado das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana entra na fila desse intervalo
- **THEN** a entrada é criada, e o limite é conferido só na confirmação

#### Scenario: Sem autenticação
- **WHEN** alguém sem sessão tenta entrar numa fila
- **THEN** o sistema responde como não autenticado

### Requirement: Corte e fechamento da fila
O corte de um intervalo DEVE (MUST) ser `prazo_fila_minutos` antes do início ou, se a antecedência mínima do tipo for maior, essa antecedência antes do início. O fechamento da fila é o corte menos `tempo_minimo_fila_minutos`. A partir do fechamento, inclusive, ninguém entra na fila do intervalo, ninguém dela é avisado e as entradas `AGUARDANDO` ficam `ENCERRADA`, sem aviso. A vaga liberada a partir do fechamento fica livre para reserva direta.

#### Scenario: Entrada antes do fechamento
- **GIVEN** o corte é de 120 minutos, o tempo mínimo é de 30 minutos, "BIB-01" está ocupado às 14h00 e são 11h29
- **WHEN** Ana entra na fila de "BIB-01" das 14h00 às 15h00
- **THEN** a entrada é criada

#### Scenario: Entrada exatamente no fechamento
- **GIVEN** o corte é de 120 minutos, o tempo mínimo é de 30 minutos, "BIB-01" está ocupado às 14h00 e são 11h30
- **WHEN** Ana tenta entrar na fila de "BIB-01" das 14h00 às 15h00
- **THEN** o sistema recusa informando que a fila desse horário já está encerrada

#### Scenario: Entradas encerradas no fechamento
- **GIVEN** o corte é de 120 minutos, o tempo mínimo é de 30 minutos e Ana aguarda na fila de "BIB-01" das 14h00 às 15h00 de hoje
- **WHEN** uma operação processa a fila às 11h30
- **THEN** a entrada de Ana fica `ENCERRADA`

#### Scenario: Vaga liberada a menos do tempo mínimo do corte
- **GIVEN** o corte é de 120 minutos, o tempo mínimo é de 30 minutos, Ana aguarda na fila de "LAB-01" das 14h00 às 15h00 de hoje e Bruno tem a reserva `PENDENTE` desse intervalo
- **WHEN** Rui recusa a reserva de Bruno às 11h40
- **THEN** a entrada de Ana fica `ENCERRADA`, ninguém é avisado e o horário fica livre para reserva direta

#### Scenario: Corte pela antecedência mínima do tipo
- **GIVEN** "Auditório" exige 1440 minutos de antecedência, o corte da fila é de 120 minutos, o tempo mínimo é de 30 minutos e Carlos aguarda na fila de "AUD-01" de quinta às 14h00
- **WHEN** a reserva da frente é cancelada na quarta às 20h00
- **THEN** a entrada de Carlos fica `ENCERRADA` e ele não é avisado, porque o fechamento foi na quarta às 13h30

### Requirement: Ordem da fila
A fila de um intervalo DEVE (MUST) ser ordenada pelo nível de prioridade da entrada, do maior para o menor, e, em empate, pela ordem de entrada registrada pelo backend. O nível é o do papel do usuário no momento da entrada.

#### Scenario: Prioridade passa à frente
- **GIVEN** Ana, aluna, entrou na fila de "LAB-01" das 14h00 às 15h00 às 09h00, e Carlos, professor, entrou na mesma fila às 10h00
- **WHEN** a vaga é liberada
- **THEN** Carlos é avisado primeiro

#### Scenario: Empate pela ordem de entrada
- **GIVEN** Ana e Bruno, alunos, entraram na mesma fila, Ana antes de Bruno
- **WHEN** a vaga é liberada
- **THEN** Ana é avisada primeiro

### Requirement: Liberação e vaga retida
Quando o intervalo de uma fila deixa de ter reserva ativa ou vaga retida sobreposta, o primeiro da fila DEVE (MUST) passar a `NOTIFICADA` e reter a vaga. Enquanto a entrada está `NOTIFICADA` e no prazo, o intervalo fica ocupado: não pode ser reservado diretamente, deslocado nem retido por outra entrada. A retenção termina quando o notificado confirma, desiste ou o prazo vence.

#### Scenario: Cancelamento libera a fila
- **GIVEN** Bruno tem a reserva de "BIB-01" das 14h00 às 15h00 de depois de amanhã e Ana aguarda na fila desse intervalo
- **WHEN** Bruno cancela a reserva
- **THEN** a entrada de Ana fica `NOTIFICADA` na mesma operação

#### Scenario: Liberação parcial não basta
- **GIVEN** Ana aguarda na fila de "LAB-01" das 10h00 às 12h00, e há reservas das 10h00 às 11h00 e das 11h00 às 12h00
- **WHEN** a reserva das 10h00 às 11h00 é cancelada
- **THEN** Ana continua `AGUARDANDO`, porque o intervalo ainda tem ocupação

#### Scenario: Reserva maior liberada
- **GIVEN** Ana aguarda na fila de "LAB-01" das 10h00 às 11h00 e Bruno tem a reserva das 09h00 às 12h00
- **WHEN** Bruno cancela a reserva
- **THEN** a entrada de Ana fica `NOTIFICADA`

#### Scenario: Recusa libera a fila
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" ocupa o intervalo da fila em que Bruno aguarda
- **WHEN** Rui recusa a reserva de Ana
- **THEN** a entrada de Bruno fica `NOTIFICADA`

#### Scenario: Expiração de pendente libera a fila
- **GIVEN** o corte é de 120 minutos, o tempo mínimo é de 30 minutos, a reserva `PENDENTE` de Ana em "LAB-01" vai das 09h00 às 14h00 de hoje e Bruno aguarda na fila das 12h00 às 12h30 (fechamento às 09h30)
- **WHEN** às 09h05 uma operação processa os vencimentos
- **THEN** a reserva de Ana fica `EXPIRADA` e a entrada de Bruno fica `NOTIFICADA`

#### Scenario: Deslocamento libera as sobras
- **GIVEN** Ana, aluna, tem uma reserva em "LAB-01" das 09h00 às 12h00 de depois de amanhã, e Bruno, aluno, aguarda na fila das 11h00 às 12h00
- **WHEN** Carlos, professor, desloca a reserva de Ana pedindo das 09h00 às 10h00
- **THEN** a entrada de Bruno fica `NOTIFICADA`, porque o intervalo dele ficou livre

#### Scenario: Vaga retida recusa reserva direta
- **GIVEN** a entrada de Ana na fila de "BIB-01" das 14h00 às 15h00 está `NOTIFICADA` e no prazo
- **WHEN** Bruno tenta reservar "BIB-01" das 14h30 às 15h30
- **THEN** o sistema recusa informando que o horário está ocupado

#### Scenario: Prioridade maior não toma a vaga retida
- **GIVEN** a entrada de Ana, aluna, está `NOTIFICADA` para "LAB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Carlos, professor, tenta reservar o mesmo intervalo e confirmar o deslocamento
- **THEN** o sistema recusa informando que o horário está ocupado, e a vaga continua retida para Ana

### Requirement: Prazo de confirmação
O notificado DEVE (MUST) ter, para confirmar, `prazo_confirmacao_fila_minutos` a partir do aviso, limitado ao corte do intervalo. A confirmação é aceita até o fim do prazo, inclusive. Vencido o prazo, a entrada fica `EXPIRADA` com o instante do prazo como vencimento, a vaga deixa de estar retida mesmo antes de a expiração ser gravada, e o próximo da fila é avisado quando a fila andar.

#### Scenario: Prazo cheio
- **GIVEN** o prazo para confirmar é de 720 minutos, o corte é de 120 minutos e a fila de "BIB-01" é de depois de amanhã às 14h00
- **WHEN** a entrada de Ana é avisada hoje às 10h00
- **THEN** o prazo dela vai até hoje às 22h00

#### Scenario: Vaga liberada de madrugada
- **GIVEN** o prazo para confirmar é de 720 minutos, o corte é de 120 minutos e a fila de "BIB-01" é de hoje às 10h00
- **WHEN** a entrada de Ana é avisada à 00h00
- **THEN** o prazo dela vai até as 08h00, o corte do intervalo, e Ana ainda confirma se abrir o sistema às 06h00

#### Scenario: Prazo limitado pelo corte
- **GIVEN** o prazo para confirmar é de 720 minutos, o corte é de 120 minutos e a fila de "BIB-01" é de hoje às 14h00
- **WHEN** a entrada de Ana é avisada às 11h00
- **THEN** o prazo dela vai até as 12h00, o corte do intervalo

#### Scenario: Confirmação no último instante
- **GIVEN** o prazo de Ana vai até as 12h00
- **WHEN** Ana confirma às 12h00
- **THEN** a reserva é criada

#### Scenario: Prazo vencido passa ao próximo
- **GIVEN** a entrada de Ana venceu às 12h00 sem confirmação e Bruno é o próximo da fila
- **WHEN** uma operação processa a fila às 12h10
- **THEN** a entrada de Ana fica `EXPIRADA` com 12h00 como vencimento e a de Bruno fica `NOTIFICADA`, com o prazo contado a partir das 12h10

#### Scenario: Vencida antes da gravação não retém
- **GIVEN** a entrada de Ana venceu às 12h00 e nenhuma operação processou a fila desde então
- **WHEN** Carlos busca "BIB-01" para esse intervalo às 12h05
- **THEN** a vaga não aparece retida por Ana

### Requirement: Filas de intervalos sobrepostos
Quando uma mesma liberação deixa livres filas de intervalos sobrepostos do mesmo espaço, a retenção DEVE (MUST) ir primeiro para a fila cujo primeiro colocado tem maior prioridade e, em empate, entrou antes. As filas que ficarem sobrepostas a essa retenção continuam aguardando e são reavaliadas quando ela terminar sem confirmação.

#### Scenario: Maior prioridade leva a retenção
- **GIVEN** Ana, aluna, aguarda na fila de "LAB-01" das 10h00 às 11h00 e Carlos, professor, na das 10h30 às 11h30, e uma reserva das 09h00 às 12h00 ocupa as duas
- **WHEN** essa reserva é cancelada
- **THEN** a entrada de Carlos fica `NOTIFICADA` e a de Ana continua `AGUARDANDO`

#### Scenario: Reavaliação quando a retenção termina
- **GIVEN** a entrada de Carlos ficou `NOTIFICADA` das 10h30 às 11h30 e Ana aguarda das 10h00 às 11h00
- **WHEN** Carlos desiste
- **THEN** a entrada de Ana fica `NOTIFICADA`

#### Scenario: Fila não sobreposta à retenção é avisada
- **GIVEN** Carlos, professor, aguarda das 10h30 às 11h30, Ana, aluna, das 10h00 às 11h00, e Bruno, aluno, das 11h40 às 12h00, todos em "LAB-01" e sob uma reserva das 09h00 às 12h00
- **WHEN** essa reserva é cancelada
- **THEN** as entradas de Carlos e de Bruno ficam `NOTIFICADA`, e a de Ana continua `AGUARDANDO`

#### Scenario: Cadeia de filas sobrepostas
- **GIVEN** Rui, coordenador, aguarda das 10h00 às 11h00, Carlos, professor, das 10h30 às 11h30, e Ana, aluna, das 11h10 às 12h00, em "LAB-01", sob uma reserva das 09h00 às 12h00
- **WHEN** essa reserva é cancelada
- **THEN** as entradas de Rui e de Ana ficam `NOTIFICADA`, porque o intervalo de Ana não sobrepõe o de Rui, e a de Carlos continua `AGUARDANDO`

### Requirement: Confirmação da vaga
O notificado DEVE (MUST) poder confirmar a vaga retida enquanto a entrada está `NOTIFICADA` e no prazo. A confirmação passa pelas validações da criação (conta ativa, espaço reservável, regra do papel, regras de horário e limite de reservas ativas) e cria a reserva com origem `FILA`: `PENDENTE` se o tipo exige aprovação para o papel, senão `CONFIRMADA`. A entrada fica `ATENDIDA`, com a referência à reserva.

#### Scenario: Confirmação cria a reserva
- **GIVEN** a entrada de Ana na fila de "BIB-01" está `NOTIFICADA` e no prazo
- **WHEN** Ana confirma
- **THEN** é criada uma reserva `CONFIRMADA` de Ana em "BIB-01" no intervalo da fila, com origem `FILA`, e a entrada fica `ATENDIDA`

#### Scenario: Tipo que exige aprovação
- **GIVEN** "Laboratório" exige aprovação de aluno e a entrada de Ana na fila de "LAB-01" está `NOTIFICADA`
- **WHEN** Ana confirma
- **THEN** a reserva de Ana nasce `PENDENTE`, com origem `FILA`, e continua ocupando o horário até a decisão

#### Scenario: Limite de ativas na confirmação
- **GIVEN** a entrada de Ana está `NOTIFICADA` e ela já tem o máximo de reservas ativas do tipo
- **WHEN** Ana tenta confirmar
- **THEN** o sistema recusa informando o limite de reservas ativas, e a entrada continua `NOTIFICADA` até o prazo

#### Scenario: Confirmação depois do prazo
- **GIVEN** o prazo de Ana venceu às 12h00
- **WHEN** Ana tenta confirmar às 12h01
- **THEN** o sistema recusa informando que o prazo para confirmar terminou

#### Scenario: Entrada que não está notificada
- **GIVEN** a entrada de Ana está `AGUARDANDO`
- **WHEN** Ana tenta confirmar
- **THEN** o sistema recusa informando que ainda não há vaga para confirmar

#### Scenario: Entrada de outra pessoa
- **WHEN** Bruno tenta confirmar a entrada de Ana
- **THEN** o sistema recusa informando que a entrada não foi encontrada, a mesma resposta de uma entrada inexistente

### Requirement: Desistência
O dono DEVE (MUST) poder desistir de uma entrada `AGUARDANDO` ou `NOTIFICADA`, que fica `DESISTIU`. Desistir de uma vaga retida libera a vaga para a fila na mesma operação. Entradas em situação final não aceitam desistência.

#### Scenario: Sair da fila
- **GIVEN** Ana aguarda na fila de "BIB-01"
- **WHEN** Ana desiste
- **THEN** a entrada fica `DESISTIU` e sai da ordem da fila

#### Scenario: Desistir da vaga retida
- **GIVEN** a entrada de Ana está `NOTIFICADA` e Bruno é o próximo da fila
- **WHEN** Ana desiste
- **THEN** a entrada de Ana fica `DESISTIU` e a de Bruno fica `NOTIFICADA` na mesma operação

#### Scenario: Entrada já atendida
- **GIVEN** a entrada de Ana está `ATENDIDA`
- **WHEN** Ana tenta desistir
- **THEN** o sistema recusa informando que a entrada não está mais ativa

#### Scenario: Desistir da entrada de outra pessoa
- **WHEN** Bruno tenta desistir da entrada de Ana
- **THEN** o sistema recusa informando que a entrada não foi encontrada

### Requirement: Encerramento pela gestão e pela conta
As entradas ativas DEVEM (MUST) ficar `ENCERRADA` quando o espaço deixa de ser reservável ou muda de unidade ou de tipo (desativação do espaço, do tipo ou da unidade, mudança de unidade, troca de tipo), na mesma operação de gestão, e quando a conta do dono é inativada. A inativação também libera para as filas as vagas das reservas canceladas. Reativar o espaço ou a conta não reabre as entradas encerradas.

#### Scenario: Espaço desativado
- **GIVEN** Ana aguarda na fila de "LAB-01" e Bruno tem uma entrada `NOTIFICADA` em outro intervalo de "LAB-01"
- **WHEN** Rui desativa "LAB-01"
- **THEN** as duas entradas ficam `ENCERRADA`

#### Scenario: Reativação não reabre
- **GIVEN** a entrada de Ana foi encerrada pela desativação de "LAB-01"
- **WHEN** Rui reativa "LAB-01"
- **THEN** a entrada de Ana continua `ENCERRADA`

#### Scenario: Conta inativada
- **GIVEN** Carlos tem uma entrada `NOTIFICADA` e uma reserva futura em "LAB-02", em cuja fila Ana aguarda
- **WHEN** o admin inativa Carlos
- **THEN** a entrada de Carlos fica `ENCERRADA`, a reserva dele é cancelada e a entrada de Ana fica `NOTIFICADA`

### Requirement: Quando a fila anda
Como o backend não tem tarefas agendadas, a fila DEVE (MUST) ser processada, sem ação de pessoa alguma:
- antes das demais verificações das operações que criam, cancelam, aprovam ou recusam reservas e das operações da fila;
- dentro da própria operação que libera uma vaga;
- na consulta da fila do usuário, quando uma verificação rápida encontrar vencimento a gravar.

Sem nenhuma dessas operações, o aviso ao próximo atrasa, mas a vaga vencida não fica retida.

#### Scenario: Próximo avisado ao abrir a página
- **GIVEN** a entrada de Ana venceu às 12h00 sem confirmação, Bruno é o próximo e nenhuma operação gravou nada desde então
- **WHEN** Bruno abre qualquer página autenticada às 12h30
- **THEN** a entrada de Ana fica `EXPIRADA`, a de Bruno fica `NOTIFICADA` e Bruno vê o aviso

#### Scenario: Nada a processar
- **GIVEN** nenhuma entrada venceu e nenhuma reserva pendente venceu
- **WHEN** Ana abre "Minhas reservas"
- **THEN** nada é gravado

#### Scenario: Reserva direta não fura a fila
- **GIVEN** a entrada de Ana venceu às 12h00, Bruno é o próximo da fila e nenhuma operação processou a fila desde então
- **WHEN** Carlos, que não pode deslocar, tenta reservar o intervalo às 12h10
- **THEN** a entrada de Bruno fica `NOTIFICADA` antes da verificação do conflito, e Carlos recebe a recusa de horário ocupado

### Requirement: Operações simultâneas da fila
As operações da fila e as operações sobre reservas do mesmo espaço DEVEM (MUST) ser atômicas entre si: uma vaga é retida para uma única entrada por vez, uma entrada recebe uma única transição a partir de `AGUARDANDO` ou `NOTIFICADA`, e nunca coexistem uma reserva ativa e uma vaga retida sobrepostas, exceto a reserva gerada pela própria entrada.

#### Scenario: Confirmação e desistência simultâneas
- **WHEN** Ana confirma e desiste da mesma entrada `NOTIFICADA` ao mesmo tempo
- **THEN** só uma das ações é gravada e a outra recebe a recusa de entrada não ativa

#### Scenario: Reserva direta e liberação simultâneas
- **GIVEN** Ana aguarda na fila de "BIB-01" das 14h00 às 15h00
- **WHEN** Bruno cancela a reserva desse intervalo no mesmo instante em que Bia, aluna, tenta reservá-lo diretamente
- **THEN** Bia é recusada, porque o horário ainda estava ocupado ou porque a vaga já estava retida para Ana; Bia nunca obtém a vaga antes de Ana

#### Scenario: Entradas simultâneas iguais
- **WHEN** Ana envia duas vezes, ao mesmo tempo, a entrada na mesma fila
- **THEN** só uma entrada é criada e a outra recebe a recusa de entrada repetida

### Requirement: Fila do próprio usuário
Todo usuário com conta ativa DEVE (MUST) poder consultar as próprias entradas de fila: as ativas, com espaço, unidade, tipo, data e horário em America/Sao_Paulo, situação efetiva, posição na fila quando `AGUARDANDO` e prazo quando `NOTIFICADA`; e as finalizadas cujo intervalo começa a partir de 30 dias atrás. A consulta NÃO DEVE (MUST NOT) mostrar quem mais está na fila nem quem ocupa o horário.

#### Scenario: Posição na fila
- **GIVEN** Carlos, professor, e Ana, aluna, aguardam na mesma fila
- **WHEN** Ana consulta a própria fila
- **THEN** a entrada dela aparece `AGUARDANDO` na posição 2, sem o nome de Carlos

#### Scenario: Prazo da vaga retida
- **GIVEN** a entrada de Ana está `NOTIFICADA` com prazo até as 12h00
- **WHEN** Ana consulta a própria fila
- **THEN** a entrada aparece com o prazo das 12h00

#### Scenario: Vencida aparece expirada
- **GIVEN** o prazo de Ana venceu e a expiração ainda não foi gravada
- **WHEN** a consulta é feita sem gravar nada
- **THEN** a entrada aparece `EXPIRADA`

### Requirement: Tela da fila de espera
O frontend DEVE (MUST) mostrar, em "Minhas reservas", uma seção "Fila de espera" com as entradas da consulta. Cada entrada `NOTIFICADA` oferece "Confirmar" e "Desistir", com o prazo, e cada entrada `AGUARDANDO` oferece "Sair da fila", com a posição. Depois de cada ação, a página mostra a mensagem da API e atualiza as reservas e a fila. Recusas aparecem na própria página.

#### Scenario: Confirmar pela tela
- **GIVEN** a entrada de Ana está `NOTIFICADA`
- **WHEN** Ana clica em "Confirmar" na seção "Fila de espera"
- **THEN** a página informa que a reserva foi confirmada, a entrada sai das ativas e a reserva aparece em "Próximas"

#### Scenario: Sair da fila pela tela
- **WHEN** Ana clica em "Sair da fila" numa entrada `AGUARDANDO` e confirma
- **THEN** a entrada sai das ativas e aparece como desistência nas finalizadas

### Requirement: Aviso de vaga retida
Toda página autenticada DEVE (MUST) mostrar, no topo, um aviso enquanto o usuário tiver entrada `NOTIFICADA` no prazo, com o espaço, o horário, o prazo e um link para "Minhas reservas". O aviso some quando não há mais vaga retida para ele.

#### Scenario: Aviso em qualquer página
- **GIVEN** a entrada de Ana está `NOTIFICADA` com prazo até as 12h00
- **WHEN** Ana abre "Buscar espaços"
- **THEN** a página mostra no topo o aviso da vaga em "BIB-01", com o prazo das 12h00 e o link para "Minhas reservas"

#### Scenario: Sem vaga retida
- **WHEN** Ana não tem entrada `NOTIFICADA`
- **THEN** nenhuma página mostra o aviso

### Requirement: Fila não entra em intervalo bloqueado
A entrada na fila DEVE (MUST) ser recusada quando o intervalo pedido se sobrepõe a um bloqueio `ATIVO` do espaço (capability `bloqueios`), informando que o espaço está bloqueado no período. A confirmação de uma vaga retida DEVE ser recusada pelo mesmo motivo, sem gravar a reserva. Intervalo encostado não é sobreposição.

#### Scenario: Entrada em intervalo bloqueado
- **GIVEN** "BIB-01" tem um bloqueio `ATIVO` de 10/12 a 12/12 e uma reserva de professor em 15/12 das 14h00 às 15h00
- **WHEN** Ana tenta entrar na fila de "BIB-01" em 11/12 das 14h00 às 15h00
- **THEN** o sistema recusa informando que o espaço está bloqueado no período, e nada é gravado

#### Scenario: Entrada fora do bloqueio
- **GIVEN** o mesmo bloqueio
- **WHEN** Ana entra na fila de "BIB-01" em 15/12 das 14h00 às 15h00
- **THEN** o bloqueio não impede a entrada

#### Scenario: Confirmação de vaga em período bloqueado
- **GIVEN** Ana tem a vaga retida de "BIB-01" em 11/12 das 14h00 às 15h00, e por algum motivo existe um bloqueio `ATIVO` sobreposto a ela
- **WHEN** Ana confirma a vaga
- **THEN** o sistema recusa informando que o espaço está bloqueado no período, e nenhuma reserva é gravada
