## 1. Preparação e confirmações no Xano Developer MCP

- [x] 1.1 Criar a branch `change/reserva-avulsa` a partir da `main` e rodar `xano workspace pull` numa pasta temporária para confirmar que o workspace está igual a `./xano` (ignorando espaços). Verificação: `git branch --show-current` e comparação sem diferenças.
- [x] 1.2 Confirmar no MCP a sintaxe de: tabela com `enum` opcional e `timestamp` opcional; índice composto (`espaco_id`, `inicio`); grupo de API novo (arquivo do grupo em `xano/api/reservas/`); consulta com `status` em lista e intervalo (`inicio < x && fim > y`); contagem; `format_timestamp` com fuso America/Sao_Paulo para `AAAA-MM-DD` e `HH:MM`. Registrar o que for confirmado em "Confirmações do apply" no `design.md`. Verificação: arquivos de sonda validados pelo MCP (sem push).
- [x] 1.3 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Xano: dados e parâmetro

- [x] 2.1 Criar `xano/table/reserva.xs` conforme o design D1 (campos, enums completos, índices por espaço com início e por usuário). Verificação: validação do MCP.
- [x] 2.2 Acrescentar `int? prazo_cancelamento_minutos?` a `configuracao_geral` e fazer o `bootstrap` gravar 120 quando vazio, sem mudar `obter_configuracao` nem `obter_configuracao_horario` (D12). Verificação: validação do MCP; `$resultado` do bootstrap com vírgulas e a chave nova em `parametros_ajustados`.
- [x] 2.3 Incluir o prazo de cancelamento no `GET` e no `POST` de `parametros` (inteiro a partir de 1, auditado em `ALTERAR_PARAMETROS`). Verificação: validação do MCP.
- [x] 2.4 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Xano: funções

- [x] 3.1 Criar `converter_horario_pedido` (D3), extraindo o bloco de `buscar_espacos` sem mudar as mensagens, e trocar o bloco inline da busca pela chamada. Verificação: validação do MCP; a busca continua passando nos casos de formato da C5 (tarefa 7.9).
- [x] 3.2 Criar `selecionar_reservas_a_cancelar` (D10), só de leitura, com o modo conta (reservas ativas que ainda não começaram) e o modo espaço (reservas ativas que ainda não terminaram, exceto as confirmadas em andamento, mais a quantidade delas e o maior fim entre elas). Verificação: validação do MCP.
- [x] 3.3 Criar `cancelar_reservas` (D10), que usa a 3.2, grava `CANCELADA`, motivo, autor e instante (no modo espaço, também `motivo_detalhe` e `motivo_descricao` quando recebidos), gera um `CANCELAR_RESERVA` por reserva e devolve a quantidade. Deve ser chamada dentro da transação e da trava de quem a usa. Verificação: validação do MCP; objetos de auditoria montados com valores calculados antes ou cadeia de `|set`.
- [x] 3.4 Criar `formatar_reserva`, que devolve `data`, `hora_inicio` e `hora_fim` em America/Sao_Paulo a partir dos instantes (D9). Verificação: validação do MCP.
- [x] 3.5 Criar `validar_motivo` (D17), com as listas de desativação e de inativação de conta, recusando código fora da lista e "Outro" sem descrição ou com mais de 500 caracteres. Verificação: validação do MCP.
- [x] 3.6 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Xano: rotas do grupo `reservas`

- [x] 4.1 Criar o grupo `reservas` e a rota `criar_reserva` (POST) na ordem do D4, com os pontos de extensão comentados para C8, C9 e C10, mensagens em português para cada motivo de `validar_horario_reserva` e auditoria `CRIAR_RESERVA`. Verificação: validação do MCP.
- [x] 4.2 Criar `cancelar_reserva` (POST) conforme o D6, com o prazo lido de `configuracao_geral` dentro da trava e a mesma recusa para reserva alheia ou inexistente. Verificação: validação do MCP.
- [x] 4.3 Criar `minhas_reservas` (GET) conforme o D9, com uma consulta por tabela e `pode_cancelar` calculado com o prazo atual. Verificação: validação do MCP.
- [x] 4.4 Criar `impacto_reservas` (GET) conforme o D8, com a autorização de cada alvo igual à da ação correspondente. Verificação: validação do MCP.
- [x] 4.5 Revisão do guardian do grupo 4 antes de marcar as tarefas.

