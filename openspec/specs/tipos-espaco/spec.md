# Especificação: Tipos de espaço

## Purpose
Representar as categorias de espaço da instituição (sala de aula, laboratório, biblioteca, auditório e outras criadas pelo admin). Nesta etapa, a capability cobre a carga inicial e a manutenção dos tipos. As regras de uso de cada tipo e a regra por papel são acrescentadas por uma change posterior.

## Requirements

### Requirement: Carga inicial de tipos de espaço
O sistema DEVE (MUST) ser implantado com os tipos ativos "Sala de aula", "Laboratório", "Biblioteca" e "Auditório", sem exigir cadastro pela interface. A carga DEVE criar os tipos somente quando ainda não existir nenhum tipo de espaço. Ela não gera registro de auditoria.

#### Scenario: Tipos disponíveis após a implantação
- **WHEN** o backend é implantado pela primeira vez no ambiente
- **THEN** existem os quatro tipos iniciais, ativos

#### Scenario: Carga repetida
- **GIVEN** a carga inicial já foi aplicada
- **WHEN** a carga é aplicada novamente
- **THEN** nenhum tipo é criado nem alterado

#### Scenario: Tipo inicial renomeado
- **GIVEN** o admin renomeou "Biblioteca" para "Biblioteca central"
- **WHEN** a carga inicial é aplicada novamente
- **THEN** nenhum tipo "Biblioteca" é recriado

### Requirement: Criação e edição de tipo de espaço
Qualquer admin DEVE (MUST) poder criar um tipo de espaço e corrigir o nome e a descrição de um tipo existente. O nome é obrigatório e DEVE ser único, sem diferenciar maiúsculas e minúsculas e ignorando espaços nas pontas; na edição, a unicidade desconsidera o próprio tipo. A descrição é opcional. O tipo nasce ativo. Coordenadores, professores e alunos NÃO DEVEM (MUST NOT) criar nem editar tipos.

#### Scenario: Criar tipo
- **WHEN** o admin cria o tipo "Estúdio de gravação"
- **THEN** o tipo é criado, ativo

#### Scenario: Nome repetido
- **GIVEN** existe o tipo "Laboratório"
- **WHEN** o admin tenta criar " laboratório "
- **THEN** o sistema recusa informando que já existe um tipo com esse nome e nada é criado

#### Scenario: Nome vazio
- **WHEN** o admin tenta criar um tipo com o nome vazio ou só com espaços
- **THEN** o sistema recusa informando que o nome é obrigatório

#### Scenario: Renomear para nome existente
- **GIVEN** existem os tipos "Biblioteca" e "Laboratório"
- **WHEN** o admin tenta renomear "Biblioteca" para "laboratório"
- **THEN** o sistema recusa informando que o nome já existe e nada muda

#### Scenario: Corrigir descrição
- **WHEN** o admin altera a descrição de "Auditório"
- **THEN** o tipo passa a ter a nova descrição e mantém id, nome, situação e espaços

#### Scenario: Coordenador tenta criar
- **WHEN** um coordenador tenta criar um tipo de espaço
- **THEN** o sistema responde com acesso negado e nada é criado

### Requirement: Desativação e reativação de tipo de espaço
Qualquer admin DEVE (MUST) poder desativar um tipo ativo e reativar um tipo desativado. Tipos NÃO DEVEM (MUST NOT) ser excluídos. A desativação NÃO DEVE alterar os espaços do tipo: eles continuam com a própria situação, mas deixam de ser reserváveis enquanto o tipo estiver desativado (capability `espacos`). Um tipo desativado não pode ser escolhido para espaços novos nem para a troca de tipo de um espaço. Desativar um tipo já desativado, ou reativar um ativo, DEVE ser recusado sem gerar auditoria.

#### Scenario: Desativar tipo com espaços
- **GIVEN** o tipo "Auditório" tem 3 espaços ativos em 2 unidades
- **WHEN** o admin desativa "Auditório"
- **THEN** o tipo fica desativado e os 3 espaços continuam ativos, mas não reserváveis

#### Scenario: Reativar tipo
- **GIVEN** "Auditório" está desativado e tem espaços ativos
- **WHEN** o admin reativa "Auditório"
- **THEN** o tipo volta a ser ativo e os espaços ativos dele, em unidades ativas, voltam a ser reserváveis

#### Scenario: Desativar tipo já desativado
- **GIVEN** "Auditório" está desativado
- **WHEN** o admin tenta desativá-lo
- **THEN** o sistema recusa informando que o tipo já está desativado

#### Scenario: Coordenador tenta desativar
- **WHEN** um coordenador tenta desativar um tipo de espaço
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Listagem de tipos de espaço
O sistema DEVE (MUST) devolver a admins e coordenadores todos os tipos de espaço, ativos e desativados, ordenados por nome, com id, nome, descrição, situação e se o tipo tem regras completas (capability `regras-tipo`). Para o admin, cada tipo DEVE trazer também quantos espaços ativos ele tem e em quantas unidades, e as regras atuais do tipo (regras de uso e regra por papel de aluno e professor), vazias quando ainda não definidas. Alunos e professores DEVEM receber acesso negado.

#### Scenario: Admin lista
- **WHEN** o admin lista os tipos de espaço
- **THEN** recebe todos os tipos, ativos e desativados, com a contagem de espaços ativos e de unidades, a indicação de regras completas e as regras atuais

#### Scenario: Coordenador lista
- **WHEN** um coordenador lista os tipos de espaço
- **THEN** recebe todos os tipos, com id, nome, descrição, situação e a indicação de regras completas

#### Scenario: Tipo sem regras na listagem
- **GIVEN** "Refeitório" ainda não tem regras
- **WHEN** o admin lista os tipos de espaço
- **THEN** "Refeitório" aparece sem regras completas e com as regras vazias

#### Scenario: Professor tenta listar
- **WHEN** um professor tenta listar os tipos de espaço
- **THEN** o sistema responde com acesso negado

### Requirement: Tela de tipos de espaço
O frontend DEVE (MUST) oferecer ao admin uma página "Tipos de espaço" para listar, criar, editar, desativar e reativar tipos e para abrir as regras de cada tipo (capability `regras-tipo`). Antes de confirmar a desativação, a página DEVE avisar quantos espaços ativos, e de quantas unidades, deixarão de ser reserváveis. Os tipos desativados DEVEM ser destacados, e os tipos sem regras completas DEVEM ser destacados como "sem regras".

#### Scenario: Aviso na desativação
- **GIVEN** "Auditório" tem 3 espaços ativos em 2 unidades
- **WHEN** o admin inicia a desativação de "Auditório"
- **THEN** a página avisa que 3 espaços de 2 unidades deixarão de ser reserváveis e pede confirmação

#### Scenario: Destaque de tipo sem regras
- **GIVEN** "Refeitório" ainda não tem regras
- **WHEN** o admin abre a página "Tipos de espaço"
- **THEN** "Refeitório" aparece destacado como "sem regras", com acesso às regras do tipo
