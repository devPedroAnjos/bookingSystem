## 1. Preparação

- [x] 1.1 Confirmar a branch `change/regras-tipo-busca` (criada da `main` com a C4) e rodar `xano workspace pull` para um diretório temporário, comparando com `./xano/`. Verificação: nenhuma diferença; se houver, apresentar ao usuário.
- [x] 1.2 Confirmar no Xano Developer MCP, antes de escrever código:
  - o tipo `int[]` em tabela, e se os elementos voltam como inteiros (não texto);
  - os filtros de data com fuso (`to_timestamp` a partir de data e hora locais e `format_timestamp` para dia, dia da semana ISO e hora em America/Sao_Paulo), lembrando que `format_timestamp` devolve texto e exige `|to_int` antes de comparar;
  - como validar os formatos `AAAA-MM-DD` e `HH:MM` (regex) antes de `to_timestamp`, que aceita texto livre ("next friday"), e como recusar datas inexistentes (`2026-02-30`) comparando a data convertida de volta com o texto informado.

  Verificação: resultado em "Confirmações do apply" no `design.md`. Se `int[]` não existir, usar `json` com lista (Risks).
- [x] 1.3 Revisão do guardian do grupo 1, feita junto com a dos grupos 2 a 4 (4.5), antes de marcar 1.1 e 1.2 (preferência do usuário: revisões por grupo, com menos chamadas).

## 2. Xano: dados e parâmetros

- [x] 2.1 Acrescentar a `tipo_espaco` os oito campos de regra (`int?` e `bool?`) e criar a tabela `regra_papel` com o índice único (`tipo_espaco_id`, `papel`) (D2). Verificação: `.xs` validados no MCP.
- [x] 2.2 Acrescentar `granularidade_minutos` e `dias_funcionamento` a `configuracao_geral` e criar `obter_configuracao_horario` (D8). **Não alterar `obter_configuracao`**, usada pelas rotas da C1 à C3. Verificação: `.xs` validados no MCP e `obter_configuracao` sem diff.
- [x] 2.3 Alterar o `bootstrap` (D9): parâmetros novos onde estiverem vazios, **nos dois ramos** (configuração nova e existente), e carga das regras dos quatro tipos iniciais só com `regra_papel` vazia, sem auditoria, com `regras_carregadas` na resposta. Vírgulas entre as chaves e entre os itens das listas de objetos. Verificação: `.xs` validado no MCP.

## 3. Xano: funções

- [x] 3.1 Criar `regra_do_papel` (D4) e `tipo_com_regras` (D3), sem acesso ao banco. Verificação: `.xs` validados no MCP.
- [x] 3.2 Alterar `disponibilidade_espaco`: entrada `bool? tipo_com_regras` e motivo `TIPO_SEM_REGRAS` (D3). Verificação: `.xs` validado no MCP.
- [x] 3.3 Criar `validar_horario_reserva` (D4b), com fuso America/Sao_Paulo e todos os motivos acumulados. Verificação: `.xs` validado no MCP.

## 4. Xano: rotas

- [x] 4.1 Criar `POST definir_regras_tipo` (D6): validação antes da trava, granularidade dentro dela, recusa sem alteração, `db.edit`/`db.add` de `regra_papel` e auditoria `ALTERAR_REGRAS_TIPO_ESPACO`. Verificação: `.xs` validado no MCP.
- [x] 4.2 Alterar `GET tipos` (`com_regras` para gestores; `regras` para admin) e `GET geridos` (passa `tipo_com_regras`). Verificação: `.xs` validados no MCP.
- [x] 4.3 Criar `GET filtros_busca` e `POST buscar_espacos` (D5, D7). Verificação: `.xs` validados no MCP.
- [x] 4.4 Alterar `GET` e `POST parametros` (D8): campos novos, validação e conferência da granularidade contra os tipos com regras, dentro da trava. Verificação: `.xs` validados no MCP.
- [x] 4.5 Revisão do guardian dos grupos 2 a 4 antes de marcar as tarefas e antes da 5.1.

## 5. Xano: publicação

