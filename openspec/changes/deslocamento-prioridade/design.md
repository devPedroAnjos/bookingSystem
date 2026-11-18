## Context

Motivação e escopo: ver `proposal.md`. As decisões do explore estão no `decisions-log.md`. Os requisitos estão nas specs delta.

Estado atual que molda a solução:
- **`criar_reserva` (C6 e C7):**
  - tudo acontece dentro de `db.transaction`, com `travar_governanca` como primeira instrução;
  - a ordem é: conta ativa, releitura do espaço, regra do papel, regras de horário, *(C10: penalidade)*, limite de ativas, *(C11: bloqueio)*, conflito e gravação;
  - o conflito hoje é uma consulta `exists` com o predicado de ocupação da C7 (D2): `CONFIRMADA` ou `PENDENTE` com `inicio > agora`;
  - o nível é calculado na hora da gravação: `ALUNO` 1, `PROFESSOR` 2, os demais 3;
  - a faxina (`aplicar_vencimentos`) roda antes da transação.
- **Rollback:** um `precondition` dentro de `db.transaction` desfaz tudo o que ela gravou. Por isso, a resposta "requer confirmação" não pode ser um `precondition`, porque ela não grava nada e precisa de um corpo próprio (D4).
- **Erros na API:** o Xano devolve no corpo do erro só a mensagem do `precondition`. A documentação (2.7.1, `essentials`) não mostra um campo próprio além dela. O cliente Reflex (`_requisitar`) lê só `message` e transforma 400 em `ErroValidacao`.
- **`cancelar_reservas` (C6, D10 e D11):** grava `CANCELADA`, o motivo, quem cancelou e quando, um `CANCELAR_RESERVA` por reserva (com a unidade do espaço) e o texto da mensagem. Os modos atuais (`conta` e `espaco`) selecionam as reservas por `selecionar_reservas_a_cancelar`.
- **`buscar_espacos` (C6 e C7):** sem trava e sem gravação. Faz uma consulta de reservas sobrepostas para todos os espaços e marca `ocupado`.
- **Parâmetros (C6, D12):** `prazo_cancelamento_minutos` aparece em seis pontos: tabela, `parametros_GET`, `parametros_POST` (no objeto `$limites` e na auditoria), `bootstrap`, `LIMITES` em `parametros_state.py` e `ROTULOS_LIMITES` em `parametros.py`.
- **Reflex:** `motivos.MOTIVOS_CANCELAMENTO["PRIORIDADE"]` já existe ("substituída por reserva de prioridade maior"). "Minhas reservas" e "Reservas da unidade" já mostram o motivo e, para o gestor, quem cancelou (C7, D9).
- **Numeração:** esta change renumera o roadmap (proposal). Aqui, C9 é a fila, C10 as penalidades, C11 os bloqueios e C14 as notificações.

## Goals / Non-Goals

**Goals:**
- Uma única regra de deslocamento, usada pela criação e pela busca, para o aviso e a ação nunca divergirem (como `selecionar_reservas_a_cancelar` faz para o impacto).
- O cancelamento das deslocadas e a gravação da nova na mesma transação, sob a mesma trava.
- O frontend decide pela resposta estruturada, nunca pelo texto da mensagem.

**Non-Goals:**
- Alterar `cancelar_reserva`, `minhas_reservas`, `reservas_unidade`, `impacto_reservas` e as ações de gestão.
- Mexer na faxina: o deslocamento não cria vencimento novo.
- Paginação ou desempenho da busca além do que já existe.

## Decisions

### D1. Campos

| Tabela | Campo | Tipo | Observação |
|---|---|---|---|
| `reserva` | `deslocada_por_reserva_id` | int?, referência a `reserva` | preenchido só no cancelamento `PRIORIDADE` |
| `configuracao_geral` | `prazo_deslocamento_minutos` | int? | padrão 120, gravado pelo `bootstrap`; inteiro >= 1 |

- **Nomes:** os do DER, sem divergência.
- **Sem índice novo:** o campo novo não é consultado. A auditoria e o gestor chegam à reserva pelo id.
- **Leitura do prazo:** direto de `configuracao_geral`, como o prazo de cancelamento (C6, D12). `obter_configuracao_horario` não muda.

