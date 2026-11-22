# Especificação: Aprovação de reservas

## Purpose
Permitir que coordenadores e administradores decidam as reservas pendentes dos espaços que gerem (aprovar ou recusar com motivo) antes do início, garantir que a pendente sem decisão expire no início e deixe de ocupar o horário mesmo sem tarefa agendada no servidor, e oferecer a consulta das reservas da unidade.

## Requirements

### Requirement: Quem decide uma reserva pendente
Só o coordenador que coordena a unidade **atual** do espaço da reserva, ou um admin, DEVE (MUST) poder aprovar ou recusar uma reserva `PENDENTE`. Aluno e professor DEVEM receber acesso negado. Para o coordenador, uma reserva de espaço de outra unidade e uma reserva inexistente DEVEM receber a mesma recusa de acesso negado. O escopo é lido no momento da requisição: quem deixou de coordenar a unidade não decide mais.

#### Scenario: Coordenador da unidade aprova
- **GIVEN** Rui coordena "Paulista" e Ana tem uma reserva `PENDENTE` em "LAB-01" de "Paulista" para amanhã
- **WHEN** Rui aprova a reserva
- **THEN** a reserva fica `CONFIRMADA`

#### Scenario: Admin decide em qualquer unidade
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" de "Vila Olímpia"
- **WHEN** o admin recusa a reserva com um motivo
- **THEN** a reserva fica `RECUSADA`

#### Scenario: Coordenador de outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta aprovar uma reserva `PENDENTE` de um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e a reserva continua `PENDENTE`

#### Scenario: Reserva inexistente para o coordenador
- **WHEN** Rui tenta aprovar um id de reserva que não existe
- **THEN** o sistema responde com acesso negado, com a mesma mensagem de uma reserva de outra unidade

#### Scenario: Aluno tenta decidir
- **WHEN** Ana, aluna, chama diretamente a aprovação de uma reserva
- **THEN** o sistema responde com acesso negado

#### Scenario: Coordenação removida
- **GIVEN** Rui coordenava "Paulista" e o admin removeu essa coordenação
- **WHEN** Rui, com o mesmo token, tenta aprovar uma reserva `PENDENTE` de "Paulista"
- **THEN** o sistema responde com acesso negado

### Requirement: Ninguém decide a própria reserva
O sistema NÃO DEVE (MUST NOT) aceitar que um coordenador ou admin aprove ou recuse uma reserva da qual é o dono. A recusa DEVE ser uma resposta de validação que informa que a própria reserva é decidida por outro coordenador da unidade ou por um admin. A reserva continua `PENDENTE`.

#### Scenario: Professor que virou coordenador
- **GIVEN** Carlos, professor, criou uma reserva `PENDENTE` em "AUD-01" de "Paulista" e depois passou a coordenar "Paulista"
- **WHEN** Carlos tenta aprovar essa reserva
- **THEN** o sistema recusa informando que a própria reserva é decidida por outro coordenador da unidade ou por um admin
- **AND** a reserva continua `PENDENTE`

#### Scenario: Outro gestor decide
- **GIVEN** a reserva `PENDENTE` de Carlos em "AUD-01" de "Paulista" e Rui também coordena "Paulista"
- **WHEN** Rui aprova a reserva
- **THEN** a reserva fica `CONFIRMADA`

### Requirement: Aprovação de reserva pendente
A aprovação DEVE (MUST) deixar a reserva `CONFIRMADA`, com quem decidiu e quando. Ela é aceita só enquanto a reserva está `PENDENTE` e o início ainda não chegou. A aprovação NÃO DEVE conferir de novo as regras do tipo, a regra do papel, o limite de reservas ativas nem o conflito: as regras valem na criação e a pendente já ocupa o horário. Reserva que não está pendente DEVE ser recusada informando que ela não está pendente.

#### Scenario: Aprovar pendente futura
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" para amanhã às 14h00
- **WHEN** Rui aprova a reserva
- **THEN** a reserva fica `CONFIRMADA`, com Rui como quem decidiu e o instante da decisão

