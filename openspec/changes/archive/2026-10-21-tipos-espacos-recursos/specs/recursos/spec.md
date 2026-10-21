## Purpose

Manter o catálogo global de recursos que os espaços podem ter (projetor, computadores, ar-condicionado, quadro digital e outros). O catálogo é mantido pelo admin; a associação de recursos a cada espaço, com quantidade, fica na capability `espacos`.

## ADDED Requirements

### Requirement: Manutenção do catálogo de recursos
Somente o admin (qualquer admin) DEVE (MUST) poder criar e renomear recursos do catálogo. O nome é obrigatório e DEVE ser único, sem diferenciar maiúsculas e minúsculas e ignorando espaços nas pontas; no renome, a unicidade desconsidera o próprio recurso. Renomear um recurso vale para todos os espaços que o têm. Coordenadores, professores e alunos NÃO DEVEM (MUST NOT) criar nem renomear recursos.

#### Scenario: Criar recurso
- **WHEN** o admin cria o recurso "Projetor"
- **THEN** o recurso passa a constar do catálogo

#### Scenario: Nome repetido
- **GIVEN** existe o recurso "Projetor"
- **WHEN** o admin tenta criar " projetor "
- **THEN** o sistema recusa informando que já existe um recurso com esse nome

#### Scenario: Nome vazio
- **WHEN** o admin tenta criar um recurso com o nome vazio ou só com espaços
- **THEN** o sistema recusa informando que o nome é obrigatório

#### Scenario: Renomear para nome existente
- **GIVEN** existem os recursos "Datashow" e "Projetor"
- **WHEN** o admin tenta renomear "Datashow" para "PROJETOR"
- **THEN** o sistema recusa informando que o nome já existe e nada muda

#### Scenario: Renomear recurso em uso
- **GIVEN** "Datashow" está associado a espaços de "Paulista" e "Centro"
- **WHEN** o admin renomeia "Datashow" para "Projetor"
- **THEN** os espaços das duas unidades passam a mostrar "Projetor", com as mesmas quantidades

#### Scenario: Coordenador tenta criar
- **WHEN** um coordenador tenta criar um recurso no catálogo
- **THEN** o sistema responde com acesso negado e nada é criado

### Requirement: Exclusão de recurso sem uso
Somente o admin DEVE (MUST) poder excluir um recurso do catálogo, e só quando nenhum espaço, ativo ou desativado, o tiver. Se algum espaço usar o recurso, a exclusão DEVE ser recusada informando quantos espaços o usam, e nada muda. A exclusão e uma associação simultânea do mesmo recurso a um espaço NÃO DEVEM (MUST NOT) resultar em espaço apontando para recurso inexistente.

#### Scenario: Excluir recurso sem uso
- **GIVEN** nenhum espaço tem o recurso "Lousa digital"
- **WHEN** o admin exclui "Lousa digital"
- **THEN** o recurso deixa de constar do catálogo

#### Scenario: Excluir recurso em uso
- **GIVEN** o espaço desativado "Lab 3" tem o recurso "Projetor"
- **WHEN** o admin tenta excluir "Projetor"
- **THEN** o sistema recusa informando que 1 espaço usa o recurso e nada muda

#### Scenario: Exclusão concorrente com associação
- **GIVEN** nenhum espaço tem o recurso "Lousa digital"
- **WHEN** o admin exclui "Lousa digital" ao mesmo tempo em que um coordenador o associa a um espaço
- **THEN** ou o recurso é excluído e a associação é recusada, ou a associação é gravada e a exclusão é recusada

#### Scenario: Coordenador tenta excluir
- **WHEN** um coordenador tenta excluir um recurso
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Listagem do catálogo de recursos
O sistema DEVE (MUST) devolver a admins e coordenadores o catálogo de recursos ordenado por nome, com id e nome. Para o admin, cada recurso DEVE trazer também quantos espaços o usam. Alunos e professores DEVEM receber acesso negado.

#### Scenario: Coordenador lista
- **WHEN** um coordenador lista o catálogo de recursos
- **THEN** recebe todos os recursos, com id e nome

#### Scenario: Aluno tenta listar
- **WHEN** um aluno tenta listar o catálogo de recursos
- **THEN** o sistema responde com acesso negado

### Requirement: Tela de recursos
O frontend DEVE (MUST) oferecer ao admin uma página "Recursos" para listar, criar, renomear e excluir recursos. A ação de excluir DEVE ficar disponível só para recursos sem uso; para os demais, a página mostra quantos espaços usam o recurso.

#### Scenario: Recurso em uso na tela
- **GIVEN** "Projetor" é usado por 5 espaços
- **WHEN** o admin abre a página "Recursos"
- **THEN** a linha de "Projetor" mostra 5 espaços e não oferece a exclusão
