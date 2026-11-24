# Especificação: Espaços

## Purpose
Cadastrar os espaços físicos reserváveis de cada unidade, com tipo, capacidade e recursos, sob a autorização por papel e por unidade. Também define quando um espaço está disponível para reserva, regra que a busca e a reserva das próximas changes usam.

## Requirements

### Requirement: Criação de espaço
Admins (em qualquer unidade) e coordenadores (só nas unidades que coordenam) DEVEM (MUST) poder criar espaços. Na criação são informados:
- unidade, obrigatória e ativa;
- tipo de espaço, obrigatório e ativo;
- nome, obrigatório;
- código, obrigatório e único **dentro da unidade**, sem diferenciar maiúsculas e minúsculas e ignorando espaços nas pontas;
- capacidade, número inteiro maior ou igual a 1;
- localização e descrição, opcionais.

O espaço nasce ativo e sem recursos. Alunos e professores NÃO DEVEM (MUST NOT) criar espaços. Se qualquer regra falhar, nada é criado.

#### Scenario: Coordenador cria na própria unidade
- **GIVEN** Rui coordena "Paulista"
- **WHEN** Rui cria o espaço "Laboratório de Redes", código "LAB-01", tipo "Laboratório", capacidade 30, em "Paulista"
- **THEN** o espaço é criado, ativo, em "Paulista"

#### Scenario: Coordenador em outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta criar um espaço em "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e nada é criado

#### Scenario: Professor tenta criar
- **WHEN** um professor tenta criar um espaço
- **THEN** o sistema responde com acesso negado

#### Scenario: Mesmo código em outra unidade
- **GIVEN** "Paulista" tem o espaço de código "101"
- **WHEN** o admin cria em "Vila Olímpia" um espaço de código "101"
- **THEN** o espaço é criado

#### Scenario: Código repetido na mesma unidade
- **GIVEN** "Paulista" tem o espaço desativado de código "LAB-01"
- **WHEN** o admin tenta criar em "Paulista" um espaço de código " lab-01 "
- **THEN** o sistema recusa informando que a unidade já tem um espaço com esse código

#### Scenario: Unidade desativada
- **GIVEN** "Centro" está desativada
- **WHEN** o admin tenta criar um espaço em "Centro"
- **THEN** o sistema recusa informando que a unidade está desativada

#### Scenario: Tipo desativado
- **GIVEN** o tipo "Auditório" está desativado
- **WHEN** o admin tenta criar um espaço do tipo "Auditório"
- **THEN** o sistema recusa informando que o tipo está desativado

#### Scenario: Capacidade inválida
- **WHEN** alguém tenta criar um espaço com capacidade 0
- **THEN** o sistema recusa informando que a capacidade deve ser de pelo menos 1

#### Scenario: Criações simultâneas com o mesmo código
- **WHEN** dois gestores criam ao mesmo tempo, em "Paulista", espaços de código "101"
- **THEN** só um espaço é criado e o outro gestor recebe a recusa de código repetido

### Requirement: Edição de espaço
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder alterar nome, código, tipo, capacidade, localização e descrição, com as mesmas validações da criação. A unicidade do código desconsidera o próprio espaço. A exigência de tipo ativo vale **somente** quando o tipo muda: um espaço cujo tipo atual está desativado pode ter os outros campos editados. A edição NÃO DEVE (MUST NOT) mudar a unidade nem a situação do espaço. Como a desativação de uma unidade remove as coordenações dela, só o admin edita espaços de unidade desativada. Trocar o tipo DEVE ser recusado, sem alterar nenhum campo, enquanto houver reserva confirmada em andamento no espaço; sem ela, a troca DEVE cancelar, na mesma operação, as reservas do espaço que ainda não terminaram (capability `reservas`). Editar sem trocar o tipo não é recusado nem altera reservas.

#### Scenario: Trocar o tipo
- **GIVEN** "Sala 12" de "Paulista" é do tipo "Sala de aula"
- **WHEN** Rui, coordenador de "Paulista", troca o tipo para "Laboratório", que está ativo
- **THEN** "Sala 12" passa a ser do tipo "Laboratório"

