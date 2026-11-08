# Especificação: Situação da conta

## Purpose
Permitir que a administração suspenda o acesso de uma conta e o restabeleça depois, sem perder o histórico e sem deixar coordenadores ou professores ligados a unidades que não servem mais.

## Requirements

### Requirement: Inativação de conta
Um admin DEVE (MUST) poder inativar uma conta `ATIVA`, escolhendo um motivo obrigatório da lista (desligamento da instituição; conclusão de curso; trancamento ou afastamento; uso indevido do sistema; conta duplicada; pedido do titular; outro), com descrição obrigatória de até 500 caracteres quando o motivo é "Outro":
- qualquer admin, para alunos, professores e coordenadores;
- só o admin principal, para admins secundários;
- ninguém, para o admin principal.

A conta passa a `INATIVA` e perde o acesso na próxima requisição. Na mesma operação, as reservas da conta que ainda não começaram são canceladas, sem falta, e a reserva em andamento continua (capability `reservas`); a resposta informa quantas foram canceladas. Contas `PENDENTE` ou `RECUSADA` NÃO DEVEM (MUST NOT) ser inativadas. A pessoa inativada não vê o motivo: o login com senha correta responde apenas que o acesso não está liberado, e as reservas canceladas pela inativação mostram só "conta inativada", sem o motivo.

#### Scenario: Inativar professor
- **GIVEN** Carlos é professor ativo e está logado
- **WHEN** um admin inativa Carlos com o motivo "Desligamento da instituição"
- **THEN** a conta de Carlos passa a `INATIVA`
- **AND** a próxima requisição de Carlos é recusada como não autenticada

#### Scenario: Inativar conta com reservas
- **GIVEN** Carlos tem 2 reservas futuras
- **WHEN** um admin inativa Carlos
- **THEN** as 2 reservas ficam canceladas com o motivo `CONTA_INATIVADA`
- **AND** a resposta informa que 2 reservas foram canceladas

#### Scenario: Inativar sem motivo
- **WHEN** um admin tenta inativar uma conta sem escolher o motivo
- **THEN** o sistema recusa pedindo o motivo e nada muda

#### Scenario: Outro sem descrição
- **WHEN** um admin tenta inativar uma conta com o motivo "Outro" e a descrição vazia
- **THEN** o sistema recusa pedindo a descrição do motivo e nada muda

#### Scenario: Motivo fora da lista
- **WHEN** alguém envia, pela API, um código de motivo de inativação que não está na lista
- **THEN** o sistema recusa informando que o motivo é inválido e nada muda

#### Scenario: Conta pendente
- **WHEN** um admin tenta inativar uma conta `PENDENTE`
- **THEN** o sistema recusa a operação

#### Scenario: Coordenador tenta inativar
- **WHEN** um coordenador tenta inativar qualquer conta
- **THEN** o sistema responde com acesso negado

### Requirement: Coordenador inativado mantém o vínculo
A inativação de um coordenador NÃO DEVE (MUST NOT) apagar as coordenações dele. Enquanto inativo, ele não conta para os limites nem para "unidade sem coordenador ativo": se era o único coordenador ativo de uma unidade, ela passa a ser destacada como sem coordenador.

#### Scenario: Último coordenador inativado
- **GIVEN** Rui é o único coordenador ativo de "Paulista"
- **WHEN** um admin inativa Rui
- **THEN** a coordenação de Rui continua registrada
- **AND** "Paulista" passa a ser destacada como sem coordenador ativo e tem 4 vagas

### Requirement: Reativação de conta
Um admin DEVE (MUST) poder reativar uma conta `INATIVA`, com as mesmas permissões da inativação, voltando-a para `ATIVA`. A reativação DEVE conferir o papel da conta:
- **coordenador**: as coordenações em unidades desativadas ou sem vaga são descartadas; se não sobrar nenhuma, o admin DEVE informar de 1 até o máximo de unidades (ativas e com vaga) na mesma operação;
- **professor**: se a unidade dele estiver desativada, o admin DEVE informar uma nova unidade ativa na mesma operação;
- **admin secundário**: a reativação DEVE ser recusada se o limite de admins ativos já foi atingido.

Se faltar a escolha exigida, nada muda e a resposta indica o que é preciso informar.

#### Scenario: Coordenador com unidade lotada
- **GIVEN** Rui, inativo, coordenava "Paulista" e "Centro", e "Paulista" está com 4 coordenadores ativos
- **WHEN** um admin reativa Rui
- **THEN** Rui volta a `ATIVA` coordenando só "Centro"
- **AND** a resposta informa que a coordenação de "Paulista" foi descartada

#### Scenario: Coordenador sem unidade válida
- **GIVEN** Rui, inativo, coordenava só "Paulista", que foi desativada
- **WHEN** um admin tenta reativar Rui sem informar unidades
- **THEN** o sistema recusa indicando que é preciso escolher 1 ou 2 unidades
- **AND** ao reativar informando "Vila Olímpia", Rui volta a `ATIVA` coordenando "Vila Olímpia"

#### Scenario: Professor com unidade desativada
- **GIVEN** Carlos, inativo, pertence a "Centro", que foi desativada
- **WHEN** um admin reativa Carlos informando "Paulista"
- **THEN** Carlos volta a `ATIVA` como professor de "Paulista"

#### Scenario: Admin acima do limite
- **GIVEN** existem 3 admins ativos e Lia é admin secundária inativa
- **WHEN** o principal tenta reativar Lia
- **THEN** o sistema recusa informando que o limite de administradores foi atingido

### Requirement: Telas de inativação e reativação
A página de usuários DEVE (MUST) oferecer, para cada conta permitida ao admin logado, "Inativar" para contas ativas e "Reativar" para contas inativas. O diálogo de inativação DEVE pedir o motivo numa caixa de seleção, com o campo de descrição quando o motivo é "Outro", e avisar quantas reservas da conta serão canceladas. Quando a reativação exigir a escolha de unidades, a página DEVE pedir essa escolha antes de enviar.

#### Scenario: Aviso de reservas na inativação
- **GIVEN** Carlos tem 2 reservas futuras
- **WHEN** o admin escolhe "Inativar" para Carlos
- **THEN** o diálogo avisa que 2 reservas serão canceladas

#### Scenario: Reativação pedindo unidade
- **GIVEN** Carlos está inativo e a unidade dele foi desativada
- **WHEN** o admin escolhe "Reativar" para Carlos
- **THEN** a página pede a nova unidade antes de enviar
