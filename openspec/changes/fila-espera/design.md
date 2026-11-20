## Context

Motivação e escopo: ver `proposal.md`. As decisões do explore estão no `decisions-log.md`. Os requisitos estão nas specs delta.

Estado atual que molda a solução:
- **Trava global:** toda rota que grava reservas ou faz gestão abre `db.transaction` com `travar_governanca` como primeira instrução. A linha `governanca` serializa essas transações, e o Xano não tem isolamento melhor (memória do projeto e C2, D3). A fila usa a mesma trava.
- **Faxina:**
  - `aplicar_vencimentos` abre uma transação própria, pega a trava e chama `processar_vencimentos`;
  - essa função grava `EXPIRADA` nas pendentes vencidas (até 50 por rodada) com um `EXPIRAR_RESERVA` cada;
  - a faxina roda antes da transação principal de `criar_reserva`, `cancelar_reserva`, `aprovar_reserva` e `recusar_reserva`.
- **Predicado de ocupação (C7, D2):** `CONFIRMADA` ou `PENDENTE` com `inicio > agora`, repetido em `criar_reserva` (limite e conflito) e em `buscar_espacos`.
- **`criar_reserva` (C6 a C8):**
  - na transação, a ordem é: conta, releitura do espaço, unidade, tipo e regras, reservável, papel, horário, *(penalidade)*, limite, *(bloqueio)*, conflito, avaliação do deslocamento e gravação;
  - o deslocamento cancela por `cancelar_reservas` no modo `prioridade`.
- **`cancelar_reservas`:**
  - é chamada por todas as rotas de gestão que cancelam reservas;
  - o modo `conta` é usado por `inativar`;
  - o modo `espaco` é usado por `desativar_espaco`, `desativar_tipo`, `desativar` (unidade), `mover_espaco` e por `editar_espaco` quando o tipo muda;
  - o modo `prioridade` é usado por `criar_reserva`.
  - `desativar_espaco` a chama sempre, mesmo sem reservas.
- **Antecedência mínima:** `validar_horario_reserva` aceita quando `inicio >= agora + antecedencia_min_minutos * 60000`, com limite inclusivo.
- **Reflex:**
  - cada página autenticada tem `on_load` com a guarda de sessão (`AuthState.verificar_sessao` ou `exigir_*`) seguida do `abrir` do próprio State;
  - `layout_autenticado` monta o cabeçalho comum;
  - o cliente `xano_cliente.py` usa uma variável de ambiente de URL por grupo de API.
- **Lições do Xano** (memória do projeto):
  - objetos literais perdem chaves sem vírgulas, e filtros ou operadores dentro de literal falham em execução: usar `|set` e calcular antes;
  - comparação frouxa com `null`: usar `is_null`;
  - `.xs` sem BOM;
  - nome de rota único no workspace, porque o CLI casa as rotas por nome.

## Goals / Non-Goals

**Goals:**
- **Uma porta de processamento:** a fila anda numa função só, `processar_fila`, usada pela faxina, pelas rotas que liberam vaga e pela gestão. A ordem e a retenção nunca divergem entre os caminhos.
- **Uma regra de ocupação:** reserva ativa ou vaga retida no prazo, usada pela criação, pela busca, pela entrada na fila e pelo processamento.
- **Situação efetiva também para a fila:** vaga retida vencida não retém, e entrada que passou do corte aparece encerrada, mesmo antes da gravação.
- **Validações da criação sem cópia:** a criação, a entrada na fila e a confirmação usam as mesmas funções de validação.

**Non-Goals:**
- Tarefa agendada, polling no frontend ou atualização em tempo real.
- Tela de fila para gestores e qualquer mudança em "Reservas da unidade".
- Mexer no deslocamento além de tratar a vaga retida como não deslocável.
- Penalidade e bloqueio, que ficam como pontos de extensão comentados nas rotas novas, como na criação.
- `impacto_reservas` e `reservas_unidade` não mudam. A prévia de impacto das ações de gestão não conta as entradas de fila que seriam encerradas.

## Decisions

### D1. Tabela `entrada_fila` (nova)

| Campo | Tipo | Observação |
|---|---|---|
| `id` | int | |
| `usuario_id` | int, referência a `usuario` | dono |
| `espaco_id` | int, referência a `espaco` | |
| `inicio`, `fim` | timestamp | o intervalo exato pedido |
| `nivel_prioridade` | int | `nivel_do_papel` do papel na entrada |
| `status` | enum `AGUARDANDO`, `NOTIFICADA`, `ATENDIDA`, `EXPIRADA`, `DESISTIU`, `ENCERRADA` | |
| `criado_em` | timestamp, padrão `now` | desempate |
| `notificado_em` | timestamp? | instante do aviso |
| `prazo_confirmacao` | timestamp? | fim do prazo, inclusive |
| `reserva_gerada_id` | int?, referência a `reserva` | na confirmação |

- **Nomes:** os do DER, sem divergência.
- **Índices:**
  - `(espaco_id, status)`, para o processamento e a busca;
  - `(usuario_id)`, para a fila do usuário;
  - `(status, prazo_confirmacao)`, para a verificação rápida e a expiração.
