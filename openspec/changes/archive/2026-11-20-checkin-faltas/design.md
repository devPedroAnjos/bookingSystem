## Context

A motivação e o escopo estão no `proposal.md`, as decisões do explore no `decisions-log.md` e os requisitos nas specs delta.

O estado atual que molda a solução:

- **Trava global:** toda rota que grava reservas ou faz gestão abre uma `db.transaction` com `travar_governanca` como primeira instrução. O Xano não tem isolamento melhor (C2, D3).
- **Faxina (C7, D3):** `aplicar_vencimentos` abre uma transação própria antes da transação principal das rotas de reserva e de fila. Ela pega a trava e chama `processar_vencimentos`, que:
  - expira até 50 pendentes;
  - chama `processar_fila`.
  
  Uma falha da faxina vai para o log e não bloqueia a operação. Nesse caso a correção vem da situação efetiva.
- **Situação efetiva:** `situacao_efetiva` só conhece PENDENTE → EXPIRADA. O predicado de ocupação `CONFIRMADA || (PENDENTE && inicio > agora)` aparece copiado em `criar_reserva`, `entrar_fila` (duas vezes), `confirmar_fila`, `buscar_espacos`, `processar_fila` e `exigir_limite_ativas`. Uma variação de "em andamento" está em `selecionar_reservas_a_cancelar`.
- **Pontos de extensão:** `criar_reserva` (passo 6), `entrar_fila` (passo 3) e `confirmar_fila` têm o comentário "recusar quem tem penalidade ativa".
- **Confirmação sem gravar:** a C8 responde `requer_confirmacao` sem gravar nada quando o deslocamento não foi confirmado.
- **Encerramento de entradas de fila:** o motivo fica só na auditoria (`ENCERRAR_FILA`, campo `motivo`), sem campo na tabela (C9, D8).
- **Lições do Xano** (memória do projeto):
  - usar `|set` em vez de objeto literal com filtros;
  - usar `is_null` em vez de comparar com `null`;
  - gravar `.xs` sem BOM;
  - dar a cada rota um nome único no workspace;
  - não há isolamento além da trava por linha.

## Goals / Non-Goals

**Goals:**
- **Uma regra de situação efetiva:** a reserva tem uma única definição de NAO_COMPARECEU e CONCLUIDA, usada pelas leituras e pelos predicados de ocupação.
- **Penalidade sempre certa no momento da decisão:** as faltas de um usuário são gravadas por inteiro e em ordem antes de qualquer decisão que dependa delas, mesmo que a faxina falhe.
- **Uma porta para os vencimentos:** NAO_COMPARECEU, CONCLUIDA, falta, penalidade e CUMPRIDA entram em `processar_vencimentos`. Assim, uma futura tarefa agendada continua chamando uma função só.

**Non-Goals:**
- Tarefa agendada, polling ou tempo real.
- Mudar o deslocamento, a busca ou a fila além da troca do predicado de ocupação e dos pontos de extensão.
- Desfazer efeitos na anulação: as entradas de fila encerradas e as reservas não voltam.
- Uma tela de faltas para coordenadores: eles só ganham os filtros em "Reservas da unidade".

## Decisions

### D1. Dados

**`reserva`:** campo novo `check_in_em` (timestamp?), que já estava previsto no DER. O enum `status` já tem `CONCLUIDA` e `NAO_COMPARECEU` desde a C6, e o `motivo_cancelamento` já tem `USUARIO_TARDIO`.

**`falta` (nova, nomes do DER):**

| Campo | Tipo | Observação |
|---|---|---|
| `id` | int | |
| `usuario_id` | int → `usuario` | o dono da reserva |
| `reserva_id` | int → `reserva` | único; garantido pela rota, dentro da trava (C2, D3) |
| `tipo` | enum `NAO_COMPARECIMENTO`, `CANCELAMENTO_TARDIO` | |
| `ocorrida_em` | timestamp | instante real: fechamento da janela ou cancelamento |
| `penalidade_id` | int? → `penalidade` | preenchido quando a falta entra numa penalidade |

Índices: `(usuario_id, ocorrida_em)` e `(reserva_id)`.

**`penalidade` (nova):**

| Campo | Tipo | Observação |
|---|---|---|
| `id` | int | |
| `usuario_id` | int → `usuario` | |
| `inicio`, `fim` | timestamp | `fim - inicio` é a duração, preservada na antecipação (D6) |
| `status` | enum `ATIVA`, `CUMPRIDA`, `ANULADA` | |
| `criado_em` | timestamp, padrão `now` | |
| `anulada_por_id` | int? → `usuario` | |
| `anulada_em` | timestamp? | |
| `parecer` | text? | **divergência do DER:** o §7.8 e o §2.13 exigem o parecer, mas o DER não tem o campo. Entra no DER no grupo de documentos |