#### Scenario: Trocar o tipo com reservas futuras
- **GIVEN** "Sala 12" tem 2 reservas futuras e nenhuma em andamento
- **WHEN** Rui troca o tipo de "Sala 12"
- **THEN** as 2 reservas ficam canceladas com o motivo `ESPACO_INDISPONIVEL`
- **AND** a resposta informa quantas reservas foram canceladas

#### Scenario: Trocar o tipo com reserva em andamento
- **GIVEN** "Sala 12" tem uma reserva confirmada em andamento até 15h00
- **WHEN** Rui tenta trocar o tipo de "Sala 12"
- **THEN** o sistema recusa informando que há reserva em andamento até 15h00 e nada muda

#### Scenario: Trocar para tipo desativado
- **GIVEN** o tipo "Auditório" está desativado
- **WHEN** Rui tenta trocar o tipo de "Sala 12" para "Auditório"
- **THEN** o sistema recusa informando que o tipo está desativado e nada muda

#### Scenario: Editar espaço de tipo desativado
- **GIVEN** "Auditório Principal" é do tipo "Auditório", que está desativado
- **WHEN** o admin altera a capacidade de "Auditório Principal" sem trocar o tipo
- **THEN** a nova capacidade é gravada

#### Scenario: Código repetido na edição
- **GIVEN** "Paulista" tem os espaços de código "LAB-01" e "LAB-02"
- **WHEN** Rui muda o código de "LAB-02" para "lab-01"
- **THEN** o sistema recusa informando que a unidade já tem um espaço com esse código e nada muda

#### Scenario: Coordenador em espaço de outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta editar um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e nada muda

#### Scenario: Espaço inexistente para o coordenador
- **WHEN** Rui, coordenador, tenta editar um id de espaço que não existe
- **THEN** o sistema responde com acesso negado, com a mesma mensagem de um espaço de outra unidade, sem indicar se o espaço existe

#### Scenario: Espaço de unidade desativada
- **GIVEN** "Centro" está desativada e tem o espaço "Sala 1"
- **WHEN** o admin altera o nome de "Sala 1"
- **THEN** o novo nome é gravado

### Requirement: Recursos do espaço
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder definir a lista completa de recursos do espaço, com a quantidade de cada um. Cada recurso DEVE existir no catálogo, aparecer no máximo uma vez e ter quantidade inteira maior ou igual a 1. A lista pode ser vazia. A nova lista substitui a anterior por inteiro; se qualquer item for inválido, nada muda.

#### Scenario: Definir recursos
- **WHEN** Rui define para "Laboratório de Redes" 30 "Computadores" e 1 "Projetor"
- **THEN** o espaço passa a ter exatamente esses recursos e quantidades

#### Scenario: Retirar todos os recursos
- **GIVEN** "Sala 12" tem 1 "Projetor"
- **WHEN** Rui define uma lista vazia para "Sala 12"
- **THEN** "Sala 12" fica sem recursos

#### Scenario: Recurso repetido
- **WHEN** Rui envia "Projetor" duas vezes na lista de recursos de um espaço
- **THEN** o sistema recusa informando o recurso repetido e nada muda

#### Scenario: Quantidade inválida
- **WHEN** Rui envia "Computadores" com quantidade 0
- **THEN** o sistema recusa informando que a quantidade deve ser de pelo menos 1 e nada muda

#### Scenario: Recurso inexistente
- **WHEN** Rui envia um recurso que não existe no catálogo
- **THEN** o sistema recusa e nada muda

#### Scenario: Recursos de espaço de outra unidade
- **GIVEN** Rui coordena apenas "Paulista"
- **WHEN** Rui tenta definir os recursos de um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Desativação e reativação de espaço
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder desativar um espaço ativo e reativar um espaço desativado. Espaços NÃO DEVEM (MUST NOT) ser excluídos. Reativar um espaço de unidade ou de tipo desativado é permitido: o espaço volta a ser ativo, mas continua não reservável até que a unidade e o tipo estejam ativos. Desativar um espaço já desativado, ou reativar um ativo, DEVE ser recusado sem gerar auditoria. A desativação DEVE ser recusada, sem alterar nada, enquanto houver reserva confirmada em andamento no espaço, informando até que horas; sem ela, a desativação DEVE cancelar, na mesma operação, as reservas do espaço que ainda não terminaram e informar quantas foram canceladas (capability `reservas`). Admin e coordenador seguem a mesma regra. A desativação DEVE exigir um motivo da lista de desativação (manutenção ou reforma; problema de infraestrutura; interdição ou risco à segurança; equipamentos ou recursos indisponíveis; mudança de uso; baixa utilização; encerramento das atividades no local; outro), e "Outro" exige descrição de até 500 caracteres; o motivo acompanha as reservas canceladas (capability `reservas`). A reativação não restaura reservas e não pede motivo.