- **Sem campo de instante de finalização:** o motivo e o instante reais do encerramento e da expiração ficam na auditoria (D8). A lista do usuário mostra as finalizadas cujo intervalo começou nos últimos 30 dias, pelo `inicio`, sem campo novo.
- **"Única ativa por usuário, espaço e intervalo":** garantida pela rota `entrar_fila` dentro da trava, como as outras unicidades do projeto (C2, D3).
- **`reserva.origem`:** já tem `FILA` desde a C6, e o enum não muda.

### D2. Parâmetro `prazo_fila_minutos`

> **Revisto pela D12 (update de 20/11/2026):** `prazo_fila_minutos` passa a ser só o corte. O prazo para confirmar e o tempo mínimo útil ganham parâmetros próprios.

`configuracao_geral.prazo_fila_minutos` (int?, padrão 120) segue o caminho do prazo para deslocar da C8:
- tabela;
- `bootstrap`, em `$parametros_padrao` e no `db.add`, com vírgulas;
- `parametros_GET`;
- `parametros_POST`, no input, em `$limites` e na auditoria;
- `LIMITES` em `parametros_state.py` e `ROTULOS_LIMITES` em `parametros.py`.

O prazo é lido direto da tabela, com a precondição do bootstrap, como os outros prazos.

### D3. Corte e situação efetiva da entrada

> **Revisto pela D12 (update de 20/11/2026):** a entrada, o aviso e o encerramento passam a usar o fechamento (corte menos o tempo mínimo útil), e o prazo passa a ser `min(aviso + prazo_confirmacao_fila_minutos, corte)`. As regras abaixo valem com essa troca.

Por entrada, com a antecedência mínima do tipo **atual** do espaço:
- `corte = inicio - max(prazo_fila_minutos, antecedencia_min_minutos) * 60000`.

Função pura `situacao_efetiva_fila(status, prazo_confirmacao, corte, agora)`:
- `NOTIFICADA` com `prazo_confirmacao < agora` passa a `EXPIRADA`;
- `AGUARDANDO` com `agora >= corte` passa a `ENCERRADA`;
- as demais situações não mudam.

Como `prazo <= corte`, a vaga retida já está vencida quando o corte chega, então não precisa de regra própria para `NOTIFICADA`.

Os limites são escolhidos para fechar sem buracos:
- **Entrada:** só com `agora < corte`. Exatamente no corte, "2 horas" não basta, coerente com o deslocamento (decisão 3 do log).
- **Aviso:** só com `agora < corte`, e `prazo = min(agora + P, corte)`. O prazo nunca tem duração zero.
- **Confirmação:** aceita com `agora <= prazo`, limite inclusivo como no cancelamento. Como `prazo <= corte`, vale `inicio - agora >= antecedência mínima`, então a confirmação sempre passa na antecedência. A antecedência máxima também, porque o tempo só avança.
- **Mudar `P`** altera o corte das entradas que aguardam, mas não os prazos já gravados.
- **Limitação aceita:** se `P` ou a antecedência mínima do tipo aumentarem enquanto uma entrada está `NOTIFICADA`, o prazo gravado pode passar do corte novo. A confirmação feita nesse intervalo cai na regra de antecedência da criação e é recusada, e a vaga fica retida até o prazo. É raro, porque exige mudar um parâmetro durante uma retenção, e não viola nenhuma invariante.

### D4. Predicado de ocupação com a vaga retida

Ocupam um intervalo do espaço:
- as reservas pelo predicado da C7;
- as entradas `NOTIFICADA` com `prazo_confirmacao >= agora` sobrepostas ao intervalo (`inicio < fim_pedido && fim > inicio_pedido`).

Onde o predicado é aplicado:
- **`criar_reserva`:** a consulta de conflito ganha a das retidas. Com qualquer retida sobreposta, o pedido é recusado como horário ocupado, antes de avaliar o deslocamento. Não há exceção para a reserva da própria entrada, porque a confirmação não passa por `criar_reserva`.
- **`buscar_espacos`:** uma consulta a mais, de todas as retidas sobrepostas ao intervalo. Elas entram em `ocupado` e forçam `deslocavel = false` (D9).
- **`entrar_fila` e `confirmar_fila`:** D6.
- **`processar_fila`:** D5.

O limite de reservas ativas não muda, porque uma entrada de fila não é reserva (decisão 6 do log).

### D5. `processar_fila(agora)`: a única porta do processamento

A função grava e pressupõe que quem chama já tem a trava. Sai cedo, sem outras consultas, quando não há entrada `AGUARDANDO` nem `NOTIFICADA`, que é o caso comum. Os passos:

1. **Expirar:** `NOTIFICADA` com `prazo_confirmacao < agora` passa a `EXPIRADA`, com um `EXPIRAR_FILA` cada e o prazo como instante.
2. **Encerrar:** passam a `ENCERRADA`, com um `ENCERRAR_FILA` de ator vazio, as `AGUARDANDO` que:
   - passaram do corte (com o corte como instante);
   - são de espaço que não é reservável (rede de segurança para a gestão);
   - são de usuário com `status_conta` diferente de `ATIVA`.