Índices: `(usuario_id, status)` e `(status, fim)`.

- **"Instante da falta que gerou a penalidade":** não ganha campo. É o maior `ocorrida_em` das faltas vinculadas, lido só na anulação.

**`configuracao_geral`:** cinco campos novos, `checkin_antes_minutos`, `checkin_depois_minutos`, `faltas_para_penalidade`, `janela_faltas_dias` e `duracao_penalidade_dias`. Eles seguem o caminho dos parâmetros da C9: tabela, `bootstrap`, `parametros_GET`, `parametros_POST` (validação >= 1) e a tela.

Mais um campo técnico, **`comparecimento_desde`** (timestamp?), o marco a partir do qual a regra de comparecimento vale (decisão 20):
- o `bootstrap` grava `now` quando o campo está vazio e nunca o sobrescreve;
- não é parâmetro: não aparece em `parametros_GET` nem na tela e não é editável;
- reservas com `inicio < comparecimento_desde` seguem a regra anterior à C10.

Ele substitui uma migração de dados, que exigiria rota temporária ou o MCP operacional. É uma divergência do DER, registrada no grupo de documentos.

### D2. Situação efetiva e predicado de ocupação

- **Fechamento da janela:** `fim_janela = min(inicio + checkin_depois * 60000, fim)`.
- **`situacao_efetiva`** passa a receber `check_in_em`, `fim`, `checkin_depois_minutos` e `comparecimento_desde`:
  - PENDENTE com `inicio <= agora` → EXPIRADA (como hoje);
  - CONFIRMADA com `inicio < comparecimento_desde` → continua CONFIRMADA (regra anterior);
  - CONFIRMADA sem check-in e `agora > fim_janela` → NAO_COMPARECEU;
  - CONFIRMADA com check-in e `agora >= fim` → CONCLUIDA.
- **Predicado de ocupação nas consultas ao banco:**

```
PENDENTE   && inicio > agora
|| CONFIRMADA && fim > agora
              && ( check_in_em preenchido
                   || inicio >= agora - depois_ms
                   || inicio < comparecimento_desde )
```

- **`fim > agora`** exclui a CONCLUIDA efetiva e também o não comparecimento cuja janela foi cortada no fim.
- **O parêntese** exclui a NAO_COMPARECEU efetiva. O último termo protege a reserva anterior ao marco, que ocupa até o fim como antes.
- **O termo é explícito** porque `buscar_espacos` aceita intervalos que já começaram, então a sobreposição sozinha não garante que a reserva ainda esteja em curso. Antes, a CONFIRMADA terminada contava como ocupando nessas buscas. Agora não conta mais, como as outras situações finais.

- **Onde troca:**
  - `criar_reserva` (conflito);
  - `entrar_fila` (as duas consultas);
  - `confirmar_fila`;
  - `buscar_espacos`;
  - `processar_fila`;
  - `exigir_limite_ativas`;
  - em `selecionar_reservas_a_cancelar`, "em andamento" passa a excluir a NAO_COMPARECEU efetiva, e ela também sai da lista a cancelar. A função lê `checkin_depois_minutos` da configuração, com a precondição do bootstrap, sem mudar a assinatura dos chamadores (`cancelar_reservas` e `impacto_reservas`).
- **Check-in antes do início não protege contra o cancelamento automático:** a reserva com check-in que ainda não começou (`inicio > agora`) é cancelada pela inativação da conta e pelas ações de gestão, sem falta, como qualquer reserva que não começou. A regra "com check-in não se cancela" vale só para o cancelamento pelo próprio usuário.

  A tarefa de apply começa com um `grep` por `"CONFIRMADA"` para não esquecer nenhum ponto.
- **Leitura dos parâmetros:** cada ponto chama `obter_configuracao_comparecimento`, função nova no padrão de `obter_configuracao_horario` (C5, D8). Ela confere os cinco parâmetros e o marco, com a precondição do bootstrap, e devolve a configuração com `depois_ms` já calculado. Assim a mesma leitura não se repete em sete lugares.
- **Alternativa recusada:** uma função que monte o predicado. O `where` do `db.query` não aceita uma expressão vinda de função, então o predicado continua repetido e a lista acima é a garantia.
- **A confirmar via MCP no apply:** a sintaxe de "campo timestamp preenchido" dentro do `where`. A memória do projeto avisa que a comparação com `null` é frouxa.

### D3. Processamento dos vencimentos por usuário

Uma função nova, `processar_vencimentos_usuario(usuario_id, agora)`, pressupõe que quem chama já segura a trava. Ela:

1. busca as CONFIRMADA do usuário com `inicio >= comparecimento_desde` já vencidas, isto é, sem check-in com a janela fechada, ou com check-in e `fim <= agora`. O lote global usa o mesmo filtro, então as reservas antigas nunca entram no processamento;
2. calcula o instante real de cada uma (`fim_janela` ou `fim`) e as ordena por ele;
3. para cada reserva:
   - grava NAO_COMPARECEU ou CONCLUIDA, com o `MARCAR_NAO_COMPARECEU` ou o `CONCLUIR_RESERVA`;
   - se for não comparecimento, chama `registrar_falta` (D4).

As faltas de um usuário nascem assim em ordem cronológica, e a janela de 30 dias e o encadeamento (D5) saem certos.

**`processar_vencimentos` (global)** passa a:

1. expirar as pendentes, como hoje;
2. buscar até 50 CONFIRMADA vencidas de qualquer usuário, por `inicio` crescente, e chamar `processar_vencimentos_usuario` para no máximo 10 usuários distintos dessa lista, na ordem em que aparecem. Cada usuário escolhido é processado por inteiro, e os demais ficam para a próxima rodada. Cada não comparecimento custa de 3 a 5 gravações (reserva, falta, penalidade e auditorias), contra 2 da expiração da C7. Os dois tetos são técnicos, e a tarefa 7.9 os mede e ajusta;
3. gravar CUMPRIDA nas `ATIVA` com `fim <= agora`, até 50, cada uma com o `CUMPRIR_PENALIDADE` (D9);
4. chamar `processar_fila`, como hoje, por último, para as vagas liberadas pelas entradas encerradas na D7 seguirem na mesma rodada.

**Garantia dentro da transação principal.** As rotas que decidem pela penalidade (`criar_reserva`, `entrar_fila`, `confirmar_fila`) ou que gravam falta (`cancelar_reserva` tardio) chamam `processar_vencimentos_usuario` do ator dentro da transação principal, depois da trava e de `usuario_ativo`, para não processar uma conta inválida.
- **Por que dentro:** a faxina antes da transação pode falhar em silêncio, e a decisão não pode depender dela.
- **Recusa desfaz as gravações:** se a operação for recusada (por exemplo, pela penalidade), a transação desfaz as gravações do usuário. A decisão continua certa, porque é recalculada de forma determinística.
- **A faxina grava em definitivo:** `aplicar_vencimentos` ganha o input opcional `usuario_id` e processa esse usuário antes do lote global, numa transação que é confirmada. Assim as faltas ficam gravadas mesmo quando a operação principal é recusada.
- **Alternativa recusada:** só a faxina, que falha em silêncio, ou só a transação principal, que perde as gravações nas recusas.

`fazer_checkin` e `minhas_faltas` também chamam a faxina com o `usuario_id`.

### D4. `registrar_falta`

A função recebe `usuario_id`, `reserva_id`, `tipo` e `ocorrida_em`, e roda dentro da trava:

1. recusa uma segunda falta da mesma reserva. Isso é proteção, porque as rotas não deveriam chegar lá;
2. grava a falta com o `REGISTRAR_FALTA`. O ator é vazio no não comparecimento e o dono no cancelamento tardio;
3. avalia a penalidade (D5).

### D5. Geração e encadeamento da penalidade

Ao registrar a falta `F`:
1. **Conta as faltas:** as do usuário com `penalidade_id` vazio e `F.ocorrida_em - janela_dias * 86400000 <= ocorrida_em <= F.ocorrida_em`. A janela inclui o limite exato de 30 dias, e a decisão 15 registra isso.
2. **Gera a penalidade** quando a contagem é `>= faltas_para_penalidade`:
   - `inicio = max(F.ocorrida_em, maior fim das penalidades não ANULADA do usuário)`;
   - `fim = inicio + duracao_dias * 86400000`;
   - `status = ATIVA`.
3. Vincula **todas** as faltas contadas. Com o parâmetro reduzido, pode haver mais que N.
4. Grava o `APLICAR_PENALIDADE`, com ator vazio e as faltas nos dados depois.
5. Se a penalidade está em vigor no `agora` da operação, encerra as entradas de fila do usuário (D7).

**Dias corridos em milissegundos:** America/Sao_Paulo não tem horário de verão desde 2019, então 7 dias são 7 × 86 400 000 ms.

### D6. Penalidade em vigor, mensagem e anulação

**`penalidade_em_vigor(usuario_id, agora)`** (função nova) lê as `ATIVA` do usuário com `fim > agora`, ordenadas por `inicio`. Se a primeira tem `inicio <= agora`, percorre a cadeia enquanto o próximo `inicio == fim` do anterior e devolve `{em_vigor, ate}`. Os três pontos de extensão chamam essa função depois de `processar_vencimentos_usuario` e recusam com "Você está com penalidade até DD/MM/AAAA às HH:MM.", no horário de America/Sao_Paulo, via `formatar_reserva`.

