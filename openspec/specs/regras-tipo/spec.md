# Especificação: Regras do tipo de espaço

## Purpose
Definir as regras de uso de cada tipo de espaço (duração, antecedência, limite de reservas ativas, horário e recorrência) e quem pode reservar cada tipo e com que aprovação. Também define quando um pedido de horário está dentro dessas regras, verificação que a busca usa e que a reserva vai reutilizar.

## Requirements

### Requirement: Regras de uso do tipo de espaço
Cada tipo de espaço DEVE (MUST) ter estas regras, que valem para todos os papéis:
- duração mínima e duração máxima, em minutos;
- antecedência mínima, em minutos, e antecedência máxima, em dias;
- máximo de reservas ativas por usuário;
- hora de abertura e hora de fechamento;
- se permite reserva recorrente.

Qualquer admin DEVE poder definir e alterar as regras de qualquer tipo, ativo ou desativado. Coordenadores, professores e alunos NÃO DEVEM (MUST NOT) alterá-las. As regras são gravadas juntas com a regra por papel do tipo, numa única operação: se qualquer valor for inválido, nada muda. Alterar as regras vale para os pedidos seguintes e não altera nada que já exista.

Todas as regras são obrigatórias. Elas DEVEM ser consistentes, com a granularidade de horário G vinda dos parâmetros:
- duração mínima ≥ G e múltipla de G;
- duração máxima ≥ duração mínima, múltipla de G e no máximo igual ao intervalo entre abertura e fechamento;
- abertura e fechamento múltiplos de G, no mesmo dia (de 00h00 até antes de 24h00), com a abertura antes do fechamento;
- antecedência mínima ≥ 0 minutos; antecedência máxima ≥ 1 dia e maior que a antecedência mínima;
- máximo de reservas ativas ≥ 1.

#### Scenario: Admin define as regras
- **WHEN** o admin define para "Biblioteca" duração de 30 a 180 minutos, antecedência de 0 minutos a 7 dias, 2 reservas ativas, horário das 08h00 às 22h40 e sem recorrência
- **THEN** as regras são gravadas e passam a valer para os pedidos seguintes

#### Scenario: Duração mínima maior que a máxima
- **WHEN** o admin tenta gravar duração mínima de 120 e máxima de 60 minutos
- **THEN** o sistema recusa indicando a regra inválida e nada muda

#### Scenario: Valor fora da granularidade
- **GIVEN** a granularidade é de 10 minutos
- **WHEN** o admin tenta gravar duração mínima de 45 minutos ou abertura às 08h05
- **THEN** o sistema recusa informando que o valor deve ser múltiplo de 10 minutos

#### Scenario: Abertura depois do fechamento
- **WHEN** o admin tenta gravar abertura às 22h00 e fechamento às 08h00
- **THEN** o sistema recusa informando que a abertura deve ser antes do fechamento

#### Scenario: Duração máxima maior que o horário do dia
- **GIVEN** o horário do tipo vai das 08h00 às 12h00
- **WHEN** o admin tenta gravar duração máxima de 300 minutos
- **THEN** o sistema recusa informando que a duração máxima não cabe no horário do tipo

#### Scenario: Antecedência máxima não maior que a mínima
- **WHEN** o admin tenta gravar antecedência mínima de 2880 minutos e máxima de 2 dias
- **THEN** o sistema recusa informando que a antecedência máxima deve ser maior que a mínima e nada muda

#### Scenario: Máximo de reservas zero
- **WHEN** o admin tenta gravar o máximo de reservas ativas igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nada muda

#### Scenario: Fechamento à meia-noite
- **WHEN** o admin tenta gravar o fechamento às 24h00
- **THEN** o sistema recusa informando que o fechamento deve ser antes da meia-noite

#### Scenario: Regra ausente
- **WHEN** o admin tenta gravar as regras de um tipo sem informar a duração máxima
- **THEN** o sistema recusa informando que todas as regras são obrigatórias e nada muda

#### Scenario: Tipo inexistente
- **WHEN** o admin tenta gravar as regras de um tipo que não existe
- **THEN** o sistema responde que o tipo não foi encontrado

#### Scenario: Regras de tipo desativado
- **GIVEN** "Auditório" está desativado
- **WHEN** o admin altera as regras de "Auditório"
- **THEN** as regras são gravadas e o tipo continua desativado

#### Scenario: Outros papéis tentam alterar regras
- **WHEN** um coordenador, um professor ou um aluno tenta alterar as regras de um tipo
- **THEN** o sistema responde com acesso negado e nada muda

#### Scenario: Regras e granularidade ao mesmo tempo
- **GIVEN** a granularidade é de 10 minutos
- **WHEN** o admin grava a duração mínima de "Estúdio" como 50 minutos ao mesmo tempo em que o principal muda a granularidade para 30 minutos
- **THEN** só uma das duas alterações é gravada e nenhum tipo fica com regras fora da granularidade

