## 1. Preparação e confirmações no Xano Developer MCP

- [x] 1.1 O usuário confirma que está na branch `change/deslocamento-prioridade`. Rodar `xano workspace pull` numa pasta temporária e confirmar que o workspace está igual a `./xano`, ignorando espaços. Verificação: resposta do usuário e comparação sem diferenças.
- [x] 1.2 Confirmar no MCP, com arquivos de sonda validados e sem push:
  - campo autorreferente `int? deslocada_por_reserva_id? {table = "reserva"}`;
  - `conditional` com `db.add` e chamada de função dentro de `db.transaction`, com variáveis declaradas fora dela;
  - `|every` e `|filter` com expressão sobre uma lista de reservas e comparação de instantes em ms;
  - por leitura do código, que `reservas_unidade` devolve `cancelado_por` para o motivo `PRIORIDADE` e que `minhas_reservas` não devolve quem cancelou.

  Registrar o que for confirmado na seção "Confirmações do apply" do `design.md`. Verificação: sondas válidas no MCP.
- [x] 1.3 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Documentação do domínio e do roadmap

- [x] 2.1 `docs/project-overview.md`:
  - §7.3: condição 2 conforme o D10, com o prazo valendo para a nova reserva e para cada deslocada, e a reserva em andamento nunca deslocada;
  - §10: nota de que o deslocamento é auditado como `CANCELAR_RESERVA` com motivo `PRIORIDADE`;
  - §11: itens 8 a 15 conforme o D10, com a fila de espera como item 9 (C9) e a questão em aberto da confirmação com aprovação.

  Verificação: `git diff docs/project-overview.md` mostrado ao usuário.
- [x] 2.2 `docs/domain-model.md`:
  - §2.9: regra do deslocamento, com as três condições, o prazo para a nova reserva e para cada deslocada, o cancelamento inteiro e a confirmação;
  - §2.18 e DER: conferir que o parâmetro e `deslocada_por_reserva_id` já constam, sem duplicar.

  Verificação: `git diff docs/domain-model.md`.
- [x] 2.3 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Xano: dados e funções

- [x] 3.1 `xano/table/reserva.xs`: acrescentar `deslocada_por_reserva_id` (D1) e atualizar o comentário do topo. Verificação: validação do MCP.
- [x] 3.2 `xano/table/configuracao_geral.xs`: acrescentar `prazo_deslocamento_minutos` (D1). No `bootstrap`, gravar 120 quando vazio, em `$parametros_padrao`, no `db.add` e no laço de ajuste (D9). Verificação: validação do MCP; a chave nova em `parametros_ajustados`.
- [x] 3.3 Criar `nivel_do_papel(papel)`, com `ALUNO` 1, `PROFESSOR` 2 e os demais 3 (D2). Verificação: validação do MCP.
- [x] 3.4 Criar `avaliar_deslocamento` conforme o D2: função pura, `>` estrito nos dois prazos, `deslocavel` falso sem conflitantes, e saída montada com `|set`. Verificação: validação do MCP.
- [x] 3.5 `cancelar_reservas`: modo `prioridade` conforme o D5 (lista recebida, sem seleção, `deslocada_por_reserva_id` gravado e nos dados depois da auditoria, sem `motivo_detalhe`), sem mudar os modos `conta` e `espaco`. Verificação: validação do MCP.
- [x] 3.6 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Xano: rotas

- [x] 4.1 `criar_reserva`, conforme o D3, o D4 e o D6:
  - entrada `deslocar`;
  - nível por `nivel_do_papel`;
  - conflito como lista;
  - `avaliar_deslocamento`;
  - recusa com a mesma mensagem de hoje;
  - resposta 200 sem gravação quando falta confirmar;
  - gravação da nova e cancelamento pelo modo `prioridade`;
  - `CRIAR_RESERVA` com `deslocadas`;
  - resposta com `requer_confirmacao`, `deslocadas` e a mensagem com o complemento.

  Atualizar os comentários. Verificação: validação do MCP.
