## MODIFIED Requirements

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