### D2. Função única da regra: `avaliar_deslocamento`

**Entradas:**
- `conflitantes`: as reservas ativas sobrepostas, já filtradas pelo predicado de ocupação;
- `nivel_solicitante`;
- `inicio_novo`;
- `nasce_confirmada`;
- `prazo_minutos`;
- `agora` (ms).

**Saída:** `{deslocavel, quantidade}`.

`deslocavel` é verdadeiro somente quando todas as condições abaixo valem:
- há conflitantes;
- todas as conflitantes têm `nivel_prioridade < nivel_solicitante`;
- `nasce_confirmada`;
- `inicio_novo - agora > prazo_minutos * 60000`;
- para toda conflitante, `inicio - agora > prazo_minutos * 60000`.

Detalhes:
- **Estritamente maior nas duas comparações de prazo.** O texto do domínio diz "mais de 2 horas". O cancelamento usa `>=`, e o contraste é intencional (decisions-log 7).
- **Função pura:** sem consulta ao banco. Quem chama monta as conflitantes, então a busca reaproveita a consulta que já faz.
- **Junto vai `nivel_do_papel(papel)`:** função que extrai o cálculo do nível, hoje embutido em `criar_reserva`, para a criação e a busca usarem a mesma tabela de níveis.
- **Alternativa descartada:** repetir a regra na busca e na criação. As duas divergiriam com o tempo, e a C9 (fila) também vai precisar dela, para oferecer a fila só a quem não pode deslocar.

### D3. `criar_reserva`: entrada e passo do conflito

**Entrada nova:** `bool deslocar?=false`.

**Passo 9:** a consulta `exists` vira `list`, com o mesmo predicado, e o resultado é `$conflitantes`. Depois:

| Situação | Resultado |
|---|---|
| Nenhuma conflitante | grava como hoje |
| `avaliar_deslocamento` dá não deslocável | `precondition` com a mesma mensagem de hoje ("Horário ocupado: já existe uma reserva neste espaço nesse intervalo.") |
| Deslocável e `deslocar` falso | **não grava nada** e responde pedindo confirmação (D4) |
| Deslocável e `deslocar` verdadeiro | grava a nova reserva, depois cancela as conflitantes (D5) e grava a auditoria (D6) |

- **`nasce_confirmada`** = `!$regra.exige_aprovacao`, que é a mesma regra que define o status gravado.
- **`nivel_solicitante`** vem de `nivel_do_papel($ator.papel)`, e a gravação usa o mesmo valor.
- **Ordem dentro da transação:** a nova reserva é gravada primeiro, porque as deslocadas precisam do id dela.
  - A sobreposição momentânea fica dentro da transação, que é atômica e protegida pela trava. Nenhuma leitura fora dela a enxerga.
  - A garantia vem da transação e da trava, não de uma restrição do banco, que não existe para sobreposição.
  - A lista de conflitantes é lida dentro da mesma transação, então o modo `prioridade` (D5) cancela exatamente o que foi avaliado.
- **O limite de ativas (passo 7) continua antes do conflito.** Um solicitante no limite é recusado pelo limite, sem chegar ao deslocamento.
- **Alternativa descartada:** rota de prévia separada, no padrão de `impacto_reservas`. Seria uma chamada a mais, e a regra teria de ser recalculada na criação de qualquer jeito.

### D4. Resposta de "requer confirmação" (200, sem gravação)

A criação responde **200** com:
- `requer_confirmacao: true`;
- `deslocaria`: a quantidade;
- `mensagem`;
- `reserva_id` e `status` nulos.

Mensagens:
- uma reserva: "Este horário está ocupado por 1 reserva de prioridade menor. Confirme para deslocá-la.";
- N reservas: "Este horário está ocupado por N reservas de prioridade menor. Confirme para deslocá-las.".

**Respostas de sucesso:** passam a trazer também `requer_confirmacao: false` e `deslocadas` (a quantidade). Quando ela é maior que zero, a mensagem ganha o complemento " 1 reserva de prioridade menor foi deslocada." ou " N reservas de prioridade menor foram deslocadas.".

**Contrato para outros consumidores** (por exemplo, a recorrência, na C12): o cliente decide só por `requer_confirmacao`. `reserva_id` nulo significa que nada foi gravado.