#### Scenario: Desativar espaço
- **WHEN** Rui desativa "Sala 12" de "Paulista" com o motivo "Manutenção ou reforma"
- **THEN** "Sala 12" fica desativado e mantém código, tipo e recursos

#### Scenario: Desativar sem motivo
- **WHEN** Rui tenta desativar "Sala 12" sem escolher o motivo
- **THEN** o sistema recusa pedindo o motivo e nada muda

#### Scenario: Outro sem descrição
- **WHEN** Rui tenta desativar "Sala 12" com o motivo "Outro" e a descrição vazia
- **THEN** o sistema recusa pedindo a descrição do motivo e nada muda

#### Scenario: Motivo fora da lista
- **WHEN** alguém envia, pela API, um código de motivo que não está na lista
- **THEN** o sistema recusa informando que o motivo é inválido e nada muda

#### Scenario: Desativar espaço com reserva em andamento
- **GIVEN** "LAB-01" tem uma reserva confirmada das 13h00 às 14h00 e são 13h58
- **WHEN** Rui tenta desativar "LAB-01"
- **THEN** o sistema recusa informando que há reserva em andamento até 14h00 e "LAB-01" continua ativo

#### Scenario: Desativar espaço com reservas futuras
- **GIVEN** "LAB-01" tem 2 reservas futuras e nenhuma em andamento
- **WHEN** o admin desativa "LAB-01"
- **THEN** "LAB-01" fica desativado e as 2 reservas ficam canceladas com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Reativar espaço de tipo desativado
- **GIVEN** "Auditório Principal" está desativado e o tipo "Auditório" também
- **WHEN** o admin reativa "Auditório Principal"
- **THEN** o espaço fica ativo, mas não reservável, com o motivo "tipo desativado"

#### Scenario: Desativar espaço já desativado
- **GIVEN** "Sala 12" está desativado
- **WHEN** Rui tenta desativá-lo
- **THEN** o sistema recusa informando que o espaço já está desativado

#### Scenario: Professor tenta desativar
- **WHEN** um professor tenta desativar um espaço
- **THEN** o sistema responde com acesso negado e nada muda

#### Scenario: Não há exclusão
- **WHEN** qualquer usuário, inclusive o admin, tenta excluir um espaço pela API
- **THEN** não existe rota que permita a operação e o espaço permanece

### Requirement: Mudança de unidade do espaço
Somente o admin DEVE (MUST) poder mover um espaço para outra unidade. A unidade de destino DEVE existir, estar ativa e ser diferente da atual, e NÃO DEVE (MUST NOT) ter outro espaço com o mesmo código, sem diferenciar maiúsculas e minúsculas. O espaço mantém tipo, situação, recursos e demais dados. Coordenadores NÃO DEVEM mover espaços, nem entre unidades que coordenam. A mudança DEVE ser recusada, sem alterar nada, enquanto houver reserva confirmada em andamento no espaço; sem ela, a mudança DEVE cancelar, na mesma operação, as reservas do espaço que ainda não terminaram (capability `reservas`).

#### Scenario: Admin move espaço
- **WHEN** o admin move "Sala 12" de "Paulista" para "Vila Olímpia"
- **THEN** "Sala 12" passa a pertencer a "Vila Olímpia", com o mesmo tipo, situação e recursos

#### Scenario: Mover espaço com reservas
- **GIVEN** "Sala 12" tem 2 reservas futuras e nenhuma em andamento
- **WHEN** o admin move "Sala 12" para "Vila Olímpia"
- **THEN** as 2 reservas ficam canceladas com o motivo `ESPACO_INDISPONIVEL`

