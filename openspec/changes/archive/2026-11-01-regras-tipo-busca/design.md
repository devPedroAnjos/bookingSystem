## Context

A C4 deixou prontos os padrões que esta change reutiliza:
- trava de governança como primeira instrução de toda escrita;
- `exigir_admin` e `usuario_ativo` (este recebendo `emitido_em`);
- auditoria na mesma transação;
- grupo de API `espacos`, com uma consulta por tabela e junção em memória (C4 D8);
- `disponibilidade_espaco`, função sem acesso ao banco que a busca e a reserva reutilizam (C4 D8 e D13);
- carga inicial idempotente pelo `bootstrap` (C4 D9).

Lições da C4 que valem aqui (memória do projeto):
- nome de rota único no workspace inteiro, porque o Xano CLI casa rotas novas pelo nome;
- vírgulas entre as chaves de objetos com várias linhas dentro de expressões, porque sem elas uma chave se perde em execução;
- o Xano descarta padrões `false` e `0`, então valores assim são gravados explicitamente;
- push com `--force` só depois do dry-run aprovado.

O Xano **não tem tipo `time`**. O validador do MCP recusou `time hora_abertura?`, e a lista de tipos do MCP não o inclui.

A motivação está no `proposal.md`. Os requisitos estão nas specs `regras-tipo`, `busca-espacos`, `tipos-espaco`, `espacos`, `parametros`, `autorizacao` e `auditoria`. As decisões do explore estão no `decisions-log.md`.

## Goals / Non-Goals

**Goals:**
- Uma única função de validação de horário, `validar_horario_reserva`, que trabalha sobre instantes (timestamps), para que a reserva da C6 a reutilize sem conversão.
- Regras do tipo e regra por papel gravadas numa única operação, auditada e sob a trava.

**Non-Goals:**
- Checagem de conflito, de bloqueio, de fila e de penalidade (C6 a C10).
- Contagem de reservas ativas por usuário: o limite é só gravado nesta change.
- Regra por papel configurável para coordenador e admin.
- Paginação e cache da busca.

## Decisions

### D1. Divisão entre Xano e Reflex

```
REFLEX                                   XANO
- /buscar (todos)                        - tipo_espaco*: + 8 campos de regra
- /tipos-espaco*: dialogo "Regras",      - regra_papel (nova)
  selo "sem regras"                      - configuracao_geral*: + granularidade_minutos,
- /parametros*: granularidade e dias       dias_funcionamento
- menu*: "Buscar espacos" para todos     - funcoes novas: regra_do_papel, tipo_com_regras,
- xano_cliente*: definir_regras_tipo,      validar_horario_reserva, obter_configuracao_horario
  filtros_busca, buscar_espacos          - funcoes*: disponibilidade_espaco, bootstrap
- BuscaState (novo), TiposEspacoState*,    (obter_configuracao NAO muda)
  ParametrosState*                       - rotas novas (grupo espacos): definir_regras_tipo,
                                           filtros_busca, buscar_espacos
                                         - rotas*: tipos, geridos (espacos); parametros GET/POST
(* = alterado)                             (contas)
```

As rotas novas ficam no grupo `espacos`, para não criar outra variável de ambiente. Os nomes `definir_regras_tipo`, `filtros_busca` e `buscar_espacos` não existem em nenhum grupo; isso é conferido no dry-run.

### D2. Dados (DER do `domain-model.md`)

