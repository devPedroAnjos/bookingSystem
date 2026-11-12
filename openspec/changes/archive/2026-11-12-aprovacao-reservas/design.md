## Context

Motivação e escopo: ver `proposal.md`. As decisões do explore estão no `decisions-log.md`.

Estado atual que molda a solução:
- **Reserva (C6):**
  - a tabela `reserva` já tem os estados `RECUSADA` e `EXPIRADA`;
  - faltam os campos da decisão (C6, design D1);
  - os índices são `espaco_id` + `inicio` e `usuario_id`.
- **Trava:** toda rota que grava reservas abre `db.transaction` com `travar_governanca` como primeira instrução. O Xano deste projeto não tem isolamento de transação; a trava por linha é a única exclusão mútua comprovada.
- **Rollback:** um `precondition` que falha dentro de `db.transaction` desfaz tudo o que a transação gravou e solta a trava (memória do projeto, medição da C2).
- **Plano gratuito do Xano:** não executa tarefas agendadas. O usuário conferiu no painel durante o explore.
- **Funções prontas:**
  - `carregar_espaco_gerido`: admin em tudo; coordenador só nas unidades que coordena; 403 igual para espaço inexistente ou fora do escopo;
  - `unidades_coordenadas`;
  - `formatar_reserva` (data e horas em São Paulo);
  - `registrar_auditoria`, que aceita ator vazio.
- **Recusa de cadastro (C2):** `recusar_POST` usa motivo em texto com `trim`, de 1 a 500 caracteres. O Reflex tem o padrão `dialogo_recusa` em `aprovacoes.py`.
- **Reflex:**
  - `tratar_erro_api` manda para o início em 403, então as recusas que o usuário deve ler na mesma tela são 400;
  - o cliente já tem `listar_unidades_geridas` e `listar_espacos_geridos`, que servem de opções para os filtros.

## Goals / Non-Goals

**Goals:**
- Uma pendente vencida nunca ocupa o horário, com ou sem a expiração gravada.
- Um único ponto que grava vencimentos, reaproveitável pela C8 e pela C9 e por uma `task` futura, se o plano mudar.
- Uma única regra de "situação efetiva", usada por todas as leituras.
- A decisão de uma pendente é atômica com o cancelamento, a expiração e as ações de gestão.

**Non-Goals:**
- Gravar a expiração no exato instante do início.
- Paginação da listagem da unidade (como em "Minhas reservas" na C6).
- Alterar `impacto_reservas`, as cinco ações de gestão e `inativar`. Eles continuam como na C6.

## Decisions

### D1. Campos e índice da tabela `reserva`

| Campo | Tipo | Observação |
|---|---|---|
| `decidido_por_id` | int?, referência a `usuario` | quem aprovou ou recusou |
| `decidido_em` | timestamp? | instante da decisão |
| `motivo_recusa` | text? com `trim` | só na recusa; de 1 a 500 caracteres |

- **Nomes:** os do DER, sem divergência.
- **Expiração:** não preenche nenhum dos três, porque não há quem decida. O instante do vencimento fica na auditoria (D8).
- **Índice novo:** `status` + `inicio`. Serve à faxina (`PENDENTE` com `inicio <= agora`) e à listagem por situação.

### D2. Situação efetiva e ocupação

Toda leitura e toda verificação passam a usar a mesma regra:

| Gravado | Condição | Situação efetiva | Ocupa o horário |
|---|---|---|---|
| `PENDENTE` | `inicio > agora` | `PENDENTE` | sim |
| `PENDENTE` | `inicio <= agora` | `EXPIRADA` | não |
| `CONFIRMADA` | — | `CONFIRMADA` | sim |
| demais | — | o próprio valor | não |