## 5. Xano: rotas alteradas

- [x] 5.1 `inativar` (contas): trocar o texto livre `motivo` por `motivo_codigo` e `motivo_descricao`, validados por `validar_motivo` com a lista de conta e gravados em `INATIVAR_CONTA`; chamar `cancelar_reservas` no modo conta, motivo `CONTA_INATIVADA`, sem detalhe nas reservas e sem recusa por reserva em andamento; incluir a quantidade na mensagem. Verificação: validação do MCP.
- [x] 5.2 `desativar_espaco`, `mover_espaco` e `editar_espaco` (só quando o tipo muda): dentro da trava e antes de gravar, recusar com o horário de término se houver reserva confirmada em andamento; senão, chamar `cancelar_reservas` no modo espaço, motivo `ESPACO_INDISPONIVEL`, e incluir a quantidade na mensagem. Só a `desativar_espaco` recebe `motivo_codigo` e `motivo_descricao` (lista de desativação), gravados em `DESATIVAR_ESPACO` e nas reservas canceladas. Em `mover_espaco`, `cancelar_reservas` é chamada antes de gravar a nova unidade, para o `CANCELAR_RESERVA` levar a unidade de origem (D11). Verificação: validação do MCP.
- [x] 5.3 `desativar_tipo` e `desativar` (unidade): a mesma regra da 5.2 com todos os espaços do tipo ou da unidade, com motivo obrigatório da lista de desativação gravado na auditoria da ação e nas reservas canceladas; na unidade, a recusa vem antes de qualquer mudança de coordenadores, professores e pedidos. Verificação: validação do MCP.
- [x] 5.4 `buscar_espacos`: com horário, uma consulta das reservas ativas sobrepostas e o campo `ocupado` em cada espaço (D13). Verificação: validação do MCP.
- [x] 5.5 Revisão do guardian do grupo 5 antes de marcar as tarefas.

## 6. Publicação

- [x] 6.1 `xano workspace push --dry-run`, mostrar o resultado ao usuário e só publicar com aprovação explícita (push com `--force` por ser terminal não interativo, nunca com `--sync`, `--delete`, `--env` ou `--records`). Verificação: saída do push.
- [x] 6.2 Executar o `bootstrap` duas vezes pelo CLI; a primeira grava o prazo e a segunda não altera nada. Verificação: saídas do CLI e `GET parametros` com o prazo 120.
- [x] 6.3 Pull de comparação: `./xano` igual ao workspace, ignorando espaços; alinhar arquivos reformatados pelo Xano e conferir vírgulas e blocos entre crases. Verificação: comparação sem diferenças.
- [x] 6.4 Obter a URL base do grupo `reservas` e acrescentar `XANO_API_RESERVAS_URL` ao `.env`, sem imprimir o valor. Verificação: o cliente consegue chamar `minhas_reservas` (tarefa 7.1). Feito pelo método `minhas_reservas` do cliente, acrescentado antes da hora; a revisão do cliente continua na 8.1.
- [x] 6.5 Revisão do guardian do grupo 6 antes de marcar as tarefas.

## 7. Verificação do backend contra o workspace

Scripts descartáveis no scratchpad, com contas, unidade e espaços de teste criados e, ao fim, desativados e inativados (sem exclusão física). Instantes relativos ao relógio real, com datas calculadas no fuso de São Paulo. Funções temporárias `tst_*`, se precisar de alguma, só com push aprovado e exclusão pelo painel pelo usuário.

**Reservas em andamento e terminadas:** a criação não aceita horário passado. Os testes usam um tipo de teste "TST Reserva C6", com horário amplo (00h00 às 23h50), duração mínima de 10 minutos e antecedência mínima 0. A reserva começa no próximo múltiplo da granularidade, e o script espera o início (para ter uma em andamento) ou o fim (para ter uma terminada). Se o teste rodar num dia sem funcionamento, o dia é incluído nos parâmetros durante o teste e removido no fim. Ao final, o tipo, os espaços e a unidade de teste são desativados, as contas inativadas e os parâmetros restaurados.

