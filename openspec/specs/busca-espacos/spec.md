# Especificação: Busca de espaços

## Purpose
Permitir que qualquer usuário autenticado encontre espaços que pode reservar, filtrando por unidade, tipo, capacidade, recursos e, opcionalmente, data e horário. A busca mostra se o horário pedido está dentro das regras do tipo; a ocupação do espaço é tratada pela change de reserva.

## Requirements

### Requirement: Quem busca e o que aparece
Todo usuário com conta ativa DEVE (MUST) poder buscar espaços. A busca DEVE mostrar espaços de **todas as unidades**, para qualquer papel, inclusive coordenadores. Só DEVEM aparecer espaços:
- reserváveis (espaço, unidade e tipo ativos e tipo com regras completas, capability `espacos`);
- de tipos que o papel de quem busca pode reservar (regra por papel; coordenador e admin podem todos).

Espaços desativados, de unidade ou tipo desativados, de tipo sem regras ou de tipo que o papel não pode reservar NÃO DEVEM (MUST NOT) aparecer.

#### Scenario: Aluno busca
- **GIVEN** existem espaços ativos de "Biblioteca", "Laboratório", "Sala de aula" e "Auditório" em "Paulista" e "Vila Olímpia"
- **WHEN** um aluno busca sem filtros
- **THEN** recebe os espaços de "Biblioteca" e "Laboratório" das duas unidades, e nenhum de "Sala de aula" ou "Auditório"

#### Scenario: Professor busca
- **WHEN** um professor busca sem filtros
- **THEN** recebe os espaços dos quatro tipos iniciais das duas unidades

#### Scenario: Coordenador busca em outras unidades
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui busca espaços
- **THEN** recebe também os espaços de "Vila Olímpia"

#### Scenario: Espaço não reservável fica de fora
- **GIVEN** "Refeitório 1" está ativo, mas o tipo "Refeitório" não tem regras
- **WHEN** o admin busca espaços
- **THEN** "Refeitório 1" não aparece

#### Scenario: Sem autenticação
- **WHEN** a busca é chamada sem token ou com conta inativa
- **THEN** o sistema responde com não autenticado

### Requirement: Filtros da busca
A busca DEVE (MUST) aceitar estes filtros, todos opcionais e combinados entre si:
- unidade;
- tipo de espaço;
- capacidade mínima (capacidade do espaço maior ou igual ao valor);
- recursos (o espaço precisa ter **todos** os recursos escolhidos);
- data, hora de início e hora de fim, informados juntos.

Filtrar por um tipo que o papel não pode reservar DEVE devolver lista vazia, sem erro. Data e horário incompletos, inválidos ou com fim antes do início DEVEM ser recusados.

#### Scenario: Capacidade e recursos
- **GIVEN** "LAB-01" tem capacidade 30, 30 "Computadores" e 1 "Projetor", e "LAB-02" tem capacidade 20 e só "Computadores"
- **WHEN** um professor busca capacidade mínima 25 com os recursos "Computadores" e "Projetor"
- **THEN** recebe só "LAB-01"

#### Scenario: Tipo que o papel não pode reservar
- **WHEN** um aluno filtra pelo tipo "Auditório"
- **THEN** recebe uma lista vazia

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
Cada espaço encontrado DEVE (MUST) trazer: id, nome, código, unidade (id e nome), tipo (id e nome), capacidade, localização, descrição, recursos (nome e quantidade) e se a reserva exigiria aprovação para o papel de quem busca. Os resultados DEVEM vir ordenados pelo nome da unidade e pelo código, sem paginação.

#### Scenario: Aprovação conforme o papel
- **GIVEN** "Laboratório" exige aprovação para o aluno e não para o professor
- **WHEN** um aluno e um professor buscam "LAB-01"
- **THEN** o resultado do aluno indica que a reserva exigiria aprovação e o do professor indica que não

#### Scenario: Códigos iguais em unidades diferentes
- **GIVEN** "Paulista" e "Vila Olímpia" têm, cada uma, um espaço de código "101"
- **WHEN** alguém busca espaços
- **THEN** os dois aparecem, cada um com o nome da própria unidade

### Requirement: Horário pedido na busca
Quando data e horário são informados, cada espaço do resultado DEVE (MUST) indicar se o pedido está **dentro das regras do tipo** (capability `regras-tipo`) e, quando não está, os motivos. Espaços fora das regras continuam no resultado, com os motivos. A busca NÃO DEVE (MUST NOT) indicar que o espaço está livre ou disponível, porque não verifica reservas nem bloqueios.

#### Scenario: Dentro e fora das regras
- **GIVEN** "Biblioteca" aceita até 180 minutos e "Laboratório" até 240 minutos
- **WHEN** um professor busca para uma quarta-feira das 09h00 às 12h20 (200 minutos)
- **THEN** os espaços de "Laboratório" aparecem dentro das regras
- **AND** os de "Biblioteca" aparecem fora das regras, com o motivo de duração acima da máxima

#### Scenario: Sem data e horário
- **WHEN** alguém busca sem informar data e horário
- **THEN** os espaços aparecem sem indicação de regras de horário

### Requirement: Opções dos filtros
O sistema DEVE (MUST) oferecer a todo usuário com conta ativa as opções dos filtros da busca:
- os tipos ativos, com regras completas, que o papel dele pode reservar, com id, nome, se exigem aprovação para ele e as regras de horário e duração;
- o catálogo de recursos (id e nome).

As unidades vêm da listagem pública de unidades ativas. As listagens de gestão de tipos e de recursos continuam restritas a gestores.

#### Scenario: Opções do aluno
- **WHEN** um aluno consulta as opções da busca
- **THEN** recebe os tipos "Biblioteca" e "Laboratório", com a indicação de que "Laboratório" exige aprovação, e o catálogo de recursos

#### Scenario: Gestão continua restrita
- **WHEN** um aluno chama a listagem de gestão de tipos ou de recursos
- **THEN** o sistema responde com acesso negado

### Requirement: Tela de busca
O frontend DEVE (MUST) oferecer a todos os usuários uma página "Buscar espaços", com os filtros, um botão para buscar e a lista de resultados. A busca só é enviada ao clicar no botão. Com data e horário informados, cada resultado mostra "dentro das regras do tipo" ou os motivos de estar fora delas; a página DEVE avisar que a busca não verifica se o horário já está ocupado.

#### Scenario: Buscar pela tela
- **WHEN** um aluno escolhe "Biblioteca", informa uma data e um horário e clica em buscar
- **THEN** a página mostra os espaços de "Biblioteca" com o código, a unidade e se o horário está dentro das regras
- **AND** mostra o aviso de que a ocupação será verificada na reserva

#### Scenario: Nenhum resultado
- **WHEN** a busca não encontra espaços
- **THEN** a página informa que nenhum espaço atende aos filtros