- **Função nova `situacao_efetiva(status, inicio, agora)`:** usada nas listagens, item por item.
- **Nas consultas ao banco**, a ocupação vira o predicado `status == "CONFIRMADA" || (status == "PENDENTE" && inicio > agora)`. Ele vale no conflito e no limite de ativas de `criar_reserva` e na ocupação de `buscar_espacos`.
- **A correção não depende da faxina (D3).** Mesmo que uma pendente vença entre a faxina e a verificação, o predicado a ignora.
- **Consequência:** o banco pode ter, por algum tempo, uma `PENDENTE` vencida e uma reserva nova sobrepostas. Por isso toda leitura futura (C8 deslocamento e fila, C10 bloqueio, C14 relatórios) DEVE usar a situação efetiva.
- **Exceção deliberada:** as cinco ações de gestão e `impacto_reservas` mantêm `status in [PENDENTE, CONFIRMADA]`, porque a C6 exige que elas cancelem e contem a pendente já iniciada.
- **Alternativa descartada:** confiar só na faxina e manter a consulta `status in [PENDENTE, CONFIRMADA]`. Ela falharia no intervalo entre as duas transações (D3), e nas leituras sem trava não haveria faxina nenhuma.

### D3. Faxina de vencimentos em transação própria

Funções novas:
- **`processar_vencimentos(agora)`:**
  - pressupõe que quem chama já segura a trava;
  - busca as `PENDENTE` com `inicio <= agora` pelo índice do D1;
  - grava `EXPIRADA` e gera um `EXPIRAR_RESERVA` por reserva (D8);
  - processa no máximo 50 reservas por rodada, das que venceram primeiro. Esse teto é técnico, como a frequência de uma `task`, e não um limite de negócio. O que sobrar continua coberto pelo D2 e vai na próxima rodada. O teto começou em 200; o teste 7.6 mediu cerca de 97 ms por reserva, o que daria uns 19 s com 200, e ele foi reduzido para 50 (decisions-log 35);
  - devolve a quantidade;
  - é idempotente: rodar de novo não acha nada.
- **`aplicar_vencimentos()`:** abre `db.transaction`, chama `travar_governanca` e chama `processar_vencimentos(now)`. É a única forma de as rotas chamarem a faxina.

Rotas que chamam `aplicar_vencimentos` **antes** da transação principal delas: `criar_reserva`, `cancelar_reserva`, `aprovar_reserva` e `recusar_reserva`.

**Ordem dentro de cada rota:**
1. Validação do formato da entrada, sem ler estado: a conversão do horário em `criar_reserva` e o motivo em `recusar_reserva`. Uma recusa aqui não aciona a faxina.
2. `aplicar_vencimentos`.
3. A transação principal.

**Outros pontos:**
- **A faxina roda antes da autorização.** Uma chamada que depois recebe 403 (por exemplo, um aluno chamando `aprovar_reserva`) também a dispara. É inofensivo, porque a faxina só grava o que já venceu, com ator vazio.
- **Falha da faxina não bloqueia a operação.** O `try_catch` fica dentro de `aplicar_vencimentos`. A correção da operação principal não depende da faxina (D2). Sem isso, um erro na faxina travaria todas as criações, os cancelamentos e as decisões.
  - **A falha não deixa rastro em produção.** O `debug.log` só aparece em execução de depuração. Uma falha permanente da faxina se notaria por pendentes vencidas acumuladas como `PENDENTE` no banco, enquanto as telas continuam certas pela situação efetiva.

- **Por que uma transação separada:**
  - a spec exige que a expiração fique gravada mesmo quando a operação é recusada (requisito "Gravação da expiração");
  - dentro da transação principal, qualquer `precondition` desfaria a faxina.
  - O custo é pegar a trava duas vezes por requisição, o que é aceitável na escala acadêmica.
- **Por que não chamar nas ações de gestão:**
  - a spec `reservas` (C6) exige que a pendente já iniciada seja **cancelada** com `ESPACO_INDISPONIVEL`;
  - o aviso de `impacto_reservas` precisa contar exatamente o que a ação cancela.
- **Volume:** teto de 50 por rodada. Critério de aceitação da tarefa 7.6: uma operação que expira cerca de 30 pendentes termina em até 10 s (medido: 5,3 s, com 2,1 s de espaçamento do teste). Com mais de 50 vencidas, a primeira operação expira 50 e a seguinte, o restante.
- **Alternativa descartada:** chamar `processar_vencimentos` dentro da transação principal. Uma recusa desfaria a gravação, e a expiração ficaria pendurada até a primeira operação aceita.

### D4. Vencimentos sem tarefa agendada (padrão do projeto)