3. **Avisar:**
   - percorre as `AGUARDANDO` restantes, ordenadas por `nivel_prioridade desc, criado_em asc, id asc`;
   - para cada uma, verifica se o intervalo está livre: nenhuma reserva ocupando (C7) e nenhuma `NOTIFICADA` no prazo sobreposta, incluindo as avisadas nesta mesma passada;
   - se estiver livre, a entrada passa a `NOTIFICADA`, com `notificado_em = agora`, `prazo_confirmacao = min(agora + P, corte)` e um `NOTIFICAR_FILA`.

**Desempenho:**
- a ocupação é lida com **uma** consulta de reservas e uma de retidas para os espaços que têm entradas aguardando, e a verificação é feita em memória;
- teto de 100 entradas por passo e por rodada (técnico, como o teto de 50 da C7). O que sobrar continua coberto pela situação efetiva e vai na próxima rodada.

**Por que o percurso guloso implementa a §7.4:**
- **Filas sobrepostas:** percorrer todas as filas do espaço na ordem global e reter quando o intervalo está livre dá a retenção à fila cujo primeiro colocado tem maior prioridade e, em empate, entrou antes.
- **Quem chega depois não toma a retenção:** só as `AGUARDANDO` são percorridas, e uma `NOTIFICADA` no prazo continua ocupando.
- **Fila sobreposta à retenção:** espera e é reavaliada na rodada em que a retenção acabar.
- **Fila sem sobreposição com a retenção:** é avisada, mesmo de nível menor. Exemplo, conferido pelo guardian: Rui das 10h às 11h e Ana das 11h10 às 12h são avisados, e Carlos, das 10h30 às 11h30, espera. Isso segue a §7.4, porque o intervalo de Ana está livre. O cenário "Cadeia de filas sobrepostas" da spec fixa esse comportamento.

**Quem chama:**
- `processar_vencimentos`, depois das expirações de reservas, para que a pendente vencida libere a fila na mesma rodada (cenário "Expiração de pendente libera a fila");
- `cancelar_reserva` e `recusar_reserva`, no fim da transação principal;
- `cancelar_reservas`, em todos os modos, o que cobre o deslocamento da criação e as ações de gestão. A ordem dentro dela é fixa:
  1. cancelar as reservas;
  2. encerrar as entradas ativas da conta (modo `conta`) ou dos espaços (modo `espaco`), com `ENCERRAR_FILA`, o ator e o motivo;
  3. só então chamar `processar_fila`.

  As rotas de gestão chamam `cancelar_reservas` antes de gravar `ativo`, o tipo ou a unidade. Por isso, o encerramento da etapa 2 é explícito e não depende da rede de segurança "espaço não reservável" da D5, que ainda não enxergaria a mudança.
  - **Consulta própria dos espaços:** o encerramento consulta os espaços das entradas, porque hoje a função só consulta `espaco` quando há reservas, e a auditoria precisa da `unidade_id` de cada entrada.
  - **`mover_espaco`:** a unidade registrada é a de origem, como no `CANCELAR_RESERVA` da C6;
- `desistir_fila`, quando a entrada estava `NOTIFICADA`.

Assim, a vaga liberada é retida na mesma transação que a liberou, sem uma janela em que outra pessoa reserve antes (cenário "Reserva direta e liberação simultâneas"). A ordem "faxina antes do conflito" da decisão 4 do log continua valendo, pela faxina de `criar_reserva`.

### D6. Rotas novas, no grupo `reservas`

Ficam no grupo existente para não exigir variável de ambiente nova no Reflex, e têm nomes únicos no workspace: `entrar_fila`, `confirmar_fila`, `desistir_fila` e `minha_fila`.

**`entrar_fila` (POST: `espaco_id`, `data`, `hora_inicio`, `hora_fim`)**

Fora da trava: conversão do horário e `aplicar_vencimentos`. Na trava, na ordem:
1. conta ativa;
2. validações da criação (D7);
3. *(ponto de extensão: penalidade)*;
4. *(ponto de extensão: bloqueio)*;
5. `agora < corte`, senão "A fila deste horário já está encerrada.";
6. sem entrada própria ativa igual;
7. sem reserva própria ocupando um intervalo sobreposto no espaço;
8. ocupação (D4):
   - nada ocupa: "Este horário está livre. Faça a reserva diretamente.";
   - sem retida e `avaliar_deslocamento` deslocável: "Você pode deslocar a ocupação deste horário. Use Deslocar e reservar.";
9. grava `AGUARDANDO` com `ENTRAR_FILA`.

**`confirmar_fila` (POST: `entrada_id`)**

Fora da trava: `aplicar_vencimentos`. Na trava, na ordem:
1. conta ativa;
2. a entrada própria: senão "Entrada não encontrada.", a mesma resposta para entrada inexistente;
3. a situação:
   - `NOTIFICADA` segue;
   - `AGUARDANDO`: "Ainda não há vaga para confirmar.";
   - as demais: "Esta entrada não está mais ativa.";
4. `agora <= prazo_confirmacao`, senão "O prazo para confirmar terminou.";
5. validações da criação (D7), inclusive o limite de ativas;
6. conferência defensiva de que nenhuma reserva ocupa o intervalo. Pela invariante, não deveria haver; se houver, a recusa é de horário ocupado;
7. grava a reserva com `origem: "FILA"`, `PENDENTE` se a regra do papel exige aprovação, senão `CONFIRMADA`, com o nível do papel atual;
8. a entrada passa a `ATENDIDA` com `reserva_gerada_id`;
9. auditoria `CRIAR_RESERVA` e `CONFIRMAR_FILA`.