| Tabela | Campos | Divergências do DER |
|---|---|---|
| `tipo_espaco` | + `duracao_min_minutos`, `duracao_max_minutos`, `antecedencia_min_minutos`, `antecedencia_max_dias`, `max_reservas_ativas_usuario`, `hora_abertura_minutos`, `hora_fechamento_minutos` (todos `int?`) e `permite_recorrencia` (`bool?`) | O DER usa `time hora_abertura` e `time hora_fechamento`. Como o Xano não tem `time`, os horários são minutos desde a meia-noite (0 a 1439, porque o fechamento é sempre antes de 24h00, no mesmo dia), com o sufixo `_minutos` do mesmo padrão de `duracao_min_minutos`. Todos os campos são opcionais porque a tabela já tem linhas; vazio significa "sem regra". |
| `regra_papel` (nova) | `tipo_espaco_id` (FK), `papel` (text), `pode_reservar` (bool), `exige_aprovacao` (bool); índice único (`tipo_espaco_id`, `papel`) | Guarda só `ALUNO` e `PROFESSOR`. A regra de `COORDENADOR` e `ADMIN` é fixa (D4), por isso não tem linha. |
| `configuracao_geral` | + `granularidade_minutos` (`int?`), `dias_funcionamento` (`int[]`, ISO: 1 = segunda a 7 = domingo) | O DER tem `string dias_funcionamento`. A lista de inteiros segue o padrão de `dominios_email` (`text[]`) e evita converter texto. Os números começam em 1, então nenhum valor é 0 (que o Xano descarta como padrão). |

- `permite_recorrencia`, `pode_reservar` e `exige_aprovacao` são gravados sempre de forma explícita, inclusive quando falsos, porque o Xano descarta padrões `false`. O mesmo vale para `antecedencia_min_minutos = 0`. A 5.1 e a 6.0 conferem, depois do bootstrap, que esses valores voltam como `0` e `false`, e não como `null`. Se voltarem como `null`, o tipo seria tratado como "sem regras".
- A carga de `regra_papel` e as rotas usam `papel` em maiúsculas, como em `usuario.papel`.

### D3. Regras completas

`tipo_com_regras(tipo, regras_do_tipo)` devolve verdadeiro quando os oito campos do tipo não são nulos e existe uma linha de `regra_papel` para `ALUNO` e outra para `PROFESSOR`. A comparação é sempre `!= null`, nunca por valor verdadeiro ou não vazio, porque `0` e `false` são regras válidas. A função recebe os dados já carregados, sem consultar o banco, para a busca e a listagem não multiplicarem consultas.

`disponibilidade_espaco` ganha a entrada `bool? tipo_com_regras` e o motivo `TIPO_SEM_REGRAS`. Nulo conta como "sem regras", na mesma linha de "nulo conta como inativo" da C4.

### D4. Regra por papel

`regra_do_papel(papel, regras_do_tipo)`:
- `COORDENADOR` e `ADMIN`: `{pode_reservar: true, exige_aprovacao: false}`, sem consultar a tabela (regra fixa do §7.2);
- `ALUNO` e `PROFESSOR`: a linha correspondente de `regras_do_tipo`; sem linha, `{pode_reservar: false, exige_aprovacao: false}`.

*Alternativa descartada:* linhas de `regra_papel` também para coordenador e admin. Elas abririam a possibilidade de exigir aprovação de quem aprova, o que não tem sentido no domínio, e o §7.2 diz que esses papéis nunca precisam de aprovação.

### D4b. Validação de horário

`validar_horario_reserva(tipo, regras_completas, configuracao, inicio, fim, agora)` recebe instantes (timestamps em ms) e devolve `{dentro_das_regras, motivos}`. Ela não consulta o banco.

1. Converte início e fim para o fuso America/Sao_Paulo com os filtros de data do Xano: dia, dia da semana ISO e minutos desde a meia-noite.
2. Acumula os motivos, sem parar no primeiro:
   - `TIPO_SEM_REGRAS`;
   - `FIM_NAO_DEPOIS_DO_INICIO` (fim igual ou anterior ao início; a busca já barra isso com 400, mas a reserva da C6 chama a função direto);
   - `DIAS_DIFERENTES` (início e fim em dias diferentes; como o fechamento é sempre antes de 24h00, um fim à meia-noite nunca é válido);
   - `DIA_SEM_FUNCIONAMENTO`;
   - `FORA_DA_GRANULARIDADE` (minutos não múltiplos da granularidade, ou segundos e milissegundos diferentes de zero, porque a C6 passará instantes);
   - `ANTES_DA_ABERTURA`;
   - `DEPOIS_DO_FECHAMENTO`;
   - `DURACAO_ABAIXO_DA_MINIMA`;
   - `DURACAO_ACIMA_DA_MAXIMA`;
   - `ANTECEDENCIA_MINIMA` (início antes de `agora + antecedência mínima`; cobre também horário no passado);
   - `ANTECEDENCIA_MAXIMA` (início depois de `agora + antecedência máxima × 24 h`).