**Anulação (`anular_penalidade`, admin)**, numa transação com a trava:
1. confere o papel ADMIN, que a penalidade é `ATIVA` com `fim > agora` (em vigor ou futura), que não é do próprio admin e que o parecer tem de 1 a 500 caracteres;
2. grava `ANULADA`, quem anulou, quando e o parecer;
3. **antecipa as encadeadas:**
   - parte de `anterior_fim` = maior `fim` das penalidades não anuladas do usuário com `inicio` menor que o da anulada;
   - percorre, em ordem de `inicio`, as `ATIVA` do usuário com `inicio >=` o da anulada;
   - para cada uma, `gatilho` = maior `ocorrida_em` das faltas dela, `novo_inicio = max(gatilho, anterior_fim)` e `novo_fim = novo_inicio + (fim - inicio)`;
   - grava se mudou e atualiza `anterior_fim`;
4. grava o `ANULAR_PENALIDADE` com o parecer e as antecipadas.

**Alternativas recusadas:**
- recalcular a cadeia inteira a partir das faltas, o que mudaria penalidades anteriores à anulada;
- gravar o gatilho num campo, uma redundância que a leitura na anulação dispensa.

### D7. Fila do penalizado

Quando a penalidade nasce em vigor, as entradas `AGUARDANDO` e `NOTIFICADA` do usuário ficam `ENCERRADA`, cada uma com um `ENCERRAR_FILA` de ator vazio e motivo `PENALIDADE`.
- **Vagas retidas:** a liberação fica para o `processar_fila` que roda no fim de `processar_vencimentos` e de `cancelar_reserva`.
- **Dentro da transação principal:** se a penalidade nascer em `criar_reserva`, `entrar_fila` ou `confirmar_fila`, a recusa desfaz o encerramento, e a faxina já o terá gravado antes (D3).
- **Barreira extra:** `processar_fila` não muda, porque `confirmar_fila` recusa o penalizado.
- **Alternativa recusada:** pular o penalizado no aviso dentro de `processar_fila` (decisão 4).
- **Limitação aceita:** uma penalidade que entra em vigor pela passagem do tempo, e não ao nascer, não encerra entradas. Isso só acontece depois de uma anulação que deixa um intervalo antes da próxima penalidade da cadeia. Nesse intervalo o usuário pode entrar na fila, e depois a confirmação o recusa enquanto a penalidade estiver em vigor (cenário "Penalidade que entra em vigor com o tempo").

### D8. Rotas e respostas

| Rota | Grupo | Mudança |
|---|---|---|
| `fazer_checkin` POST | `reservas` | nova: `reserva_id`; faxina com o usuário, trava, recusas da spec e grava `check_in_em` com o `CHECK_IN` |
| `minhas_faltas` GET | `reservas` | nova: faxina com o usuário e depois as faltas (com espaço, data e hora da reserva) e as penalidades (situação efetiva, parecer se anulada), além de `em_vigor` e `ate` |
| `penalidades` GET | `contas` | nova, só admin: filtros `situacao` (`EM_VIGOR` padrão, `ATIVA`, `CUMPRIDA`, `ANULADA`, `TODAS`) e `busca` (nome ou e-mail); teto de 200 com `limitada`; usuário, faltas e anulação |
| `anular_penalidade` POST | `contas` | nova: `penalidade_id`, `parecer` |
| `cancelar_reserva` POST | `reservas` | input `aceitar_falta` (bool, padrão falso); a resposta ganha `requer_confirmacao`, no padrão da C8 |
| `minhas_reservas` GET | `reservas` | `pode_cancelar` (nome mantido da C6, nova regra: antes do início e sem check-in), `cancelamento_gera_falta`, `check_in_em` e `check_in_hora`, `checkin_abre` e `checkin_fecha` (HH:MM em São Paulo), `checkin_possivel` e `falta` (tipo derivado da situação efetiva, visível antes da gravação); situação efetiva nova |
| `reservas_unidade` GET | `reservas` | situações aceitas mais `CONCLUIDA` e `NAO_COMPARECEU`; o filtro `CONFIRMADA` exclui as vencidas; campo `check_in_em` |

- **Grupos já existentes:** nenhuma variável de ambiente nova. Os nomes das rotas são únicos no workspace.
- **Escopo da listagem:** `penalidades` é global porque a penalidade é do usuário, não de uma unidade. Só o admin acessa, e o coordenador não tem escopo sobre penalidades.

**`cancelar_reserva`, nova ordem dentro da trava** (`agora` é capturado uma única vez, antes do passo 1, e usado na classificação e no `ocorrida_em` da falta, porque o passo 6 pode levar segundos e cruzar o limite do prazo):
1. conta;
2. reserva própria;
3. ativa: PENDENTE ou CONFIRMADA, e não vencida;
4. `inicio > agora` (senão "a reserva já começou");
5. sem check-in;
6. `processar_vencimentos_usuario`;
7. classificação:
   - **no prazo, ou PENDENTE:** `USUARIO`;
   - **senão, sem `aceitar_falta`:** responde `requer_confirmacao` com status 200, sem alterar a reserva. Não pode ser um erro, porque um erro desfaria os vencimentos gravados no passo 6;
   - **senão:** `USUARIO_TARDIO` e `registrar_falta` com `ocorrida_em = agora`;
