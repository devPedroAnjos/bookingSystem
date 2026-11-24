## MODIFIED Requirements

### Requirement: Quem busca e o que aparece
Todo usuário com conta ativa DEVE (MUST) poder buscar espaços. A busca DEVE mostrar espaços de **todas as unidades**, para qualquer papel, inclusive coordenadores. Só DEVEM aparecer espaços reserváveis (espaço, unidade e tipo ativos e tipo com regras completas, capability `espacos`). Os espaços de tipos que o papel de quem busca pode reservar (regra por papel; coordenador e admin podem todos) aparecem completos; os de tipos que o papel não pode reservar aparecem **restritos** (requisito "Espaço restrito ao papel").

Espaços desativados, de unidade ou tipo desativados ou de tipo sem regras NÃO DEVEM (MUST NOT) aparecer.

#### Scenario: Aluno busca
- **GIVEN** existem espaços ativos de "Biblioteca", "Laboratório", "Sala de aula" e "Auditório" em "Paulista" e "Vila Olímpia"
- **WHEN** um aluno busca sem filtros
- **THEN** recebe os espaços de "Biblioteca" e "Laboratório" das duas unidades completos
- **AND** recebe os de "Sala de aula" e "Auditório" restritos

#### Scenario: Professor busca
- **WHEN** um professor busca sem filtros
- **THEN** recebe os espaços dos quatro tipos iniciais das duas unidades, todos completos

#### Scenario: Coordenador busca em outras unidades
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui busca espaços
- **THEN** recebe também os espaços de "Vila Olímpia", sem nenhum restrito

#### Scenario: Espaço não reservável fica de fora
- **GIVEN** "Refeitório 1" está ativo, mas o tipo "Refeitório" não tem regras
- **WHEN** o admin ou um aluno busca espaços
- **THEN** "Refeitório 1" não aparece, nem como restrito

#### Scenario: Sem autenticação
- **WHEN** a busca é chamada sem token ou com conta inativa
- **THEN** o sistema responde com não autenticado

### Requirement: Filtros da busca
A busca DEVE (MUST) aceitar estes filtros, todos opcionais e combinados entre si:
- texto, com até 100 caracteres, procurado no nome, no código, na descrição e na localização do espaço e nos nomes da unidade e do tipo, sem diferenciar maiúsculas, minúsculas e acentos e ignorando espaços nas pontas;
- unidade;
- tipo de espaço;
- capacidade mínima (capacidade do espaço maior ou igual ao valor);
- recursos (o espaço precisa ter **todos** os recursos escolhidos);
- data, hora de início e hora de fim, informados juntos.

Os filtros valem também para os espaços restritos, mas o texto só é procurado nos campos que o restrito mostra (nome, código, localização, unidade e tipo), nunca na descrição dele, e o filtro de recursos não o encontra. Filtrar por um tipo que o papel não pode reservar DEVE devolver os espaços desse tipo restritos, sem erro. Texto vazio ou só com espaços equivale a não filtrar por texto. Texto acima do limite, e data e horário incompletos, inválidos ou com fim antes do início, DEVEM ser recusados.

#### Scenario: Capacidade e recursos
- **GIVEN** "LAB-01" tem capacidade 30, 30 "Computadores" e 1 "Projetor", e "LAB-02" tem capacidade 20 e só "Computadores"
- **WHEN** um professor busca capacidade mínima 25 com os recursos "Computadores" e "Projetor"
- **THEN** recebe só "LAB-01"

#### Scenario: Tipo que o papel não pode reservar
- **WHEN** um aluno filtra pelo tipo "Auditório"
- **THEN** recebe os espaços de "Auditório" restritos

#### Scenario: Busca por texto sem acento e sem maiúsculas
- **GIVEN** "BIB-02" se chama "Sala Ipê" e fica no "Bloco Á"
- **WHEN** um aluno busca o texto "sala ipe"
- **THEN** recebe "BIB-02"

#### Scenario: Texto no nome da unidade ou do tipo
- **WHEN** alguém busca o texto "paulista"
- **THEN** recebe os espaços da unidade "Paulista", inclusive os que não têm "paulista" no nome

#### Scenario: Texto combinado com outros filtros
- **GIVEN** "LAB-01" e "BIB-01" ficam no "Bloco B"
- **WHEN** um professor busca o texto "bloco b" com o tipo "Laboratório"
- **THEN** recebe só "LAB-01"

#### Scenario: Texto longo demais
- **WHEN** alguém busca um texto de 101 caracteres
- **THEN** o sistema recusa informando o limite de 100 caracteres