**`desistir_fila` (POST: `entrada_id`)**

Fora da trava: `aplicar_vencimentos`. Na trava, na ordem:
1. conta ativa;
2. a entrada própria, com a mesma resposta para inexistente;
3. `AGUARDANDO` ou `NOTIFICADA`, senão "Esta entrada não está mais ativa.";
4. grava `DESISTIU` com `DESISTIR_FILA`;
5. se a entrada estava `NOTIFICADA`, chama `processar_fila`.

**`minha_fila` (GET)**

1. Conta ativa.
2. **Verificação rápida, só leitura:** há pendente vencida (`PENDENTE` com `inicio <= agora`) ou vaga retida vencida (`NOTIFICADA` com `prazo_confirmacao < agora`)? Só nesse caso chama `aplicar_vencimentos`, que pega a trava. A entrada que só passou do corte não dispara gravação, porque ninguém espera por ela e a situação efetiva já a mostra encerrada.
3. **Lista:**
   - as entradas ativas do usuário e as finalizadas com `inicio` nos últimos 30 dias, com espaço, unidade, tipo, data e horas em America/Sao_Paulo (`formatar_reserva`), situação efetiva (D3), prazo formatado e posição;
   - **posição:** 1 + a quantidade de `AGUARDANDO` do mesmo espaço e intervalo à frente na ordem da D5. A posição conta só a fila do mesmo intervalo, sem nomes;
   - `avisos`: as `NOTIFICADA` no prazo, para o aviso global.

A rota alimenta o aviso de todas as páginas (D10), então a verificação rápida roda em toda navegação. O custo é de duas consultas `count` quando não há nada a processar.

### D7. Validações da criação extraídas em funções

`criar_reserva`, `entrar_fila` e `confirmar_fila` precisam das mesmas validações. Para não copiar uns 120 linhas três vezes, os passos 2 a 5 e 7 da criação saem para duas funções, e `criar_reserva` passa a usá-las sem mudar o comportamento:
- **`validar_pedido_reserva(espaco_id, papel, inicio, fim, agora)`:**
  - releitura do espaço, da unidade, do tipo e das regras;
  - reservável;
  - regra do papel;
  - regras de horário, com os mesmos rótulos e as mesmas mensagens de recusa;
  - devolve `espaco`, `tipo`, `regra` e `exige_aprovacao`.
- **`exigir_limite_ativas(usuario_id, espaco, tipo, agora)`:** a contagem e a recusa do passo 7.

O refatoramento tem risco de regressão na criação. A verificação repete os testes principais da C6 à C8 (tasks).

### D8. Auditoria

A entidade é `entrada_fila`, e a unidade é a atual do espaço.

| Ação | Ator | Dados antes | Dados depois |
|---|---|---|---|
| `ENTRAR_FILA` | dono | — | `status`, `espaco_id`, `inicio`, `fim`, `nivel_prioridade` |
| `CONFIRMAR_FILA` | dono | `status` | `status`, `reserva_gerada_id` |
| `DESISTIR_FILA` | dono | `status` | `status` |
| `NOTIFICAR_FILA` | vazio | `status` | `status`, `prazo_confirmacao` |
| `EXPIRAR_FILA` | vazio | `status` | `status`, `expirou_em` (o prazo) |
| `ENCERRAR_FILA` (corte ou rede de segurança) | vazio | `status` | `status`, `motivo` (`CORTE`, `ESPACO_INDISPONIVEL` ou `CONTA_INATIVADA`) e, no corte, `encerrou_em` |
| `ENCERRAR_FILA` (gestão ou inativação) | quem executou | `status` | `status` e `motivo` (`ESPACO_INDISPONIVEL` ou `CONTA_INATIVADA`) |

Os nomes das ações seguem o padrão `VERBO_ENTIDADE` das outras ações.

### D9. Busca

Para cada espaço com horário:
- **`ocupado`:** inclui as retidas no prazo.
- **`deslocavel` e `deslocaria`:** com retida sobreposta, `deslocavel` é falso e `deslocaria` é 0.
- **Prazo da fila:** lido de `configuracao_geral` junto com o prazo de deslocamento, com a mesma precondição do bootstrap.
- **`na_fila`:** o usuário tem entrada `AGUARDANDO` ou `NOTIFICADA` no mesmo espaço e exatamente no mesmo intervalo. Uma consulta das entradas ativas do usuário.
- **`pode_entrar_fila`:** é verdadeiro quando o espaço está `ocupado` e `dentro_das_regras`, não é `deslocavel`, `na_fila` é falso, nenhuma das reservas ocupantes é do próprio usuário e `agora < corte`.

Sem horário, as quatro chaves ficam ausentes, como `deslocavel` na C8. A busca continua sem trava e sem gravação.

### D10. Reflex