Enquanto o plano for gratuito, nenhum vencimento depende de relógio no servidor. Três regras valem para esta change e para as próximas:
1. **Uma porta só.** Todo vencimento é gravado por `processar_vencimentos`, chamada por `aplicar_vencimentos`. Nenhuma rota grava vencimento por conta própria. As changes seguintes acrescentam seus vencimentos a essa função.
2. **Uma verdade só para leitura.** Toda leitura de reservas (e, depois, de fila e penalidade) usa a situação efetiva (D2). Nenhuma tela nem relatório lê o `status` gravado diretamente.
3. **O instante real, não o da constatação.** Cada vencimento registra quando de fato venceu: a expiração usa o início da reserva (D8); na C9, a falta usará o fim da janela de check-in. As consequências (penalidade, prazos) são calculadas a partir desse instante. Assim, o atraso da faxina nunca muda o resultado.

**Migração para um plano pago:** uma `task` agendada chama `aplicar_vencimentos`. Nada mais muda, e o D2 continua como rede de segurança.

**Alternativas descartadas:**
- *Gatilho externo pelo servidor Reflex ou por um cron (por exemplo, GitHub Actions):*
  - exige uma credencial de serviço, e o domínio não tem usuário "sistema";
  - deixa a expiração dependendo do Reflex estar no ar;
  - o cron externo seria tecnologia nova (AGENTS §3).
- *Plano pago:* tem custo, e quem decide é o usuário.

### D5. Quem decide e a própria reserva

Função nova `carregar_reserva_gerida(ator_id, reserva_id, emitido_em)`, chamada depois da trava, seguindo o padrão de `carregar_espaco_gerido`:
1. `usuario_ativo`. Se o papel não for `ADMIN` nem `COORDENADOR`, responde 403 "Você não tem acesso à gestão de reservas.".
2. Lê a reserva e o espaço dela.
3. Admin: reserva inexistente dá 404 "Reserva não encontrada.".
4. Coordenador: reserva inexistente, ou de espaço cuja unidade **atual** ele não coordena, dá 403 "Você não tem acesso a esta reserva.".
5. Devolve o ator, a reserva e o espaço.

Nas rotas de decisão, depois dela, nesta ordem:
- **Própria reserva:** `reserva.usuario_id == ator.id` dá 400 "Sua própria reserva é decidida por outro coordenador da unidade ou por um administrador.".
- **Prazo:** `EXPIRADA`, ou `PENDENTE` com `inicio <= agora`, dá 400 "O prazo de decisão terminou: a reserva começou sem aprovação.".
- **Situação:** qualquer outra que não seja `PENDENTE` dá 400 "Esta reserva não está pendente.".

A ordem põe primeiro a autorização, depois a regra da pessoa e por último o estado. Como a faxina já rodou (D3), o `EXPIRADA` aparece com a mensagem de prazo, não com a de "não está pendente".

### D6. Rotas de decisão

**`aprovar_reserva` (POST, entrada `reserva_id`):**
1. `aplicar_vencimentos`.
2. Transação com trava, chamando `carregar_reserva_gerida` e as checagens do D5.
3. Grava `CONFIRMADA`, `decidido_por_id` e `decidido_em`, e registra `APROVAR_RESERVA`.
4. Resposta: "Reserva aprovada.".
- Não confere de novo as regras, o limite nem o conflito (spec `aprovacao-reservas`).

**`recusar_reserva` (POST, entradas `reserva_id` e `motivo`):**
1. Antes da faxina e fora da trava, valida `motivo` com `trim`: obrigatório ("Informe o motivo da recusa.") e até 500 caracteres ("O motivo deve ter no máximo 500 caracteres."), com as mesmas mensagens da recusa de cadastro.
2. Depois segue como a aprovação, gravando `RECUSADA` e `motivo_recusa`.
3. Resposta: "Reserva recusada.".

- **Nomes de rota:** únicos no workspace, porque o CLI casa rotas pelo nome.
- **Alternativa descartada:** uma rota só `decidir_reserva` com um campo de decisão. Duas rotas deixam a validação do motivo e a auditoria mais simples.

### D7. Rotas alteradas

