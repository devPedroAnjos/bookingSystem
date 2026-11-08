## Why

A C5 deixou os tipos de espaço com regras e criou a busca, mas ninguém consegue **reservar**. A busca só diz se um horário está "dentro das regras do tipo" e avisa que a ocupação não é verificada. Sem reserva, o sistema não cumpre o seu objetivo central (`project-overview.md`, §1 e §6, itens 3 e 4) e não há como construir aprovação (C7), fila e prioridade (C8), faltas (C9) nem bloqueios (C10).

Esta change (C6) cria a **reserva avulsa**, com a verificação de regras e de conflito de horário feita de forma atômica no backend. Ela também resolve as pendências deixadas pela C2 (inativar conta cancela as reservas futuras), pela C4 (efeito da desativação de espaço, tipo e unidade e da mudança de unidade sobre as reservas) e pela C5 (validar o horário dentro da trava, limite de reservas ativas e regra do papel na criação).

## What Changes

**Reserva avulsa (todos os papéis)**
- Qualquer usuário com conta ativa reserva um espaço para si, informando data, hora de início e hora de fim (America/Sao_Paulo).
- O backend valida, de forma atômica:
  - espaço reservável (espaço, unidade e tipo ativos e tipo com regras completas);
  - regra do papel (quem não pode reservar o tipo é recusado);
  - regras do tipo (dias de funcionamento, horário, granularidade, duração e antecedência), com a mesma validação da busca;
  - máximo de reservas ativas do usuário naquele tipo;
  - conflito com reservas ativas (pendentes ou confirmadas) sobrepostas no mesmo espaço, inclusive sobreposição parcial.
- A reserva nasce **confirmada**, ou **pendente** quando o tipo exige aprovação para o papel. Ela guarda o nível de prioridade do papel e o instante de criação do backend.
- Com o horário ocupado, a C6 só recusa ("horário ocupado"). Deslocamento por prioridade e fila de espera são da C8.

**Cancelamento pelo próprio usuário**
- O usuário cancela a própria reserva ativa até o **prazo de cancelamento** antes do início (parâmetro novo, padrão 2 horas), sem falta.
- Depois do prazo, o cancelamento é recusado. O cancelamento tardio, que gera falta, é da C9.

**Cancelamentos automáticos, sem falta**
- **Inativar uma conta** cancela as reservas dela que ainda não começaram (motivo `CONTA_INATIVADA`). A reserva em andamento continua.
- **Desativar um espaço, um tipo ou uma unidade, mover um espaço de unidade ou trocar o tipo de um espaço:**
  - Enquanto houver uma reserva confirmada **em andamento** num dos espaços afetados, a ação é **recusada** e informa até que horas; ninguém, nem admin nem coordenador, encerra uma reserva em uso.
  - Sem reserva em andamento, a ação é aceita e cancela as reservas desses espaços que ainda não começaram (motivo `ESPACO_INDISPONIVEL`). Pendentes cujo início já passou também são canceladas, porque não foram aprovadas.
  - Admin e coordenador seguem a mesma regra, cada um no seu escopo atual.
- Antes de confirmar essas ações, a tela avisa quantas reservas serão canceladas ou, se houver reserva em andamento, até que horas a ação ficará recusada.

**Motivo nas desativações e na inativação de conta**
- Desativar um espaço, um tipo ou uma unidade passa a exigir um **motivo escolhido numa lista** (manutenção ou reforma, problema de infraestrutura, interdição ou risco à segurança, equipamentos indisponíveis, mudança de uso, baixa utilização, encerramento das atividades no local, ou "Outro" com descrição).
- Inativar uma conta troca o texto livre por uma lista (desligamento, conclusão de curso, trancamento ou afastamento, uso indevido, conta duplicada, pedido do titular, ou "Outro" com descrição).
- O motivo vai para a auditoria. Nas reservas canceladas por desativação, ele também aparece em "Minhas reservas". Na inativação de conta, ele fica só na auditoria.
- Reativar a conta, o espaço, o tipo ou a unidade não restaura reservas canceladas.

**Busca e telas**
- Com data e horário informados, a busca passa a dizer se cada espaço está **livre** ou **ocupado** naquele intervalo (sem dizer por quem) e oferece **Reservar** quando está livre e dentro das regras.
- Página nova "Minhas reservas", para todos os papéis, com as reservas do usuário, a situação, o motivo de cancelamento e o botão de cancelar dentro do prazo.
- Parâmetro novo **prazo de cancelamento** (minutos) na página de parâmetros do admin principal.