- **`xano_cliente.py`:** `entrar_fila`, `confirmar_fila`, `desistir_fila` e `minha_fila`, no grupo de reservas.
- **`FilaState` (novo):**
  - `entradas` (ativas e finalizadas, formatadas para a tela) e `avisos`;
  - `carregar_aviso`: chama `minha_fila` e é acrescentado ao `on_load` de todas as páginas autenticadas, depois da guarda e com sessão válida, fora da troca de senha provisória;
  - os handlers `confirmar`, `desistir` e o diálogo de saída da fila;
  - depois de cada ação, recarrega a fila e as reservas (`ReservasState.abrir`).
- **`layout_autenticado`:** mostra o aviso (callout) acima do conteúdo quando `FilaState.avisos` não está vazio, com o espaço, o horário, o prazo e o link para "Minhas reservas".
- **"Minhas reservas":**
  - seção "Fila de espera" com tabela própria: "Confirmar" e "Desistir" nas `NOTIFICADA`, "Sair da fila" nas `AGUARDANDO`, com diálogo de confirmação;
  - as finalizadas ficam abaixo, com a situação;
  - os rótulos das situações ficam num dicionário em `motivos.py`.
- **Busca:**
  - `_espaco_para_tela` ganha `na_fila` e `pode_entrar_fila`;
  - o card mostra "Entrar na fila" ou a etiqueta "Você está na fila";
  - o diálogo de entrada na fila reaproveita `dialogo` de `componentes.py`, com o texto do prazo da fila;
  - a recusa fica dentro do diálogo, como na reserva.
- **Parâmetros:** campo novo, como o prazo para deslocar.

### D11. Replanejamento nos documentos

O texto vai como item explícito do proposal e é revisado com ele (decisão 1 do log).

**`project-overview.md`:**
- **§5:** notificações in-app e contestação de penalidade passam para "Fora do escopo (v1)", como evolução.
- **§6:** os itens 9, 11 e 14 deixam de citar notificação e contestação como da v1.
- **§7.3 e §7.6:** "notificado (a partir da C14)" passa a "vê em 'Minhas reservas'".
- **§7.4:**
  - corte pela antecedência mínima do tipo;
  - limite inclusivo das 2 horas ("2 horas ou menos" encerra);
  - o aviso é pela tela e pelo aviso global;
  - a confirmação num tipo que exige aprovação gera uma reserva pendente (decisão 7 do log);
  - a entrada é recusada quando o usuário já tem reserva ativa sobreposta no espaço (decisão 9).
- **§7.8:** sai a contestação. O admin continua anulando a penalidade e registrando o parecer, que é a justificativa da anulação, se a change de check-in implementar isso.
- **§7.11:** vira "Avisos na v1", com o aviso de vaga retida e os motivos em "Minhas reservas". A central de notificações é evolução.
- **§10:** auditoria da fila.
- **§11:** a lista nova:
  1. C9, fila de espera;
  2. C10, check-in e faltas enxuta;
  3. C11, bloqueios;
  4. C12, reserva recorrente;
  5. C13, espaço (fotos, feed, página e avaliações);
  6. C14, visual;
  7. painel e relatórios em aberto;
  8. notificações como trabalho futuro.
  - As pendências antigas da C14 (notificar cancelamentos, aprovação, recusa e deslocamento) passam a "trabalho futuro", com a observação de que o motivo já aparece em "Minhas reservas".

**`domain-model.md`:**
- **§2.11:**
  - corte pela antecedência e limite inclusivo;
  - a confirmação em tipo com aprovação gera `PENDENTE`;
  - a recusa da entrada com reserva própria sobreposta;
  - `ENCERRADA` entre os fins da retenção.
- **§2.13 (Contestação) e Notificação:** marcadas como fora da v1, sem apagar do MER e do DER, para servir de base à evolução.
- **§2.18:** confere `prazo_fila_minutos`.

### D12. Update de 20/11/2026: prazo para confirmar separado e fechamento da fila

**Motivo:** com um parâmetro só, a vaga liberada de madrugada vencia em 2 horas, antes de a pessoa abrir o sistema. Separar o prazo para confirmar do corte dá uma noite inteira de folga. O tempo mínimo útil evita avisar alguém que teria poucos minutos para confirmar. Decisões 25 a 28 do log, todas do usuário.

**Parâmetros em `configuracao_geral`** (int?, inteiros >= 1, editados só pelo admin principal, gravados pelo `bootstrap` quando vazios):

| Campo | Padrão | Papel |
|---|---|---|
| `prazo_fila_minutos` | 120 | Corte: minutos antes do início (ou a antecedência mínima do tipo, se maior) |
| `prazo_confirmacao_fila_minutos` (novo) | 720 | Prazo para confirmar, contado do aviso |
| `tempo_minimo_fila_minutos` (novo) | 30 | Tempo mínimo útil antes do corte |

- **Divergência com o DER** (AGENTS §6): os dois campos novos não estavam no DER. Entram no DER e no §2.18 do `domain-model.md` nesta change.
- **`bootstrap`:** já preenche os parâmetros vazios de uma configuração existente (`parametros_ajustados`). Basta acrescentar os dois padrões, sem migração de dados.

**Instantes de uma entrada:**
- `corte = inicio - max(prazo_fila_minutos, antecedencia_min_minutos) * 60000` (como na D3);
- `fechamento = corte - tempo_minimo_fila_minutos * 60000` (novo);
- `prazo = min(aviso + prazo_confirmacao_fila_minutos * 60000, corte)`.

