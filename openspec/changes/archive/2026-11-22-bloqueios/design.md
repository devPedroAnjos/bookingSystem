## Context

Ver `proposal.md` (Why). O que já existe e molda a abordagem:
- **Cancelamento em lote:** `selecionar_reservas_a_cancelar` (modos `conta` e `espaco`) escolhe as reservas, e `cancelar_reservas` as cancela, grava um `CANCELAR_RESERVA` por reserva, encerra as entradas de fila (`ENCERRAR_FILA`) e chama `processar_fila` no fim. `exigir_sem_reserva_em_andamento` recusa quando há `CONFIRMADA` em andamento, ignorando o não comparecimento efetivo (C10, D2). A desativação de espaço (`desativar_espaco_POST`) é o modelo de rota de gestão: `travar_governanca`, depois `carregar_espaco_gerido`, depois a recusa e o cancelamento.
- **Pontos de extensão marcados:** passo 8 de `criar_reserva_POST` (antes do conflito e do deslocamento) e passo 4 de `entrar_fila_POST`.
- **`reserva`** já tem o motivo `BLOQUEIO` no enum, mas não tem `bloqueio_id`. **`entrada_fila`** já tem o status `ENCERRADA` e não tem campo de motivo; o motivo do encerramento vai só na auditoria.
- `converter_horario_pedido` converte uma data e duas horas do mesmo dia. O bloqueio precisa de duas datas.
- O Xano não tem isolamento de transação; a atomicidade vem da trava por linha (`travar_governanca`), como em todas as operações sobre reservas e filas.

## Goals / Non-Goals

**Goals:**
- Reaproveitar o cancelamento em lote e a recusa por reserva em andamento, acrescentando um modo por intervalo, em vez de escrever um terceiro caminho de cancelamento.
- Manter o bloqueio fora do predicado de ocupação de reserva (os 7 pontos da C10, D2): ele é uma consulta à parte, feita só onde a regra o exige.

**Non-Goals:**
- Centralizar o predicado de ocupação.
- Pré-visualização de impacto (a rota `impacto_reservas_GET` existe, mas não é estendida nesta change).

## Decisions

### D1. Dados (Xano)
- **Tabela nova `bloqueio`**, conforme o DER: `id`, `espaco_id`, `criado_por_id`, `inicio`, `fim`, `tipo` (`MANUTENCAO`, `EVENTO`, `FERIADO`), `motivo` (texto de 1 a 500), `status` (`ATIVO`, `REMOVIDO`), `criado_em`. Índice btree `(espaco_id, inicio, fim, status)` (`domain-model.md`, índices).
- **Campo novo `reserva.bloqueio_id`** (int opcional, referência a `bloqueio`), preenchido só no cancelamento por bloqueio.
- **Sem campos de remoção** (`removido_por`, `removido_em`): o DER não os tem, e quem removeu e quando ficam no `REMOVER_BLOQUEIO`. Sem divergência do DER.
- O limite de 500 caracteres do motivo segue o do `motivo_recusa` (C7).

### D2. Conversão de data e hora
Função nova `converter_periodo_bloqueio(data_inicio, hora_inicio, data_fim, hora_fim)`, com as mesmas regex e a mesma volta da data de `converter_horario_pedido` e as mesmas mensagens. Alternativa recusada: chamar `converter_horario_pedido` duas vezes, porque ela exige fim depois do início no mesmo dia e devolveria a mensagem errada.

### D3. Seleção e cancelamento por intervalo
- `selecionar_reservas_a_cancelar` ganha o **modo `bloqueio`** (`espacos_ids` com um espaço, `inicio`, `fim`):
  - consulta `PENDENTE` e `CONFIRMADA` do espaço com `reserva.inicio < fim` e `reserva.fim > inicio` (encostado não conta);
  - a `CONFIRMADA` em andamento sobreposta vai para `em_andamento`, salvo o não comparecimento efetivo, com o mesmo trecho de código do modo `espaco`;
  - só entram em `reservas` as que têm `inicio > agora`. A pendente já iniciada é expiração (C7) e não é cancelada.