**Implementação:** a gravação e a auditoria ficam num `conditional` dentro da transação. A variável `$requer_confirmacao` é declarada fora dela, como `$reserva_id` já é, e a resposta é montada depois.

**Por que 200 e não 400 com um código:**
- o guardian pediu um código distinto, para o frontend não depender do texto;
- o `precondition` não carrega um campo próprio (Context);
- um 400 também passaria por `tratar_erro_api` como `ErroValidacao`;
- um 200 com campo booleano cumpre a exigência com o mecanismo já confirmado.

**Alternativas descartadas:**
- 400 com o código no texto da mensagem: o frontend dependeria do texto;
- `throw` com `name` próprio: o corpo devolvido não está documentado e exigiria sondagem em execução.

### D5. Cancelamento das deslocadas: `cancelar_reservas` com modo `prioridade`

`cancelar_reservas` ganha:
- o modo `prioridade`;
- as entradas opcionais `reservas` (a lista lida na transação) e `deslocada_por_reserva_id`.

**No modo `prioridade`:**
- não chama `selecionar_reservas_a_cancelar` e usa a lista recebida;
- grava `deslocada_por_reserva_id`, o motivo `PRIORIDADE`, `cancelado_por_id` (o solicitante) e `cancelado_em`;
- `motivo_detalhe` e `motivo_descricao` ficam vazios.

**A edição e a auditoria são as mesmas dos outros modos.** Ninguém mais grava `CANCELADA` com outro formato (AGENTS §7).

**Alternativa descartada:** uma função `deslocar_reservas` própria. Ela repetiria a edição, a auditoria e a busca da unidade.

### D6. Auditoria

| Ação | Ator | Unidade | Dados |
|---|---|---|---|
| `CRIAR_RESERVA` | o solicitante | unidade do espaço | os de hoje e, quando houve deslocamento, `deslocadas` com a lista de ids |
| `CANCELAR_RESERVA` (uma por deslocada) | o solicitante | unidade do espaço | antes: `status`; depois: `status` `CANCELADA`, `motivo_cancelamento` `PRIORIDADE` e `deslocada_por_reserva_id` |

- **Reaproveita `CANCELAR_RESERVA`** com o motivo, em vez de criar `DESLOCAR_RESERVA`. É o mesmo padrão dos cancelamentos automáticos da C6, e a spec `auditoria` já filtra por motivo.
- **Sem registro:** o pedido de confirmação (D4) e as recusas não geram registro.

### D7. `buscar_espacos`

- **O que lê a mais:** o `prazo_deslocamento_minutos` e o nível do papel de quem busca, por `nivel_do_papel`.
- **Para cada espaço incluído com horário:**
  - as conflitantes são as `$sobrepostas` daquele espaço, porque a consulta já traz a lista completa;
  - `avaliar_deslocamento` recebe `nasce_confirmada = !$regra.exige_aprovacao`;
  - o item ganha `deslocavel` e `deslocaria`.
- **Espaço livre ou fora das regras do tipo:** `deslocavel` falso e `deslocaria` 0. A criação recusa pelas regras antes de olhar o conflito, então a busca não oferece deslocamento que a criação recusaria.
- **Sem data e horário:** as chaves `deslocavel` e `deslocaria` ficam ausentes, como `ocupado` e `dentro_das_regras`.
- **Continua sem trava e sem gravação.** As indicações são informativas, como `ocupado`, e não identificam ninguém. Só a quantidade sai da função.

### D8. Reflex

**Cliente:** `criar_reserva(token, espaco_id, data, hora_inicio, hora_fim, deslocar=False)` envia `deslocar`.

**`busca_state.py`:**
- `_espaco_para_tela` ganha:
  - `deslocaria` (texto);
  - `pode_deslocar`: "sim" quando o horário está dentro das regras, o espaço está ocupado e `deslocavel` é verdadeiro.
- `abrir_reservar` guarda `deslocar = (espaco["pode_deslocar"] == "sim")` e monta o aviso de quantas reservas serão canceladas.
- `confirmar_reservar` envia `deslocar`:
  - se a resposta vier com `requer_confirmacao`, a confirmação continua aberta, com o aviso da mensagem da API, e passa `deslocar = True`. Só um segundo clique cria. Esse é o caso de um espaço que parecia livre;
  - no sucesso, mostra a `mensagem` da API, que já traz as deslocadas;
  - no `ErroValidacao`, como hoje, mostra a recusa dentro da confirmação.