- [x] 5.1 Rodar `xano workspace push -d ./xano --dry-run` e mostrar ao usuário. Critério: só as tabelas, funções e rotas desta change; nenhuma rota de outro grupo como "updated". Push com `--force` **só com aprovação explícita**, sem `--sync`, `--delete`, `--env` nem `--records`. Executar o `bootstrap` duas vezes e fazer pull para alinhar a formatação. Verificação: os quatro tipos iniciais com as regras da tabela, granularidade 10 e dias 1 a 5; a "Biblioteca" com `antecedencia_min_minutos = 0` e `permite_recorrencia = false` (não `null`); os quatro com `com_regras = true`; a segunda execução não altera nada; o pull bate com `./xano/` depois do alinhamento, com as vírgulas preservadas nas rotas.

## 6. Xano: verificação das specs por chamadas à API

Script descartável fora do repositório, com controle de ritmo (10 requisições a cada 20 s) e credenciais do `.env` sem impressão. Os testes rodam no workspace (branch `live`). As regras alteradas nos testes são restauradas ao fim, e os dados de teste que não podem ser apagados são listados no relatório. Senhas de contas de teste ficam só no scratchpad e são apagadas no fim.

- [x] 6.0 Checar em execução que nenhum objeto em expressão perdeu chave e que `0` e `false` foram gravados como valores:
  - `filtros_busca` traz `exige_aprovacao` e as regras de cada tipo;
  - `buscar_espacos` traz `motivos` e a `quantidade` dos recursos;
  - `tipos` traz `regras.aluno` e `regras.professor`;
  - a "Biblioteca" volta com `antecedencia_min_minutos = 0` e `permite_recorrencia = false`, e com `com_regras = true`.
- [x] 6.1 Regras do tipo:
  - definir regras válidas → aceito e refletido em `tipos`;
  - duração mínima > máxima, fora da granularidade, abertura ≥ fechamento, duração máxima maior que o horário, antecedência máxima ≤ mínima, máximo de reservas 0, aprovação sem permissão → 400 e nada muda;
  - salvar sem alteração → 400 sem auditoria;
  - regras de tipo desativado → aceito;
  - campo ausente, fechamento às 24h00 e tipo inexistente (404);
  - coordenador, professor e aluno → 403;
  - coordenador em `GET tipos` recebe `com_regras`, mas não `regras`;
  - tipo sem regras ("Refeitório") → `com_regras` falso e os espaços dele com motivo `TIPO_SEM_REGRAS` em `geridos`.
- [x] 6.2 Validação de horário com **instante fixo**: uma função temporária `tst_*`, executada só pelo CLI (push aprovado, exclusão pelo painel depois), chama `validar_horario_reserva` com `agora` injetado e datas fixas, sem depender do relógio real:
  - dentro das regras;
  - início exatamente às 08h00 e término exatamente às 22h40 → dentro;
  - término às 22h50 → fora (fechamento); início às 07h50 → fora (abertura);
  - 22h40 às 23h10 → fora (fechamento);
  - sábado → fora (dia);
  - 10h05 e instante com segundos → fora (granularidade);
  - duração exatamente na mínima e na máxima → dentro; abaixo e acima → fora;
  - antecedência exatamente no limite → dentro; antecedência mínima do "Auditório" e horário no passado → fora;
  - antecedência máxima → fora;
  - fim igual ou antes do início → fora (`FIM_NAO_DEPOIS_DO_INICIO`); fim no dia seguinte → fora (`DIAS_DIFERENTES`);
  - vários motivos de uma vez;
  - sexta 22h00–22h40 em São Paulo (sábado em UTC) → dentro, com dia e horário no fuso local.

  Pela API (busca), só o que depende do relógio atual, com datas montadas a partir do dia da execução (o próximo dia útil e o próximo sábado): um pedido dentro das regras, um sábado fora, data e hora inválidas (`2026-02-30`, "próxima sexta", "25:00") → 400, horário incompleto ou fim antes do início → 400.
- [x] 6.3 Busca:
  - aluno só vê "Biblioteca" e "Laboratório"; professor vê os quatro; coordenador vê outras unidades; admin vê todos os tipos com regras;
  - espaço de tipo sem regras, desativado, de unidade ou tipo desativados → não aparece;
  - filtros de unidade, tipo, capacidade mínima e recursos (todos), combinados;
  - aluno filtrando "Auditório" → lista vazia;
  - `exige_aprovacao` conforme o papel;
  - códigos iguais em unidades diferentes;
  - sem token → 401; conta inativa → 401; senha provisória → 403 "Troque sua senha para continuar.";
  - `filtros_busca` do aluno só com os tipos dele; aluno em `GET tipos` e `GET recursos` → 403.
