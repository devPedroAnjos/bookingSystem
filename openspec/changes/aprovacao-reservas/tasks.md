## 1. Preparação e confirmações no Xano Developer MCP

- [x] 1.1 Confirmar que a branch é `change/aprovacao-reservas` e rodar `xano workspace pull` numa pasta temporária para confirmar que o workspace está igual a `./xano` (ignorando espaços). Verificação: `git branch --show-current` e comparação sem diferenças.
- [x] 1.2 Confirmar no MCP, com arquivos de sonda validados e sem push:
  - `where` com `||` e parênteses (`status == "CONFIRMADA" || (status == "PENDENTE" && inicio > $agora)`);
  - função que abre `db.transaction` e é chamada fora de transação (`aplicar_vencimentos`);
  - `text?` com `filters=trim` e `int?` com referência a `usuario` na tabela;
  - índice composto `status` + `inicio`;
  - conversão de data AAAA-MM-DD para o início do dia em America/Sao_Paulo.

  Registrar o que for confirmado numa seção "Confirmações do apply" do `design.md`. Se o `||` não for aceito, aplicar a alternativa do risco correspondente do design. Verificação: sondas válidas no MCP.
- [x] 1.3 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Documentação da arquitetura e do domínio

- [x] 2.1 `docs/project-overview.md`:
  - §7.3: a pendente ocupa o horário só até o início;
  - §7.6: nota de expiração efetiva no início e gravada na próxima operação, e ninguém decide a própria reserva;
  - §8: diagrama e tabela sem "tarefas agendadas", conforme o D11;
  - §10: aprovar, recusar e expirar na lista de ações auditadas;
  - §11: item 7 como C7, sem a pendência da C4, e as pendências do D12 nos itens 8, 9, 10, 13 e 14.

  Verificação: `git diff docs/project-overview.md` mostrado ao usuário.
- [x] 2.2 `docs/domain-model.md`:
  - §2.9: quem decide, proibição de decidir a própria reserva, recusa com motivo e expiração efetiva; a linha "Ativas (ocupam o horário)" passa a dizer pendente que ainda não começou e confirmada;
  - §4, invariante 1: a mesma definição de ocupação;
  - nota de ator vazio sem "tarefa agendada".

  Verificação: `git diff docs/domain-model.md`.
- [x] 2.3 `AGENTS.md`:
  - tabela da §3: "tarefas agendadas" substituído conforme o D11;
  - §6: a ocupação ativa passa a dizer pendente que ainda não começou.

  Verificação: `git diff AGENTS.md` mostrado ao usuário, que aprova a mudança nas instruções do agente.
- [x] 2.4 `openspec/config.yaml`: trocar "tarefas agendadas" na stack do `context` e na regra do `design` pelo processamento de vencimentos nas operações (D11) e, por decisão do usuário no apply (decisions-log 27), ajustar a invariante de ocupação à pendente que ainda não começou, sem outras mudanças. Verificação: `git diff openspec/config.yaml` mostrado ao usuário e `openspec validate aprovacao-reservas --strict` ainda válido.
- [x] 2.5 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Xano: dados e funções

- [x] 3.1 `xano/table/reserva.xs`: acrescentar `decidido_por_id`, `decidido_em` e `motivo_recusa` (D1) e o índice `status` + `inicio`, atualizando o comentário do topo. Verificação: validação do MCP.
- [x] 3.2 Criar `situacao_efetiva(status, inicio, agora)` conforme a tabela do D2. Verificação: validação do MCP.
- [x] 3.3 Criar `processar_vencimentos(agora)` (D3):
  - pressupõe a trava de quem chama;
  - grava `EXPIRADA` nas `PENDENTE` com `inicio <= agora`, no máximo 50 por rodada, das mais antigas (era 200; reduzido depois da medição da 7.6, decisions-log 35);
  - gera um `EXPIRAR_RESERVA` por reserva, com ator vazio, a unidade atual do espaço e `expirou_em` (D8);
  - devolve a quantidade.

  Verificação: validação do MCP; objetos de auditoria montados com `|set`.
- [x] 3.4 Criar `aplicar_vencimentos()` (D3): `db.transaction` com `travar_governanca` como primeira instrução e a chamada da 3.3. Verificação: validação do MCP.
- [x] 3.5 Criar `carregar_reserva_gerida(ator_id, reserva_id, emitido_em)` (D5), com 403 para papel sem gestão, 404 para reserva inexistente pedida por admin e 403 igual para reserva inexistente ou fora do escopo pedida por coordenador. Verificação: validação do MCP.
- [x] 3.6 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Xano: rotas novas do grupo `reservas`