8. `processar_fila`.

### D9. Auditoria

As ações `CHECK_IN`, `MARCAR_NAO_COMPARECEU`, `CONCLUIR_RESERVA`, `REGISTRAR_FALTA`, `APLICAR_PENALIDADE`, `CUMPRIR_PENALIDADE` e `ANULAR_PENALIDADE` seguem a spec, e `CANCELAR_RESERVA` e `ENCERRAR_FILA` ganham motivos novos.
- **Unidade:**
  - falta: a unidade do espaço da reserva;
  - penalidade: vazia, porque não é de uma unidade.
- **CUMPRIDA auditada:** `CUMPRIR_PENALIDADE` com ator vazio e o `fim` como instante, no padrão de `EXPIRAR_RESERVA` (decisão 17).

### D10. Reflex

- **`xano_cliente.py`:** `fazer_checkin`, `minhas_faltas`, `listar_penalidades` e `anular_penalidade`, e o `cancelar_reserva` com `aceitar_falta`.
- **"Minhas reservas"** (`reservas_state.py`, `minhas_reservas.py`):
  - botão "Fazer check-in";
  - diálogo de cancelamento com o aviso de falta e um segundo passo quando a API responde `requer_confirmacao`;
  - selos de falta, check-in, concluída e não compareceu;
  - seção "Faltas e penalidades" (estado próprio carregado no `abrir`), com o destaque da penalidade em vigor.
- **Página "Penalidades"** (`penalidades.py`, `penalidades_state.py`):
  - guarda `exigir_admin`;
  - filtros e lista com as faltas;
  - diálogo "Anular" com parecer obrigatório.
- **Outros ajustes:**
  - menu em `layout.py`;
  - rota em `bookingSystem.py`;
  - opções novas no filtro de "Reservas da unidade" e o check-in na linha da reserva;
  - cinco campos novos em "Parâmetros".
- **Rótulos:** ficam onde já estavam e não precisaram mudar. `USUARIO_TARDIO` já tinha "cancelada por você depois do prazo" em `motivos.py`, e "Concluída" e "Não compareceu" já estavam em `SITUACOES` (`reservas_state.py`). Só os tipos de falta, que são novos, ficaram em `TIPOS_FALTA` (`faltas_state.py`), usados pela seção e pela página "Penalidades".

### D11. Documentos

| Documento | Seções e ajustes |
|---|---|
| `project-overview.md` | **§7.8:** pendente sem falta, cancelamento só antes do início e sem check-in, tardio com confirmação, janela limitada ao fim, encerramento das entradas de fila, anulação só pelo admin e nunca da própria |
| | **§8:** os vencimentos do comparecimento e das penalidades na porta única |
| | **§10:** as ações novas de auditoria |
| | **§11:** as pendências da C6, C7 e C9 marcadas como resolvidas na C10 |
| `domain-model.md` | **§2.9:** "em andamento" exclui o não comparecimento, e o `USUARIO_TARDIO` só vale para `CONFIRMADA` |
| | **§2.12:** `ocorrida_em` como instante real |
| | **§2.13:** o termo "em vigor" e a anulação apenas de `ATIVA` |
| | **§2.18:** nenhuma mudança de valores |
| | **DER:** `penalidade.parecer` e `configuracao_geral.comparecimento_desde` |

## Confirmações do apply

Tarefa 1.3: sonda `sonda_c10.xs` na pasta temporária, validada no MCP e nunca publicada.

| Item | Resultado |
|---|---|
| Campo timestamp opcional no `where` | `$db.reserva.check_in_em != null` e `== null` são aceitos pelo validador. **O comportamento em execução** (se viram `IS NULL` ou `IS NOT NULL`) só se confirma no teste 7.5, com uma reserva com e outra sem check-in. Se falhar, o plano B é consultar a CONFIRMADA com `fim > agora` e filtrar em memória com `|is_null`. |
| `max` e `min` entre dois inteiros | O validador aceita `x\|max:y` e `x\|min:y`, mas os dois também são aliases das versões de lista (`array_max` e `array_min`), como a C9 já registrou em `corte_fila`. Por isso, a implementação usa `conditional`: o fechamento da janela fica na função `fechamento_checkin` (cinco usos), e os dois `max` da penalidade são calculados no próprio lugar. Os aliases `num_max` e `num_min` da documentação **não** passam no validador. |
| `\|max` sobre lista mapeada | `($lista\|map:$$.inicio\|max)\|to_int` é válido. |
| Input bool opcional com padrão | `bool aceitar_falta?=false` é válido. |
| Edição em lote | `db.edit` dentro de `foreach` é válido. O `db.bulk.update` com `where` da documentação **não** passa no validador, então não é usado. |