- `exigir_sem_reserva_em_andamento` ganha `inicio` e `fim` opcionais. Com eles, usa o modo `bloqueio`, e a mensagem continua a mesma.
- `cancelar_reservas` ganha o **modo `bloqueio`** com `bloqueio_id`, `inicio` e `fim`:
  - grava `motivo_cancelamento = BLOQUEIO` e `bloqueio_id`, e leva o `bloqueio_id` no `dados_depois` do `CANCELAR_RESERVA`;
  - encerra as entradas `AGUARDANDO` e `NOTIFICADA` do espaço com intervalo sobreposto ao bloqueio, com `ENCERRAR_FILA` e o motivo `BLOQUEIO`. No modo `espaco`, encerra todas as entradas do espaço;
  - passa a devolver também `entradas_encerradas` (quantas entradas de fila encerrou), usada na mensagem de `criar_bloqueio`. O campo é só acrescentado: os modos existentes continuam com o mesmo comportamento e podem ignorá-lo;
  - chama `processar_fila` no fim, como nos outros modos. Assim, o trecho de uma reserva cancelada que fica fora do bloqueio pode atender uma fila não sobreposta. As filas sobrepostas já foram encerradas antes, então nenhuma vaga é retida dentro do bloqueio.
- Alternativa recusada: um cancelamento próprio do bloqueio. Duplicaria a auditoria e o encerramento da fila.

### D4. Recusa por bloqueio
Função nova `exigir_sem_bloqueio(espaco_id, inicio, fim)`: consulta `bloqueio` `ATIVO` do espaço com sobreposição estrita. Se houver, recusa com "O espaço está bloqueado neste período (<tipo>)." e sem o motivo, que é interno da gestão. Chamada em:
1. `criar_reserva_POST`, passo 8, dentro da trava, antes do conflito. Por isso o deslocamento nunca passa por cima de um bloqueio;
2. `entrar_fila_POST`, passo 4;
3. `confirmar_fila_POST`, antes de gravar a reserva. É uma defesa: o caso é inalcançável, porque o bloqueio encerra a fila sobreposta.

`processar_fila`, `exigir_limite_ativas` e `decidir_reserva` não mudam. A reserva cancelada já sai dos status ativos, e nenhuma pendente sobreposta sobrevive ao bloqueio.

### D5. Rotas (Xano, grupo `espacos`)
- **`criar_bloqueio` (POST):**
  1. validação dos campos e conversão (D2);
  2. `aplicar_vencimentos` antes da transação, como em `aprovar_reserva`;
  3. na transação: `travar_governanca`, depois `carregar_espaco_gerido` (escopo e 403), espaço ativo, `fim > agora`, `exigir_sem_reserva_em_andamento` com o intervalo, gravação do bloqueio, `cancelar_reservas` no modo `bloqueio` e `CRIAR_BLOQUEIO`.

  Responde com a mensagem e as quantidades de reservas canceladas e de entradas encerradas. A auditoria vem depois da gravação do bloqueio, porque o `CANCELAR_RESERVA` precisa do `bloqueio_id`.
- **`remover_bloqueio` (POST):** na transação, `travar_governanca`, carregar o bloqueio, `carregar_espaco_gerido` do espaço dele, exigir `ATIVO` e `fim > agora`, mudar para `REMOVIDO` e gravar `REMOVER_BLOQUEIO`.
- **`listar_bloqueios` (GET):**
  - quem pode é o admin ou o coordenador (os demais recebem 403), com as unidades do escopo vindas de `unidades_coordenadas` (admin: todas);
  - filtro opcional `unidade_id`, recusado com 403 fora do escopo;
  - `ATIVO` com `fim > agora`, em ordem de início, com espaço, unidade, tipo, motivo, início e fim formatados em America/Sao_Paulo e o nome de quem criou.
- **Por que no grupo `espacos`:** o bloqueio é gestão de espaço, como a desativação. Os nomes das rotas são únicos no workspace, porque o CLI casa rotas pelo nome.

### D6. Busca e "Minhas reservas" (Xano)
- **`buscar_espacos_POST`:** com horário pedido, uma consulta de `bloqueio` `ATIVO` sobrepostos ao intervalo, para os espaços do resultado, feita uma vez fora do `foreach`. O espaço com bloqueio recebe `bloqueado = true`, `ocupado = true`, não deslocável, 0 a deslocar e sem fila.
- **`minhas_reservas_GET`:** para as reservas com `bloqueio_id`, uma consulta dos bloqueios por id, devolvendo `bloqueio_tipo` e `bloqueio_motivo`, sem o autor.

### D7. Reflex
- **`xano_cliente.py`:** `criar_bloqueio`, `remover_bloqueio` e `listar_bloqueios`.
- **`state/bloqueios_state.py` e `pages/bloqueios.py`:**
  - lista com filtro por unidade, a partir das unidades geridas que já são usadas em "Espaços";
  - diálogo de criação com o espaço vindo dos espaços geridos, tipo, motivo, data e hora de início e de fim, e o aviso fixo;
  - remoção com o diálogo de confirmação dos componentes existentes.