#### Scenario: Horário incompleto
- **WHEN** alguém informa a data e a hora de início, mas não a hora de fim
- **THEN** o sistema recusa informando que data, início e fim devem ser informados juntos

#### Scenario: Fim antes do início
- **WHEN** alguém informa início às 11h00 e fim às 10h00
- **THEN** o sistema recusa informando que o fim deve ser depois do início

#### Scenario: Data ou hora inválida
- **WHEN** alguém informa a data "2026-02-30", a data "próxima sexta" ou a hora "25:00"
- **THEN** o sistema recusa informando que a data deve estar no formato AAAA-MM-DD e as horas no formato HH:MM, com valores existentes

### Requirement: Resultado da busca
Cada espaço encontrado DEVE (MUST) trazer: id, nome, código, unidade (id e nome), tipo (id e nome), capacidade, localização, a URL da foto de capa quando houver (capability `espacos`) e se está restrito ao papel de quem busca. O espaço não restrito traz também a descrição, os recursos (nome e quantidade), se a reserva exigiria aprovação para o papel de quem busca, a média das avaliações com uma casa decimal e a quantidade delas (capability `avaliacoes`). Os resultados DEVEM vir ordenados pelo nome da unidade e pelo código, sem paginação.

#### Scenario: Aprovação conforme o papel
- **GIVEN** "Laboratório" exige aprovação para o aluno e não para o professor
- **WHEN** um aluno e um professor buscam "LAB-01"
- **THEN** o resultado do aluno indica que a reserva exigiria aprovação e o do professor indica que não

#### Scenario: Códigos iguais em unidades diferentes
- **GIVEN** "Paulista" e "Vila Olímpia" têm, cada uma, um espaço de código "101"
- **WHEN** alguém busca espaços
- **THEN** os dois aparecem, cada um com o nome da própria unidade

#### Scenario: Média no resultado
- **GIVEN** "BIB-01" tem avaliações de nota 5 e 4, e "BIB-03" não tem nenhuma
- **WHEN** um aluno busca "Biblioteca"
- **THEN** "BIB-01" vem com a média 4,5 e a quantidade 2, e "BIB-03" com a quantidade 0 e sem média

#### Scenario: Foto no resultado
- **GIVEN** "LAB-01" tem foto de capa e "LAB-02" não tem
- **WHEN** alguém busca "Laboratório"
- **THEN** "LAB-01" vem com a URL da foto e "LAB-02" sem ela

### Requirement: Horário pedido na busca
Quando data e horário são informados, cada espaço **não restrito** do resultado DEVE (MUST) indicar se o pedido está **dentro das regras do tipo** (capability `regras-tipo`) e, quando não está, os motivos. Espaços fora das regras continuam no resultado, com os motivos. Cada espaço não restrito DEVE indicar também se está **livre** ou **ocupado** no intervalo pedido: ocupado quando há reserva `PENDENTE` ou `CONFIRMADA` sobreposta no espaço (capability `reservas`), sem contar a pendente cujo início já chegou, que expirou (capability `aprovacao-reservas`), ou quando há vaga retida pela fila sobreposta, sem contar a retenção cujo prazo já venceu (capability `fila-espera`). Cada espaço ocupado e dentro das regras DEVE indicar ainda se quem busca poderia deslocar a ocupação, pelas condições do deslocamento por prioridade (capability `reservas`), e quantas reservas seriam deslocadas; espaços livres ou fora das regras aparecem não deslocáveis, com 0 reservas a deslocar, e a vaga retida torna o espaço não deslocável. Cada espaço não restrito DEVE indicar também se quem busca já está na fila desse intervalo e, quando não está, se pode entrar nela: ocupado, dentro das regras, não deslocável e antes do fechamento da fila (o corte menos o tempo mínimo útil, capability `fila-espera`). A busca NÃO DEVE (MUST NOT) identificar quem ocupa o horário nem quem está na fila. As indicações são informativas: a reserva e a entrada na fila verificam tudo de novo.

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
- **THEN** os espaços aparecem sem indicação de regras de horário, de ocupação, de deslocamento nem de fila

#### Scenario: Ocupado e deslocável
- **GIVEN** "LAB-01" tem reservas de dois alunos sobrepostas ao intervalo pedido, que começa depois de amanhã
- **WHEN** um professor busca "Laboratório" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e deslocável, com 2 reservas a deslocar, sem indicação de quem reservou, e sem oferta de fila

#### Scenario: Ocupado e não deslocável
- **GIVEN** "LAB-01" tem uma reserva de um professor sobreposta ao intervalo pedido, que começa depois de amanhã
- **WHEN** outro professor busca "Laboratório" para esse intervalo
- **THEN** "LAB-01" aparece ocupado, não deslocável e com a possibilidade de entrar na fila