- [x] 4.1 Criar `aprovar_reserva` (POST) conforme o D6: `aplicar_vencimentos` antes, num `try_catch` que não bloqueia (D3); dentro da trava, `carregar_reserva_gerida`, as checagens do D5 na ordem (própria, prazo, situação), a gravação e `APROVAR_RESERVA`. Verificação: validação do MCP.
- [x] 4.2 Criar `recusar_reserva` (POST) conforme o D6, com a validação do motivo antes da faxina e fora da trava (mesmas mensagens da recusa de cadastro), a gravação de `motivo_recusa` e `RECUSAR_RESERVA`. Verificação: validação do MCP.
- [x] 4.3 Criar `reservas_unidade` (GET) conforme o D9:
  - escopo por papel e 403 igual para unidade ou espaço fora do escopo;
  - filtros de situação com a regra do D2, e 400 para situação inválida;
  - teto de 200 itens com `limitada`;
  - período em São Paulo, com as recusas de formato e de ordem;
  - ordem por situação;
  - uma consulta por tabela;
  - só nome e e-mail dos usuários.

  Verificação: validação do MCP.
- [x] 4.4 Revisão do guardian do grupo 4 antes de marcar as tarefas.

## 5. Xano: rotas alteradas

- [x] 5.1 `criar_reserva`: chamar `aplicar_vencimentos` depois da conversão do horário e antes da transação, num `try_catch` que não bloqueia, e trocar, no limite de ativas e no conflito, `status in ["PENDENTE", "CONFIRMADA"]` pelo predicado de ocupação do D2, atualizando os comentários. Verificação: validação do MCP.
- [x] 5.2 `cancelar_reserva`: chamar `aplicar_vencimentos` antes da transação, num `try_catch` que não bloqueia (D3 e D7). Verificação: validação do MCP.
- [x] 5.3 `minhas_reservas`: `status` igual à situação efetiva, `pode_cancelar` só para situação efetiva ativa e o campo `motivo_recusa` (D7). Verificação: validação do MCP.
- [x] 5.4 `buscar_espacos`: consulta de ocupação com o predicado do D2. Verificação: validação do MCP.
- [x] 5.5 Revisão do guardian do grupo 5 antes de marcar as tarefas.

## 6. Publicação

- [x] 6.1 `xano workspace push --dry-run`, mostrar o resultado ao usuário e só publicar com aprovação explícita. O push é feito com `--force`, por ser terminal não interativo, e nunca com `--sync`, `--delete`, `--env` ou `--records`. Verificação: saída do push.
- [x] 6.2 Pull de comparação: `./xano` igual ao workspace, ignorando espaços. Alinhar os arquivos reformatados pelo Xano e conferir vírgulas e blocos entre crases. Verificação: comparação sem diferenças.
- [x] 6.3 Revisão do guardian do grupo 6 antes de marcar as tarefas.
- [x] 6.4 Push 4 com as correções achadas nos testes, com dry-run e aprovação, e pull de comparação:
  - regex de data em `converter_data_pedido` (mês 13);
  - a mesma regex em `converter_horario_pedido` (C6), por decisão do usuário (decisions-log 33);
  - teto da faxina reduzido para 50 (decisions-log 35).

  Verificação: saída do push e comparação sem diferenças.
- [x] 6.5 Restaurar `prazo_cancelamento_minutos` para 120 pela API de parâmetros, por decisão do usuário (decisions-log 34). Verificação: `GET parametros` com 120 e um `ALTERAR_PARAMETROS` de 5 para 120.

## 7. Verificação do backend contra o workspace

Scripts descartáveis no scratchpad. As contas, a unidade e os espaços de teste são criados para o teste e, ao fim, desativados ou inativados, sem exclusão física. Os instantes são relativos ao relógio real.

Para ter pendentes vencidas, os testes usam um tipo de teste "TST Aprovação C7":
- horário amplo (00h00 às 23h50), duração mínima de 10 minutos, antecedência mínima 0 e limite de ativas alto;
- exige aprovação para o aluno.

A pendente começa no próximo múltiplo da granularidade, e o script espera o início. Se o teste rodar num dia sem funcionamento, o dia entra nos parâmetros durante o teste e é removido no fim. Ao final, tudo é desativado e os parâmetros são restaurados.