- **`layout.py`:** item "Bloqueios" para quem é gestor. **`bookingSystem.py`:** a rota da página, com a mesma proteção de "Espaços".
- **`motivos.py`:** `texto_cancelamento` mostra "Cancelada por bloqueio: <Tipo> — <motivo>" quando houver `bloqueio_tipo`.
- **Busca:** o badge "Bloqueado" no lugar de "Livre" ou "Ocupado", e nenhuma ação.

## Risks / Trade-offs

- **[Lote grande dentro da trava]** Um bloqueio longo num espaço muito usado cancela muitas reservas numa transação só. → A escala do projeto é pequena. A mesma situação já existe na desativação de espaço.
- **[Sem isolamento de transação]** A garantia contra a corrida entre reserva e bloqueio é a trava por linha. → As duas rotas a pegam como primeira instrução da transação. O teste de concorrência é limitado e o relatório diz o que não deu para provar.
- **[Encerramento da fila sem motivo visível]** O dono vê "Fila encerrada" sem o motivo. → Decisão 10, aceita por causa do prazo. O motivo fica na auditoria.
- **[Mensagem de recusa expõe o tipo do bloqueio]** → Só o tipo é exposto, nunca o motivo nem o autor, e isso é útil para quem pede.

## Migration Plan

1. Publicar a tabela `bloqueio` e o campo opcional `reserva.bloqueio_id`, que fica vazio nas reservas existentes e dispensa migração. Depois, as funções e as rotas. Tudo com `xano workspace push --dry-run`, mostrando o resultado e com a aprovação do usuário.
2. **Rollback:** as rotas novas podem ser despublicadas sem efeito nos dados antigos. O campo opcional pode ficar.

## Confirmações do apply

- **Tarefa 1.2 (MCP, sem push):** a sonda `function/sonda_bloqueio.xs`, feita fora do repositório, foi aceita pelo validador. Ela usa no `where` de `db.query` a combinação de `in` sobre uma lista de ids convertida com `map:($$|to_int)`, a igualdade de enum e a sobreposição estrita (`inicio < fim_pedido && fim > inicio_pedido`). O campo int opcional com `table` e o enum já estão em uso em `reserva.xs` (`deslocada_por_reserva_id`, `motivo_cancelamento`), sem sonda nova.

## Resultados dos testes da API (tarefa 2.7)

Os testes rodaram em 22/11/2026, depois do push aprovado (2.6), com um script descartável no scratchpad contra o workspace, no relógio real. Durante o script, os parâmetros ficaram temporariamente assim: granularidade de 1 minuto, todos os dias da semana e janela de check-in de 1 minuto depois do início. No fim eles foram restaurados e conferidos iguais aos originais. O plano gratuito limita a API a 10 requisições a cada 20 segundos, então o script espaça as chamadas e repete quando recebe 429.

**Cenário:** tipo de teste com aprovação para aluno; espaços S1 a S8, um desativado e um em outra unidade; contas de teste de duas alunas, um professor e um coordenador da unidade 1; e o admin.

**Resultado: 55 casos, 0 falhas.** São 51 no script principal, mais 4 pedidos na revisão do guardian: professor e aluno tentando remover e listar bloqueios, com 403 nos quatro.
- **Permissões:** professor e aluno recebem 403 ao criar, remover e listar; coordenador em outra unidade recebe 403 ao criar, filtrar a listagem e remover; sem token, 401; admin cria em outra unidade.
- **Validações:** tipo inválido, motivo vazio, motivo com 501 caracteres, data inexistente, fim antes do início, fim no passado e espaço desativado são recusados com as mensagens das specs. São aceitos o bloqueio de vários dias, fora de 08h00–22h40, e o feriado já em curso.
- **Efeitos:**
  - o bloqueio de S1 cancelou 2 reservas (a pendente com sobreposição parcial e a confirmada) com o motivo `BLOQUEIO`, o tipo e o motivo em "Minhas reservas" e sem falta;
  - encerrou 2 entradas de fila (uma `AGUARDANDO` e a vaga retida `NOTIFICADA`);
  - continuaram ativas a reserva encostada, a reserva fora do período, a reserva de outro espaço e a fila fora do período;
  - o trecho liberado fora do bloqueio (S3) passou à fila (`NOTIFICADA`).
- **Pontos de extensão:**
  - recusados com "O espaço está bloqueado neste período (manutenção).": a reserva sobreposta, a reserva com sobreposição parcial, o pedido com deslocamento confirmado e a entrada na fila;
  - aceitos: a reserva encostada ao início do bloqueio e a reserva depois da remoção.