#### Scenario: Mover espaço em uso
- **GIVEN** "Sala 12" tem uma reserva confirmada em andamento até 16h00
- **WHEN** o admin tenta mover "Sala 12" para "Vila Olímpia"
- **THEN** o sistema recusa informando que há reserva em andamento até 16h00 e "Sala 12" continua em "Paulista"

#### Scenario: Código já existe no destino
- **GIVEN** "Vila Olímpia" tem um espaço de código "101"
- **WHEN** o admin tenta mover para "Vila Olímpia" o espaço de código "101" de "Paulista"
- **THEN** o sistema recusa informando que o destino já tem um espaço com esse código e nada muda

#### Scenario: Destino igual à unidade atual
- **WHEN** o admin tenta mover "Sala 12" de "Paulista" para "Paulista"
- **THEN** o sistema recusa informando que o espaço já pertence a essa unidade

#### Scenario: Destino desativado
- **GIVEN** "Centro" está desativada
- **WHEN** o admin tenta mover um espaço para "Centro"
- **THEN** o sistema recusa informando que a unidade de destino está desativada

#### Scenario: Mover espaço de tipo desativado
- **GIVEN** "Auditório Principal" é do tipo desativado "Auditório"
- **WHEN** o admin move o espaço para "Vila Olímpia", que está ativa
- **THEN** o espaço é movido e continua não reservável pelo tipo desativado

#### Scenario: Coordenador tenta mover
- **GIVEN** Rui coordena "Paulista" e "Centro"
- **WHEN** Rui tenta mover um espaço de "Paulista" para "Centro"
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Disponibilidade do espaço para reserva
Um espaço DEVE (MUST) ser considerado reservável somente quando o próprio espaço, a unidade dele e o tipo dele estão ativos e o tipo tem regras completas (capability `regras-tipo`). Espaços não reserváveis NÃO DEVEM (MUST NOT) aparecer na busca nem aceitar novas reservas, regra que as changes de busca e de reserva aplicam. Desativar ou reativar uma unidade ou um tipo, ou definir as regras de um tipo, NÃO DEVE alterar a situação dos espaços; muda apenas se eles são reserváveis.

#### Scenario: Unidade desativada
- **GIVEN** "Sala 12" está ativo e é de "Paulista"
- **WHEN** o admin desativa "Paulista"
- **THEN** "Sala 12" continua ativo, mas deixa de ser reservável, com o motivo "unidade desativada"

#### Scenario: Unidade reativada
- **GIVEN** "Paulista" está desativada e "Sala 12", ativo e de tipo ativo com regras completas, pertence a ela
- **WHEN** o admin reativa "Paulista"
- **THEN** "Sala 12" volta a ser reservável sem nenhuma ação sobre o espaço

#### Scenario: Tipo sem regras
- **GIVEN** "Refeitório 1" está ativo, numa unidade ativa, e o tipo "Refeitório" está ativo, mas sem regras
- **WHEN** a listagem de gestão é consultada
- **THEN** "Refeitório 1" aparece como não reservável, com o motivo "tipo sem regras"

#### Scenario: Vários motivos
- **GIVEN** "Sala 1" está desativado, a unidade dele está desativada e o tipo dele também, sem regras
- **WHEN** a listagem de gestão é consultada
- **THEN** "Sala 1" aparece como não reservável, com os motivos "espaço desativado", "unidade desativada", "tipo desativado" e "tipo sem regras"

### Requirement: Listagem de espaços geridos
O sistema DEVE (MUST) devolver os espaços das unidades sobre as quais o usuário tem escopo, ativos e desativados, ordenados por unidade e por código. Cada espaço DEVE trazer id, nome, código, capacidade, localização, descrição, situação, unidade (id, nome e situação), tipo (id, nome e situação), recursos (id, nome e quantidade), a URL da foto de capa quando houver, se é reservável e os motivos quando não é. A listagem DEVE trazer também o tamanho máximo da foto de capa em vigor:
- o admin recebe os espaços de todas as unidades;
- o coordenador recebe os das unidades que coordena;
- aluno e professor recebem acesso negado.