- [x] 7.1 Quem decide:
  - coordenador da unidade aprova;
  - admin recusa em outra unidade;
  - coordenador de outra unidade e reserva inexistente recebem o mesmo 403;
  - admin com reserva inexistente recebe 404;
  - aluno recebe 403;
  - coordenação removida recebe 403 com o mesmo token.

  Verificação: script com o resultado de cada caso.
- [x] 7.2 Própria reserva: um professor cria uma pendente e é promovido a coordenador da unidade; a decisão dele é recusada com a mensagem do D5, e outro coordenador aprova. Verificação: script.
- [x] 7.3 Aprovação e recusa:
  - aprovar pendente futura, com o decisor e o instante gravados;
  - aprovar depois de reduzir a duração máxima do tipo;
  - recusar com motivo, depois do que o horário fica livre para outra reserva;
  - recusar sem motivo, só com espaços e com 501 caracteres; essas recusas não acionam a faxina;
  - reserva já `CONFIRMADA`, `RECUSADA` ou `CANCELADA` recebe "não está pendente";
  - uma reserva aprovada a menos do prazo de cancelamento do início não pode ser cancelada pelo dono, e a recusa informa o prazo.

  Verificação: script.
- [x] 7.4 Prazo da decisão:
  - aprovar a cerca de 1 minuto do início é aceito;
  - aprovar depois do início é recusado com a mensagem de prazo, e a reserva fica `EXPIRADA`.

  O instante exato do início não dá para acertar com o relógio real. Ele é conferido por revisão do código (`inicio > agora` estrito) e fica como "não testado" no relatório. Verificação: script.
- [x] 7.5 Expiração:
  - "Minhas reservas", a listagem da unidade e a busca mostram a pendente vencida como expirada e livre **antes** da gravação;
  - uma criação recusada grava a expiração;
  - uma criação aceita no intervalo da pendente vencida grava a expiração e cria a nova reserva;
  - o limite de ativas não conta a vencida;
  - cancelar a vencida recebe "não está ativa";
  - a pendente iniciada de uma conta inativada expira na próxima operação;
  - desativar o espaço antes da faxina cancela a pendente iniciada com `ESPACO_INDISPONIVEL`;
  - mover o espaço antes da faxina cancela a pendente iniciada, e o `CANCELAR_RESERVA` leva a unidade de origem;
  - `EXPIRAR_RESERVA` tem ator vazio e `expirou_em` igual ao início;
  - com zero vencidas as operações seguem normais, e uma segunda faxina logo depois não grava nada;
  - uma pendente das 22h30 em São Paulo (já o dia seguinte em UTC) expira com `expirou_em` igual ao início e aparece no dia certo na listagem.

  Verificação: script e consulta da auditoria.
- [x] 7.6 Volume: cerca de 30 pendentes vencidas (vários espaços de teste) expiradas por uma única operação, com tempo medido e o número de registros de auditoria conferido. Critério: até 10 s. Se passar disso, reduzir o teto do D3 e repetir. Verificação: script com o tempo e as contagens.
- [x] 7.7 Concorrência:
  - aprovar e recusar ao mesmo tempo;
  - aprovar enquanto o dono cancela;
  - aprovar enquanto o coordenador desativa o espaço;
  - duas criações simultâneas com pendente vencida no intervalo;
  - várias requisições simultâneas que encontram a mesma pendente vencida.

  Em todos os casos, uma única transição, exatamente um `EXPIRAR_RESERVA` por reserva e nenhuma sobreposição ativa. Verificação: script com chamadas em paralelo e consulta final.
- [x] 7.8 Listagem da unidade:
  - escopo do coordenador e do admin;
  - padrão de pendentes futuras em ordem crescente;
  - filtros de situação (inclusive `EXPIRADA` derivada e `TODAS`, com a ordem decrescente), espaço e período, inclusive uma reserva noturna perto da virada do dia em São Paulo;
  - situação inválida recusada; datas com mês 13, dia 31 de mês curto e 30 de fevereiro recusadas; período só com data inicial, só com final e sem nenhuma;
  - listagem sem nenhuma reserva e com reservas sem decisor nem cancelador; coordenador sem unidades (se for possível criar o caso) recebe lista vazia, sem vazamento; espaço fora da unidade escolhida recebe 403;
  - teto de 200 com `limitada`, conferido por revisão de código se criar 200 reservas de teste não for viável no limite de requisições;
  - unidade e espaço fora do escopo recebem 403;
  - datas inválidas e final antes da inicial são recusadas;
  - os itens não trazem dados pessoais além de nome e e-mail, e a reserva cancelada por inativação de conta vem sem quem cancelou;
  - a listagem não gera auditoria.

  Verificação: script.