#### Scenario: Regras alteradas depois da criação
- **GIVEN** Ana tem uma reserva `PENDENTE` de 180 minutos em "LAB-01" e o admin reduziu a duração máxima de "Laboratório" para 120 minutos
- **WHEN** Rui aprova a reserva
- **THEN** a reserva fica `CONFIRMADA`

#### Scenario: Aprovar a poucos minutos do início
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" às 14h00 e são 13h55
- **WHEN** Rui aprova a reserva
- **THEN** a reserva fica `CONFIRMADA`

#### Scenario: Reserva já decidida
- **GIVEN** a reserva de Ana já está `CONFIRMADA`, `RECUSADA` ou `CANCELADA`
- **WHEN** Rui tenta aprová-la
- **THEN** o sistema recusa informando que a reserva não está pendente e nada muda

### Requirement: Recusa de reserva pendente com motivo
A recusa DEVE (MUST) exigir um motivo em texto, sem espaços nas pontas, com 1 a 500 caracteres, e deixar a reserva `RECUSADA`, com quem decidiu, quando e o motivo. A reserva recusada deixa de ocupar o horário. Ela é aceita só enquanto a reserva está `PENDENTE` e o início ainda não chegou. O motivo DEVE ser visível ao dono da reserva.

#### Scenario: Recusar com motivo
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" para amanhã das 14h00 às 15h00
- **WHEN** Rui recusa a reserva com o motivo "Laboratório reservado para manutenção dos computadores"
- **THEN** a reserva fica `RECUSADA` com esse motivo
- **AND** o horário das 14h00 às 15h00 em "LAB-01" fica livre para nova reserva

#### Scenario: Motivo ausente
- **WHEN** Rui tenta recusar uma reserva pendente sem motivo, ou só com espaços
- **THEN** o sistema recusa informando que o motivo da recusa é obrigatório e a reserva continua `PENDENTE`

#### Scenario: Motivo longo demais
- **WHEN** Rui tenta recusar com um motivo de 501 caracteres
- **THEN** o sistema recusa informando o limite de 500 caracteres e a reserva continua `PENDENTE`

### Requirement: Prazo da decisão
Aprovar e recusar DEVEM (MUST) ser recusados quando o início da reserva é igual ou anterior ao instante da requisição, informando que o prazo de decisão terminou, mesmo que a expiração ainda não tenha sido gravada.

#### Scenario: Depois do início
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" que começou às 14h00 e são 14h05
- **WHEN** Rui tenta aprová-la
- **THEN** o sistema recusa informando que o prazo de decisão terminou
- **AND** a reserva fica `EXPIRADA`

#### Scenario: Exatamente no início
- **GIVEN** Ana tem uma reserva `PENDENTE` às 14h00
- **WHEN** Rui tenta recusá-la às 14h00 em ponto
- **THEN** o sistema recusa informando que o prazo de decisão terminou

### Requirement: Expiração da pendente sem decisão
Uma reserva `PENDENTE` cujo início chegou sem decisão DEVE (MUST) expirar, sem gerar falta: a partir do início ela deixa de ocupar o horário e todas as consultas a mostram como `EXPIRADA`, mesmo antes de a expiração ser gravada.

#### Scenario: Horário liberado no início
- **GIVEN** a antecedência mínima de "Laboratório" é de 0 minutos, e Ana tem uma reserva `PENDENTE` em "LAB-01" das 14h00 às 16h00 sem decisão e são 14h20
- **WHEN** Carlos reserva "LAB-01" das 14h30 às 15h30
- **THEN** a reserva de Carlos é criada
- **AND** a reserva de Ana fica `EXPIRADA`

#### Scenario: Consulta antes da gravação
- **GIVEN** Ana tem uma reserva `PENDENTE` que começou às 14h00 e nenhuma reserva foi criada, cancelada ou decidida desde então
- **WHEN** Ana abre "Minhas reservas" às 14h20
- **THEN** a reserva aparece como expirada, no histórico