3. `agora` vem do `now` do backend, nunca do cliente. Como `now` só é avaliado em campo `timestamp` (memória do projeto), quem chama faz `var $agora { value = now }` e passa a variável. Por receber `agora` como entrada, a função pode ser testada com um instante fixo (tarefa 6.2), sem depender do relógio real.
4. Os filtros de data devolvem texto: dia da semana, hora e minuto passam por `|to_int` antes de qualquer comparação com a lista de dias e com os minutos.

A C6 chama a mesma função antes de checar conflito. A busca recusa antes (400) início depois do fim e data ou hora em formato inválido; a função continua cobrindo `DIAS_DIFERENTES` para a reserva.

### D5. Rotas

| Rota | Quem | Regras principais | Auditoria |
|---|---|---|---|
| `POST definir_regras_tipo` | admin | D6 | `ALTERAR_REGRAS_TIPO_ESPACO` |
| `GET filtros_busca` | qualquer conta ativa | tipos ativos com regras completas que o papel pode reservar (id, nome, `exige_aprovacao`, horário e duração), catálogo de recursos (id, nome) | — |
| `POST buscar_espacos` | qualquer conta ativa | D7 | — |
| `GET tipos` (alterada) | gestor | + `com_regras` para todos; + `regras` (os oito campos e `aluno` e `professor`) só para o admin | — |
| `GET geridos` (alterada) | gestor | passa `tipo_com_regras` a `disponibilidade_espaco` | — |
| `GET/POST parametros` (alteradas, grupo `contas`) | principal | + `granularidade_minutos` e `dias_funcionamento`; validação de D8 | `ALTERAR_PARAMETROS` (já existe) |

`buscar_espacos` é **POST**, apesar de só ler: a lista de recursos e o horário vão no corpo JSON, sem codificar listas na URL. *Alternativa descartada:* GET com `recursos_ids` como texto separado por vírgulas, que exigiria parsing manual e validação a mais.

### D6. `definir_regras_tipo`

- **Antes da trava:** os oito campos são obrigatórios e inteiros; `aluno` e `professor` têm `pode_reservar` e `exige_aprovacao` booleanos; "exige aprovação" só com "pode reservar"; abertura < fechamento; 0 ≤ abertura; fechamento < 1440; mínimos e máximos coerentes (spec `regras-tipo`).
- **Granularidade:** lida por `obter_configuracao_horario` (D8).
- **Auditoria:** os dados antes e depois, com `aluno` e `professor`, são montados com vírgulas entre as chaves (lição da C4).
- **Dentro da trava:**
  1. `travar_governanca`, `exigir_admin`;
  2. `db.get tipo_espaco` → 404;
  3. `obter_configuracao_horario` → granularidade G; duração e horários múltiplos de G; duração máxima ≤ fechamento − abertura;
  4. lê as linhas atuais de `regra_papel` do tipo;
  5. compara campo a campo: sem nenhuma diferença → 400 "Nenhuma regra foi alterada.";
  6. `db.edit tipo_espaco` com os oito campos; para cada papel, `db.edit` da linha existente ou `db.add` da nova;
  7. audita só o que mudou, com as regras por papel em chaves planas (`aluno_pode_reservar`, `aluno_exige_aprovacao`, `professor_pode_reservar`, `professor_exige_aprovacao`).

A conferência de G roda dentro da trava, a mesma de `parametros`, para que uma mudança simultânea de granularidade não deixe regras incompatíveis.

### D7. `buscar_espacos`

