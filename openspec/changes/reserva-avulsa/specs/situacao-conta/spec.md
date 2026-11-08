## MODIFIED Requirements

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