**`buscar.py`:**
- botão "Deslocar e reservar" quando `pode_deslocar` é "sim";
- "Reservar" continua só para os livres;
- a confirmação mostra o aviso de deslocamento quando houver.

**Parâmetros:**
- `prazo_deslocamento_minutos` em `LIMITES` (`parametros_state.py`);
- em `ROTULOS_LIMITES` (`parametros.py`), o rótulo "Prazo para deslocar por prioridade, em minutos antes do início".

**Sem mudança:** "Minhas reservas" e "Reservas da unidade", que já mostram o motivo `PRIORIDADE` e, para o gestor, quem cancelou.

### D9. Parâmetro nos seis pontos

O mesmo caminho do prazo de cancelamento (Context):
- tabela;
- `parametros_GET`;
- `parametros_POST`: no objeto `$limites`, o que já dá a validação >= 1 e a gravação, e nos dados de auditoria antes e depois;
- `bootstrap`: 120 quando vazio, com o laço de ajuste já existente;
- `LIMITES` e `ROTULOS_LIMITES`.

**O POST exige todos os limites juntos.** Os testes de API mandam o conjunto completo.

### D10. Documentos

**`project-overview.md`:**
- §7.3, condição 2: "a nova reserva e cada reserva deslocada começam a mais de `prazo_deslocamento_minutos` (padrão 2 horas) de agora; reserva em andamento nunca é deslocada";
- §10: "deslocar" já está na lista de auditadas, e a nota diz que é um `CANCELAR_RESERVA` com motivo `PRIORIDADE`;
- §11, item 8: passa a ser a C8 (`deslocamento-prioridade`).
- §11, item 9: passa a ser a fila de espera (C9), com as pendências da C6 e da C7 e as decisões do explore (decisions-log 2 a 6 e 15):
  - um parâmetro só, `prazo_fila_minutos`, para o prazo de confirmação e o corte antes do início;
  - o prazo do próximo conta do aviso real, e o vencimento de quem estava antes é gravado com o instante real;
  - a criação de reserva e a entrada na fila processam os vencimentos e a fila do espaço antes de avaliar o conflito, para não furar a fila;
  - aviso em "Minhas reservas" e no Início, sem a tabela de notificação;
  - a entrada na fila valida as regras da criação, menos o conflito e o limite de ativas, que é conferido na confirmação;
  - **em aberto:** confirmação de fila em tipo que exige aprovação, que gera uma `PENDENTE`;
  - o deslocamento libera as sobras parciais para a fila, a retenção não é deslocável e a fila só é oferecida a quem não pode deslocar (`avaliar_deslocamento`).
- §11, itens 10 a 15: os itens seguintes são renumerados, mantendo as pendências que já têm. As penalidades (10) recebem a penalidade ativa também na entrada da fila. As notificações (14) recebem "avisar o deslocado".

**`domain-model.md`:**
- §2.9: regra do deslocamento com as três condições e a precisão do prazo;
- §2.18: conferir "Antecedência mínima para deslocar por prioridade" (já existe) e o DER (o campo já existe).

## Risks / Trade-offs