1. `usuario_ativo`.
2. **Antes de consultar:** se algum de `data`, `hora_inicio` e `hora_fim` foi informado, os três são obrigatórios. `data` em `AAAA-MM-DD` e horas em `HH:MM`, convertidos para instantes no fuso America/Sao_Paulo; fim depois do início; senão 400.
3. Uma consulta por tabela: `espaco`, `unidade`, `tipo_espaco`, `regra_papel`, `espaco_recurso`, `recurso` e `configuracao_geral`.
4. Para cada espaço:
   - `disponibilidade_espaco`, com `tipo_com_regras`; só os reserváveis;
   - `regra_do_papel`; só se `pode_reservar`;
   - filtros de unidade, tipo, `capacidade >= capacidade_minima` e recursos (todos os ids pedidos presentes);
   - com horário, `validar_horario_reserva`.
5. Ordem: nome da unidade e código. Cada item traz os campos da spec `busca-espacos`, `exige_aprovacao` do papel e, com horário, `dentro_das_regras` e `motivos`.

Objetos montados dentro de `push:` ou `map:` levam vírgula entre as chaves (lição da C4). O mesmo vale para `filtros_busca`, para o objeto `regras` de `GET tipos` e para os dados de auditoria de `definir_regras_tipo`.

**Validação de data e hora:** `data` precisa casar com `AAAA-MM-DD` e as horas com `HH:MM` (00–23 e 00–59) **antes** da conversão, porque `to_timestamp` aceita texto livre ("next friday"). Depois de converter, a data convertida de volta para texto no fuso de São Paulo precisa ser igual à informada; isso recusa datas inexistentes como `2026-02-30`.

### D8. Parâmetros

- **`obter_configuracao` não muda.** Ela é chamada por 11 rotas e funções da C1 à C3 (criar unidade, acrescentar coordenador, alterar papel, reativar, rebaixar admin, situação e reenvio de pedido, entre outras), e exigir nela os parâmetros novos faria todas falharem entre o push e o bootstrap.
- **Função nova `obter_configuracao_horario`:** devolve a configuração e exige `granularidade_minutos` e `dias_funcionamento` preenchidos ("Configuração de horário incompleta: execute o bootstrap."). Ela é usada só por `definir_regras_tipo` e `buscar_espacos`. O `POST parametros` lê o estado anterior com `obter_configuracao`, para o principal poder gravar os valores mesmo antes do bootstrap.
- `POST parametros`:
  - granularidade em {1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60};
  - dias entre 1 e 7, sem repetição, ao menos um;
  - **dentro da trava**, se a granularidade mudou, confere todos os tipos com regras: duração mínima, duração máxima, abertura e fechamento múltiplos da nova granularidade. Os incompatíveis vão na mensagem 400.
- `GET parametros` devolve os dois campos novos.

### D9. Carga inicial (bootstrap)

1. Preenche `granularidade_minutos = 10` e `dias_funcionamento = [1, 2, 3, 4, 5]` onde estiverem vazios, **nos dois ramos**: hoje o bootstrap só completa parâmetros quando a configuração já existe (`else`). Por isso, o `db.add` da configuração nova também passa a incluir os dois campos. O laço dos parâmetros padrão já trata inteiros; a lista de dias é preenchida à parte.
2. Se `regra_papel` estiver **vazia**, aplica a tabela da spec `regras-tipo` aos tipos encontrados pelo **nome exato** dos quatro tipos iniciais. Para cada um, grava os oito campos e as linhas de `ALUNO` e `PROFESSOR`.
   - Não há auditoria, como na carga dos tipos da C4.
   - A resposta lista `regras_carregadas`.

A tabela das regras iniciais é uma lista de objetos longos: vírgulas entre as chaves e entre os itens desde o primeiro arquivo, porque o Xano converte esses objetos para o modo expressão.

A busca pelo nome acontece só nessa carga única, e nada em execução depende do nome do tipo, como pedia a pendência da C4. Tipo renomeado antes da carga fica sem regras (falha segura). A trava "regra_papel vazia" impede que a carga sobrescreva regras depois que algum admin as definiu.