#### Scenario: Coordenador lista
- **GIVEN** Rui coordena "Paulista" e existem espaços em "Paulista" e em "Vila Olímpia"
- **WHEN** Rui lista os espaços geridos
- **THEN** recebe apenas os espaços de "Paulista"

#### Scenario: Admin lista
- **WHEN** o admin lista os espaços geridos
- **THEN** recebe os espaços de todas as unidades, ativas e desativadas, com a indicação de reservável e os motivos

#### Scenario: Aluno tenta listar
- **WHEN** um aluno tenta listar os espaços geridos
- **THEN** o sistema responde com acesso negado

#### Scenario: Foto e tamanho máximo na listagem
- **GIVEN** "LAB-01" tem foto de capa e "LAB-02" não tem, e o tamanho máximo é de 1024 KB
- **WHEN** Rui lista os espaços geridos
- **THEN** "LAB-01" vem com a URL da foto, "LAB-02" sem ela, e a listagem informa o limite de 1024 KB

### Requirement: Tela de espaços
O frontend DEVE (MUST) oferecer a admins e coordenadores uma página "Espaços" para:
- listar os espaços do escopo, agrupados ou filtráveis por unidade;
- criar e editar espaços, oferecendo apenas unidades ativas do escopo e tipos ativos; na edição, o tipo atual aparece mesmo desativado;
- definir os recursos e as quantidades de cada espaço;
- desativar e reativar espaços;
- mover um espaço para outra unidade, opção exibida só ao admin;
- ver a foto de capa de cada espaço e enviar, trocar e remover a foto.

Os espaços não reserváveis DEVEM ser destacados com o motivo. A desativação DEVE ser confirmada num diálogo com a caixa de seleção do motivo e, para "Outro", o campo de descrição, avisando que o texto de "Outro" fica visível para quem teve a reserva cancelada. Antes de confirmar a desativação ou a mudança de unidade, e no diálogo de edição para o caso de troca de tipo, a página DEVE avisar quantas reservas serão canceladas ou, se houver reserva confirmada em andamento, que a ação será recusada até o horário de término dela. O diálogo da foto DEVE mostrar uma prévia do cartão do feed, os formatos aceitos, o tamanho máximo e o aviso para não usar fotos com pessoas ou dados pessoais; a remoção pede confirmação, e a recusa aparece no diálogo, sem fechá-lo.

#### Scenario: Destaque de espaço não reservável
- **GIVEN** "Auditório Principal" está ativo, mas o tipo "Auditório" está desativado
- **WHEN** o admin abre a página "Espaços"
- **THEN** "Auditório Principal" aparece destacado como não reservável, com o motivo "tipo desativado"

#### Scenario: Coordenador não vê a opção de mover
- **WHEN** um coordenador abre a página "Espaços"
- **THEN** a página não oferece mover espaços entre unidades

#### Scenario: Confirmação da desativação
- **GIVEN** "LAB-01" tem 2 reservas futuras e nenhuma em andamento
- **WHEN** Rui escolhe desativar "LAB-01"
- **THEN** a página pede confirmação avisando que 2 reservas serão canceladas

#### Scenario: Aviso de espaço em uso
- **GIVEN** "LAB-01" tem uma reserva confirmada em andamento até 14h00
- **WHEN** Rui escolhe desativar "LAB-01"
- **THEN** a página avisa que a desativação só será aceita depois das 14h00

#### Scenario: Enviar pela tela
- **WHEN** Rui escolhe "Foto" em "LAB-01", seleciona um JPEG e confirma
- **THEN** a página informa que a foto foi salva e passa a mostrá-la em "LAB-01"

#### Scenario: Recusa na tela
- **WHEN** Rui seleciona uma foto maior que o tamanho máximo e confirma
- **THEN** o diálogo mostra a recusa com o tamanho máximo, sem fechar

#### Scenario: Remover pela tela
- **WHEN** Rui escolhe remover a foto de "LAB-01" e confirma
- **THEN** a página informa que a foto foi removida e "LAB-01" passa a aparecer sem foto

