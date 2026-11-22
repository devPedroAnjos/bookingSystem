## 1. Preparação e documentação

- [x] 1.1 O usuário confirma a conta e o workspace do Xano CLI e a branch `change/bloqueios`. Rodar `xano workspace pull` numa pasta temporária e confirmar que o workspace está igual a `./xano`. Verificação: resposta do usuário e comparação sem diferenças.
- [x] 1.2 Confirmar no Xano Developer MCP, com sondas validadas e sem push:
  - o `where` de `db.query` com sobreposição estrita (`inicio < x && fim > y`) e `in` sobre lista de ids;
  - o enum novo e o campo int opcional com `table` em `reserva`.

  Registrar o resultado numa seção "Confirmações do apply" do `design.md`. Verificação: sondas válidas no MCP.
- [x] 1.3 `docs/project-overview.md`:
  - §7.7: remoção sem restaurar, sem edição, recusa por reserva em andamento;
  - §7.5: recorrência fora da v1;
  - §10: `CRIAR_BLOQUEIO` e `REMOVER_BLOQUEIO`;
  - §11: replanejamento de 22/11/2026. C11 feita; C12, upload de fotos e C15 em "Trabalho futuro"; a próxima change junta feed, página do espaço, avaliações e visual; bloqueio em lote como change extra.

  Verificação: `git diff docs/project-overview.md` mostrado ao usuário.
- [x] 1.4 `docs/domain-model.md`:
  - §2.8: sem edição, remoção sem restaurar, bloqueio em lote fora da v1, recusa por reserva em andamento;
  - §2.10: recorrência fora da v1.

  Verificação: `git diff docs/domain-model.md`.
- [x] 1.5 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Xano

- [x] 2.1 Criar `xano/table/bloqueio.xs` (D1) e acrescentar `bloqueio_id` em `xano/table/reserva.xs`, sem tocar nos demais campos, e atualizar o comentário do cabeçalho. Verificação: validação do MCP e `git diff xano/table/reserva.xs` só com o campo e o comentário.
- [x] 2.2 Criar `converter_periodo_bloqueio` (D2) e `exigir_sem_bloqueio` (D4). Verificação: validação do MCP.
- [x] 2.3 Modo `bloqueio` em `selecionar_reservas_a_cancelar` (com o mesmo trecho de não comparecimento do modo `espaco`) e em `cancelar_reservas`, que passa a devolver `entradas_encerradas`, e `inicio`/`fim` opcionais em `exigir_sem_reserva_em_andamento` (D3), sem mudar os modos existentes. Verificação: validação do MCP; leitura do diff dos modos `conta`, `espaco` e `prioridade` sem alteração de comportamento; o cenário "Não comparecimento não impede" fica coberto em 2.7.
- [x] 2.4 Rotas `criar_bloqueio`, `remover_bloqueio` e `listar_bloqueios` no grupo `espacos` (D5), com nomes únicos no workspace. Verificação: validação do MCP.
- [x] 2.5 Chamar `exigir_sem_bloqueio` no passo 8 de `criar_reserva_POST`, no passo 4 de `entrar_fila_POST` e antes da gravação em `confirmar_fila_POST`, e atualizar os comentários dos pontos de extensão. Indicação `bloqueado` em `buscar_espacos_POST` e `bloqueio_tipo`/`bloqueio_motivo` em `minhas_reservas_GET` (D6). Verificação: validação do MCP.
- [x] 2.6 Publicação: `xano workspace push --dry-run`, mostrar o resultado ao usuário e só publicar com aprovação explícita. Conferir depois com `pull` numa pasta temporária. Verificação: dry-run mostrado, aprovação registrada, pull igual.
- [x] 2.7 Testes da API (chamadas reais no sandbox, com dados preparados e depois limpos ou registrados), cobrindo:
  - criação pelo coordenador e pelo admin;
  - 403 para professor e para coordenador de outra unidade, em criar, remover e listar;
  - espaço desativado;
  - tipo e motivo inválidos;
  - data inexistente;
  - fim antes do início e fim no passado;
  - início no passado com fim futuro;
  - vários dias e horários fora de 08h00–22h40;
  - recusa por reserva em andamento sobreposta e aceite com a em andamento fora do período;
  - não comparecimento que não impede;
  - sobreposição parcial cancelada inteira, encostado mantido, outra reserva do espaço mantida, pendente vencida não cancelada;
  - filas `AGUARDANDO` e `NOTIFICADA` sobrepostas encerradas, fila fora do período mantida, trecho liberado fora do bloqueio notificando a fila;
  - contagens na resposta;
  - remoção sem restaurar, de bloqueio terminado e de bloqueio removido;
  - listagem por escopo;
  - criar reserva sobreposta, encostada, com deslocamento e após a remoção;
  - entrar na fila sobreposta e fora do bloqueio;
  - busca com bloqueado, encostado e sem horário;
  - `minhas_reservas` com tipo e motivo do bloqueio;
  - auditoria `CRIAR_BLOQUEIO`, `REMOVER_BLOQUEIO`, `CANCELAR_RESERVA` com `bloqueio_id` e `ENCERRAR_FILA` com motivo `BLOQUEIO`, e nenhum registro na recusa;
  - reserva e bloqueio disparados ao mesmo tempo no mesmo intervalo.

  Verificação: tabela de casos com resultado esperado e obtido, com o que não foi possível testar declarado (incluindo a confirmação de fila em período bloqueado, inalcançável pelo fluxo normal).
- [x] 2.8 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Reflex

- [x] 3.1 `xano_cliente.py` com `criar_bloqueio`, `remover_bloqueio` e `listar_bloqueios`, sem expor o token. Verificação: `reflex run` compila sem erro.
- [x] 3.2 `state/bloqueios_state.py` e `pages/bloqueios.py` (D7): lista com filtro por unidade, diálogo de criação com o aviso fixo e as recusas no diálogo, mensagem de sucesso com as contagens, remoção com confirmação. Item "Bloqueios" em `layout.py` para gestores e rota protegida em `bookingSystem.py`. Verificação: compila e a página abre para coordenador e admin.
- [x] 3.3 `motivos.py` com "Cancelada por bloqueio: <Tipo> — <motivo>" e o badge "Bloqueado" sem ações na busca. Verificação: compila.
- [x] 3.4 Testes pelo Playwright:
  - menu do aluno sem "Bloqueios" e com o endereço digitado levando para "Início";
  - menus do coordenador e do admin com "Bloqueios";
  - criar pela tela com as contagens;
  - recusa no diálogo (reserva em andamento);
  - remover pela tela;
  - busca com "Bloqueado" e sem botões;
  - "Minhas reservas" do dono com o motivo do bloqueio e sem o nome do coordenador.

  Verificação: capturas ou relato de cada caso, com o que não foi possível testar declarado.
- [x] 3.5 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Revisão final

- [x] 4.1 `openspec validate bloqueios --strict` sem erros e `decisions-log.md` completo. Verificação: saída do comando.
- [x] 4.2 Relatório de revisão final do guardian (MODO REVISÃO FINAL), mostrado ao usuário antes de qualquer commit. Verificação: relatório entregue e aprovação do usuário.

## Workflow follow-up

- O usuário faz os commits, o push e o PR; o agente entrega os comandos prontos.
- Arquivar a change depois da aprovação do usuário e do merge.
- Teto combinado: cerca de 4 h para esta change. Se estourar, congelar o que estiver pronto e seguir para a change do feed e das avaliações.
