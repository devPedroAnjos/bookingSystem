## MODIFIED Requirements

### Requirement: Gravação da expiração
A situação `EXPIRADA` DEVE (MUST) ser gravada sem ação de pessoa alguma, na próxima operação que cria, cancela, aprova ou recusa reservas, ou que entra, confirma ou desiste de uma fila (capability `fila-espera`): depois da validação do formato da entrada e antes das demais verificações, mesmo que a operação seja recusada depois. Ela também é gravada na consulta da fila do próprio usuário, feita ao abrir as páginas autenticadas, quando há vencimento a gravar. Nas ações de gestão que cancelam reservas, a pendente já iniciada continua sendo cancelada por indisponibilidade do espaço (capability `reservas`).

#### Scenario: Gravada por uma operação recusada
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" começou às 14h00 sem decisão
- **WHEN** Carlos tenta, às 14h20, reservar outro espaço num horário ocupado e é recusado
- **THEN** a reserva de Ana fica `EXPIRADA`

#### Scenario: Pendente de conta inativada
- **GIVEN** Carlos tinha uma reserva `PENDENTE` que começou às 14h00, e o admin inativou Carlos às 14h10, sem cancelar essa reserva porque ela já tinha começado
- **WHEN** Ana cria uma reserva às 14h20
- **THEN** a reserva de Carlos fica `EXPIRADA`

#### Scenario: Gestão antes da gravação
- **GIVEN** Ana tem uma reserva `PENDENTE` em "LAB-01" que começou às 14h00, ainda não gravada como expirada
- **WHEN** Rui desativa "LAB-01" às 14h10
- **THEN** a reserva de Ana fica `CANCELADA` com o motivo `ESPACO_INDISPONIVEL`, como na capability `reservas`

#### Scenario: Gravada ao abrir uma página
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" começou às 14h00 sem decisão, e nenhuma operação gravou nada desde então
- **WHEN** Bruno abre "Buscar espaços" às 14h20
- **THEN** a reserva de Ana fica `EXPIRADA`

#### Scenario: Gravada pela entrada na fila
- **GIVEN** a reserva `PENDENTE` de Ana em "LAB-01" começou às 14h00 sem decisão
- **WHEN** Bruno entra na fila de outro espaço às 14h20
- **THEN** a reserva de Ana fica `EXPIRADA`