- [x] 7.1 Criação: aluno na Biblioteca `CONFIRMADA` com nível 1; aluno no Laboratório `PENDENTE`; coordenador no Auditório `CONFIRMADA` com nível 3; aluno em Sala de aula recusado (papel); espaço de tipo desativado e id inexistente com a mesma recusa; conta inativa como não autenticada. Verificação: script com o resultado de cada caso.
- [x] 7.2 Bordas de horário na criação: 21h40–22h40 aceito; 22h00–22h50 recusado (fechamento); 07h50–08h50 recusado (abertura); 10h05–11h05 recusado (granularidade); sábado recusado; antecedência máxima e mínima; 21h00–22h00 de quarta em São Paulo aceito como quarta (virada do dia em UTC); 2026-02-30 recusado. Verificação: script.
- [x] 7.3 Conflito: sobreposição parcial recusada; encostadas aceitas; pendente ocupa; cancelada libera; professor não desloca aluno (prioridade fica para a C8); mesmo horário em outro espaço aceito. Verificação: script.
- [x] 7.4 Concorrência: duas criações simultâneas para intervalos sobrepostos no mesmo espaço resultam em uma reserva; criação e desativação simultâneas do espaço nunca deixam reserva ativa em espaço desativado. Verificação: script com chamadas em paralelo e consulta final.
- [x] 7.5 Limite por tipo: com o limite do tipo de teste em 2, a terceira reserva é recusada; outro tipo, reserva cancelada e reserva já terminada não contam (a terminada é obtida pelo método do início deste grupo). Verificação: script.
- [x] 7.6 Cancelamento pelo usuário: com antecedência aceito; dos dois lados do limite, com margem de cerca de 1 minuto, usando um prazo pequeno ajustado em `parametros` só durante o teste e restaurado depois. O instante exato do limite não dá para acertar com o relógio real: ele é conferido por revisão do código (comparação em milissegundos, D6) e fica como "não testado" no relatório. Também: pendente aceito; reserva alheia e já cancelada recusadas; prazo de cancelamento igual a 0 recusado em `parametros`. Verificação: script.
- [x] 7.7 Cancelamentos automáticos e recusa por reserva em andamento:
  - inativar conta: futuras canceladas e a em andamento mantida;
  - desativar espaço, trocar tipo, mover espaço, desativar tipo e desativar unidade, com reserva confirmada em andamento: recusados com o horário de término, sem nada alterado, para admin e para coordenador;
  - as mesmas ações sem reserva em andamento: futuras canceladas, inclusive pendente já iniciada;
  - editar sem trocar tipo: nem recusado nem cancela;
  - unidade com destino faltando: recusada sem cancelar nenhuma reserva;
  - reservas terminadas intactas; reativações não restauram;
  - desativar tipo com cerca de 20 reservas futuras numa só transação;
  - motivo: desativação e inativação sem motivo, com "Outro" sem descrição e com código fora da lista recusadas sem alterar nada; reservas canceladas por desativação com o código e a descrição de "Outro"; reservas canceladas por inativação, por mudança de unidade e por troca de tipo sem detalhe, e `minhas_reservas` devolvendo o detalhe vazio sem erro.
  Verificação: script.
- [x] 7.8 Impacto: contagens e `em_andamento_ate` para cada alvo, iguais ao que a ação faz em seguida; nenhum alvo ou dois alvos recusados; coordenador de outra unidade, coordenador com espaço inexistente (mesma mensagem) e coordenador com tipo ou unidade recebem acesso negado. Verificação: script.
- [x] 7.9 Busca e minhas reservas: livre, ocupado e encostado na busca, sem identificar quem ocupa; casos de formato da C5 inalterados; minhas reservas só do próprio usuário, com `data` e horas em São Paulo e `pode_cancelar` correto. Verificação: script.
- [x] 7.10 Auditoria: `CRIAR_RESERVA`, `CANCELAR_RESERVA` do usuário e um `CANCELAR_RESERVA` por reserva nos cancelamentos automáticos, com o ator da ação (na mudança de unidade, com a unidade de origem); `ALTERAR_PARAMETROS` com o prazo de cancelamento; código e descrição do motivo em `DESATIVAR_ESPACO`, `DESATIVAR_TIPO_ESPACO`, `DESATIVAR_UNIDADE` e `INATIVAR_CONTA`; nada para recusas (inclusive a recusa por reserva em andamento), busca, listagem e impacto. Verificação: leitura do log por função temporária executada só pelo CLI, com push aprovado e exclusão pelo painel.
- [x] 7.11 Revisão do guardian do grupo 7 antes de marcar as tarefas.