- **[A busca diz deslocável e a criação recusa]** O prazo passou, ou o conflito mudou. → As indicações são informativas, a criação recalcula tudo na trava, e a tela mostra a recusa na confirmação, como já faz com "ocupado".
- **[O deslocado não é avisado até a C14]** → O prazo mínimo de 2h dá margem, e "Minhas reservas" mostra o motivo. A limitação fica registrada na proposal.
- **[Sobras parciais livres sem fila]** Por exemplo, das 9h às 10h, depois de deslocar uma reserva das 9h às 12h por uma das 10h às 11h. → Ficam livres para reserva direta, e a fila é tratada na C9.
- **[Cliente Reflex antigo com o Xano novo]** Um cliente antigo leria a `mensagem` de "confirme" como sucesso. → O Xano e o Reflex sobem juntos na mesma change, e o pedido sem `deslocar` nunca grava nada. No pior caso, nada é deslocado sem confirmação.
- **[`cancelar_reservas` com três modos]** → O modo novo não usa a seleção, e cada modo é coberto por teste de regressão (C6).
- **[Lições de Xano]** → Objetos com `|set`, `is_null` em checagens de vazio, nenhum filtro dentro de literal, nomes de rota únicos, `.xs` sem BOM. Cada chave da resposta usada pela tela é testada em execução.
- **[Literais sem vírgula na forma do pull]** No primeiro push, o Xano converteu o `$resultado` do `bootstrap`, sem vírgulas, em bloco entre crases, e a resposta perdeu `principal_marcado` (decisions-log 25). → Por decisão do usuário (decisions-log 27), `bootstrap.xs` e `parametros_POST.xs` são versionados **com vírgulas** nos literais longos, a forma que funciona em execução. No pull de comparação, diferença só de vírgulas e colunas nesses dois arquivos não é defeito. Depois de qualquer push desses arquivos, conferir em execução o resultado do `bootstrap` e o `GET parametros`.
- **[A quantidade deslocada pode crescer entre a busca e o clique]** Com "Deslocar e reservar", a tela envia `deslocar=True` desde o primeiro clique, e a criação recalcula tudo. Se outra reserva de prioridade menor entrar no intervalo nesse meio-tempo, o professor que viu "1 reserva" desloca 2. → **Limitação aceita pelo usuário** (decisions-log 26): o caso é raro, só atinge reservas de prioridade menor dentro das regras do deslocamento, e a mensagem de sucesso informa a quantidade real. A alternativa de a API conferir a quantidade confirmada mudaria o contrato e foi descartada nesta change.
- **[Instante exato do prazo]** O relógio real não permite acertar o milissegundo. → Testes com o limite de 120 min, inteiro, e de 121 min. O `>` estrito também fica coberto por revisão de código.

## Migration Plan

1. Push com dry-run e aprovação:
   - campo em `reserva` e em `configuracao_geral`;
   - `bootstrap`;
   - as funções novas (`avaliar_deslocamento` e `nivel_do_papel`) e a alterada (`cancelar_reservas`);
   - as rotas `criar_reserva`, `buscar_espacos`, `parametros_GET` e `parametros_POST`.
2. Executar o `bootstrap` duas vezes pelo CLI: a primeira grava 120 e a segunda não altera nada.
3. Reflex na mesma change.
4. **Rollback:** novo push com os arquivos anteriores. As reservas já deslocadas continuam `CANCELADA`, conforme o domínio, e o campo novo fica sem uso.

## Confirmações do apply

Confirmado no Xano Developer MCP (documentação 2.7.1), com arquivos de sonda validados e sem push (tarefa 1.2):

| Item | Sintaxe confirmada | Evidência |
|---|---|---|
| Campo autorreferente | `int? deslocada_por_reserva_id? { table = "sonda_reserva" }` numa tabela que referencia a si mesma | Sonda de tabela válida |
| Gravação condicional na transação | `db.transaction { stack { function.run travar_governanca ...; conditional { if (...) { var.update ... } else { db.add ... as $nova; var.update $reserva_id {...}; function.run ... } } } }`, com `$reserva_id` e `$requer_confirmacao` declaradas antes da transação | Sonda de função válida |
| Regra sobre a lista | `$lista\|every:($$.nivel_prioridade < $input.nivel_solicitante)`, `$lista\|filter:($$.inicio <= $limite)` e `$limite = $input.agora + ($input.prazo_minutos * 60000)` | Sonda de função válida. No controle negativo, o `\|every` com um parêntese a menos foi recusado na linha certa |
| Booleano composto | calculado num `conditional` (`if ($quantidade > 0 && $todas_menores && ...)`) que atualiza uma variável iniciada em `false`, e não em `value` de variável (memória do projeto: `x == true` vira `x` e o `&&` em `value` deu `null`) | Sonda válida; o valor em execução é conferido no grupo 6 |
| Quem cancelou nas listagens | `reservas_unidade` devolve `cancelado_por` para todo motivo, exceto `CONTA_INATIVADA` (`reservas_unidade_GET.xs`, linha 392); `minhas_reservas` não devolve `cancelado_por` | Leitura do código |

O comportamento em execução (`|every` com lista vazia, comparação de instantes e gravação condicional) é conferido nos testes do grupo 6.