### Requirement: Gravação da expiração
A situação `EXPIRADA` DEVE (MUST) ser gravada sem ação de pessoa alguma, na próxima operação que cria, cancela, aprova ou recusa reservas, ou que entra, confirma ou desiste de uma fila (capability `fila-espera`): depois da validação do formato da entrada e antes das demais verificações, mesmo que a operação seja recusada depois. Ela também é gravada na consulta da fila do próprio usuário, feita ao abrir as páginas autenticadas, quando há vencimento a gravar. Nas ações de gestão que cancelam reservas, a pendente já iniciada continua sendo cancelada por indisponibilidade do espaço (capability `reservas`).

#### Scenario: Gravada por uma operação recusada
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" começou às 14h00 sem decisão
- **WHEN** Carlos tenta, às 14h20, reservar outro espaço num horário ocupado e é recusado
- **THEN** a reserva de Ana fica `EXPIRADA`

#### Scenario: Pendente de conta inativada
- **GIVEN** Carlos tinha uma reserva `PENDENTE` que começou às 14h00, e o admin inativou Carlos às 14h10, sem cancelar essa reserva porque ela já tinha começado
- **WHEN** Ana cria uma reserva às 14h20
- **THEN** a reserva de Carlos fica `EXPIRADA`

#### Scenario: Gestão antes da gravação
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" que começou às 14h00, ainda não gravada como expirada
- **WHEN** Rui desativa "LAB-01" às 14h10
- **THEN** a reserva de Ana fica `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`, como na capability `reservas`

#### Scenario: Gravada ao abrir uma página
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" começou às 14h00 sem decisão, e nenhuma operação gravou nada desde então
- **WHEN** Bruno abre "Buscar espaços" às 14h20
- **THEN** a reserva de Ana fica `EXPIRADA`

#### Scenario: Gravada pela entrada na fila
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" começou às 14h00 sem decisão
- **WHEN** Bruno entra na fila de outro espaço às 14h20
- **THEN** a reserva de Ana fica `EXPIRADA`

### Requirement: Decisões simultâneas
A decisão, o cancelamento pelo dono, a expiração e as ações de gestão sobre a mesma reserva DEVEM (MUST) ser atômicas entre si: uma reserva recebe uma única transição a partir de `PENDENTE`, e as demais tentativas de decisão são recusadas porque ela não está mais pendente. Depois de aprovada, a reserva segue as regras da `CONFIRMADA`, inclusive o cancelamento pelo dono no prazo. Nenhuma transição sai de `CONFIRMADA` para `RECUSADA` nem de um estado final.

#### Scenario: Aprovar e recusar ao mesmo tempo
- **WHEN** Rui aprova e o admin recusa a mesma reserva `PENDENTE` no mesmo instante
- **THEN** só uma das decisões é gravada e a outra recebe a recusa de reserva não pendente

#### Scenario: Aprovar enquanto o dono cancela
- **WHEN** Rui aprova a reserva `PENDENTE` de Ana no mesmo instante em que Ana a cancela, dentro do prazo
- **THEN** a reserva recebe uma única transição a partir de `PENDENTE`: ou é cancelada e a aprovação é recusada por não estar pendente, ou é aprovada e em seguida cancelada por Ana
- **AND** ela termina `CANCELADA`, nunca `CONFIRMADA` depois do cancelamento

#### Scenario: Aprovada e depois cancelada pelo dono
- **GIVEN** Rui aprovou a reserva `PENDENTE` de Ana para amanhã
- **WHEN** Ana cancela a reserva dentro do prazo
- **THEN** a reserva fica `CANCELADA` com o motivo `USUARIO`

### Requirement: Reservas da unidade
Coordenadores e admins DEVEM (MUST) poder listar as reservas dos espaços no seu escopo: o coordenador, das unidades que coordena; o admin, de todas. Filtros opcionais: unidade, espaço, situação e período (data inicial e final, em America/Sao_Paulo). Sem filtro de situação, só as pendentes que ainda podem ser decididas, da mais próxima para a mais distante. Aluno e professor, e coordenador que filtra unidade fora do escopo, DEVEM receber acesso negado.