## 8. Reflex

- [x] 8.1 Acrescentar ao `xano_cliente.py` `criar_reserva`, `cancelar_reserva`, `minhas_reservas` e `impacto_reservas`, com `_RESERVAS = "XANO_API_RESERVAS_URL"`. Verificação: script descartável chama as leituras contra o workspace.
- [x] 8.2 Busca: mostrar "Livre" ou "Ocupado", botão "Reservar" quando livre e dentro das regras, diálogo de confirmação com erro dentro dele (`limpar_ao_enviar=False`), mensagem de confirmada ou aguardando aprovação, busca refeita depois de reservar e o novo aviso fixo (D13, D14). Verificação: `reflex compile --dry`.
- [x] 8.3 Criar `ReservasState` e a página `/minhas-reservas` (próximas e histórico, motivos em português, "Cancelar" com confirmação quando `pode_cancelar`), registrada com `verificar_sessao`. Verificação: `reflex compile --dry`.
- [x] 8.4 Avisos de impacto (D8): diálogo de confirmação novo para desativar espaço; avisos nos diálogos de editar (troca de tipo) e mover espaço, de desativar tipo, de desativar unidade e de inativar conta (compartilhado por usuários e administradores). Verificação: `reflex compile --dry`.
- [x] 8.5 Motivo (D17): caixa de seleção com rótulos em português e campo "Descreva o motivo" para "Outro" nos diálogos de desativar espaço, tipo e unidade e no de inativar conta (que deixa de ter texto livre), com o aviso de que o texto de "Outro" fica visível nas reservas canceladas por desativação; em "Minhas reservas", o rótulo do motivo da desativação ao lado de "espaço indisponível", e só "espaço indisponível" quando não há motivo (mover espaço, trocar o tipo). Verificação: `reflex compile --dry`.
- [x] 8.6 Parâmetros: campo do prazo de cancelamento em `ParametrosState` e na página. Menu: "Minhas reservas" para todos, depois de "Buscar espaços". Verificação: `reflex compile --dry` e checagem de nomes sem uso.
- [x] 8.7 Revisão do guardian do grupo 8 antes de marcar as tarefas.

## 9. Documentação, verificação no navegador e entrega

- [x] 9.1 Atualizar `docs/domain-model.md` e `docs/project-overview.md` conforme o D15 (inclusive a correção do §2.9) e mostrar o diff ao usuário. Verificação: diff mostrado.
- [x] 9.2 Verificação manual (usuário):
  - menu de todos os papéis com "Minhas reservas";
  - reservar pela busca como aluno (Biblioteca confirmada e Laboratório pendente) e ver o espaço ocupado ao refazer a busca;
  - recusa de horário ocupado dentro da confirmação;
  - cancelar em "Minhas reservas" e ver a reserva no histórico;
  - avisos de impacto ao desativar um espaço com reservas futuras e ao inativar uma conta, e os motivos em "Minhas reservas";
  - tentativa de desativar um espaço com reserva em andamento, recusada com o horário de término;
  - desativar um espaço escolhendo o motivo (inclusive "Outro" com descrição) e ver o motivo na reserva cancelada em "Minhas reservas";
  - inativar uma conta escolhendo o motivo na lista;
  - alterar o prazo de cancelamento na página de parâmetros.
- [x] 9.3 Verificar no DevTools que o token do Xano não chega ao navegador. Verificação: confirmação do usuário.
- [x] 9.4 Revisar o código (PEP 8, sem `print`, sem código morto, sem segredo, sem função temporária no workspace) e mostrar o `git diff` antes de commitar.
- [x] 9.5 Pedir ao `change-guardian` o relatório em MODO REVISÃO FINAL e mostrá-lo ao usuário antes de qualquer commit ou push.
- [x] 9.6 Relatório final:
  - o que foi testado e o que não foi;
  - as divergências do DER;
  - os dados de teste que ficaram no workspace;
  - os casos de borda do AGENTS.md §9 cobertos (sobreposição parcial, 08h00 e 22h40, prazo de 2 horas no cancelamento, requisições simultâneas) e os que não se aplicam (vaga retida pela fila, janela de check-in e empate de prioridade, que ficam para C8 e C9);
  - o instante exato do limite do cancelamento, verificado só por revisão do código.
