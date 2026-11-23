## Purpose

Mostrar a qualquer usuário que pode reservar um espaço tudo o que se sabe sobre ele num só lugar: dados, recursos, foto de capa, média e avaliações.

## ADDED Requirements

### Requirement: Quem abre a página do espaço
Todo usuário com conta ativa DEVE (MUST) poder consultar o detalhe de um espaço reservável (capability `espacos`) de tipo que o papel dele pode reservar; coordenador e admin podem todos os tipos. Espaço inexistente, não reservável ou restrito ao papel de quem pede DEVE ser recusado com a mesma mensagem de espaço não encontrado.

#### Scenario: Aluno abre um laboratório
- **GIVEN** o aluno pode reservar "Laboratório" e "LAB-01" está ativo
- **WHEN** um aluno consulta o detalhe de "LAB-01"
- **THEN** recebe os dados de "LAB-01"

#### Scenario: Espaço restrito ao papel
- **GIVEN** o aluno não pode reservar "Auditório"
- **WHEN** um aluno consulta o detalhe de "AUD-01" pelo endereço
- **THEN** o sistema recusa com a mensagem de espaço não encontrado

#### Scenario: Espaço desativado
- **WHEN** alguém consulta o detalhe de um espaço desativado ou de unidade desativada
- **THEN** o sistema recusa com a mensagem de espaço não encontrado

#### Scenario: Sem autenticação
- **WHEN** o detalhe é pedido sem token ou com conta inativa
- **THEN** o sistema responde com não autenticado

#### Scenario: Senha provisória
- **GIVEN** Lia está com senha provisória
- **WHEN** Lia pede o detalhe de um espaço
- **THEN** o sistema recusa com "Troque sua senha para continuar." (capability `senha`)

### Requirement: Conteúdo da página do espaço
O detalhe DEVE (MUST) trazer: id, nome, código, unidade (id e nome), tipo (id e nome), capacidade, localização, descrição, recursos (nome e quantidade), se a reserva exigiria aprovação para o papel de quem pede, a URL da foto de capa quando houver (capability `espacos`) e as avaliações do espaço com a média e a quantidade (capability `avaliacoes`). O detalhe NÃO DEVE (MUST NOT) mostrar reservas, ocupação nem bloqueios.

#### Scenario: Detalhe completo
- **GIVEN** "BIB-01" tem foto de capa, 4 "Tomadas" e duas avaliações
- **WHEN** um aluno consulta o detalhe de "BIB-01"
- **THEN** recebe os dados, os recursos, a URL da foto, a média, a quantidade 2 e as duas avaliações

#### Scenario: Espaço sem foto
- **WHEN** alguém consulta o detalhe de um espaço sem foto de capa
- **THEN** o detalhe vem sem URL de foto

### Requirement: Tela da página do espaço
O frontend DEVE (MUST) oferecer uma página para cada espaço, aberta pelo cartão do feed. A página mostra a foto de capa ou, sem foto, a faixa colorida com o ícone do tipo; o nome, o código, a unidade, o tipo, a capacidade, a localização, a descrição e os recursos; um destaque com a média e a quantidade de avaliações; e a lista de avaliações com estrelas, comentário, data e autor. Quando o detalhe é recusado, a página informa que o espaço não foi encontrado e oferece a volta para a Início.

#### Scenario: Abrir pelo feed
- **WHEN** um aluno escolhe o cartão de "BIB-01" no feed
- **THEN** a página de "BIB-01" mostra os dados, a média e as avaliações

#### Scenario: Espaço sem avaliações na tela
- **WHEN** a página de um espaço sem avaliações é aberta
- **THEN** a página informa que o espaço ainda não tem avaliações

#### Scenario: Endereço de espaço restrito
- **WHEN** um aluno digita o endereço da página de "AUD-01"
- **THEN** a página informa que o espaço não foi encontrado e oferece a volta para a Início