### D10. Reflex

- **Cliente:**
  - `definir_regras_tipo(token, tipo_id, regras)`, `filtros_busca(token)` e `buscar_espacos(token, filtros)`;
  - `salvar_parametros` passa a enviar os dois campos novos.
- **Conversão de horário:** a tela usa "HH:MM" (de 00:00 a 23:59; o fechamento é sempre antes da meia-noite), e duas funções do State convertem de e para minutos. O backend valida de novo.
- **`/buscar`** (guarda `verificar_sessao`, todos os papéis), com `BuscaState`:
  - os filtros vêm de `filtros_busca` e as unidades de `listar_unidades_ativas`;
  - a busca só sai no clique (plano Free: 10 requisições a cada 20 s);
  - cada resultado mostra código, unidade, tipo, capacidade, recursos, o selo "exige aprovação" e, com horário, "dentro das regras do tipo" ou os motivos em texto;
  - um aviso fixo diz que a ocupação é verificada na reserva.
- **`/tipos-espaco`:**
  - selo "sem regras";
  - botão "Regras", com um diálogo para os oito campos e para aluno e professor ("pode reservar" e "exige aprovação");
  - erro dentro do diálogo, com `limpar_ao_enviar=False` (lição da C4).
- **`/parametros`:** campo de granularidade e caixas de seleção dos sete dias.
- **Menu:** "Buscar espaços" para todos, logo depois de "Início".

### D11. Documentos e configuração

Esta change atualiza, como tarefa:
- **`domain-model.md`:**
  - §2.4: horário em minutos; regras completas; tipo novo sem regras;
  - §2.5: regra fixa de coordenador e admin; `regra_papel` só para aluno e professor;
  - §2.18: granularidade e dias como parâmetros editáveis; o horário 08h00–22h40 deixa de ser parâmetro global;
  - DER: `TIPO_ESPACO` (horários em minutos), `CONFIGURACAO_GERAL` (dias como lista de inteiros) e `REGRA_PAPEL` (papéis);
  - A.1: `regra_papel` e as validações dos campos de regra.
- **`project-overview.md`:**
  - §7.1: 08h00–22h40 como padrão de cada tipo; granularidade e dias como parâmetros;
  - §7.2: tabela com as regras iniciais completas;
  - §11: item 5 identificado como C5; pendências passadas à C6.
- **`openspec/config.yaml`:** a invariante "início a partir de 08h00, término até 22h40, múltiplos de 10 min" passa a "dentro do horário do tipo (padrão 08h00–22h40), nos dias de funcionamento e em múltiplos da granularidade". Mudar o `config.yaml` é configuração do workflow; aqui ele só acompanha a regra que a change altera.

### D12. Pendências para a C6

| Pendência |
|---|
| Chamar `validar_horario_reserva` na criação da reserva, relendo tipo, regras e configuração dentro da trava antes de checar conflito. |
| Aplicar `max_reservas_ativas_usuario` contando as reservas ativas do usuário naquele tipo. |
| Usar `regra_do_papel` no momento da criação: sem permissão, recusa; com aprovação, a reserva nasce `PENDENTE`. |
| A busca passa a poder indicar ocupação ("livre ou ocupado"), sem mudar a regra de horário. |
| Reserva recorrente (C11): ocorrências isentas da antecedência máxima (§7.5), e só tipos com `permite_recorrencia`. |

## Risks / Trade-offs