**Fora do escopo**
- Aprovação, recusa e expiração das reservas pendentes, e a listagem de reservas da unidade para coordenador e admin (C7). Até a C7, uma reserva pendente ocupa o horário sem prazo.
- Deslocamento por prioridade e fila de espera, inclusive a vaga retida pela fila (C8).
- Cancelamento tardio, check-in, falta e penalidade, e a checagem de penalidade ativa na criação (C9).
- Bloqueios e feriados, e a checagem de bloqueio na criação (C10).
- Reserva recorrente (C11), avaliações (C12) e notificações (C13). Os cancelamentos automáticos aparecem só em "Minhas reservas", com o motivo.
- Reserva em nome de outra pessoa e alteração de uma reserva existente (o usuário cancela e reserva de novo).
- Agenda do dia de um espaço.

## Capabilities

### New Capabilities
- `reservas`: criação da reserva avulsa com validação atômica de regras e conflito, situação inicial conforme a regra do papel, limite de reservas ativas, cancelamento pelo próprio usuário no prazo, cancelamentos automáticos por inativação de conta e por indisponibilidade do espaço, consulta do impacto antes dessas ações, listagem "Minhas reservas" e as telas de reservar e de minhas reservas.

### Modified Capabilities
- `busca-espacos`: com data e horário, cada espaço indica livre ou ocupado; a tela oferece "Reservar" e deixa de avisar que a ocupação não é verificada.
- `espacos`: desativar, trocar o tipo e mover um espaço são recusados com reserva em andamento e, sem ela, cancelam as reservas futuras; a desativação exige motivo da lista; a tela pede confirmação com o aviso de impacto.
- `tipos-espaco`: desativar um tipo segue a mesma regra e exige motivo; o aviso da desativação inclui as reservas.
- `unidades`: desativar uma unidade segue a mesma regra e exige motivo; o formulário de desativação avisa as reservas.
- `situacao-conta`: inativar uma conta cancela as reservas dela que ainda não começaram, e o motivo passa a ser escolhido numa lista; o diálogo de inativação avisa quantas reservas serão canceladas.
- `parametros`: novo parâmetro prazo de cancelamento.
- `autorizacao`: o menu de todos os papéis ganha "Minhas reservas".
- `auditoria`: requisitos novos com as ações de criar e cancelar reserva e com o motivo nas desativações e na inativação de conta.

## Impact

- **Papéis afetados:**
  - Aluno, professor, coordenador e admin: reservam, cancelam no prazo e consultam as próprias reservas.
  - Coordenador e admin: ao desativar, mover ou trocar o tipo de espaços, ou ao desativar tipos e unidades (admin), cancelam reservas.
  - Admin: ao inativar contas, cancela as reservas futuras delas.
  - Admin principal: define o prazo de cancelamento.
- **Regras do `project-overview.md` tocadas:**
  - §6, itens 3, 4 e 8: verificação de disponibilidade, reserva e cancelamento pelo usuário (sem a parte tardia);
  - §7.1 e §7.2: horário e regras do tipo aplicados na criação;
  - §7.3: nunca duas reservas ativas sobrepostas, com verificação e gravação atômicas (prioridade e deslocamento ficam para a C8);
  - §7.8: cancelamento sem penalidade até 2 horas antes, agora parametrizado;
  - §10: auditoria das novas ações.
  - O `domain-model.md` (§2.9 desatualizado desde a C5, §2.18, DER de `RESERVA` e `CONFIGURACAO_GERAL`) e o §11 do overview são atualizados nesta change.
- **Xano:**
  - tabela nova `reserva`;
  - parâmetro novo em `configuracao_geral`;
  - grupo de API novo `reservas`, com as rotas de criar, cancelar, listar as próprias e consultar o impacto;
  - funções novas de conversão do horário pedido (compartilhada com a busca) e de cancelamento em lote;
  - rotas alteradas: `buscar_espacos`, `desativar_espaco`, `editar_espaco`, `mover_espaco`, `desativar_tipo`, `desativar` (unidade), `inativar` (conta), `parametros` (GET e POST) e `bootstrap`.
  - Publicação sempre com dry-run e aprovação.
- **Reflex:**
  - cliente com as rotas novas e a variável de ambiente do grupo `reservas`;
  - diálogo de reservar na busca;
  - página "Minhas reservas";
  - avisos de cancelamento nos diálogos de espaços, tipos, unidades e contas;
  - diálogo de confirmação novo para desativar espaço;
  - campo novo na página de parâmetros;
  - menu atualizado.
- **Dependências:** nenhuma nova.
