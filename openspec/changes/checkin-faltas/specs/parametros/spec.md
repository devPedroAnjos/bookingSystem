## MODIFIED Requirements

### Requirement: Consulta e edição dos parâmetros
Somente o admin principal DEVE (MUST) poder consultar e editar estes parâmetros de `ConfiguracaoGeral`:
- domínios de e-mail aceitos;
- máximo de coordenadores por unidade;
- máximo de unidades por coordenador;
- máximo de pedidos de cadastro;
- máximo de admins ativos;
- granularidade de horário, em minutos (padrão: 10);
- dias de funcionamento (padrão: segunda a sexta);
- prazo de cancelamento sem penalidade, em minutos antes do início da reserva (padrão: 120);
- prazo para deslocar por prioridade, em minutos antes do início da nova reserva e de cada deslocada (padrão: 120);
- corte da fila de espera, em minutos antes do início (padrão: 120);
- prazo para confirmar a vaga retida pela fila, em minutos a partir do aviso (padrão: 720);
- tempo mínimo útil da fila, em minutos antes do corte, que define o fechamento da fila (padrão: 30);
- abertura da janela de check-in, em minutos antes do início (padrão: 15);
- fechamento da janela de check-in, em minutos depois do início (padrão: 15);
- faltas para gerar penalidade (padrão: 2);
- janela de contagem das faltas, em dias (padrão: 30);
- duração da penalidade, em dias (padrão: 7).

Admins secundários e demais papéis NÃO DEVEM (MUST NOT) consultar nem editar essa área. Os valores padrão da granularidade, dos dias de funcionamento, do prazo de cancelamento, do prazo para deslocar, dos três parâmetros da fila e dos cinco parâmetros de check-in e penalidade são gravados pela carga inicial quando ainda não existem.

#### Scenario: Principal altera um limite
- **WHEN** o principal altera o máximo de coordenadores por unidade de 4 para 5
- **THEN** o novo valor passa a valer para todas as unidades a partir da próxima operação

#### Scenario: Principal altera os dias de funcionamento
- **WHEN** o principal inclui o sábado nos dias de funcionamento
- **THEN** pedidos de horário em sábados passam a poder estar dentro das regras dos tipos (capability `regras-tipo`)

#### Scenario: Principal altera o prazo de cancelamento
- **WHEN** o principal altera o prazo de cancelamento de 120 para 60 minutos
- **THEN** os usuários passam a poder cancelar as próprias reservas sem falta até 60 minutos antes do início (capability `reservas`)

#### Scenario: Principal altera o prazo para deslocar
- **WHEN** o principal altera o prazo para deslocar de 120 para 240 minutos
- **THEN** o deslocamento por prioridade passa a exigir que a nova reserva e cada deslocada comecem a mais de 240 minutos de agora (capability `reservas`)

#### Scenario: Carga inicial do prazo para deslocar
- **GIVEN** a configuração ainda não tem o prazo para deslocar
- **WHEN** a carga inicial é executada duas vezes
- **THEN** a primeira grava 120 minutos e a segunda não altera nada

#### Scenario: Principal altera o corte da fila
- **WHEN** o principal altera o corte da fila de 120 para 180 minutos
- **THEN** o corte das filas passa a ser 180 minutos antes do início, salvo antecedência mínima maior do tipo, e o fechamento passa a ser o corte menos o tempo mínimo útil (capability `fila-espera`)

#### Scenario: Principal altera o prazo para confirmar
- **WHEN** o principal altera o prazo para confirmar de 720 para 360 minutos
- **THEN** as próximas vagas retidas têm até 360 minutos para ser confirmadas, limitados ao corte (capability `fila-espera`)
- **AND** os prazos das vagas já retidas não mudam

#### Scenario: Carga inicial dos parâmetros da fila
- **GIVEN** a configuração ainda não tem o corte, o prazo para confirmar nem o tempo mínimo útil da fila
- **WHEN** a carga inicial é executada duas vezes
- **THEN** a primeira grava 120, 720 e 30 minutos e a segunda não altera nada

#### Scenario: Principal altera a janela de check-in
- **WHEN** o principal altera o fechamento da janela de check-in de 15 para 10 minutos
- **THEN** as janelas de check-in, inclusive das reservas já criadas, passam a fechar 10 minutos depois do início (capability `comparecimento`)

#### Scenario: Principal altera a regra da penalidade
- **WHEN** o principal altera as faltas para gerar penalidade de 2 para 3
- **THEN** as próximas faltas registradas passam a gerar penalidade a partir de 3 faltas sem penalidade na janela (capability `penalidades`)
- **AND** as penalidades já geradas não mudam

#### Scenario: Carga inicial dos parâmetros de check-in e penalidade
- **GIVEN** a configuração ainda não tem os parâmetros de check-in e penalidade
- **WHEN** a carga inicial é executada duas vezes
- **THEN** a primeira grava 15 e 15 minutos, 2 faltas, 30 dias e 7 dias, e a segunda não altera nada