#### Scenario: Deslocamento fora do prazo
- **GIVEN** o prazo para deslocar é de 120 minutos e "LAB-01" tem uma reserva de aluno que começa daqui a 1 hora
- **WHEN** um professor busca "LAB-01" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e não deslocável

#### Scenario: Nova reserva exigiria aprovação
- **GIVEN** o admin configurou "Laboratório" para exigir aprovação do professor, e "LAB-01" tem uma reserva de aluno que começa depois de amanhã
- **WHEN** um professor busca "LAB-01" para esse intervalo
- **THEN** "LAB-01" aparece ocupado e não deslocável

#### Scenario: Ocupado e fora das regras
- **GIVEN** "BIB-01" tem uma reserva de aluno das 21h40 às 22h40 de depois de amanhã
- **WHEN** um professor busca "BIB-01" das 22h00 às 22h50
- **THEN** "BIB-01" aparece fora das regras, ocupado e não deslocável, com 0 reservas a deslocar e sem a possibilidade de entrar na fila

#### Scenario: Espaço livre não tem o que deslocar
- **WHEN** um espaço aparece livre no intervalo pedido
- **THEN** ele aparece não deslocável, com 0 reservas a deslocar e sem a possibilidade de entrar na fila

#### Scenario: Vaga retida ocupa o espaço
- **GIVEN** a vaga de "LAB-01" das 14h00 às 15h00 de depois de amanhã está retida para uma aluna, no prazo
- **WHEN** um professor busca "LAB-01" para esse intervalo
- **THEN** "LAB-01" aparece ocupado, não deslocável e com a possibilidade de entrar na fila, sem indicação de quem retém a vaga

#### Scenario: Vaga retida vencida não ocupa
- **GIVEN** o prazo da vaga retida em "BIB-01" das 14h00 às 15h00 venceu e não há outra ocupação no intervalo
- **WHEN** alguém busca "BIB-01" para esse intervalo
- **THEN** "BIB-01" aparece livre

#### Scenario: Fila depois do fechamento
- **GIVEN** o corte da fila é de 120 minutos, o tempo mínimo útil é de 30 minutos e "BIB-01" tem uma reserva de professor que começa daqui a 140 minutos
- **WHEN** uma aluna busca "BIB-01" para esse intervalo
- **THEN** "BIB-01" aparece ocupado e sem a possibilidade de entrar na fila

#### Scenario: Já na fila
- **GIVEN** Ana aguarda na fila de "BIB-01" das 14h00 às 15h00 de depois de amanhã
- **WHEN** Ana busca "BIB-01" para esse intervalo
- **THEN** "BIB-01" aparece ocupado, com a indicação de que ela já está na fila, e sem a possibilidade de entrar de novo

#### Scenario: Restrito com horário pedido
- **GIVEN** "AUD-01" tem uma reserva de professor das 14h00 às 15h00 de depois de amanhã
- **WHEN** um aluno busca para esse intervalo
- **THEN** "AUD-01" aparece restrito, sem indicação de regras, de ocupação, de deslocamento nem de fila

### Requirement: Opções dos filtros
O sistema DEVE (MUST) oferecer a todo usuário com conta ativa as opções dos filtros da busca:
- os tipos ativos com regras completas, com id, nome e se o papel dele pode reservá-los; para os que ele pode reservar, também se exigem aprovação para ele e as regras de horário e duração;
- o catálogo de recursos (id e nome).

As unidades vêm da listagem pública de unidades ativas. As listagens de gestão de tipos e de recursos continuam restritas a gestores.

#### Scenario: Opções do aluno
- **WHEN** um aluno consulta as opções da busca
- **THEN** recebe "Biblioteca" e "Laboratório" como reserváveis por ele, com a indicação de que "Laboratório" exige aprovação, "Sala de aula" e "Auditório" como não reserváveis por ele, e o catálogo de recursos

#### Scenario: Gestão continua restrita
- **WHEN** um aluno chama a listagem de gestão de tipos ou de recursos
- **THEN** o sistema responde com acesso negado