- [x] 7.9 Regressão da C6: criação com conflito, encostadas, limite, cancelamento no prazo, busca livre e ocupado, e as ações de gestão com reserva em andamento continuam passando. Verificação: script com os casos principais da C6.
- [x] 7.10 Revisão do guardian do grupo 7 antes de marcar as tarefas.
- [x] 7.11 Retestes depois das tarefas 6.4 e 6.5:
  - datas com mês 13, dia 00, 31 de abril e 30 de fevereiro recusadas com a mensagem em português, na listagem, na busca e na criação;
  - mais de 50 pendentes vencidas: a primeira operação expira 50, a seguinte expira o restante, com um `EXPIRAR_RESERVA` por reserva;
  - regressão da C6 com o prazo de 120: cancelamento recusado depois do prazo e aceito com margem antes dele;
  - reserva aprovada e depois cancelada pelo dono no prazo termina `CANCELADA`.

  A saída do complemento anterior (7.9) é anexada ao log. Verificação: script e log.

## 8. Reflex

- [x] 8.1 Cliente: `aprovar_reserva`, `recusar_reserva` e `reservas_unidade` em `xano_cliente.py`, no grupo `_RESERVAS`. Verificação: chamada real de cada uma num script com conta de teste, sem imprimir token.
- [x] 8.2 Criar `ReservasUnidadeState` e a página `/reservas-unidade` conforme o D10:
  - guarda `e_gestor`;
  - filtros de unidade, espaço, situação e período;
  - tabela com dono, papel na criação, espaço, data, horário e situação;
  - "Aprovar" e "Recusar" com diálogo de motivo e aviso;
  - erros 400 na página ou no diálogo e recarga depois de cada decisão;
  - aviso quando a lista vem `limitada`.

  Verificação: `reflex run` e teste no navegador (Playwright) aprovando, recusando, recusando sem motivo, com o prazo vencido e com o coordenador que perde a coordenação com a página aberta (é levado para "Início").
- [x] 8.3 "Minhas reservas": a recusada mostra `motivo_recusa`, e a pendente vencida aparece expirada no histórico, sem "Cancelar". Verificação: navegador com reservas de teste nas duas situações.
- [x] 8.4 Menu: "Reservas da unidade" depois de "Aprovações" para coordenador e admin; um aluno que abre `/reservas-unidade` vai para "Início". Verificação: navegador com aluno, coordenador e admin.
- [x] 8.5 Revisão do guardian do grupo 8 antes de marcar as tarefas.

## 9. Encerramento do apply

- [x] 9.1 Atualizar o `decisions-log.md` com as decisões tomadas no apply e registrar no relatório o que não foi possível testar (instante exato do início e vencimento entre as duas transações, cobertos por revisão de código). Verificação: arquivo atualizado.
- [x] 9.2 Pedir ao guardian o relatório de revisão final e mostrá-lo ao usuário antes de qualquer commit ou push da change. Verificação: relatório apresentado.
- [ ] 9.3 Limpeza dos testes:
  - o usuário remove pelo painel as funções `tst_faxina_falha`, `tst_c7_auditoria` e `tst_c7_reservas`, e os arquivos locais são apagados;
  - pull final de comparação sem diferenças;
  - unidades e tipo de teste desativados e contas de teste inativadas, sem exclusão física.

  Verificação: `git status -- xano` sem `tst_*` e comparação sem diferenças.

  Situação em 11/11/2026 às 21h08:
  - feitos: funções temporárias removidas (painel e local), pull final sem diferenças, `.playwright-mcp/` apagada, 7 contas de teste inativas e a unidade "TST C7 B" desativada;
  - pendentes: a unidade "TST C7" e o tipo "TST Aprovação C7" foram recusados por uma reserva confirmada em andamento até as 22h30. A desativação deles fica para depois desse horário.

## Workflow follow-up

- Mostrar o `git diff` e commitar em português, no imperativo, depois da aprovação do usuário.
- Arquivar a change depois da revisão humana (`/opsx:archive`), conferindo as specs consolidadas de `aprovacao-reservas`, `reservas`, `busca-espacos`, `auditoria` e `autorizacao`.