**Regras, com os limites:**
- **Entrada:** só com `agora < fechamento`. Fora disso: "A fila deste horário já está encerrada."
- **Aviso:** só com `agora < fechamento`. Assim, todo avisado tem pelo menos o tempo mínimo útil para confirmar, porque `prazo >= fechamento + tempo mínimo` quando `prazo = corte`.
- **Encerramento:** `AGUARDANDO` com `agora >= fechamento` passa a `ENCERRADA`. A auditoria registra o motivo `CORTE`, com `encerrou_em` = fechamento. A situação efetiva usa a mesma regra.
- **Confirmação:** continua aceita com `agora <= prazo`, e o prazo nunca passa do corte.
- **Busca:** `pode_entrar_fila` exige `agora < fechamento`.

**No código** (aplicado no grupo 9 de tarefas):
- uma função pura `fechamento_fila` (ou um input a mais em `corte_fila`) para o fechamento;
- `processar_fila`: encerra no fechamento, avisa só antes dele e calcula o prazo com o parâmetro novo;
- `entrar_fila`, `minha_fila` e `buscar_espacos`: usam o fechamento;
- `situacao_efetiva_fila`: recebe o fechamento no lugar do corte para a `AGUARDANDO`;
- as preconditions do bootstrap passam a conferir os campos novos onde forem lidos;
- parâmetros GET e POST, `LIMITES` e `ROTULOS_LIMITES`: os dois campos novos.

**Documentos:**
- **§7.4 do overview e §2.11 do domain-model:** prazo para confirmar e fechamento.
- **§2.18 e DER:** os dois parâmetros novos.
- **§11:** o e-mail de "vaga liberada" anotado como trabalho futuro.

## Confirmações do apply

**Tarefa 1.1:** o pull do workspace 147364, com a conta confirmada pelo usuário, trouxe 119 documentos. São iguais a `./xano`, exceto `bootstrap.xs` e `parametros_POST.xs`, que diferem só pelas vírgulas da decisão 27 da C8.

**Tarefa 1.2:** sondas no scratchpad, validadas no MCP (documentação 2.7.1) e sem push:
- **`db.query` com `sort` de várias chaves** (`{nivel_prioridade: "desc", criado_em: "asc", id: "asc"}`) e `paging`: válido. A documentação só mostra uma chave, então a ordem efetiva entre as chaves é conferida em execução nos testes 6.2 e 6.3.
- **`|filter` e `|some`** com expressão sobre lista em memória e comparação de instantes em ms: válidos.
- **Maior entre dois inteiros:** `|num_max` não é reconhecido pelo validador. `|max:valor` valida, mas `max` também é o alias de `array_max`, o que deixa ambíguo o comportamento em execução. Por isso, o maior entre `prazo_fila_minutos` e a antecedência mínima é calculado com `conditional`, sem filtro.
- **Rota GET com consulta `count` e chamada condicional de `aplicar_vencimentos`:** válida.
- **Tabela com enum de situação e referências a outras tabelas:** mesmo padrão de `reserva.xs`, já publicado. É conferido na validação da tarefa 3.1.

## Verificação do apply: o que foi testado e o que não foi

**Backend (grupo 6):** scripts contra o workspace, com o cenário de teste (unidade 18, tipo 13 "TST Fila C9", espaços 88 a 95 e 51 espaços extras C9-G01 a G51, contas 100 a 106 e o admin de teste). Todos os casos das tarefas 6.1 a 6.12 passaram:

| Teste | Casos |
|---|---|
| 6.1 | 17/17 (o caso do limite de ativas foi refeito depois de um erro do próprio teste) |
| 6.2 | 18/18, mais 6/6 da expiração de pendente com espera real |
| 6.3 | 7/7, incluindo a cadeia da D5 |
| 6.4 | 15/15 |
| 6.5 | 14/14 |
| 6.6 | 12/12 |
| 6.7 | 9/9, mais 4/4 do acúmulo de 51 pendentes (2,6 s e 0,6 s) |
| 6.8 | 8/8 |
| 6.9 | 9/9 |
| 6.10 | 12/12, lendo a auditoria pela função temporária `tst_c9_auditoria` |
| 6.11 | 9/9, incluindo o 403 do admin secundário (coordenador de teste promovido e rebaixado de volta) |
| 6.12 | 14/14 |
| Lacunas apontadas pelo guardian | 5/5: retida vencida sem próximo não impede a criação; lotes de 50 + 1 confirmados pelos intervalos entre registros; `ATENDIDA` não aceita desistência |

**Verificações com folga, não no instante exato:**
- **Corte da entrada:** testado com o corte cerca de 35 s à frente (aceita) e 25 s atrás (recusa). O milissegundo exato fica para a revisão de código (`<` e `>=`).
- **Confirmação "no último minuto":** o prazo é exibido truncado em `HH:MM`, e a confirmação foi feita de 5 s a 64 s antes do prazo real. O limite inclusivo no instante exato não foi testado em execução.
- **Concorrência:** uma rodada por cenário, sem controle da ordem real das chamadas. O resultado é compatível com a atomicidade pela trava global, mas não prova a ausência de corrida.
- **Privacidade da busca e da fila:** conferida por uma lista de chaves proibidas, não por uma lista de chaves permitidas.
- **Regressão:** cobre parte das mensagens de horário, o limite, o conflito, as reservas encostadas, o deslocamento, o cancelamento no prazo, a aprovação, a recusa e a gestão com reserva em andamento. Os limites das 08h00 e das 22h40 e o cancelamento recusado dentro das 2 horas não foram repetidos.