Tarefa 4.1: limites da `situacao_efetiva`, com a reserva das 14h00 às 15h00, janela fechando 15 minutos depois do início e marco anterior ao início.

| Estado gravado | Check-in | Agora | Situação efetiva |
|---|---|---|---|
| PENDENTE | não | 13h59 | PENDENTE |
| PENDENTE | não | 14h00 | EXPIRADA |
| CONFIRMADA | não | 14h15 (= fechamento) | CONFIRMADA |
| CONFIRMADA | não | 14h15 + 1 ms | NAO_COMPARECEU |
| CONFIRMADA (14h00 às 14h10) | não | 14h10 + 1 ms (fechamento cortado no fim) | NAO_COMPARECEU |
| CONFIRMADA | sim | 14h59 | CONFIRMADA |
| CONFIRMADA | sim | 15h00 (= fim) | CONCLUIDA |
| CONFIRMADA com início antes do marco | não | qualquer | CONFIRMADA |

Tarefa 6.6: `penalidades` usa `usuario_id in? $ids_buscados` para ignorar o filtro quando não há busca. O validador aceita o `in?`, mas a documentação só mostra o `==?` e o `>=?`. O teste 7.8 confere a listagem com e sem busca. Se o `in?` não ignorar o nulo, o plano B é uma consulta por ramo, com e sem busca.

Na `situacao_efetiva`, os inputs novos são opcionais. Sem eles, só vale a expiração da pendente, e os dois chamadores (`minhas_reservas` e `reservas_unidade`) passam todos.

## Resultados dos testes do backend (grupo 7)

Os testes rodaram com scripts descartáveis no scratchpad, contra o workspace, no relógio real, com o log em `log_c10.txt`.

**Cenário de teste:**
- **Tipos:** 16 ("TST C10 Livre") e 17 ("TST C10 Aprov", com aprovação de aluno).
- **Espaços:** 155 a 164, na unidade 1.
- **Contas:** alunos 117 a 124, professor 125 e um segundo admin (126).
- **Parâmetros de teste:** granularidade de 1 minuto e janela de 1 minuto antes e 1 depois (3 depois na fase da janela cortada). São restaurados na limpeza.
- **Leitura:** a função temporária `tst_c10_consulta` (só leitura), publicada com aprovação.
- **Faltas antigas:** gravadas com `xano function run registrar_falta`, com autorização do usuário, só na conta 117.

| Bateria | Escopo | Resultado |
|---|---|---|
| A (7.4, 7.5) | Janela, check-in, não comparecimento, conclusão, horário liberado e gestão | 31/31 |
| B (7.6 a 7.8) | Cancelamento tardio, penalidade, cadeia, fila do penalizado e anulação | 43/44. A falha é do roteiro e saiu como "Missing param: reserva_id". A reserva do caso não chegou a ser criada, porque a conta já estava penalizada pelas duas faltas da bateria A (linhas `!!` do log). O cancelamento então foi chamado sem reserva. O caso foi refeito na C e passou. |
| C (7.6, 7.7, 7.9, 7.10) | Casos restantes, faltas antigas pelo CLI, concorrência e volume | 17/19. As duas falhas são do roteiro: a pendente não foi criada porque o espaço estava ocupado. Os casos foram refeitos na D e passaram. |
| D | Expiração (regressão) | 3/3 |
| E | Filtros de `reservas_unidade` e validação dos parâmetros novos | 12/12 |
| F | Lacunas apontadas pelo guardian no grupo 7 | 20 casos. Dois falharam por erro de leitura da saída do CLI no script (7.1) e foram refeitos, com bootstrap repetido sem ajustes e o marco inalterado. Outros dois são do teto do lote (7.9), explicados abaixo. Passaram também: `confirmar_fila` (7.10); anulação de cumprida recusada; duração preservada com o parâmetro em 3 dias; faltas que continuam vinculadas; reserva mantida; confirmação da fila recusada pela penalidade; fim exato da penalidade; check-in pouco antes do fechamento. |
| 7.2 | Reservas antigas (antes do marco) | 23 `CONFIRMADA` já terminadas continuam `CONFIRMADA`; nenhuma falta nem penalidade nas contas 1 a 116 |

**Confirmado em execução:**
- `== null` e `!= null` no `where`, tanto para `check_in_em` quanto para `penalidade_id`;
- `in?` com e sem busca;
- os dois `max` e `min` feitos com `conditional`;
- o padrão descartado de `aceitar_falta`.