### Requirement: Tela de busca
O frontend DEVE (MUST) oferecer a todos os usuários o feed de espaços na página "Início": um campo de busca por texto, os filtros, um botão para buscar e os espaços em cartões. Ao abrir a Início, o feed mostra todos os espaços, sem filtros; depois, a busca só é enviada ao clicar no botão ou ao confirmar o texto com Enter. O endereço antigo da busca DEVE levar para a Início. Cada cartão não restrito mostra a foto de capa ou, sem foto, uma faixa com a cor e o ícone do tipo; o nome, o código, a unidade, o tipo, a capacidade, a localização, os recursos e a média com a quantidade de avaliações, ou "Sem avaliações"; e abre a página do espaço (capability `pagina-espaco`). Com data e horário informados, cada cartão não restrito mostra "dentro das regras do tipo" ou os motivos de estar fora delas e se o espaço está livre ou ocupado; os espaços livres e dentro das regras oferecem "Reservar", os ocupados, deslocáveis e dentro das regras oferecem "Deslocar e reservar", e os que permitem entrar na fila oferecem "Entrar na fila". O espaço em cuja fila o usuário já está mostra essa indicação. "Reservar" abre uma confirmação com o espaço, a unidade, a data, o horário e se a reserva exigirá aprovação. "Deslocar e reservar" abre a mesma confirmação, com o aviso de quantas reservas de prioridade menor serão canceladas. Se a criação pedir a confirmação do deslocamento de um espaço que parecia livre, a confirmação passa a mostrar esse aviso e pede uma nova confirmação. "Entrar na fila" abre uma confirmação com o espaço, a unidade, a data, o horário e o aviso de que a vaga liberada aparece no sistema e precisa ser confirmada dentro do prazo da fila. Depois de confirmar, a página mostra o resultado (reserva confirmada, aguardando aprovação ou entrada na fila) ou a recusa dentro da confirmação, e atualiza o feed. A página DEVE avisar que a disponibilidade é conferida de novo no momento da reserva.

#### Scenario: Feed ao abrir a Início
- **WHEN** um aluno abre a Início
- **THEN** a página mostra os cartões de todos os espaços, com os de "Sala de aula" e "Auditório" restritos

#### Scenario: Endereço antigo da busca
- **WHEN** alguém abre o endereço antigo da página "Buscar espaços"
- **THEN** é levado para a Início

#### Scenario: Buscar pela tela
- **WHEN** um aluno escolhe "Biblioteca", informa uma data e um horário e clica em buscar
- **THEN** a página mostra os espaços de "Biblioteca" com o código, a unidade, se o horário está dentro das regras e se o espaço está livre
- **AND** mostra o aviso de que a disponibilidade é conferida de novo na reserva

#### Scenario: Buscar por texto pela tela
- **WHEN** um aluno digita "ipe" no campo de busca e tecla Enter
- **THEN** o feed mostra só os espaços que têm "ipê" em algum dos campos procurados

#### Scenario: Cartão abre a página do espaço
- **WHEN** um aluno escolhe o cartão de "BIB-01"
- **THEN** a página do espaço "BIB-01" é aberta

#### Scenario: Reservar pela busca
- **GIVEN** "BIB-01" aparece livre e dentro das regras para o horário pedido
- **WHEN** Ana escolhe "Reservar" em "BIB-01" e confirma
- **THEN** a página informa que a reserva foi confirmada
- **AND** ao atualizar o resultado, "BIB-01" aparece ocupado

#### Scenario: Recusa na confirmação
- **GIVEN** outra pessoa reservou "BIB-01" no mesmo horário depois da busca de Ana
- **WHEN** Ana confirma a reserva de "BIB-01"
- **THEN** a confirmação mostra a recusa de horário ocupado, sem fechar

#### Scenario: Espaço ocupado sem botão
- **WHEN** um resultado aparece ocupado, não deslocável e sem a possibilidade de entrar na fila, ou fora das regras
- **THEN** a página não oferece "Reservar", "Deslocar e reservar" nem "Entrar na fila" para ele

#### Scenario: Deslocar pela busca
- **GIVEN** "LAB-01" aparece ocupado e deslocável, com 1 reserva a deslocar, para o professor Carlos
- **WHEN** Carlos escolhe "Deslocar e reservar" em "LAB-01"
- **THEN** a confirmação avisa que 1 reserva de prioridade menor será cancelada
- **AND** ao confirmar, a página informa que a reserva foi confirmada e que 1 reserva foi deslocada, e o resultado é atualizado

#### Scenario: Ocupado depois da busca e deslocável
- **GIVEN** "LAB-01" apareceu livre para Carlos, e um aluno o reservou em seguida
- **WHEN** Carlos confirma "Reservar" em "LAB-01"
- **THEN** a confirmação continua aberta, avisa que 1 reserva de prioridade menor será cancelada e pede nova confirmação
- **AND** nada é gravado até Carlos confirmar de novo