- **[Conversão de fuso]** → A tarefa 1.2 confirma no MCP os filtros de data com fuso (`to_timestamp` e `format_timestamp`) e o formato do dia da semana. Os testes cobrem a virada do dia em São Paulo, perto da meia-noite.
- **[`int[]` em `configuracao_geral`]** → Confirmado na 1.2, inclusive se os elementos voltam como inteiros e não como texto. Se não existir, `json` com uma lista, validado na rota.
- **[Busca carrega todas as tabelas]** → Uma requisição só, com junção em memória (C4 D8). Sem paginação (Non-Goal).
- **[Feriado aparece como "dentro das regras"]** → A spec e a tela dizem que a busca não verifica ocupação nem bloqueio (C10).
- **[Mudança de granularidade]** → Recusada se deixar tipos incompatíveis (D8), sob a trava.
- **[Carga por nome]** → Uma única vez, com tabela vazia; tipo renomeado fica sem regras (falha segura).
- **[Regra definida antes da carga]** → Se algum admin definir regras de qualquer tipo antes da primeira execução do bootstrap, `regra_papel` deixa de estar vazia e os quatro tipos iniciais nunca recebem a carga. Eles ficam "sem regras" (falha segura) e o admin os configura pela tela. Na prática, o bootstrap roda logo depois do push (5.1), antes de qualquer uso.
- **[Regressão nas rotas da C1 à C3]** → Evitada por não alterar `obter_configuracao` (D8).
- **[Relógio real nos testes]** → `validar_horario_reserva` recebe `agora`, então os cenários de dia da semana, antecedência e fuso são testados com instante fixo por uma função temporária executada só pelo CLI (6.2).

## Migration Plan

1. Pull de comparação.
2. Confirmações no MCP (1.2).
3. Tabelas, funções e rotas validadas no MCP.
4. Dry-run (nenhuma rota de outro grupo como "updated"), aprovação e push com `--force`.
5. `bootstrap` duas vezes: na primeira, os parâmetros novos e as regras dos quatro tipos iniciais; na segunda, nada.
6. Pull de comparação para alinhar a formatação.
7. Testes de API, Reflex e verificação manual.

## Confirmações do apply

| Ponto | Resultado |
|---|---|
| **Pull de comparação (1.1)** | `./xano` igual ao workspace (diff zero). |
| **`int[]` (1.2)** | O validador aceita `int[] dias_funcionamento` em tabela. Se os elementos voltam como inteiros só se confirma em execução (5.1 e 6.0). |
| **Datas com fuso (1.2)** | `to_timestamp:"America/Sao_Paulo"` converte texto de data e hora local em instante (ms), mas aceita texto livre ("next friday"), então a regex vem antes. `format_timestamp:"<formato>":"America/Sao_Paulo"` devolve **texto** em formato PHP: `Y-m-d`, `N` (dia ISO, 1 = segunda), `H`, `i`, `s`, e por isso passa por `\|to_int` antes de comparar. O valor de `N` é conferido na 6.2. |
| **Formato de data e hora (1.2)** | `"/^\d{4}-\d{2}-\d{2}$/"\|regex_matches:$texto` devolve verdadeiro ou falso. Datas inexistentes (`2026-02-30`) são recusadas comparando `format_timestamp:"Y-m-d"` do instante convertido com o texto informado (D7). |

| **Push e bootstrap (5.1)** | Push aprovado (96 documentos, 8 `guid`). Bootstrap: 1ª execução preencheu `granularidade_minutos` e `dias_funcionamento` e carregou as regras dos 4 tipos; 2ª não alterou nada. Valores conferidos em `GET tipos`: antecedência mínima `0` e recorrência `false` gravadas (não `null`). |
| **Comparação frouxa (5.1)** | Em execução, `com_regras` veio falso para a "Biblioteca" com todas as regras gravadas: no Xano, `0 != null` e `false != null` dão falso. Corrigido com `is_null` e `json_encode` (decisions-log 22). |
| **Vírgulas depois do pull (5.1)** | O Xano mantém as vírgulas dentro dos blocos que converte para o modo expressão e as remove dos literais comuns. O `$resultado` do bootstrap, literal sem vírgulas vindo da C4, virou bloco de expressão ao ganhar `regras_carregadas` e perdeu `principal_marcado`; recebeu vírgulas. |

**Rollback:** campos novos opcionais e tabela nova. As rotas alteradas voltam ao arquivo anterior com novo push. Sem regras gravadas, os tipos ficam "sem regras" e nenhum espaço é reservável, o que é seguro porque a reserva só existe a partir da C6.