- [x] 4.2 `buscar_espacos`, conforme o D7: prazo e nível lidos uma vez, `deslocavel` e `deslocaria` por espaço com horário (livre: falso e 0), sem trava e sem gravação. Verificação: validação do MCP.
- [x] 4.3 `parametros_GET` e `parametros_POST`: devolver, validar (no `$limites`), gravar e auditar `prazo_deslocamento_minutos` (D9). Verificação: validação do MCP.
- [x] 4.4 Revisão do guardian do grupo 4 antes de marcar as tarefas.

## 5. Publicação

- [x] 5.1 `xano workspace push --dry-run`, mostrar o resultado ao usuário e só publicar com aprovação explícita. O push usa `--force`, por ser terminal não interativo, e nunca `--sync`, `--delete`, `--env` ou `--records`. Verificação: saída do push.
- [x] 5.2 Pull de comparação: `./xano` igual ao workspace, ignorando espaços. Alinhar os arquivos reformatados pelo Xano e conferir vírgulas e blocos entre crases. Verificação: comparação sem diferenças.
- [x] 5.3 Executar o `bootstrap` duas vezes pelo CLI: a primeira grava o prazo e a segunda não altera nada. Verificação: saídas do CLI e `GET parametros` com `prazo_deslocamento_minutos` igual a 120.
- [x] 5.4 Revisão do guardian do grupo 5 antes de marcar as tarefas.

## 6. Verificação do backend contra o workspace

Scripts descartáveis no scratchpad. As contas (aluno, dois professores, coordenador), a unidade e os espaços de teste são criados para o teste e, ao fim, desativados ou inativados, sem exclusão física. Os instantes são relativos ao relógio real.

Para testar o limite do prazo sem esperar, o teste usa um tipo "TST Deslocamento C8":
- horário amplo (00h00 às 23h50) e granularidade atual;
- antecedência mínima 0 e limite de ativas alto;
- sem aprovação para aluno e professor.

O prazo é alterado temporariamente pela API de parâmetros quando o teste precisar de um valor pequeno e restaurado para 120 no fim. Se o teste rodar num dia sem funcionamento, o dia entra nos parâmetros durante o teste e é removido no fim.

- [x] 6.1 Condições do deslocamento:
  - professor desloca aluno;
  - coordenador de outra unidade desloca professor;
  - pendente de aluno é deslocada;
  - reserva criada como aluno e dono promovido depois continua deslocável;
  - mesmo nível recusado;
  - níveis mistos recusados, sem nada cancelado;
  - aluno nunca desloca;
  - nova reserva que exigiria aprovação é recusada (tipo de teste configurado para exigir aprovação do professor);
  - solicitante no limite de ativas é recusado pelo limite;
  - pendente vencida sobreposta é ignorada e expira.

  Verificação: script com o resultado de cada caso.
- [x] 6.2 Prazo:
  - conflitante que começa a exatamente o prazo (minuto inteiro) é recusada, e a que começa a 1 minuto além é deslocada;
  - o mesmo limite para o início da nova reserva, com a conflitante distante;
  - empate no nível 3 (coordenador contra admin e contra outro coordenador) é recusado;
  - pedido fora das regras do tipo é recusado pelas regras, com `deslocar`, sem cancelar nada;
  - reserva em andamento nunca é deslocada;
  - nova reserva que começa a menos do prazo é recusada mesmo com a conflitante distante;
  - mudar o prazo pela API muda o resultado.

  O milissegundo exato fica para revisão de código (`>` estrito). Verificação: script.
- [x] 6.3 Confirmação:
  - sem `deslocar`, a resposta é 200 com `requer_confirmacao` e `deslocaria`, nada gravado e nenhuma auditoria;
  - com `deslocar`, duas deslocadas, com motivo, autor, instante e `deslocada_por_reserva_id` gravados;
  - sobreposição parcial cancela a reserva inteira e libera as sobras;
  - `deslocar` sem conflito cria normalmente;
  - conflito que muda para não deslocável entre os dois pedidos é recusado sem cancelar nada;
  - auditoria: `CRIAR_RESERVA` com `deslocadas` e um `CANCELAR_RESERVA` por deslocada, com motivo `PRIORIDADE` e o solicitante como ator.

  Verificação: script e consulta da auditoria.