### Requirement: Regra por papel
Para cada tipo de espaço, a regra por papel DEVE (MUST) definir, para **aluno** e para **professor**, se o papel pode reservar o tipo e se a reserva exige aprovação. Um papel que não pode reservar NÃO DEVE exigir aprovação. **Coordenador e administrador** têm regra fixa, que não é configurável: podem reservar todos os tipos e nunca precisam de aprovação.

#### Scenario: Aluno reserva laboratório com aprovação
- **GIVEN** a regra de "Laboratório" diz que o aluno pode reservar com aprovação
- **WHEN** um aluno consulta o tipo "Laboratório"
- **THEN** o tipo aparece como reservável, com aprovação

#### Scenario: Aluno não reserva sala de aula
- **GIVEN** a regra de "Sala de aula" diz que o aluno não pode reservar
- **WHEN** um aluno busca espaços
- **THEN** nenhum espaço do tipo "Sala de aula" aparece

#### Scenario: Coordenador sem aprovação
- **GIVEN** a regra de "Auditório" exige aprovação do professor
- **WHEN** um coordenador consulta o tipo "Auditório"
- **THEN** o tipo aparece como reservável, sem aprovação

#### Scenario: Aprovação sem permissão de reservar
- **WHEN** o admin tenta gravar para o aluno "não pode reservar" e "exige aprovação" no mesmo tipo
- **THEN** o sistema recusa informando que só exige aprovação quem pode reservar

### Requirement: Tipo com regras completas
Um tipo de espaço DEVE (MUST) ser considerado com regras completas somente quando as oito regras de uso e a regra por papel de aluno e de professor estão definidas. Tipos criados pelo admin nascem sem regras. Espaços de um tipo sem regras completas NÃO DEVEM (MUST NOT) ser reserváveis (capability `espacos`).

#### Scenario: Tipo novo sem regras
- **WHEN** o admin cria o tipo "Estúdio"
- **THEN** o tipo nasce ativo e sem regras, e os espaços dele não são reserváveis

#### Scenario: Tipo passa a ter regras
- **GIVEN** "Estúdio" não tem regras e tem o espaço ativo "EST-01" numa unidade ativa
- **WHEN** o admin define todas as regras de "Estúdio"
- **THEN** "EST-01" passa a ser reservável

### Requirement: Carga inicial das regras
O sistema DEVE (MUST) definir, uma única vez, as regras dos tipos iniciais, sem exigir cadastro pela interface. A carga DEVE ocorrer somente enquanto nenhuma regra por papel tiver sido gravada, e DEVE usar estes valores:

| Tipo | Duração (min) | Antecedência mín. | Antecedência máx. | Reservas ativas | Horário | Recorrência | Aluno | Professor |
|---|---|---|---|---|---|---|---|---|
| Sala de aula | 50 a 300 | 0 min | 30 dias | 10 | 08h00 às 22h40 | sim | não reserva | reserva |
| Laboratório | 30 a 240 | 0 min | 14 dias | 3 | 08h00 às 22h40 | não | reserva com aprovação | reserva |
| Biblioteca | 30 a 180 | 0 min | 7 dias | 2 | 08h00 às 22h40 | não | reserva | reserva |
| Auditório | 50 a 480 | 1440 min | 60 dias | 2 | 08h00 às 22h40 | não | não reserva | reserva com aprovação |

Tipos que não forem os iniciais NÃO DEVEM (MUST NOT) receber regras pela carga. A carga não gera registro de auditoria.

#### Scenario: Carga aplicada
- **GIVEN** nenhuma regra por papel foi gravada
- **WHEN** a carga é aplicada
- **THEN** "Sala de aula", "Laboratório", "Biblioteca" e "Auditório" ficam com as regras da tabela
- **AND** "Refeitório" continua sem regras

#### Scenario: Carga repetida
- **GIVEN** a carga já foi aplicada e o admin alterou as regras de "Biblioteca"
- **WHEN** a carga é aplicada novamente
- **THEN** nenhuma regra é criada nem alterada

#### Scenario: Tipo inicial renomeado
- **GIVEN** o admin renomeou "Biblioteca" para "Biblioteca central" antes da carga
- **WHEN** a carga é aplicada
- **THEN** "Biblioteca central" fica sem regras, e os outros três tipos iniciais recebem as regras da tabela

### Requirement: Pedido dentro das regras do tipo
Um pedido de horário (início e fim) para um espaço DEVE (MUST) ser considerado dentro das regras do tipo somente quando todas estas condições valem, avaliadas no fuso America/Sao_Paulo e com o instante atual tomado pelo backend:
- o tipo tem regras completas;
- início antes do fim, no mesmo dia;
- o dia é um dos dias de funcionamento;
- início e fim múltiplos da granularidade, sem segundos;
- início a partir da abertura e fim até o fechamento do tipo;
- duração entre a mínima e a máxima do tipo;
- início pelo menos a antecedência mínima depois do instante atual e no máximo a antecedência máxima depois dele.

Quando o pedido não está dentro das regras, o sistema DEVE informar todos os motivos. Essa verificação NÃO DEVE (MUST NOT) considerar ocupação do espaço (reservas, bloqueios ou fila), que é tratada pelas changes de reserva e bloqueio.