#### Scenario: Secundário tenta editar
- **WHEN** um admin secundário tenta editar os parâmetros
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Validação dos parâmetros
Cada limite, inclusive o prazo de cancelamento, o prazo para deslocar, os três parâmetros da fila e os cinco parâmetros de check-in e penalidade, DEVE (MUST) ser um número inteiro maior ou igual a 1. A lista de domínios DEVE ter ao menos um domínio, sem `@`, sem espaços e sem repetição, gravado em minúsculas. A granularidade DEVE ser um divisor de 60 (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30 ou 60) e NÃO DEVE (MUST NOT) ser alterada para um valor do qual algum tipo com regras tenha duração, abertura ou fechamento que não seja múltiplo. Os dias de funcionamento DEVEM ter ao menos um dia, de segunda (1) a domingo (7), sem repetição. Reduzir um limite abaixo da quantidade atual NÃO DEVE remover ninguém: só impede novas entradas. Se qualquer valor for inválido, nada é gravado.

#### Scenario: Limite zero
- **WHEN** o principal tenta gravar o máximo de admins igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Prazo de cancelamento inválido
- **WHEN** o principal tenta gravar o prazo de cancelamento igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Prazo para deslocar inválido
- **WHEN** o principal tenta gravar o prazo para deslocar igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Parâmetro da fila inválido
- **WHEN** o principal tenta gravar o corte, o prazo para confirmar ou o tempo mínimo útil da fila igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Parâmetro de check-in ou penalidade inválido
- **WHEN** o principal tenta gravar a abertura ou o fechamento da janela de check-in, as faltas para penalidade, a janela das faltas ou a duração da penalidade igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Lista de domínios vazia
- **WHEN** o principal tenta remover todos os domínios aceitos
- **THEN** o sistema recusa informando que é preciso ao menos um domínio

#### Scenario: Redução abaixo do atual
- **GIVEN** "Paulista" tem 4 coordenadores ativos
- **WHEN** o principal reduz o máximo de coordenadores por unidade para 2
- **THEN** a alteração é aceita e os 4 coordenadores continuam
- **AND** "Paulista" não aceita novos coordenadores enquanto tiver 2 ou mais

#### Scenario: Granularidade que não divide a hora
- **WHEN** o principal tenta gravar a granularidade de 7 minutos
- **THEN** o sistema recusa informando os valores aceitos e nenhum parâmetro muda

#### Scenario: Granularidade incompatível com os tipos
- **GIVEN** "Sala de aula" tem duração mínima de 50 minutos
- **WHEN** o principal tenta mudar a granularidade para 30 minutos
- **THEN** o sistema recusa indicando os tipos com regras incompatíveis e nenhum parâmetro muda

#### Scenario: Sem dias de funcionamento
- **WHEN** o principal tenta desmarcar todos os dias de funcionamento
- **THEN** o sistema recusa informando que é preciso ao menos um dia

### Requirement: Tela de parâmetros
O frontend DEVE (MUST) oferecer ao admin principal uma página "Parâmetros", com os valores atuais preenchidos, incluindo a granularidade de horário, os dias de funcionamento (um campo por dia da semana), o prazo de cancelamento, o prazo para deslocar por prioridade, os três parâmetros da fila de espera (corte, prazo para confirmar e tempo mínimo útil) e os cinco parâmetros de check-in e penalidade (abertura e fechamento da janela de check-in, faltas para penalidade, janela das faltas e duração da penalidade), e mostrar a mensagem da API depois de salvar.

#### Scenario: Salvar pela página
- **WHEN** o principal altera o máximo de pedidos de cadastro para 4 e salva
- **THEN** a página mostra a confirmação e o novo valor

#### Scenario: Dias e granularidade pela página
- **WHEN** o principal abre a página "Parâmetros"
- **THEN** vê a granularidade atual e os dias de funcionamento marcados, de segunda a domingo
- **AND** ao marcar o sábado e salvar, a página mostra a confirmação e o sábado marcado

#### Scenario: Prazo de cancelamento pela página
- **WHEN** o principal abre a página "Parâmetros"
- **THEN** vê o prazo de cancelamento atual, em minutos, e pode alterá-lo

#### Scenario: Prazo para deslocar pela página
- **WHEN** o principal abre a página "Parâmetros"
- **THEN** vê o prazo para deslocar por prioridade atual, em minutos, e pode alterá-lo

#### Scenario: Parâmetros da fila pela página
- **WHEN** o principal abre a página "Parâmetros"
- **THEN** vê o corte, o prazo para confirmar e o tempo mínimo útil da fila de espera atuais, em minutos, e pode alterá-los

#### Scenario: Parâmetros de check-in e penalidade pela página
- **WHEN** o principal abre a página "Parâmetros"
- **THEN** vê a abertura e o fechamento da janela de check-in, em minutos, as faltas para penalidade, a janela das faltas e a duração da penalidade, em dias, e pode alterá-los
- **AND** a página avisa que a mudança da janela de check-in vale também para as reservas já criadas, inclusive as que estão na janela naquele momento