| Rota | Mudança |
|---|---|
| `criar_reserva` | Chama `aplicar_vencimentos` antes da transação. O limite de ativas e o conflito usam o predicado de ocupação do D2, com o `agora` lido dentro da trava. |
| `cancelar_reserva` | Chama `aplicar_vencimentos` antes da transação. A pendente vencida chega como `EXPIRADA` e recebe "Esta reserva não está ativa.". A checagem de prazo cobre a corrida de milissegundos entre as duas transações. |
| `minhas_reservas` | O `status` devolvido passa a ser a situação efetiva. `pode_cancelar` só vale quando a situação efetiva é ativa. Devolve `motivo_recusa`. Não devolve quem decidiu, assim como já não devolve quem cancelou. |
| `buscar_espacos` | A consulta de ocupação usa o predicado do D2. Não grava nada. |

O Reflex já separa "Próximas" e "Histórico" pelo `status`, então a pendente vencida, devolvida como `EXPIRADA`, vai para o histórico sem mudança nessa regra.

### D8. Auditoria

| Ação | Ator | Unidade | Dados antes | Dados depois |
|---|---|---|---|---|
| `APROVAR_RESERVA` | quem decidiu | unidade atual do espaço | `status: PENDENTE` | `status: CONFIRMADA` |
| `RECUSAR_RESERVA` | quem decidiu | unidade atual do espaço | `status: PENDENTE` | `status: RECUSADA`, `motivo_recusa` |
| `EXPIRAR_RESERVA` | vazio (sistema) | unidade atual do espaço | `status: PENDENTE` | `status: EXPIRADA`, `expirou_em` = `inicio` da reserva |

- Os objetos de dados são montados com cadeia de `|set` (lição da C5).
- O registro de expiração é gravado na mesma transação da faxina.
- Recusas e a listagem não geram registro.

### D9. Listagem `reservas_unidade` (GET)

**Entradas, todas opcionais:**
- `unidade_id` e `espaco_id`;
- `situacao`: `PENDENTE` (padrão), `CONFIRMADA`, `RECUSADA`, `EXPIRADA`, `CANCELADA` ou `TODAS`. Qualquer outro valor dá 400 "Situação inválida.". `CONCLUIDA` e `NAO_COMPARECEU` entram na C9;
- `data_inicial` e `data_final` (AAAA-MM-DD).

**Escopo:**
- `usuario_ativo`. Papel diferente de `ADMIN` ou `COORDENADOR` dá 403.
- Admin: espaços de todas as unidades. Coordenador: espaços de `unidades_coordenadas`.
- `unidade_id` fora do escopo, ou `espaco_id` inexistente ou fora do escopo, dá 403 com a mesma mensagem (padrão do D5).
- **Sem trava e sem gravação:** é só leitura.

**Período:**
- Data inválida dá 400 "Informe as datas no formato AAAA-MM-DD, com valores existentes." (`converter_data_pedido`, no padrão de `converter_horario_pedido`).
- Data final antes da inicial dá 400.
- As datas são convertidas em São Paulo (`to_timestamp` com o fuso, como em `converter_horario_pedido`):
  - início do período: 00h00 da data inicial;
  - fim do período: 00h00 do dia seguinte à data final.
- Filtra por `inicio` dentro do período.

**Situação na consulta (D2):**
- `PENDENTE`: `status == PENDENTE && inicio > agora`.
- `EXPIRADA`: `status == EXPIRADA || (status == PENDENTE && inicio <= agora)`.
- As demais: igualdade simples.
- `TODAS`: sem filtro.

**Ordem:** `PENDENTE` por `inicio` crescente (a mais urgente primeiro); todas as demais, inclusive `TODAS`, por `inicio` decrescente.

**Teto de 200 itens:**
- A resposta traz `limitada: true` quando havia mais reservas do que o teto.
- A tela avisa "Mostrando as 200 primeiras; use o período ou o espaço para refinar.".
- Assim a listagem não cresce sem limite enquanto não há paginação. É um teto técnico de resposta, não um limite de negócio.