**Volume (7.9):**
- 50 reservas vencidas de um só usuário foram gravadas pela faxina desse usuário em **10,7 s**: 50 `NAO_COMPARECEU`, 50 faltas e 25 penalidades encadeadas, sem sobreposição;
- a 51ª reserva não chegou a ser criada, porque o espaço do tipo com aprovação estava ocupado. Como `processar_vencimentos_usuario` não tem teto, 50 ou 51 não muda o resultado;
- **teto do lote global:** 56 reservas vencidas de 12 contas novas. A auditoria mostra duas rodadas, e todos os usuários envolvidos são do lote:
- **10h21:** disparada por uma operação de fora do script, com as contas 127, 128 e 129, que eram as que já tinham reservas vencidas;
- **10h29:** a do gatilho, com exatamente 10 usuários.

A conta 129 aparece nas duas rodadas. Às 10h21, só parte das reservas dela tinha vencido, e a rodada gravou todas as que já tinham vencido. As outras venceram depois e ficaram para a rodada seguinte. Por isso as duas rodadas somam 13 usuários, mas são 12 contas distintas, todas gravadas por inteiro. A situação efetiva cobriu as reservas ainda não gravadas. Só o teto de 10 usuários foi medido, e o teto de 50 reservas por rodada não foi exercitado à parte. Os dois casos da bateria F que falharam partiam da premissa de que nada seria gravado antes do gatilho, e a rodada externa quebrou essa premissa. O teto em si foi confirmado pela auditoria.

**Concorrência (7.9), uma rodada por cenário, sem controle da ordem real:**
- check-in disputando com a gravação perto do fechamento: venceu o não comparecimento, e nunca ficaram check-in e falta juntos;
- cancelamento tardio disputando com a desativação: venceu a desativação, sem falta;
- duas anulações simultâneas: só uma foi gravada.

**Não testado (aceito sem teste):**
- **check-in nos limites de 08h00 e 22h00–22h40:** o horário do teste não permitia. A janela não depende do horário do tipo;
- **limites ao milissegundo:** a janela e a penalidade foram testadas a poucos segundos de cada limite, dos dois lados. O limite exato está na tabela da 4.1, conferida na leitura do código;
- **"1 minuto" antes da abertura:** o caso testado foi a cerca de 4 minutos. Com a janela de 1 minuto, os casos de poucos segundos de cada lado cobrem o comportamento;
- **falha simulada da faxina:** não há como forçar a falha sem mudar o código. A decisão de penalidade dentro da transação principal foi exercitada em todas as rotas;
- **coordenador nas rotas de penalidade:** o acesso negado foi conferido com aluno, professor e admin secundário (parâmetros), e as rotas usam `exigir_admin`;
- **penalidade nascendo com filas de intervalos sobrepostos:** o encerramento das entradas e a passagem da vaga ao próximo foram testados numa fila só. As filas sobrepostas seguem o `processar_fila` da C9, que não mudou.

## Resultados dos testes do frontend (grupo 8)

Navegador com Playwright, contra o app em modo produção (`reflex run --env prod --single-port`), com as contas de teste. O `reflex compile --dry` passou antes e depois da correção abaixo.

**"Minhas reservas" (a8):**
- **Antes do check-in:** "Fazer check-in" aparece durante a janela, com o texto "Check-in das HH:MM às HH:MM".
- **Depois do check-in:** a linha mostra "Check-in às 10:34" e fica sem botões.
- **Cancelamento tardio:**
  - o diálogo avisa da falta, e o botão muda para "Cancelar e aceitar a falta";
  - depois de confirmar, aparece a mensagem com a falta, e a seção passa a mostrar a penalidade em vigor em destaque, as duas faltas com "Gerou" e o selo "Falta: Cancelou depois do prazo" no histórico.
- **Histórico:** traz os selos "Concluída" (com o check-in) e "Não compareceu" (com a falta).

**Troca de conta (8.5):** depois de sair da conta a8 e entrar com o admin de teste, nenhum dado de a8 apareceu. A seção mostrou as faltas e a penalidade anulada do admin de teste, com o parecer e sem o nome de quem anulou.

**"Penalidades" (admin secundário):**
- o menu mostra "Penalidades" e não mostra "Administradores" nem "Parâmetros";
- a lista em vigor traz as faltas de cada penalidade;
- "Anular" sem parecer mostra a recusa dentro do diálogo, que continua aberto;
- com parecer, a anulação é confirmada e a lista se atualiza;
- o filtro "Todas" com busca por e-mail mostra "Anulada por … em …: parecer".

**"Reservas da unidade":** os filtros "Concluídas" e "Não compareceu" aparecem. Com "Concluídas", cada linha mostra o check-in.

**Acesso:** o aluno que digita `/penalidades` é levado para o Início.

**Console:** nenhum erro durante a sessão. Só apareceram erros de conexão quando o servidor foi reiniciado de propósito.