- **Busca:** com horário, o espaço bloqueado aparece `bloqueado`, ocupado, não deslocável e sem fila, sem o motivo; o espaço livre e o intervalo encostado aparecem `bloqueado` falso; sem horário, não há indicação.
- **Em andamento** (reservas de hoje, com espera real até o início):
  - recusa com "Há uma reserva em andamento neste espaço até 16:17.";
  - bloqueio aceito quando a reserva em andamento está fora do período;
  - o não comparecimento efetivo não impede o bloqueio;
  - a pendente vencida aparece `EXPIRADA` e não é cancelada (0 reservas).
- **Remoção:** passa a `REMOVIDO` sem restaurar a reserva. Remover de novo e remover um bloqueio terminado são recusados, e terminados e removidos saem da lista. O coordenador lista só a própria unidade; o admin lista todas.
- **Concorrência:** reserva e bloqueio disparados ao mesmo tempo no mesmo intervalo. A reserva foi gravada primeiro e cancelada pelo bloqueio (1 reserva cancelada), e no fim não sobrou reserva ativa sobreposta.
- **Auditoria:** conferida num pull com registros, numa pasta temporária apagada em seguida:
  - `CRIAR_BLOQUEIO` e `REMOVER_BLOQUEIO` com o coordenador como ator, a unidade, o espaço, o tipo, o motivo e o período;
  - `CANCELAR_RESERVA` com o `bloqueio_id` e o motivo `BLOQUEIO`;
  - 2 `ENCERRAR_FILA` com o motivo `BLOQUEIO`;
  - 10 `CRIAR_BLOQUEIO`, exatamente os 10 bloqueios aceitos, então as recusas não geraram registro.

**Não testado:**
- **Confirmação de vaga retida em período bloqueado:** é inalcançável pelo fluxo normal, porque o bloqueio encerra a entrada sobreposta. A recusa é uma defesa revisada só por leitura.
- **Corrida inversa:** o bloqueio vence a reserva e a reserva é recusada. Uma única tentativa não força essa ordem. A trava é a mesma nas duas rotas.

**Limpeza, sem exclusão física, feita depois dos testes do frontend:**
- os 8 bloqueios ativos dos espaços de teste foram removidos;
- as 7 contas de teste foram inativadas. Três vieram de uma primeira execução interrompida pelo limite de requisições e quatro da execução principal; o coordenador voltou a professor antes da inativação;
- o tipo de teste é desativado depois do fim da reserva em andamento de hoje. A desativação do tipo deixa os espaços dele não reserváveis;
- os parâmetros foram restaurados, e o Reflex foi parado.

## Resultados dos testes do frontend (tarefa 3.4)

Os testes foram feitos no navegador, com Playwright, contra o app em modo produção (`reflex run --env prod --single-port`), com as contas de teste da tarefa 2.7. O `reflex compile --dry` passou antes.

- **Aluno:**
  - o menu mostra "Início", "Buscar espaços", "Minhas reservas" e "Trocar senha", sem "Bloqueios";
  - o endereço `/bloqueios` digitado leva para "Início";
  - em "Minhas reservas", a reserva cancelada aparece como "Cancelada" com "Cancelada por bloqueio: Manutenção — Troca dos computadores", sem o nome do coordenador.
- **Coordenador:**
  - o menu tem "Bloqueios" depois de "Espaços";
  - a página lista os 6 bloqueios ativos da unidade dele, com espaço, unidade, tipo, motivo, início, fim e autor.
- **Criar pela tela:**
  - o bloqueio "Evento — Semana acadêmica" em S2 mostrou "Espaço bloqueado. Reservas canceladas: 1. Entradas de fila encerradas: 0." e apareceu na lista;
  - sem o tipo, a validação de usabilidade apareceu no diálogo, sem perder o que foi digitado;
  - com reserva em andamento (S4), a recusa do Xano apareceu dentro do diálogo, que continuou aberto: "Há uma reserva em andamento neste espaço até 16:17.".
- **Remover pela tela:** a confirmação mostra o espaço, o período e o aviso de que nada é restaurado. Depois aparece "Bloqueio removido.", e o bloqueio sai da lista.
- **Busca (25/11, 10h00–11h00):** S3 aparece "Dentro das regras do tipo" com o badge "Bloqueado" e sem nenhuma ação. S2, livre, oferece "Reservar".

**Não testado no navegador:** o menu do admin. Ele usa a mesma condição de gestor (`AuthState.e_gestor`) que o menu do coordenador, testado, e nenhuma conta de admin de teste foi criada para não tocar nas contas reais.
