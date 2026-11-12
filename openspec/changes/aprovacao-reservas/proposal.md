## Why

Desde a C6, uma reserva **pendente ocupa o horário sem prazo**. Ninguém consegue aprová-la nem recusá-la, e ela nunca expira. O laboratório pedido por um aluno e o auditório pedido por um professor ficam presos até o próprio dono cancelar. Isso contraria a §7.6 do `project-overview.md` (aprovação pelo coordenador da unidade, recusa com motivo, expiração sem decisão até o início). Coordenadores e administradores também não têm onde ver as reservas dos espaços que gerem.

Há também uma restrição nova: o plano gratuito do Xano **não inclui tarefas agendadas** (Background Tasks). A expiração não pode depender de um relógio no servidor. Esta change define o mecanismo que substitui as tarefas agendadas e que as changes C8, C9, C13 e C14 vão reutilizar.

## What Changes

**Aprovação e recusa (coordenador e admin)**
- O coordenador que coordena a unidade **atual** do espaço, ou qualquer admin, aprova ou recusa uma reserva `PENDENTE` enquanto ela não começou.
- A aprovação deixa a reserva `CONFIRMADA`. Ela não confere de novo as regras do tipo, o limite nem o conflito, porque essas regras valem na criação e a pendente já ocupa o horário.
- A recusa deixa a reserva `RECUSADA` e exige um motivo em texto, que o dono vê em "Minhas reservas".
- **Ninguém decide a própria reserva.** Esse caso só ocorre quando o dono mudou de papel depois de criá-la. A reserva fica para outro coordenador da unidade ou para um admin e, sem decisão, expira.
- Depois do início, aprovar e recusar são recusados com a mensagem de que o prazo de decisão terminou.

**Expiração sem tarefa agendada**
- Uma pendente sem decisão até o início **expira**.
- Como o plano gratuito não tem tarefas agendadas, a expiração é **preguiçosa**:
  - toda operação que grava reservas (criar, cancelar, aprovar, recusar) primeiro grava como `EXPIRADA` as pendentes vencidas, dentro da trava de governança;
  - as consultas mostram a pendente vencida como expirada e livre, mesmo antes dessa gravação.
- As ações de gestão continuam como na C6: uma pendente já iniciada é cancelada por indisponibilidade do espaço.
- Essa expiração preguiçosa passa a ser o **padrão do projeto para todos os vencimentos** enquanto o plano for gratuito, com um plano para as próximas changes.
- **BREAKING (documentação de arquitetura):** o `project-overview.md` e o `AGENTS.md` deixam de atribuir "tarefas agendadas" ao Xano.

**Reservas da unidade (coordenador e admin)**
- Página nova "Reservas da unidade":
  - o coordenador vê as reservas dos espaços das unidades que coordena, e o admin vê as de todas;
  - filtros por unidade, espaço, situação (padrão: pendentes) e período;
  - as pendentes aparecem da mais próxima para a mais distante, com "Aprovar" e "Recusar".
- Cada reserva mostra quem pediu (nome, e-mail e papel na criação), o espaço, a data, o horário, a situação e os dados da decisão ou do cancelamento.

**Minhas reservas**
- As recusadas mostram o motivo. As pendentes vencidas aparecem como expiradas, no histórico.

**Fora do escopo**
- Notificações do resultado da decisão e da expiração (C13). Até lá, o dono acompanha em "Minhas reservas".
- Deslocamento por prioridade e fila de espera (C8); falta, penalidade e check-in (C9); bloqueios (C10).
- Tarefas agendadas e qualquer gatilho externo (cron, servidor Reflex), e a mudança para um plano pago do Xano.
- Desfazer uma decisão (reabrir uma recusa ou "desaprovar" uma confirmada).
- Decidir várias reservas de uma vez.
- Paginação da listagem e exportação. Painel e relatórios ficam na C14.

## Capabilities

### New Capabilities
- `aprovacao-reservas`: decisão sobre reservas pendentes (quem decide, aprovar, recusar com motivo, proibição de decidir a própria reserva, prazo até o início), expiração preguiçosa com a situação efetiva nas consultas e a listagem e a página "Reservas da unidade" para coordenador e admin.

### Modified Capabilities
- `reservas`: a pendente sem decisão até o início deixa de ocupar o horário e expira; a criação e o cancelamento gravam as expirações vencidas antes de verificar; "Minhas reservas" passa a mostrar a situação efetiva e o motivo da recusa.
- `busca-espacos`: a pendente cujo início já passou não deixa o espaço ocupado.
- `auditoria`: ações novas `APROVAR_RESERVA`, `RECUSAR_RESERVA` e `EXPIRAR_RESERVA` (esta com ator vazio).
- `autorizacao`: o menu de coordenador e admin ganha "Reservas da unidade".

## Impact

- **Papéis afetados:**
  - Coordenador: decide as pendentes das unidades que coordena e consulta as reservas delas.
  - Admin: decide as pendentes de qualquer unidade e consulta as reservas de todas.
  - Aluno e professor: as pendentes deles passam a ser aprovadas, recusadas ou expiradas, e eles veem o resultado em "Minhas reservas".
- **Regras do `project-overview.md` tocadas:**
  - §6, item 7: aprovação;
  - §7.3: a pendente ocupa o horário só até o início;
  - §7.6: aprovação pelo coordenador da unidade do espaço ou pelo admin, recusa com motivo e expiração;
  - §8 e §10: arquitetura (tarefas agendadas) e auditoria das ações novas;
  - §11: pendências das próximas changes.
- **Documentos:**
  - `project-overview.md` (§7.3, §7.6, §8, §10 e §11), `domain-model.md` (§2.9, §4 e a nota de ator vazio), `AGENTS.md` (§3 e §6) e `openspec/config.yaml` (as duas menções a "tarefas agendadas"), atualizados nesta change;
  - a pendência da C4 sobre mover um espaço com pendentes deixa de existir, porque a C6 já cancela essas pendentes.
- **Xano:**
  - tabela `reserva`: campos `decidido_por_id`, `decidido_em` e `motivo_recusa`, e o índice novo `status` + `inicio`;
  - funções novas: vencimentos e situação efetiva;
  - rotas novas no grupo `reservas`: aprovar, recusar e reservas da unidade;
  - rotas alteradas: `criar_reserva`, `cancelar_reserva`, `minhas_reservas` e `buscar_espacos`;
  - nenhuma tarefa agendada;
  - publicação sempre com dry-run e aprovação.
- **Reflex:**
  - cliente com as rotas novas;
  - página e State novos de "Reservas da unidade", com diálogo de recusa;
  - motivo da recusa em "Minhas reservas";
  - menu atualizado.
- **Dependências:** nenhuma nova. Nenhuma variável de ambiente nova, porque o grupo `reservas` já existe.