#### Scenario: Entrar na fila pela busca
- **GIVEN** "BIB-01" aparece ocupado, não deslocável e com a possibilidade de entrar na fila para Ana
- **WHEN** Ana escolhe "Entrar na fila" em "BIB-01" e confirma
- **THEN** a página informa que ela entrou na fila e, ao atualizar o resultado, "BIB-01" mostra que ela já está na fila

#### Scenario: Espaço liberado antes de entrar na fila
- **GIVEN** "BIB-01" apareceu ocupado para Ana, e a reserva foi cancelada em seguida, sem ninguém na fila desse intervalo
- **WHEN** Ana confirma "Entrar na fila" em "BIB-01"
- **THEN** a confirmação mostra a recusa de que o horário está livre, sem fechar

#### Scenario: Nenhum resultado
- **WHEN** a busca não encontra espaços
- **THEN** a página informa que nenhum espaço atende aos filtros

### Requirement: Espaço bloqueado na busca
Quando data e horário são informados, cada espaço **não restrito** do resultado DEVE (MUST) indicar se está bloqueado: há bloqueio `ATIVO` sobreposto ao intervalo pedido (capability `bloqueios`). O espaço bloqueado aparece ocupado e "Bloqueado", não deslocável, com 0 reservas a deslocar e sem a possibilidade de entrar na fila, e a tela não oferece "Reservar", "Deslocar e reservar" nem "Entrar na fila" para ele. A busca NÃO DEVE (MUST NOT) mostrar o motivo nem quem criou o bloqueio.

#### Scenario: Espaço bloqueado no horário pedido
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO` de 10/12 a 12/12, e "LAB-02" está livre
- **WHEN** um professor busca "Laboratório" em 11/12 das 10h00 às 11h00
- **THEN** "LAB-01" aparece "Bloqueado", não deslocável e sem fila, sem o motivo
- **AND** "LAB-02" aparece livre

#### Scenario: Intervalo encostado ao bloqueio
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO` até 12/12 às 18h00 e nenhuma reserva depois disso
- **WHEN** um professor busca "LAB-01" em 12/12 das 18h00 às 19h00
- **THEN** "LAB-01" aparece livre, sem indicação de bloqueio

#### Scenario: Busca sem horário
- **GIVEN** "LAB-01" tem um bloqueio `ATIVO`
- **WHEN** alguém busca sem informar data e horário
- **THEN** "LAB-01" aparece sem indicação de bloqueio, como os demais espaços sem horário pedido

#### Scenario: Tela mostra o bloqueio
- **WHEN** a busca pela tela devolve "LAB-01" bloqueado no horário pedido
- **THEN** a página mostra "Bloqueado" em "LAB-01" e não oferece nenhuma ação para ele

#### Scenario: Restrito bloqueado
- **GIVEN** "AUD-01" tem um bloqueio `ATIVO` no intervalo pedido
- **WHEN** um aluno busca para esse intervalo
- **THEN** "AUD-01" aparece só restrito, sem indicação de bloqueio

## ADDED Requirements

### Requirement: Espaço restrito ao papel
O espaço de tipo que o papel de quem busca não pode reservar DEVE (MUST) vir marcado como restrito, com um aviso que lista os papéis que podem reservar o tipo. Ele NÃO DEVE (MUST NOT) trazer descrição, recursos, aprovação, média, avaliações nem indicações de horário. Na tela, o cartão restrito mostra a foto ou a faixa, nome, código, unidade, tipo, capacidade e localização, acinzentado, com cadeado e "Restrito" (diferente de "Bloqueado"), sem abrir a página e sem ações.

#### Scenario: Aviso com os papéis que podem reservar
- **GIVEN** "Auditório" só pode ser reservado por professores, além de coordenadores e admins
- **WHEN** um aluno busca "Auditório"
- **THEN** "AUD-01" vem restrito, com o aviso de que é reservável por professores, coordenadores e administradores

#### Scenario: Tipo só da gestão
- **GIVEN** "Sala de reunião" não pode ser reservado por aluno nem por professor
- **WHEN** um professor busca espaços
- **THEN** os espaços de "Sala de reunião" vêm restritos, com o aviso de que são reserváveis por coordenadores e administradores

#### Scenario: Cartão restrito na tela
- **WHEN** um aluno vê o cartão restrito de "AUD-01" no feed
- **THEN** o cartão aparece acinzentado, com a foto ou a faixa, os dados básicos, cadeado, "Restrito" e o aviso, sem média, sem ações e sem abrir a página do espaço

#### Scenario: Texto na descrição de um restrito
- **GIVEN** a descrição de "AUD-01", restrito para o aluno, menciona "palco", e o nome não
- **WHEN** um aluno busca o texto "palco"
- **THEN** "AUD-01" não aparece