**Item da lista:**
- `id`;
- `dono` (`nome`, `email`) e `nivel_prioridade`, que é o nível na criação e não o papel atual; nível 3 é "Coordenação/administração";
- `espaco` (`id`, `nome`, `codigo`), `unidade` (`id`, `nome`) e `tipo` (`id`, `nome`);
- `inicio`, `fim`, `data`, `hora_inicio` e `hora_fim` (`formatar_reserva`);
- `status` efetivo e `criado_em`;
- `decidido_por` (nome), `decidido_em` e `motivo_recusa`;
- `motivo_cancelamento`, `motivo_detalhe`, `motivo_descricao` e `cancelado_por` (nome). Em `CONTA_INATIVADA`, `cancelado_por` vem vazio, para não expor o admin que inativou (decisions-log 24).

**Montagem:**
- Uma consulta por tabela (reservas, espaços, unidades, tipos e usuários envolvidos), sem consulta por reserva, como em `minhas_reservas`.
- Dos usuários sai só nome e e-mail. Nada de situação da conta, papel atual, unidade de vínculo nem motivo de inativação.

**Alternativa descartada:** estender `minhas_reservas` com um modo "unidade". Mistura autorização de dono com autorização de gestor numa rota só.

### D10. Reflex

**Cliente:** `aprovar_reserva`, `recusar_reserva` e `reservas_unidade`, no grupo `_RESERVAS` que já existe.

**Página `/reservas-unidade`:**
- Arquivo `pages/reservas_unidade.py` e `ReservasUnidadeState` em `state/reservas_unidade_state.py`.
- Guarda de sessão para `e_gestor`, como em "Aprovações" e "Espaços".

**Filtros e lista:**
- Filtros: unidade (de `listar_unidades_geridas`), espaço (de `listar_espacos_geridos`, restrito à unidade escolhida), situação (padrão "Pendentes") e período (duas datas). A busca é enviada com um botão.
- Tabela com dono e papel na criação (1 Aluno, 2 Professor, 3 Coordenação/administração), espaço, unidade, data, horário, situação e "Criada em". Os demais dados (decisão ou cancelamento) aparecem conforme a situação.
- Pendentes: botões "Aprovar" (direto, sem diálogo, como a aprovação de cadastro) e "Recusar" (diálogo).
- Com `limitada`, a tela mostra o aviso do D9 acima da tabela.

**Diálogo de recusa:**
- Segue `dialogo(..., limpar_ao_enviar=False)` e `erro_dialogo`, como a recusa de cadastro.
- Texto: "O motivo será mostrado à pessoa que fez a reserva.".

**Erros e atualização:**
- `ErroValidacao`: na aprovação, a mensagem aparece no topo da página e a lista é recarregada; na recusa, aparece dentro do diálogo.
- Depois de qualquer decisão aceita, a lista é recarregada.

**Outras telas:**
- **Minhas reservas:** para `RECUSADA`, o motivo exibido é `motivo_recusa`. Ajuste em `_reserva_para_tela` ou numa função de `motivos.py`, reaproveitando o padrão de `texto_cancelamento`.
- **Menu:** "Reservas da unidade" logo depois de "Aprovações", para `e_gestor`.

**Alternativa descartada:** acrescentar as reservas à página "Aprovações". O `ContasState` dela trata pedidos de cadastro, e juntar os dois incharia o State.

### D11. Documentos

**`project-overview.md`:**
- §7.6: nota de que a expiração é efetiva no início e gravada na próxima operação;
- §8, diagrama e tabela: "tarefas agendadas" passa a "vencimentos processados nas operações (plano gratuito sem tarefas agendadas)";
- §11: item 7 identificado como C7, sem a pendência da C4 (já resolvida pela C6), e as pendências do D12 nos itens 8, 9, 10, 13 e 14.

**`domain-model.md`:**
- §2.9: decisão de aprovação e expiração, regra de quem decide e proibição de decidir a própria reserva;
- a nota do ator vazio troca "tarefa agendada" por "ação do sistema (por exemplo, a expiração de reservas)".

**`AGENTS.md`:** na tabela da §3, "tarefas agendadas" passa a "processamento de vencimentos", com a referência estável a `docs/project-overview.md`, seção 8, porque o `design.md` vai para o archive. Isso muda as instruções do agente, então a alteração é mostrada ao usuário no diff.