**Não testado em execução:**
- **Mover o espaço de unidade:** usa o mesmo caminho (`cancelar_reservas`, modo `espaco`) que a desativação e a troca de tipo, testadas.
- **Desativar o tipo ou a unidade com entradas ativas:** mesmo caminho. O tipo B foi desativado sem entradas.
- **Inativar uma conta com entrada `NOTIFICADA`:** o teste usou uma entrada `AGUARDANDO`. O encerramento não depende da situação.
- **Empate de prioridade entre filas sobrepostas** (a retenção vai para quem entrou antes): só a prioridade maior foi testada entre filas sobrepostas. O empate na mesma fila foi testado.
- **Corte de 30 dias das finalizadas em `minha_fila`:** o teste só confere que as finalizadas recentes aparecem.
- **O `id` como último desempate:** não ficou isolado em nenhum teste.
- **"Papel sem permissão":** testado desligando `aluno_pode_reservar` no tipo de teste, e não com uma sala de aula real. É equivalente.

**Reflex (grupo 7), no navegador (Playwright, `reflex run --env prod`):**
- **Cliente (7.1):** as quatro funções novas foram chamadas de verdade (5/5).
- **Aviso no topo:** aparece no Início e em "Buscar espaços" para quem tem vaga retida (`aluno1` e `aluno3`), e não aparece para o professor.
- **Busca do aluno:** "Entrar na fila" no espaço ocupado, diálogo com o aviso do prazo, mensagem de sucesso e a etiqueta "Você está na fila".
- **Busca do professor:** no mesmo espaço, aparece "Deslocar e reservar", sem oferta de fila; no espaço livre, "Reservar".
- **"Minhas reservas":**
  - seção "Fila de espera" com a situação, a posição, o prazo, "Confirmar", "Desistir" e "Sair da fila", e as encerradas abaixo;
  - confirmar criou a reserva em "Próximas" e tirou o aviso;
  - sair da fila levou a entrada para "Você desistiu".
  - A mensagem aparece um ou dois segundos antes de a lista recarregar, como nas outras ações da página.
- **Correção feita no teste:** o estado da fila não era limpo ao sair, e o aviso da conta anterior podia aparecer por um instante para a próxima pessoa no mesmo navegador. Agora `FilaState.limpar` roda no `on_load` do login e do cadastro, e o primeiro carregamento de outra conta não mostra nada da anterior.
- **Chamadas ao Xano por navegação** (contadas pelo `on_load` de cada página; as chamadas saem do servidor Reflex, não do navegador):

  | Página | Chamadas |
  |---|---|
  | Início | 2 (sessão e `minha_fila`) |
  | "Buscar espaços" | 4 (sessão, filtros, unidades e `minha_fila`) |
  | "Minhas reservas" | 3 (sessão, reservas e `minha_fila`) |
  | Páginas de gestão | 3 |

  O aviso global acrescenta uma chamada por página. Nos testes, o plano gratuito devolveu 429 só em rajadas de scripts, com mais de 10 chamadas seguidas. Na navegação manual, nenhum 429 apareceu.
- **Não testado no navegador:**
  - a página "Parâmetros", porque o admin de teste é o principal e a senha dele não é digitada nas ferramentas. O campo foi conferido pela API (6.11) e pela revisão de `LIMITES` e `ROTULOS_LIMITES`;
  - o botão "Desistir" de uma vaga retida, que usa o mesmo diálogo e o mesmo evento de "Sair da fila" e foi testado pela API (6.5);
  - a recusa dentro do diálogo de entrar na fila, que é tratada como no diálogo de reserva e teve a recusa testada pela API (6.1).

**Update D12 (grupo 9, 20/11/2026):**
- **Publicação:** dry-run aprovado, push de 129 documentos e `bootstrap` executado (1ª execução gravou 720 e 30; a 2ª não alterou nada). O pull só difere pelas vírgulas da decisão 27 da C8.
- **Testes do D12** (cenário novo: unidade 19, tipo 15, espaços 147 a 154, contas 110 a 116), 16/16:
  - GET com os três parâmetros, e POST com 0 recusado para cada um;
  - prazo cheio de cerca de 720 minutos, e prazo limitado ao corte;
  - aviso antes do fechamento: o prazo vai até o corte, com ao menos o tempo mínimo útil;
  - busca e entrada antes e depois do fechamento;
  - vaga liberada depois do fechamento: a entrada fica `ENCERRADA`, sem aviso, e o horário fica livre;
  - entrada a cerca de 35 s antes do fechamento é aceita, e a cerca de 25 s depois é recusada.