- [x] 6.4 Concorrência:
  - dois professores confirmam ao mesmo tempo o deslocamento do mesmo intervalo;
  - deslocamento e cancelamento pelo dono ao mesmo tempo;
  - deslocamento e desativação do espaço ao mesmo tempo.

  Em todos, uma única transição por reserva, nenhuma sobreposição ativa e nenhum cancelamento sem confirmação. Verificação: script com chamadas em paralelo e consulta final.
- [x] 6.5 Busca:
  - ocupado e deslocável com a quantidade;
  - ocupado e não deslocável por nível, por prazo e por aprovação;
  - ocupado e fora das regras, não deslocável e com 0;
  - livre com `deslocavel` falso e 0, e sem horário sem as duas chaves;
  - nenhum dado de quem ocupa;
  - nenhuma auditoria.

  Verificação: script.
- [x] 6.6 Parâmetros: GET com o prazo; POST com 0 recusado e nada gravado; POST válido auditado com o valor antigo e o novo; admin secundário recebe acesso negado. Verificação: script.
- [x] 6.7 "Minhas reservas" do deslocado mostra `CANCELADA` com o motivo `PRIORIDADE` e sem quem cancelou. "Reservas da unidade" do coordenador mostra quem cancelou. Verificação: script.
- [x] 6.8 Regressão da C6 e da C7: conflito simples, encostadas, limite, cancelamento no prazo, ações de gestão com reserva em andamento (modos `conta` e `espaco` de `cancelar_reservas`), aprovação, recusa e expiração. Verificação: script com os casos principais.
- [x] 6.9 Revisão do guardian do grupo 6 antes de marcar as tarefas.

## 7. Reflex

- [x] 7.1 Cliente: `criar_reserva` com `deslocar=False` (D8). Verificação: chamada real com e sem `deslocar` num script com conta de teste, sem imprimir token.
- [x] 7.2 Busca, conforme o D8:
  - `_espaco_para_tela` com `deslocaria` e `pode_deslocar`;
  - botão "Deslocar e reservar";
  - confirmação com o aviso de quantas reservas serão canceladas;
  - `requer_confirmacao` recebido ao reservar um espaço que parecia livre mantém a confirmação aberta e pede novo clique;
  - mensagem de sucesso com as deslocadas.

  Verificação: `reflex run` e teste no navegador (Playwright) com um professor deslocando um aluno, com o caso de um espaço que parecia livre e foi ocupado por aluno depois da busca, e com um aluno que não vê o botão.
- [x] 7.3 Parâmetros: o campo "Prazo para deslocar por prioridade" aparece com o valor atual e salva. Verificação: navegador com o admin principal, ou, para não digitar a senha real dele nas ferramentas, a chamada real da API com o conjunto completo de limites e a revisão do `LIMITES`. O que não for testado no navegador fica registrado.
- [x] 7.4 "Minhas reservas" do deslocado mostra a reserva no histórico, com o motivo de substituição por prioridade maior. Verificação: navegador com a conta de teste deslocada.
- [x] 7.5 Revisão do guardian do grupo 7 antes de marcar as tarefas.

## 8. Encerramento do apply

- [x] 8.1 Atualizar o `decisions-log.md` com as decisões do apply e registrar no `design.md` o que não foi possível testar. Verificação: arquivos atualizados.
- [x] 8.2 Pedir ao guardian o relatório de revisão final e mostrá-lo ao usuário antes de qualquer commit ou push da change. Verificação: relatório apresentado.
- [x] 8.3 Limpeza dos testes:
  - funções temporárias `tst_*` removidas pelo usuário no painel e apagadas localmente;
  - pull final sem diferenças;
  - unidade e tipo de teste desativados e contas de teste inativadas, sem exclusão física;
  - prazo e dias de funcionamento restaurados.

  Verificação: nenhum `tst_*` em `xano/`, comparação sem diferenças e `GET parametros` com os valores originais.

## Workflow follow-up

- O usuário mostra o `git diff` e faz os commits em português, no imperativo, depois da aprovação.
- Arquivar a change depois da revisão humana (`/opsx:archive`), conferindo as specs consolidadas de `reservas`, `busca-espacos`, `parametros` e `auditoria`.