#### Scenario: Coordenador vê só a própria unidade
- **GIVEN** Rui coordena "Paulista" e há reservas pendentes em "Paulista" e em "Vila Olímpia"
- **WHEN** Rui lista as reservas da unidade sem filtros
- **THEN** recebe só as pendentes de "Paulista", da mais próxima para a mais distante

#### Scenario: Admin vê todas
- **WHEN** o admin lista as reservas da unidade sem filtros
- **THEN** recebe as pendentes de todas as unidades

#### Scenario: Pendente vencida não aparece como pendente
- **GIVEN** uma reserva `PENDENTE` de "Paulista" começou às 14h00 e são 14h10
- **WHEN** Rui lista as pendentes
- **THEN** essa reserva não aparece entre as pendentes
- **AND** aparece quando Rui filtra a situação expirada

#### Scenario: Filtro por situação e período
- **WHEN** Rui filtra as reservas confirmadas de "LAB-01" da próxima semana
- **THEN** recebe só as reservas `CONFIRMADA` de "LAB-01" com início nesse período

#### Scenario: Unidade fora do escopo
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui filtra a unidade "Vila Olímpia"
- **THEN** o sistema responde com acesso negado

#### Scenario: Aluno tenta listar
- **WHEN** Ana, aluna, chama diretamente a listagem de reservas da unidade
- **THEN** o sistema responde com acesso negado

### Requirement: Filtros de situação e período da listagem
O filtro de situação DEVE (MUST) aceitar pendentes (padrão), confirmadas, concluídas, não compareceu, recusadas, expiradas, canceladas ou todas, e recusar qualquer outro valor. As situações vencidas valem pela situação efetiva, gravadas ou não: expiradas, não compareceu e concluídas. O período DEVE aceitar datas AAAA-MM-DD existentes, com a data final igual ou posterior à inicial, e recusar o resto. As pendentes vêm da mais próxima para a mais distante; as demais situações, inclusive todas, da mais recente para a mais antiga.

#### Scenario: Situação inválida
- **WHEN** Rui filtra a situação "ARQUIVADA"
- **THEN** o sistema recusa informando que a situação é inválida

#### Scenario: Período invertido
- **WHEN** Rui filtra de 2026-11-20 a 2026-11-10
- **THEN** o sistema recusa informando que a data final deve ser igual ou posterior à inicial

#### Scenario: Reserva noturna no período
- **GIVEN** "LAB-01" tem uma reserva de quarta-feira das 21h00 às 22h00 em São Paulo, que em UTC já é quinta-feira
- **WHEN** Rui filtra o período só de quarta-feira, com a situação todas
- **THEN** a reserva aparece

#### Scenario: Não compareceu antes da gravação
- **GIVEN** a janela da reserva `CONFIRMADA` de Ana em "LAB-01" fechou às 14h15 sem check-in, ainda sem gravação
- **WHEN** Rui filtra as reservas de "Paulista" com a situação não compareceu, às 14h30
- **THEN** a reserva de Ana aparece
- **AND** ela não aparece quando Rui filtra as confirmadas

#### Scenario: Concluídas
- **GIVEN** Ana fez check-in da reserva das 14h00 às 15h00 em "LAB-01"
- **WHEN** Rui filtra as concluídas de "Paulista" às 15h30
- **THEN** a reserva de Ana aparece, com o check-in

### Requirement: Tamanho da listagem
A listagem DEVE (MUST) devolver no máximo 200 reservas por consulta e indicar quando havia mais. A tela DEVE avisar que só as 200 primeiras foram mostradas e sugerir refinar por período ou espaço.

#### Scenario: Mais de 200 reservas
- **GIVEN** "Paulista" tem 250 reservas confirmadas
- **WHEN** Rui filtra as confirmadas de "Paulista" sem período
- **THEN** recebe 200 reservas e a indicação de que havia mais
- **AND** a tela mostra o aviso para refinar a busca

