## Why

Hoje não há como tornar um espaço indisponível por um período: manutenção, evento ou feriado exigem desativar o espaço inteiro, o que vale por tempo indeterminado e cancela todas as reservas futuras. A §7.7 do `project-overview.md` define o bloqueio por período, e as changes C6, C7 e C9 deixaram pontos de extensão e pendências para ele (§11, item 11). Esta change também registra o replanejamento de 22/11/2026, feito por causa do prazo de entrega (decisão 1).

## What Changes

**Bloqueio**
- O coordenador da unidade do espaço ou o admin cria um bloqueio para um espaço ativo, com tipo (`MANUTENCAO`, `EVENTO` ou `FERIADO`), motivo, início e fim, cada um com data e hora em America/Sao_Paulo.
- O bloqueio pode durar vários dias e pode ter começado antes da criação, mas o fim tem de estar no futuro. As regras de horário do tipo (08h00 a 22h40, granularidade, dias de funcionamento) não se aplicam a ele.
- **Recusa:** a criação é recusada, sem gravar nada, quando há reserva `CONFIRMADA` em andamento sobreposta ao bloqueio, como na desativação de espaço.
- **Efeitos, na mesma operação atômica:**
  - as reservas `PENDENTE` e `CONFIRMADA` sobrepostas que ainda não começaram são canceladas inteiras, com o motivo `BLOQUEIO`, o bloqueio que as causou e sem falta;
  - as entradas de fila (`AGUARDANDO` e `NOTIFICADA`) sobrepostas ficam `ENCERRADA`;
  - as filas de trechos liberados fora do bloqueio são processadas normalmente.
- **Remoção:** quem pode criar remove um bloqueio `ATIVO` que ainda não terminou. Ele passa a `REMOVIDO` e nada é restaurado. Não há edição.

**Onde o bloqueio passa a valer**
- A criação de reserva, inclusive com deslocamento, recusa intervalo sobreposto a bloqueio ativo (pendência da C6).
- A entrada na fila recusa intervalo sobreposto a bloqueio ativo, e a confirmação da vaga retida também recusa, por defesa (pendências da C9).
- A busca com data e horário mostra o espaço sobreposto a bloqueio ativo como "Bloqueado", sem reservar, deslocar nem entrar na fila.

**Telas**
- **"Bloqueios" (nova, coordenador e admin):** lista os bloqueios ativos que ainda não terminaram nas unidades que o usuário gere, com filtro por unidade; cria, com o aviso de que reservas e filas sobrepostas serão canceladas sem penalidade; remove, com confirmação. A mensagem de sucesso informa quantas reservas foram canceladas e quantas entradas de fila foram encerradas.
- **"Minhas reservas":** a reserva cancelada por bloqueio mostra o tipo e o motivo do bloqueio.
- **"Buscar espaços":** a indicação "Bloqueado".

**Auditoria:** `CRIAR_BLOQUEIO` e `REMOVER_BLOQUEIO`, além de um `CANCELAR_RESERVA` por reserva cancelada e um `ENCERRAR_FILA` por entrada encerrada, com o motivo `BLOQUEIO`.

**Documentos (replanejamento de 22/11/2026, decisão 1)**
- `project-overview.md` §11: a reserva recorrente (C12), o upload de fotos da C13 e o painel e relatórios (C15) saem da v1 e vão para "Trabalho futuro"; a próxima change junta o feed, a página do espaço, as avaliações e o visual. A §7.5 (recorrência) passa a dizer que está fora da v1. O bloqueio em lote de uma unidade inteira vira change extra, se houver tempo.
- `project-overview.md` §7.7 e §10; `domain-model.md` §2.8 (bloqueio em lote fora da v1, sem edição, remoção sem restaurar) e §2.10 (recorrência fora da v1).

**Fora do escopo**
- Bloqueio em lote de todos os espaços de uma unidade (feriado da unidade inteira): change extra, se houver tempo (decisão 3).
- Edição de bloqueio (remover e criar outro).
- Pré-visualização das reservas afetadas antes de confirmar.
- Motivo do encerramento na seção "Fila de espera" de "Minhas reservas" (exigiria campo novo em `entrada_fila`).
- Notificações aos donos das reservas canceladas (fora da v1).
- Reserva recorrente, feed, avaliações e painel.

## Capabilities

### New Capabilities
- `bloqueios`: criação, validação, recusa por reserva em andamento, efeitos sobre reservas e filas, remoção, listagem, permissões por papel e unidade, a página "Bloqueios" e o motivo visível em "Minhas reservas".

### Modified Capabilities
- `reservas`: (requisito novo) a criação, inclusive com deslocamento, recusa intervalo sobreposto a bloqueio ativo.
- `fila-espera`: (requisito novo) a entrada e a confirmação da vaga retida recusam intervalo sobreposto a bloqueio ativo.
- `busca-espacos`: (requisito novo) o espaço sobreposto a bloqueio ativo no horário pedido aparece "Bloqueado", sem ações.
- `autorizacao`: o menu do coordenador e do admin ganha "Bloqueios".
- `auditoria`: (requisito novo) criação e remoção de bloqueio, e os cancelamentos e encerramentos que ela causa, são auditados.

## Impact

- **Papéis afetados:**
  - **coordenador:** cria e remove bloqueios nas unidades que coordena;
  - **admin:** cria e remove bloqueios em qualquer unidade;
  - **todos:** veem a reserva cancelada por bloqueio, o espaço "Bloqueado" na busca e a recusa ao reservar ou entrar na fila.
- **Regras do `project-overview.md` tocadas:** §7.7 (inteira), §7.2 e §7.3 (o bloqueio impede reserva e deslocamento), §7.4 (fila não entra em intervalo bloqueado; encerramento), §7.5 (fora da v1), §10 (auditoria) e §11.
- **Xano:**
  - tabela nova `bloqueio` e campo `bloqueio_id` em `reserva`;
  - rotas novas no grupo `espacos`: criar, remover e listar bloqueios;
  - função nova que recusa intervalo sobreposto a bloqueio ativo;
  - alterações em `selecionar_reservas_a_cancelar`, `cancelar_reservas`, `criar_reserva`, `entrar_fila`, `confirmar_fila`, `buscar_espacos` e `minhas_reservas`;
  - publicação sempre com dry-run e aprovação.
- **Reflex:** cliente com as rotas novas; página "Bloqueios" no menu de gestão; motivo do bloqueio em "Minhas reservas"; "Bloqueado" na busca.
- **Dependências:** nenhuma nova. Nenhuma variável de ambiente nova.