- [x] 6.4 Parâmetros:
  - principal grava granularidade e dias válidos → aceito;
  - granularidade 7 → 400; granularidade incompatível com os tipos (30, com "Sala de aula" em 50) → 400 com os tipos;
  - dias vazios ou repetidos → 400;
  - secundário → 403;
  - incluir sábado → sábado passa a estar dentro das regras na busca;
  - restaurar os valores ao fim.
- [x] 6.5 Concorrência: `definir_regras_tipo` com duração de 50 minutos ao mesmo tempo que a mudança da granularidade para 30 → só uma das duas é gravada e nenhum tipo fica incompatível.
- [x] 6.6 Auditoria: `ALTERAR_REGRAS_TIPO_ESPACO` com só os campos alterados e as regras por papel; `ALTERAR_PARAMETROS` com granularidade e dias; nenhum registro para tentativas recusadas, salvar sem alteração, busca e carga inicial. Usar uma função temporária de leitura do log executada só pelo CLI, com push aprovado e exclusão pelo painel depois.
- [x] 6.7 Revisão do guardian do grupo 6 antes de marcar as tarefas.

## 7. Reflex

- [x] 7.1 Acrescentar ao `xano_cliente.py` `definir_regras_tipo`, `filtros_busca` e `buscar_espacos`, e os campos novos em `salvar_parametros`. Verificação: script descartável chama as leituras contra o workspace.
- [x] 7.2 Criar `BuscaState` e a página `/buscar` (D10), com guarda de sessão para todos os papéis e o aviso de que a ocupação é verificada na reserva. Verificação: `reflex compile --dry`.
- [x] 7.3 Alterar `TiposEspacoState` e `/tipos-espaco`: selo "sem regras" e diálogo "Regras" (HH:MM, aluno e professor, erro dentro do diálogo, sem limpar o formulário). Verificação: `reflex compile --dry`.
- [x] 7.4 Alterar `ParametrosState` e `/parametros`: granularidade e dias. Atualizar o menu (spec `autorizacao`). Verificação: `reflex compile --dry` e checagem de nomes sem uso.
- [x] 7.5 Revisão do guardian do grupo 7 antes de marcar as tarefas.

## 8. Documentação, verificação no navegador e entrega

- [x] 8.1 Atualizar `docs/domain-model.md`, `docs/project-overview.md` e a invariante de horário do `openspec/config.yaml` (D11) e mostrar o diff ao usuário. Conferir que o "limite das 22h40" do AGENTS.md §9 continua válido como padrão dos tipos, sem precisar mudar.
- [x] 8.2 Verificação manual (usuário):
  - menu de aluno, professor, coordenador e admin com "Buscar espaços";
  - buscar como aluno e como professor, com e sem data e horário;
  - resultado fora das regras mostra os motivos; o aviso de ocupação aparece;
  - definir as regras do "Refeitório" pela tela e ver o "Refeitório 1" aparecer na busca;
  - erro de regra inválida dentro do diálogo, sem apagar os valores;
  - alterar granularidade e dias na página de parâmetros.
- [x] 8.3 Verificar no DevTools que o token do Xano não chega ao navegador. Verificação: confirmação do usuário.
- [x] 8.4 Revisar o código: PEP 8, sem `print`, sem código morto, sem segredo e sem a função temporária. Mostrar o `git diff` antes de commitar.
- [x] 8.5 Pedir ao `change-guardian` o relatório em MODO REVISÃO FINAL e mostrá-lo ao usuário antes de qualquer commit ou push.
- [x] 8.6 Relatório final:
  - o que foi testado e o que não foi;
  - as divergências do DER;
  - os dados de teste que ficaram no workspace;
  - os casos de borda do AGENTS.md §9 cobertos (08h00, 22h40, granularidade, fuso) e os que não se aplicam (conflito, fila, check-in, prioridade).