**`openspec/config.yaml`:** a stack do `context` e a regra do `design` citam "tarefas agendadas". As duas linhas são corrigidas nesta change, com o diff mostrado ao usuário (decisions-log 25). Assim a C8 e a C9 não herdam a contradição.

### D12. Pendências para as próximas changes

| Change | Pendência |
|---|---|
| C8 | A retenção da fila (`NOTIFICADA`) vencida entra no predicado de ocupação (D2) e na `processar_vencimentos`. Decidir no explore como tratar o atraso para o próximo da fila: contar o prazo dele a partir de quando é de fato avisado, acionar a faxina ao abrir "Minhas reservas" ou a fila, ou aceitar o atraso. |
| C9 | Não comparecimento, fechamento de reservas passadas e falta entram na `processar_vencimentos`, com o instante real (D4, regra 3). A penalidade ativa é derivada por datas. A faxina roda antes da checagem de penalidade na criação. Rever o predicado de "em andamento" se o check-in mudar o que conta como uso. Uma reserva aprovada a minutos do início fica `CONFIRMADA`; a janela de check-in dela é definida na C9. |
| C13 | A notificação de expiração sai na faxina, portanto atrasada. Avaliar no explore acionar a faxina ao abrir a central de notificações. |
| C10 | A verificação de bloqueio e o cancelamento por bloqueio usam a situação efetiva (D2) ao procurar reservas ativas sobrepostas. |
| C14 | Painel e relatórios usam a situação efetiva (D4, regra 2). |
| Qualquer | Se o atraso incomodar na prática: uma rota autenticada de faxina chamada no login, usando o próprio usuário, sem credencial de serviço. |

## Risks / Trade-offs

- **[Banco atrasado em relação à verdade]** → Toda leitura usa a situação efetiva (D2). Quem olha a tabela direto no painel do Xano pode ver `PENDENTE` vencida, e isso fica documentado no §8 do overview.
- **[Trava presa por muito tempo depois de dias sem uso]** → Índice `status` + `inicio`, teto de 50 por rodada (cerca de 5 s) e testes com 33 vencidas numa operação e com mais de 50 em duas operações.
- **[Trava pega duas vezes por requisição]** → A faxina sem vencidos é uma consulta indexada que devolve vazio. O plano gratuito já limita o volume a 10 requisições a cada 20 s.
- **[Pendente iniciada cancelada pela gestão em vez de expirada]** → Aceito. Os dois são estados finais e sem falta, e o comportamento é o que a spec da C6 exige.
- **[Coordenador perde a coordenação com a página aberta]** → A decisão recebe 403 e o Reflex leva para "Início", que é o padrão de toda a gestão.
- **[Unidade com um único coordenador, dono da própria pendente]** → Um admin decide ou a reserva expira. O menu do admin mostra todas as unidades.
- **[Predicado com `||` e parênteses no `where`]** → Confirmar a sintaxe no MCP antes de escrever (tarefa 1.2). Se o `where` não aceitar, fazer duas consultas (`CONFIRMADA` e `PENDENTE` com `inicio > agora`) e juntar.
- **[Listagem sem paginação]** → Sem filtro de situação, mostra só as pendentes futuras, que já são limitadas pela antecedência máxima. As demais situações têm o teto de 200 itens com aviso (D9).
- **[Vencimento entre as duas transações]** → Não dá para provocar com o relógio real. Fica coberto pela revisão de código do predicado do D2 e do `inicio > agora` estrito, e registrado como "não testado".
- **[Lições de Xano]** → Objetos com `|set`, `is_null` em checagens de vazio, `conditional` para booleanos compostos e nomes de rota únicos. Cada chave que a tela usa é testada em execução.

## Migration Plan

1. Push com dry-run e aprovação: campos e índice em `reserva`; funções novas; rotas novas e alteradas.
2. Nenhum `bootstrap` e nenhuma variável de ambiente nova, porque o grupo `reservas` já tem URL no `.env`.
3. As pendentes antigas, criadas na C6 e já vencidas, são expiradas pela primeira operação depois do push, com auditoria do sistema.
4. **Rollback:** novo push com os arquivos anteriores. As reservas decididas ou expiradas não voltam a `PENDENTE`, conforme o domínio, e os campos novos ficam sem uso.

## Confirmações do apply