#### Scenario: Pedido dentro das regras
- **GIVEN** "Biblioteca" vai das 08h00 às 22h40, com duração de 30 a 180 minutos e antecedência de 0 minutos a 7 dias, e hoje é segunda-feira
- **WHEN** alguém pede a "Biblioteca" na quarta-feira, das 10h00 às 11h30
- **THEN** o pedido está dentro das regras do tipo

#### Scenario: Término exatamente às 22h40
- **WHEN** alguém pede a "Biblioteca" num dia útil, das 21h40 às 22h40
- **THEN** o pedido está dentro das regras do tipo

#### Scenario: Início exatamente às 08h00
- **WHEN** alguém pede a "Biblioteca" num dia útil, das 08h00 às 09h00
- **THEN** o pedido está dentro das regras do tipo

#### Scenario: Duração exatamente nos limites
- **WHEN** alguém pede a "Biblioteca" por exatamente 30 minutos, ou por exatamente 180 minutos
- **THEN** os dois pedidos estão dentro das regras do tipo

#### Scenario: Fim não depois do início
- **WHEN** alguém pede um horário com o fim igual ou anterior ao início
- **THEN** o pedido está fora das regras, com o motivo de fim não depois do início

#### Scenario: Término depois do fechamento
- **WHEN** alguém pede a "Biblioteca" das 22h00 às 22h50
- **THEN** o pedido está fora das regras, com o motivo de término depois do fechamento

#### Scenario: Início antes da abertura
- **WHEN** alguém pede a "Biblioteca" das 07h50 às 08h40
- **THEN** o pedido está fora das regras, com o motivo de início antes da abertura

#### Scenario: Início às 22h40
- **WHEN** alguém pede a "Biblioteca" das 22h40 às 23h10
- **THEN** o pedido está fora das regras, com o motivo de término depois do fechamento

#### Scenario: Fim de semana
- **GIVEN** os dias de funcionamento são de segunda a sexta
- **WHEN** alguém pede a "Biblioteca" num sábado
- **THEN** o pedido está fora das regras, com o motivo de dia sem funcionamento

#### Scenario: Fora da granularidade
- **WHEN** alguém pede a "Biblioteca" das 10h05 às 11h05
- **THEN** o pedido está fora das regras, com o motivo de horário fora da granularidade

#### Scenario: Duração abaixo da mínima e acima da máxima
- **WHEN** alguém pede a "Sala de aula" por 40 minutos, ou a "Biblioteca" por 190 minutos
- **THEN** o pedido está fora das regras, com o motivo de duração abaixo da mínima ou acima da máxima

#### Scenario: Antecedência mínima
- **GIVEN** "Auditório" exige antecedência mínima de 1440 minutos e agora são 10h00 de segunda-feira
- **WHEN** alguém pede o "Auditório" para terça-feira às 09h00
- **THEN** o pedido está fora das regras, com o motivo de antecedência mínima

#### Scenario: Antecedência exatamente no limite
- **GIVEN** "Auditório" exige antecedência mínima de 1440 minutos e agora são 10h00 de segunda-feira
- **WHEN** alguém pede o "Auditório" para terça-feira às 10h00
- **THEN** o pedido está dentro das regras do tipo

#### Scenario: Antecedência máxima
- **GIVEN** "Biblioteca" aceita até 7 dias de antecedência
- **WHEN** alguém pede a "Biblioteca" para daqui a 10 dias
- **THEN** o pedido está fora das regras, com o motivo de antecedência máxima

#### Scenario: Horário no passado
- **WHEN** alguém pede um horário que já começou
- **THEN** o pedido está fora das regras, com o motivo de antecedência mínima

#### Scenario: Virada do dia no fuso de São Paulo
- **WHEN** alguém pede a "Biblioteca" numa sexta-feira das 22h00 às 22h40 em São Paulo (sábado, 01h00 às 01h40, em UTC)
- **THEN** o dia da semana e os horários são calculados no fuso de São Paulo e o pedido está dentro das regras do tipo

#### Scenario: Vários motivos
- **WHEN** alguém pede a "Biblioteca" num sábado, das 07h05 às 07h25
- **THEN** o pedido está fora das regras, com os motivos de dia sem funcionamento, horário fora da granularidade, início antes da abertura e duração abaixo da mínima

### Requirement: Tela de regras do tipo
O frontend DEVE (MUST) oferecer ao admin, na página "Tipos de espaço", um diálogo "Regras" por tipo, com as oito regras de uso e a regra por papel de aluno e professor, preenchido com os valores atuais. Horários são exibidos e digitados como HH:MM. Erros de validação DEVEM aparecer dentro do diálogo, sem apagar o que foi digitado.

#### Scenario: Editar regras pela tela
- **WHEN** o admin abre "Regras" de "Laboratório", altera a duração máxima para 180 minutos e salva
- **THEN** a página mostra a confirmação e o tipo passa a ter a nova duração máxima

#### Scenario: Erro dentro do diálogo
- **WHEN** o admin informa abertura às 22h00 e fechamento às 08h00 e salva
- **THEN** a mensagem de erro aparece dentro do diálogo e os valores digitados continuam preenchidos