**Publicação (grupo 5):**
- **Primeiro push:** o dry-run listou 14 itens, todos desta change:
  - 6 de tabela: `UPDATE` e `ADD_FIELD` em `configuracao_geral` e em `reserva`, mais dois `UPDATE_FIELD` de comentário em `reserva`;
  - 4 funções: `CREATE` de `avaliar_deslocamento` e `nivel_do_papel`, `UPDATE` de `bootstrap` e `cancelar_reservas`;
  - 4 rotas.
- **Segundo push:** só o `bootstrap` (decisions-log 25).
- **Terceiro push:** só a função temporária `tst_c8_auditoria`, com `-i`, para não reenviar o `bootstrap`. Ela é só de leitura e é removida na limpeza.

## Verificação do apply: o que foi testado e o que não foi

**Cenário:**
- scripts descartáveis contra o workspace publicado;
- unidade 17 "TST C8" e unidade 15 "TST C7", reativada só para o teste, porque a unidade nova exige um coordenador;
- tipo 12, com horário de 00h00 a 23h50 e antecedência 0;
- espaços 84 a 87 e contas 93 a 99.

**Resultados, sem falha:**

| Tarefa | O que cobriu | Resultado |
|---|---|---|
| 6.1 | as condições a) a k) | 28/28 |
| 6.2 | limite do prazo para a conflitante e para a nova, ajustando o parâmetro em torno do instante real; reserva em andamento e pendente vencida, com espera do início real | 14/14 |
| 6.3 | confirmação | 18/18, mais 17/17 na auditoria pela função temporária |
| 6.4 | concorrência | 9/9 em cada uma das 3 rodadas, com as duas ordens da corrida "deslocar × cancelar pelo dono" |
| 6.5 | busca | 9/9 |
| 6.6 a 6.8 | parâmetros, listagens e regressão da C6 e da C7 (modos `conta` e `espaco`, gestão com reserva em andamento, aprovação, recusa e expiração) | 19/19, mais 2/2 |
| 7.1 | cliente Reflex com e sem `deslocar` | 3/3 |
| 7.2 e 7.4 | no navegador: "Deslocar e reservar", espaço que parecia livre (o diálogo fica aberto e só o segundo clique grava), aluno sem o botão e a reserva deslocada em "Minhas reservas" | todos os casos |

**Não testado em execução:**

| Ponto | Por que não | Como ficou coberto |
|---|---|---|
| Milissegundo exato do prazo (`inicio == agora + prazo`) | O relógio real não permite acertar o milissegundo. Os testes cercaram o limite com `ceil(d)+1`, que recusa, e `floor(d)-1`, que desloca | Revisão de código: `>` estrito em `avaliar_deslocamento` |
| "O deslocamento não gera falta" | A tabela de faltas só existe na C10 | Revisão de código: nenhum ponto desta change cria falta |
| 403 do admin secundário nos parâmetros | Não há conta de admin secundário com senha conhecida | O 403 do coordenador passou, e o `exigir_principal` não mudou nesta change |
| Limites de 22h40 e de 08h00 com `deslocar` | O tipo de teste vai de 00h00 a 23h50 | A recusa pelas regras antes do deslocamento foi testada pela granularidade, e as regras de horário são as da C6 |
| Página "Parâmetros" no navegador | A conta de admin de teste é a do principal, e a senha não é digitada nas ferramentas | API (6.6) e revisão de `LIMITES` e `ROTULOS_LIMITES` |
| "Nenhuma auditoria" na busca | Não há um id de reserva para conferir | `buscar_espacos` não tem gravação nem `registrar_auditoria` |

**Observações:**
- Com o filtro `-i`, o push avisou que as tabelas "não existem", mas a função temporária consultou as tabelas reais. O aviso vem do filtro.
- O dry-run sem filtro mostra `UPDATE` no `bootstrap`, mesmo com o arquivo local igual ao pull, byte a byte. Por isso o terceiro push usou `-i` (decisions-log 27).
- O plano gratuito devolveu 429 algumas vezes durante os testes, e a tela de busca mostrou a mensagem de limite corretamente.
- Cosmético: o botão "Deslocar e reservar", em `size="1"`, quebra em duas linhas na tabela da busca.
