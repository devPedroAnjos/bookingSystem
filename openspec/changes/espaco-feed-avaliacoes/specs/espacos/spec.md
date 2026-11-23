## ADDED Requirements

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

## MODIFIED Requirements

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