- **Regressão com os parâmetros novos:** 6.2 sem falhas, 6.3 7/7 e 6.5 14/14. O 6.5 precisou de um ajuste no preparo do caso do limite: ocupar o horário antes de baixar o limite.
- **Auditoria (5/5):** `ENCERRAR_FILA` com o instante do fechamento, `NOTIFICAR_FILA` com o prazo de cerca de 720 minutos, e `ALTERAR_PARAMETROS` com os valores antigos e novos dos dois parâmetros. Lida pela função temporária `tst_c9_auditoria`, publicada de novo com aprovação.
- **Navegador:** o aviso mostra "Confirme até" 12 horas depois do aviso, sem erro no console. Isso confirma no navegador a correção do HTML do aviso (decisão 24).
- **Não testado nesta rodada:**
  - a página "Parâmetros" no navegador (admin principal), conferida pela API e pela revisão de `LIMITES` e `ROTULOS_LIMITES`;
  - o fechamento no milissegundo exato, testado com folga de segundos;
  - requisições simultâneas exatamente na fronteira do fechamento. O caminho é o mesmo da trava global, testado no 6.8;
  - o fechamento pela antecedência mínima do tipo combinada com o tempo mínimo útil, que segue a mesma fórmula testada.

**Observação do teste do cliente (7.1):** com a rajada de logins dos scripts, o plano gratuito devolveu 429, e o cliente mostrou a mensagem de "Muitas tentativas". O aviso global faz uma chamada a mais por página (`minha_fila`). A tarefa 7.2 mede isso no navegador.

## Risks / Trade-offs

- **[Risco] A fila não anda sem tráfego.** O próximo só é avisado quando alguém usa o sistema. → A verificação de `minha_fila` em toda página autenticada cobre quem está esperando a vaga. A situação efetiva impede que uma vaga vencida bloqueie alguém. É uma limitação aceita do plano gratuito (§8).
- **[Risco] `minha_fila` em toda página pega a trava global quando há vencimento.** As leituras ficam serializadas com as escritas nesse momento. → A trava só é pega depois da verificação rápida encontrar algo, e a gravação é curta, limitada pelo teto.
- **[Risco] Falha repetida da faxina.** `aplicar_vencimentos` engole a falha e desfaz a transação inteira, inclusive as expirações de reservas. Como `minha_fila` roda em toda página, uma falha persistente em `processar_fila` se repetiria a cada navegação, pegando a trava global. → Teto por passo para a rodada ser curta. O teste 6.7 cobre o acúmulo (mais de 50 vencidas) e confere que o erro vai para o log e a página continua respondendo.
- **[Risco] Dono que perde a permissão no tipo durante a retenção.** O papel pode mudar (`alterar_papel`), ou o admin pode tirar a permissão do papel (`definir_regras_tipo`). A rede de segurança da D5 não encerra esses casos. A vaga fica retida até o prazo, e a confirmação é recusada pela regra do papel. → Aceito como limitação. A alternativa é estender a rede de segurança para conferir a regra do papel, ao custo de mais consultas por rodada (para o usuário decidir na revisão).
- **[Risco] Custo da faxina a cada operação.** → Saída cedo quando não há entradas ativas, uma consulta de ocupação por rodada e teto por passo.
- **[Risco] Regressão em `criar_reserva` pelo refatoramento da D7.** → Repetir os testes principais da C6 à C8: regras de horário, limite, conflito, deslocamento com e sem confirmação, e concorrência.
- **[Risco] Objetos literais do Xano.** As respostas novas têm várias chaves, e os literais perdem chaves sem vírgulas. → Usar `|set` em todas as respostas e auditorias.
- **[Trade-off] Fila sobreposta de nível maior pode esperar enquanto uma de nível menor sem sobreposição é avisada** (cadeia da D5). → É a leitura literal da §7.4, confirmada pelo guardian e fixada em cenário.
- **[Trade-off] A posição na fila conta só o mesmo intervalo.** Filas sobrepostas de prioridade maior podem passar à frente na prática. → O texto da tela diz "posição nesta fila", sem prometer ordem global.
- **[Trade-off] A confirmação recusada pelo limite de ativas mantém a vaga retida até o prazo.** → É coerente com "a confirmação passa por todas as validações". A pessoa pode cancelar outra reserva e confirmar dentro do prazo, ou desistir.

## Migration Plan

1. **Xano**, pelo CLI e com dry-run mostrado ao usuário e aprovado:
   - a tabela `entrada_fila`;
   - o campo em `configuracao_geral`;
   - as funções novas e alteradas;
   - as rotas novas e alteradas.
2. **Bootstrap:** rodar de novo para gravar `prazo_fila_minutos = 120`. A carga é idempotente (C8, D9).
3. **Reflex:** cliente, State, páginas e `on_load`. Não há dependência nem variável de ambiente nova.
4. **Rollback:**
   - reverter as rotas e as funções pelo CLI;
   - a tabela `entrada_fila` e o campo novo podem ficar, porque nenhum código antigo os lê;
   - entradas `NOTIFICADA` deixadas por um rollback não retêm nada no código antigo.
5. **Update de 20/11/2026 (D12):**
   - push com dry-run e aprovação dos dois campos novos em `configuracao_geral`, do `bootstrap`, da função de fechamento e das funções e rotas alteradas;
   - rodar o `bootstrap` duas vezes: a primeira grava 720 e 30, a segunda não altera nada;
   - publicar o Reflex com os campos novos em "Parâmetros".
   - Enquanto o `bootstrap` não roda, as rotas que leem os campos novos recusam com "execute o bootstrap", como nos outros parâmetros.