**Correção feita no teste:** a seção "Faltas e penalidades" dizia "Você não tem faltas nem penalidades" enquanto ainda carregava. Ela passou a mostrar um indicador de carregamento até os dados chegarem (decisão 30).

**Fluxo completo (9.1), só pela tela, com o aluno a4 (que já tinha 1 falta) e o admin de teste:**
1. a4 cancela pela tela uma reserva a menos de 2 horas, com o aviso de falta;
2. a seção mostra a penalidade em vigor;
3. na busca, "Reservar" é recusado dentro do diálogo com "Você está com penalidade até 27/11/2026 às 10:46";
4. o admin anula pela página "Penalidades", com parecer;
5. a4 reserva de novo o mesmo espaço e horário, e a reserva é confirmada.

Captura em `.playwright-mcp/c10_9_1_reserva_apos_anulacao.png`, apagada na limpeza. Depois do reinício do servidor, o console não teve nenhum erro.

**Não testado no navegador:**
- **página "Parâmetros":** é só do admin principal, e a senha dele não é digitada no navegador. Os campos foram conferidos pela API (bateria E) e pela revisão de `LIMITES` e `ROTULOS_LIMITES`, como na C9;
- **segundo passo do aviso de falta:** quando o prazo vence entre a carga da página e o clique, a API devolve `requer_confirmacao` (testado na bateria B). O diálogo então mostra o aviso e espera o novo clique, comportamento conferido na leitura de `confirmar_cancelar`;
- **filtro "Não compareceu" na tela:** foi testado pela API (bateria E). Na tela, foi exercitado o filtro "Concluídas".

## Risks / Trade-offs

- **Volume de gravação:** toda reserva confirmada acaba gerando uma gravação (NAO_COMPARECEU ou CONCLUIDA) e um registro de auditoria. Isso aumenta o trabalho da faxina.
  → Mitigação: teto de 50 reservas por rodada no lote global; o que sobrar fica coberto pela situação efetiva. A tarefa de testes mede o tempo com acúmulo, como a C7 e a C9 fizeram.
- **Processamento do usuário dentro da transação principal:** diferente da faxina, ele não é protegido pelo `try_catch`. Um erro nele derruba `criar_reserva`, `entrar_fila`, `confirmar_fila` e `cancelar_reserva`, e a trava global fica retida pelo tempo do processamento.
  → Mitigação: o caso comum é uma consulta vazia. Os testes 7.5 a 7.9 exercitam a função antes das rotas, e o 7.9 mede o tempo com 20 vencidas. Se um erro aparecer em produção, a operação falha de forma visível em vez de decidir a penalidade errado.
- **Usuário com muitas reservas vencidas:** `processar_vencimentos_usuario` não tem teto.
  → Mitigação: o volume de um usuário é limitado pelo limite de ativas por tipo e pelo tempo entre operações. O teste mede um caso com 20 vencidas.
- **Encadeamento por `inicio == fim`:** depende de os timestamps serem gravados idênticos.
  → Mitigação: os dois saem do mesmo cálculo em ms, sem arredondamento. O teste cobre a cadeia de três penalidades.
- **Parâmetros mudados durante uma reserva:** mudar a janela de check-in altera as reservas já criadas (decisão 9). Reduzir o fechamento da janela enquanto uma reserva está na janela pode transformá-la em NAO_COMPARECEU com falta retroativa, com o instante calculado pela regra nova.
  → Aceito pelo usuário (decisão 23), com o aviso na tela de parâmetros.
- **Check-in antes do deslocamento:** com `checkin_antes_minutos >= prazo_deslocamento_minutos`, uma reserva com check-in feito ainda poderia ser deslocada. Com os padrões (15 e 120) isso não acontece.
  → Registrado como limitação. Não há validação cruzada de parâmetros nesta change.
- **Penalizado inativado:** a conta inativada pode ficar com reserva em andamento que vira falta. A penalidade nasce para uma conta inativa e não tem efeito até a reativação.
  → Aceito: a falta é verdadeira.
- **Sintaxe de nulo no `where`:** ver D2.
  → Confirmar no MCP e testar os dois casos (com e sem check-in) antes de trocar os sete pontos.

## Migration Plan

1. Publicar as tabelas `falta` e `penalidade`, o campo `check_in_em` e os campos de `configuracao_geral` com dry-run e aprovação, e rodar o `bootstrap`, que só preenche os vazios.
2. Publicar as funções, depois as rotas e depois o Reflex.
3. **Reservas antigas, sem migração de dados (decisão 20):** o `bootstrap` grava `comparecimento_desde` antes de qualquer rota nova ser publicada. As reservas que começaram antes do marco continuam `CONFIRMADA`, sem falta, e as que começam depois seguem a C10.
4. **Rollback:** reverter as rotas para a versão anterior pelo Git e publicar com dry-run. As tabelas novas podem ficar, porque não são lidas pelo código antigo.