### Requirement: Dados de cada reserva da unidade
Cada reserva listada DEVE (MUST) trazer: id; dono (nome, e-mail institucional e papel no momento da criação, pelo nível de prioridade); espaço (nome e código), unidade e tipo; data e horas de início e fim em America/Sao_Paulo; situação efetiva; instante de criação; na decisão, quem decidiu, quando e o motivo da recusa; no cancelamento, o motivo e quem cancelou; e o instante do check-in, quando houver.

#### Scenario: Pendente com o dono identificado
- **GIVEN** Ana, aluna, tem uma reserva `PENDENTE` em "LAB-01"
- **WHEN** Rui lista as pendentes de "Paulista"
- **THEN** a reserva traz o nome e o e-mail de Ana, o papel aluno, "LAB-01", a data e o horário em São Paulo

#### Scenario: Recusada com a decisão
- **GIVEN** Rui recusou uma reserva com o motivo "Laboratório em manutenção"
- **WHEN** o admin filtra as recusadas de "Paulista"
- **THEN** a reserva traz Rui como quem decidiu, o instante e o motivo

#### Scenario: Confirmada com check-in
- **GIVEN** Ana fez check-in às 13h55 da reserva `CONFIRMADA` das 14h00 em "LAB-01"
- **WHEN** Rui filtra as confirmadas de "Paulista" às 14h10
- **THEN** a reserva traz o check-in às 13h55

#### Scenario: Cancelada tardiamente
- **GIVEN** Ana cancelou tardiamente a reserva dela em "LAB-01"
- **WHEN** Rui filtra as canceladas de "Paulista"
- **THEN** a reserva traz o motivo de cancelamento tardio e Ana como quem cancelou

### Requirement: Dados que a listagem da unidade não expõe
A listagem NÃO DEVE (MUST NOT) trazer dados pessoais do dono além de nome, e-mail institucional e nível na criação, nem o motivo da inativação de conta. Na reserva cancelada por inativação de conta, ela DEVE (MUST) mostrar o motivo do cancelamento sem identificar quem cancelou.

#### Scenario: Cancelada por inativação de conta
- **GIVEN** o admin inativou Carlos e isso cancelou uma reserva dele em "LAB-01"
- **WHEN** Rui filtra as canceladas de "Paulista"
- **THEN** a reserva aparece cancelada por inativação de conta, sem o nome de quem cancelou e sem o motivo da inativação

### Requirement: Tela de reservas da unidade
O frontend DEVE (MUST) oferecer a coordenadores e admins a página "Reservas da unidade", com os filtros da listagem, as pendentes em destaque e, em cada pendente, "Aprovar" e "Recusar". "Recusar" abre um diálogo com o motivo obrigatório e avisa que o motivo será mostrado ao dono. Recusas de validação aparecem dentro da própria página ou do diálogo. Depois de cada decisão, a página atualiza a lista.

#### Scenario: Aprovar pela página
- **GIVEN** Rui abre "Reservas da unidade" e vê a pendente de Ana em "LAB-01"
- **WHEN** Rui escolhe "Aprovar"
- **THEN** a página mostra a confirmação e a reserva sai da lista de pendentes

#### Scenario: Recusar pela página
- **WHEN** Rui escolhe "Recusar" na pendente de Ana, escreve o motivo e confirma
- **THEN** o diálogo fecha, a página mostra a confirmação e a reserva sai da lista de pendentes

#### Scenario: Prazo terminou com a página aberta
- **GIVEN** Rui abriu a página às 13h58 com uma pendente que começa às 14h00
- **WHEN** Rui escolhe "Aprovar" às 14h01
- **THEN** a página mostra que o prazo de decisão terminou e atualiza a lista

#### Scenario: Própria reserva na lista
- **GIVEN** Carlos coordena "Paulista" e tem uma reserva `PENDENTE` própria em "AUD-01"
- **WHEN** Carlos escolhe "Aprovar" nessa reserva
- **THEN** a página mostra que a própria reserva é decidida por outro coordenador ou por um admin
