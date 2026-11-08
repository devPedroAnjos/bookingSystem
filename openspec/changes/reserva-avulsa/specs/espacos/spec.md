## MODIFIED Requirements

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

### Requirement: Tela de espaços
O frontend DEVE (MUST) oferecer a admins e coordenadores uma página "Espaços" para:
- listar os espaços do escopo, agrupados ou filtráveis por unidade;
- criar e editar espaços, oferecendo apenas unidades ativas do escopo e tipos ativos; na edição, o tipo atual aparece mesmo desativado;
- definir os recursos e as quantidades de cada espaço;
- desativar e reativar espaços;
- mover um espaço para outra unidade, opção exibida só ao admin.

Os espaços não reserváveis DEVEM ser destacados com o motivo. A desativação DEVE ser confirmada num diálogo com a caixa de seleção do motivo e, para "Outro", o campo de descrição, avisando que o texto de "Outro" fica visível para quem teve a reserva cancelada. Antes de confirmar a desativação ou a mudança de unidade, e no diálogo de edição para o caso de troca de tipo, a página DEVE avisar quantas reservas serão canceladas ou, se houver reserva confirmada em andamento, que a ação será recusada até o horário de término dela.

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