### Requirement: Envio da foto de capa
Quem tem escopo sobre a unidade do espaço (admin em qualquer unidade, coordenador só nas que coordena) DEVE (MUST) poder enviar uma foto de capa para o espaço, ativo ou desativado. A foto DEVE ser JPEG, PNG ou WEBP e ter até `foto_tamanho_max_kb` (capability `parametros`). Se o espaço já tem foto, a nova substitui a anterior, que é apagada do armazenamento. Arquivo inválido DEVE ser recusado sem alterar a foto atual. Aluno e professor NÃO DEVEM (MUST NOT) enviar fotos.

#### Scenario: Coordenador envia a foto
- **GIVEN** Rui coordena "Paulista" e "LAB-01" é de "Paulista", sem foto
- **WHEN** Rui envia um JPEG de 300 KB para "LAB-01"
- **THEN** "LAB-01" passa a ter a foto de capa

#### Scenario: Troca de foto
- **GIVEN** "LAB-01" já tem uma foto de capa
- **WHEN** o admin envia outra foto para "LAB-01"
- **THEN** "LAB-01" passa a ter a nova foto, e o arquivo da anterior é apagado do armazenamento e deixa de ser referenciado pelo espaço

#### Scenario: Arquivo grande demais
- **GIVEN** o tamanho máximo da foto é de 1024 KB
- **WHEN** Rui envia uma foto de 1,5 MB
- **THEN** o sistema recusa informando o tamanho máximo, e a foto atual não muda

#### Scenario: Formato não aceito
- **WHEN** Rui envia um PDF ou um GIF como foto
- **THEN** o sistema recusa informando que a foto deve ser JPEG, PNG ou WEBP

#### Scenario: Coordenador de outra unidade
- **GIVEN** Rui coordena só "Paulista"
- **WHEN** Rui envia uma foto para um espaço de "Vila Olímpia"
- **THEN** o sistema responde com acesso negado

#### Scenario: Aluno tenta enviar
- **WHEN** um aluno envia uma foto para "BIB-01"
- **THEN** o sistema responde com acesso negado

### Requirement: Remoção da foto de capa
Quem tem escopo sobre a unidade do espaço DEVE (MUST) poder remover a foto de capa. O espaço fica sem foto e o arquivo é apagado do armazenamento. Remover de um espaço sem foto DEVE ser recusado sem gerar auditoria.

#### Scenario: Remover a foto
- **GIVEN** "LAB-01" tem foto de capa
- **WHEN** Rui remove a foto de "LAB-01"
- **THEN** "LAB-01" fica sem foto, e o arquivo é apagado do armazenamento

#### Scenario: Espaço sem foto
- **WHEN** Rui tenta remover a foto de um espaço que não tem foto
- **THEN** o sistema recusa informando que o espaço não tem foto de capa

### Requirement: Foto de capa pública
A foto de capa DEVE (MUST) ser servida numa URL pública, que abre sem autenticação, porque o armazenamento do plano gratuito do Xano não oferece acesso privado. Além das rotas públicas já previstas (cadastro, login e unidades ativas), é a única exceção à regra de que o acesso exige autenticação, e vale só para a foto de capa; o envio e a remoção exigem autenticação e escopo. A foto pode ter a marca d'água do plano gratuito.

#### Scenario: Abrir a foto sem login
- **GIVEN** "LAB-01" tem foto de capa
- **WHEN** alguém abre a URL da foto numa janela sem sessão
- **THEN** a imagem é exibida

#### Scenario: Envio sem autenticação
- **WHEN** alguém envia uma foto sem token
- **THEN** o sistema responde com não autenticado

#### Scenario: Cópia de foto já aberta
- **GIVEN** a foto de "LAB-01" já foi aberta pela URL pública, e o Xano gerou a cópia com marca d'água
- **WHEN** a foto é trocada ou removida
- **THEN** o arquivo original é apagado, e a cópia com marca d'água pode continuar acessível pela URL antiga, por limitação do armazenamento do plano gratuito

#### Scenario: Senha provisória
- **GIVEN** Rui está com senha provisória
- **WHEN** Rui envia ou remove uma foto
- **THEN** o sistema recusa com "Troque sua senha para continuar." (capability `senha`)

#### Scenario: Trocas simultâneas
- **WHEN** duas fotos são enviadas ao mesmo tempo para "LAB-01"
- **THEN** "LAB-01" termina com uma das duas como foto de capa, e a auditoria registra os dois envios
