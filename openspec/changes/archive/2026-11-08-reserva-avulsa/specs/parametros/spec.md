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
- prazo de cancelamento sem penalidade, em minutos antes do início da reserva (padrão: 120).

Admins secundários e demais papéis NÃO DEVEM (MUST NOT) consultar nem editar essa área. Os valores padrão da granularidade, dos dias de funcionamento e do prazo de cancelamento são gravados pela carga inicial quando ainda não existem.

#### Scenario: Principal altera um limite
- **WHEN** o principal altera o máximo de coordenadores por unidade de 4 para 5
- **THEN** o novo valor passa a valer para todas as unidades a partir da próxima operação

#### Scenario: Principal altera os dias de funcionamento
- **WHEN** o principal inclui o sábado nos dias de funcionamento
- **THEN** pedidos de horário em sábados passam a poder estar dentro das regras dos tipos (capability `regras-tipo`)

#### Scenario: Principal altera o prazo de cancelamento
- **WHEN** o principal altera o prazo de cancelamento de 120 para 60 minutos
- **THEN** os usuários passam a poder cancelar as próprias reservas até 60 minutos antes do início (capability `reservas`)

#### Scenario: Secundário tenta editar
- **WHEN** um admin secundário tenta editar os parâmetros
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Validação dos parâmetros
Cada limite, inclusive o prazo de cancelamento, DEVE (MUST) ser um número inteiro maior ou igual a 1. A lista de domínios DEVE ter ao menos um domínio, sem `@`, sem espaços e sem repetição, gravado em minúsculas. A granularidade DEVE ser um divisor de 60 (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30 ou 60) e NÃO DEVE (MUST NOT) ser alterada para um valor do qual algum tipo com regras tenha duração, abertura ou fechamento que não seja múltiplo. Os dias de funcionamento DEVEM ter ao menos um dia, de segunda (1) a domingo (7), sem repetição. Reduzir um limite abaixo da quantidade atual NÃO DEVE remover ninguém: só impede novas entradas. Se qualquer valor for inválido, nada é gravado.

#### Scenario: Limite zero
- **WHEN** o principal tenta gravar o máximo de admins igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Prazo de cancelamento inválido
- **WHEN** o principal tenta gravar o prazo de cancelamento igual a 0
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
O frontend DEVE (MUST) oferecer ao admin principal uma página "Parâmetros", com os valores atuais preenchidos, incluindo a granularidade de horário, os dias de funcionamento (um campo por dia da semana) e o prazo de cancelamento, e mostrar a mensagem da API depois de salvar.

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