Confirmado no Xano Developer MCP (documentação 2.7.1), com arquivos de sonda validados e sem push (tarefa 1.2):

| Item | Sintaxe confirmada | Evidência |
|---|---|---|
| Predicado de ocupação | `where = $db.reserva.espaco_id == 1 && ($db.reserva.status == "CONFIRMADA" \|\| ($db.reserva.status == "PENDENTE" && $db.reserva.inicio > $input.agora))` | Sonda de função válida. No controle negativo, o mesmo `where` com um parêntese a menos foi recusado. A documentação `database` mostra `\|\|` no `where`. |
| Transação aberta numa função | `function` com `try_catch { try { db.transaction { stack { function.run travar_governanca ... } } } catch { debug.log {...} } }` | Sonda válida. O comportamento em execução (trava e rollback) é conferido na tarefa 7.7. |
| Teto por consulta | `return = {type: "list", paging: {page: 1, per_page: 200, metadata: false}}` com `sort = {inicio: "asc"}` | Sonda válida; documentação `database` (paginação e busca vetorial com `metadata: false`) |
| Campos da tabela | `int? decidido_por_id? { table = "usuario" }`, `timestamp? decidido_em?`, `text? motivo_recusa? filters=trim` | Sonda de tabela válida |
| Índice composto | `{type: "btree", field: [{name: "status"}, {name: "inicio"}]}` | Sonda de tabela válida |
| Início do dia em São Paulo | `($data ~ " 00:00")\|to_timestamp:"America/Sao_Paulo"`; dia seguinte com `\|add_secs_to_timestamp:86400` (sem horário de verão em São Paulo desde 2019) | Sonda válida; filtros na documentação (`add_secs_to_timestamp`, `slice`); conversão já em produção em `converter_horario_pedido` |
| Listagem com teto | consulta com `per_page: 201`; `limitada` quando volta mais de 200 itens; corte com `\|slice:0:200` | Filtro `slice` na documentação |

**Lição de ambiente:** um `.xs` gravado com BOM (`Set-Content -Encoding utf8` do PowerShell 5.1) é recusado pelo validador na linha 1. Os arquivos são gravados sem BOM.
## Verificação do apply: o que não foi testado

Os testes do grupo 7 passaram em 82 de 84 casos na primeira rodada. As duas falhas foram resolvidas: a do horário fora da granularidade era erro do script e passou no complemento, e a da data com mês 13 era defeito real e foi corrigida (decisões 33 e 35). Os retestes da 7.11 passaram em 18 de 18. No navegador, a 8.2 a 8.4 passaram, inclusive depois da correção da decisão 36. Os pontos abaixo **não** foram testados em execução:

| Ponto | Por que não | Como ficou coberto |
|---|---|---|
| Instante exato do início (`inicio == agora`) | O relógio real não permite acertar o milissegundo | Revisão de código: decidir exige `inicio > agora`, e a faxina e a situação efetiva usam `inicio <= agora` |
| Vencimento entre a faxina e a transação principal | A janela é de milissegundos | Revisão de código do predicado de ocupação (D2) no conflito, no limite e na busca |
| Teto de 200 itens da listagem | Criar mais de 200 reservas esbarra no limite de requisições do plano gratuito | Revisão de código (`per_page` 201, `limitada`, `slice`) |
| Coordenador sem unidades | O caso não foi criado | Revisão de código: sem espaços no escopo, a rota não consulta (nunca `in` com lista vazia) |
| Pendente das 22h30 em São Paulo expirando | Seria preciso esperar até a noite | A listagem de uma reserva das 21h no dia certo passou; a expiração usa instantes absolutos |
| Releitura do dono ativo em `decidir_reserva` | Inalcançável pela API: a inativação cancela as pendentes futuras do dono | Revisão de código |
| Menu e página com o admin no navegador | Para não digitar a senha real do admin nas ferramentas | O menu e a rota usam o mesmo `AuthState.e_gestor` do coordenador, testado; a API do admin foi testada nos scripts |

Também ficou registrado: a falha da faxina (`tst_faxina_falha`) solta a trava e não bloqueia a rota seguinte (segunda trava em 90 ms), e em produção essa falha não deixa rastro (D3).