## 1. Preparação e confirmações no Xano Developer MCP

- [x] 1.1 O usuário confirma a conta e o workspace do Xano CLI e a branch `change/fila-espera`. Rodar `xano workspace pull` numa pasta temporária e confirmar que o workspace está igual a `./xano`, ignorando espaços e as vírgulas já conhecidas. Verificação: resposta do usuário e comparação sem diferenças.
- [x] 1.2 Confirmar no MCP, com arquivos de sonda validados e sem push:
  - tabela com enum de situação e campos referenciando `usuario`, `espaco` e `reserva`;
  - ordenação múltipla (`nivel_prioridade desc, criado_em asc, id asc`) com paginação;
  - `|filter` e `|some`, ou equivalente, sobre listas em memória, com comparação de instantes em ms;
  - `max` entre dois inteiros;
  - consulta `count` numa rota GET seguida de uma chamada condicional a `aplicar_vencimentos`.

  Registrar o que for confirmado na seção "Confirmações do apply" do `design.md`. Verificação: sondas válidas no MCP.
- [x] 1.3 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Documentação do domínio, do escopo e do roadmap

- [x] 2.1 `docs/project-overview.md`, conforme o D11: §5, §6, §7.3, §7.4 (com a confirmação `PENDENTE` em tipo com aprovação e a recusa por reserva própria sobreposta), §7.6, §7.8, §7.11, §10 e §11. Verificação: `git diff docs/project-overview.md` mostrado ao usuário.
- [x] 2.2 `docs/domain-model.md`, conforme o D11:
  - §2.11: corte e limite inclusivo, confirmação `PENDENTE`, recusa por reserva própria sobreposta e `ENCERRADA` entre os fins da retenção;
  - contestação e notificação marcadas como fora da v1;
  - §2.18 e DER conferidos.

  Verificação: `git diff docs/domain-model.md`.
- [x] 2.3 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Xano: dados e funções de apoio

- [x] 3.1 Criar `xano/table/entrada_fila.xs` conforme o D1, com os índices. Verificação: validação do MCP.
- [x] 3.2 `configuracao_geral.prazo_fila_minutos` e `bootstrap`, com o padrão 120 em `$parametros_padrao`, no `db.add` e no ajuste, com vírgulas (D2). Verificação: validação do MCP.
- [x] 3.3 Criar `situacao_efetiva_fila` e uma função de corte, conforme o D3: puras, com os limites `<` e `>=` exatamente como no design. Verificação: validação do MCP.
- [x] 3.4 Extrair `validar_pedido_reserva` e `exigir_limite_ativas` de `criar_reserva`, conforme o D7, com as mesmas mensagens e a mesma ordem. Verificação: validação do MCP e comparação lado a lado das mensagens com as da rota atual.
- [x] 3.5 Criar `processar_fila(agora)` conforme o D5:
  - saída cedo;
  - expirar, encerrar e avisar, nessa ordem;
  - percurso guloso na ordem `nivel_prioridade desc, criado_em asc, id asc`;
  - ocupação em memória, com as avisadas da passada;
  - teto por passo;
  - auditoria do D8 com `|set`.

  Verificação: validação do MCP.
- [x] 3.6 `processar_vencimentos` passa a chamar `processar_fila` depois das expirações de reservas. `cancelar_reservas`, nesta ordem (D5):
  1. cancela as reservas, como hoje;
  2. encerra as entradas ativas da conta (modo `conta`) ou dos espaços (modo `espaco`), com o ator, o motivo e uma consulta própria dos espaços para a unidade da auditoria (em `mover_espaco`, a de origem);
  3. chama `processar_fila`, em todos os modos.

  Atualizar os comentários. Verificação: validação do MCP.
- [x] 3.7 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Xano: rotas

- [x] 4.1 `criar_reserva`:
  - usar as funções do D7;
  - conflito com as retidas, que recusam antes do deslocamento (D4);
  - comentário do ponto de extensão da C9 resolvido.

  Verificação: validação do MCP.
- [x] 4.2 `cancelar_reserva` e `recusar_reserva` chamam `processar_fila` no fim da transação (D5). Verificação: validação do MCP.
- [x] 4.3 Criar `entrar_fila`, `confirmar_fila` e `desistir_fila` no grupo `reservas`, conforme o D6, com os pontos de extensão de penalidade e bloqueio comentados e nomes únicos no workspace. Verificação: validação do MCP e busca de homônimos em `xano/api`.
- [x] 4.4 Criar `minha_fila` (GET), conforme o D6: verificação rápida, faxina condicional, lista com situação efetiva, posição, prazo e `avisos`. Verificação: validação do MCP.
- [x] 4.5 `buscar_espacos`, conforme o D9:
  - retidas em `ocupado`;
  - com retida, `deslocavel` falso e `deslocaria` 0;
  - `prazo_fila_minutos` lido com a precondição do bootstrap;
  - `na_fila` e `pode_entrar_fila`;
  - chaves ausentes sem horário;
  - sem trava e sem gravação.

  Verificação: validação do MCP.
- [x] 4.6 `parametros_GET` e `parametros_POST`: devolver, validar no `$limites`, gravar e auditar `prazo_fila_minutos` (D2). Verificação: validação do MCP.
- [x] 4.7 Revisão do guardian do grupo 4 antes de marcar as tarefas.

## 5. Publicação

- [x] 5.1 `xano workspace push --dry-run`, mostrar o resultado ao usuário e só publicar com aprovação explícita. Usar `--force`, por ser terminal não interativo, e `-i` quando for preciso filtrar. Nunca `--sync`, `--delete`, `--env` ou `--records`. Verificação: saída do push.
- [x] 5.2 Pull de comparação: `./xano` igual ao workspace, ignorando espaços. Alinhar os arquivos reformatados pelo Xano e conferir vírgulas e blocos entre crases. Verificação: comparação sem diferenças.
- [x] 5.3 Executar o `bootstrap` duas vezes pelo CLI: a primeira grava o prazo da fila e a segunda não altera nada. Verificação: saídas do CLI e `GET parametros` com `prazo_fila_minutos` igual a 120.
- [x] 5.4 Revisão do guardian do grupo 5 antes de marcar as tarefas.

## 6. Verificação do backend contra o workspace

Scripts descartáveis no scratchpad. As contas (alunos, professores, coordenador), a unidade, o tipo e os espaços de teste são criados para o teste e, ao fim, desativados ou inativados, sem exclusão física. Os instantes são relativos ao relógio real.

Para testar prazos e corte sem esperar, o teste usa um tipo "TST Fila C9":
- horário amplo (00h00 às 23h50);
- antecedência mínima 0 e limite de ativas alto;
- sem aprovação, salvo quando o caso pedir.

O prazo da fila é reduzido temporariamente pela API de parâmetros (por exemplo, 1 ou 2 minutos) e restaurado para 120 no fim. Se o teste rodar num dia sem funcionamento, o dia entra nos parâmetros durante o teste e é removido no fim. As pausas respeitam o limite de requisições do plano gratuito.

- [x] 6.1 Entrada:
  - aluno entra em intervalo ocupado;
  - intervalo livre é recusado;
  - quem pode deslocar é recusado;
  - entrada sobre vaga retida é aceita até para nível 3;
  - fora das regras é recusada;
  - papel sem permissão é recusado;
  - entrada repetida é recusada;
  - reserva própria sobreposta é recusada;
  - limite de ativas não impede a entrada;
  - entrada a 1 minuto além do corte é aceita, e no corte (minuto inteiro) é recusada;
  - sem token, a resposta é 401.

  Verificação: script com o resultado de cada caso.
- [x] 6.2 Liberação e retenção:
  - cancelamento avisa o primeiro na mesma operação;
  - liberação parcial não avisa;
  - reserva maior liberada avisa;
  - recusa libera;
  - pendente expirada pela faxina libera;
  - sobras do deslocamento liberam;
  - vaga retida recusa reserva direta e deslocamento;
  - ordem por nível e por entrada.

  Verificação: script.
- [x] 6.3 Filas sobrepostas: a maior prioridade leva a retenção; a desistência reavalia; a fila não sobreposta é avisada; a cadeia Rui, Carlos e Ana do D5. Verificação: script.
- [x] 6.4 Prazo, corte e situação efetiva:
  - prazo cheio e prazo limitado pelo corte;
  - confirmação no último minuto aceita e depois do prazo recusada;
  - prazo vencido passa ao próximo, com o prazo novo contado do aviso;
  - vencida antes da gravação não retém, nem na busca nem na criação;
  - corte encerra as que aguardam;
  - vaga liberada depois do corte, por recusa de pendente, fica livre;
  - corte pela antecedência mínima do tipo (tipo de teste com antecedência alterada temporariamente).

  Verificação: script.
- [x] 6.5 Confirmação e desistência:
  - confirmação cria a reserva com origem `FILA`;
  - tipo com aprovação gera `PENDENTE`;
  - limite de ativas recusa e mantém `NOTIFICADA`;
  - `AGUARDANDO` não confirma;
  - entrada de outra pessoa recebe a mesma resposta da inexistente;
  - sair da fila;
  - desistir da vaga avisa o próximo;
  - entrada final não aceita desistência.

  Verificação: script.
- [x] 6.6 Gestão e conta:
  - desativar o espaço encerra as entradas `AGUARDANDO` e `NOTIFICADA`;
  - reativar o espaço não as reabre;
  - mover o espaço ou trocar o tipo encerra;
  - inativar a conta encerra as entradas e libera a vaga da reserva cancelada para a fila.

  Verificação: script.
- [x] 6.7 `minha_fila` e o momento em que a fila anda:
  - posição sem nomes, prazo e situação efetiva;
  - finalizadas dos últimos 30 dias;
  - abrir a fila com uma retida vencida grava a expiração e avisa o próximo;
  - sem nada a processar, nada é gravado (auditoria sem registros novos);
  - reserva direta não fura a fila depois de um vencimento não gravado;
  - acúmulo de mais de 50 vencimentos: o teto limita a rodada, o restante vai nas rodadas seguintes e a página continua respondendo.

  Verificação: script.
- [x] 6.8 Concorrência:
  - confirmação e desistência simultâneas;
  - cancelamento e reserva direta simultâneos com alguém na fila;
  - duas entradas iguais simultâneas;
  - duas desistências que liberam filas sobrepostas ao mesmo tempo.

  Em todos, uma transição por entrada, nenhuma ocupação sobreposta e nenhuma reserva direta antes da retida. Verificação: script com chamadas em paralelo e consulta final.
- [x] 6.9 Busca:
  - retida ocupa e não é deslocável;
  - retida vencida aparece livre;
  - `pode_entrar_fila` nos casos do D9 (deslocável, fora das regras, depois do corte, já na fila, reserva própria);
  - sem horário, sem as chaves;
  - nenhum dado de quem ocupa ou de quem está na fila.

  Verificação: script.
- [x] 6.10 Auditoria: `ENTRAR_FILA`, `CONFIRMAR_FILA` com o `CRIAR_RESERVA`, `DESISTIR_FILA`, `NOTIFICAR_FILA` com o prazo, `EXPIRAR_FILA` com o instante do prazo, `ENCERRAR_FILA` pelo corte (ator vazio) e pela desativação (ator e motivo); recusas sem registro. Verificação: consulta da auditoria.
- [x] 6.11 Parâmetros: GET com o prazo da fila; POST com 0 recusado e nada gravado; POST válido auditado; admin secundário recebe acesso negado. Verificação: script.
- [x] 6.12 Regressão da C6 à C8, pelo refatoramento do D7:
  - regras de horário com as mesmas mensagens;
  - limite de ativas;
  - conflito simples e encostadas;
  - deslocamento com e sem confirmação;
  - cancelamento no prazo;
  - aprovação, recusa e expiração;
  - gestão com reserva em andamento.

  Verificação: script com os casos principais.
- [x] 6.13 Revisão do guardian do grupo 6 antes de marcar as tarefas.

## 7. Reflex

- [x] 7.1 Cliente: `entrar_fila`, `confirmar_fila`, `desistir_fila` e `minha_fila` (D10). Verificação: chamada real de cada uma num script com conta de teste, sem imprimir token.
- [x] 7.2 `FilaState` e o aviso global: `carregar_aviso` no `on_load` das páginas autenticadas (fora da troca de senha provisória) e o aviso no `layout_autenticado`. Verificação:
  - `reflex compile --dry`;
  - no navegador (Playwright), o aviso aparecendo em "Buscar espaços" e no Início para uma conta com vaga retida e ausente para outra;
  - contagem das chamadas ao Xano por navegação, comparada com o limite de requisições do plano gratuito.
- [x] 7.3 "Minhas reservas": seção "Fila de espera" com "Confirmar", "Desistir" e "Sair da fila", diálogos, mensagens e recarga das reservas e da fila. Verificação: navegador confirmando uma vaga (a reserva aparece em "Próximas") e saindo de outra fila.
- [x] 7.4 Busca: "Entrar na fila" com diálogo e recusa dentro dele; etiqueta "Você está na fila"; nenhum botão de fila em espaço livre, deslocável ou fora das regras. Verificação: navegador com aluno entrando na fila e professor vendo "Deslocar e reservar" no mesmo espaço.
- [x] 7.5 Parâmetros: campo "Prazo da fila de espera". Verificação: navegador com o admin principal ou, para não digitar a senha real dele nas ferramentas, chamada real da API com o conjunto completo de limites e revisão do `LIMITES`. O que não for testado no navegador fica registrado.
- [x] 7.6 Revisão do guardian do grupo 7 antes de marcar as tarefas.

## 8. Encerramento do apply

- [x] 8.1 Atualizar o `decisions-log.md` com as decisões do apply e registrar no `design.md` o que não foi possível testar. Verificação: arquivos atualizados.
- [x] 8.2 Pedir ao guardian o relatório de revisão final e mostrá-lo ao usuário antes de qualquer commit ou push da change. Verificação: relatório apresentado.
- [x] 8.3 Limpeza dos testes:
  - funções temporárias `tst_*` removidas pelo usuário no painel e apagadas localmente;
  - pull final sem diferenças;
  - unidade e tipo de teste desativados e contas de teste inativadas, sem exclusão física;
  - prazos e dias de funcionamento restaurados.

  Verificação: nenhum `tst_*` em `xano/`, comparação sem diferenças e `GET parametros` com os valores originais.

## 9. Update de 20/11/2026: prazo para confirmar e fechamento da fila (D12)

- [x] 9.1 Documentos, conforme o D12:
  - `project-overview.md` §7.4: prazo para confirmar (12 h, limitado ao corte) e fechamento (corte menos o tempo mínimo útil);
  - §11: e-mail de "vaga liberada" como trabalho futuro;
  - `domain-model.md` §2.11, §2.18 e DER: os dois parâmetros novos.

  Verificação: o usuário confere `git diff docs/`.
- [x] 9.2 Xano, dados e funções:
  - `configuracao_geral` com `prazo_confirmacao_fila_minutos` e `tempo_minimo_fila_minutos`;
  - `bootstrap` com os padrões 720 e 30, com vírgulas;
  - função pura de fechamento, ou input a mais em `corte_fila`;
  - `situacao_efetiva_fila` com o fechamento para a `AGUARDANDO`;
  - `processar_fila`: encerra no fechamento, avisa só antes dele e calcula o prazo com o parâmetro novo, limitado ao corte, com as preconditions dos campos novos.

  Verificação: validação do MCP.
- [x] 9.3 Xano, rotas:
  - `entrar_fila` recusa a partir do fechamento;
  - `minha_fila` usa o fechamento na situação efetiva;
  - `buscar_espacos` calcula `pode_entrar_fila` pelo fechamento;
  - `parametros_GET` e `parametros_POST`: input, `$limites` com vírgulas, gravação e auditoria dos dois campos.

  Verificação: validação do MCP da pasta `xano/` inteira.
- [x] 9.4 Reflex: `LIMITES` e `ROTULOS_LIMITES` com os dois campos novos e rótulos claros ("Prazo para confirmar a vaga da fila" e "Tempo mínimo útil da fila"). O rótulo do corte passa a "Corte da fila de espera". Verificação: `reflex compile --dry`.
- [x] 9.5 Revisão do guardian dos itens 9.1 a 9.4 antes de marcá-los.
- [x] 9.6 Publicação: o usuário confirma a conta do Xano CLI. `xano workspace push --dry-run` mostrado ao usuário e publicado só com aprovação explícita (`--force`, sem `--sync`, `--delete`, `--env` ou `--records`). Pull de comparação sem diferenças além das vírgulas da decisão 27 da C8. `bootstrap` executado duas vezes: a primeira grava 720 e 30, a segunda não altera nada. Verificação: saídas do CLI e `GET parametros` com 120, 720 e 30.
- [x] 9.7 Testes do backend, com cenário de teste novo e limpeza ao fim, sem exclusão física:
  - entrada 1 minuto antes do fechamento aceita, e exatamente no fechamento recusada (com a folga de segundos usada no 6.1);
  - vaga liberada depois do fechamento: ninguém é avisado, a entrada fica `ENCERRADA` e o horário fica livre;
  - prazo cheio de 12 h e prazo limitado pelo corte;
  - aviso logo antes do fechamento: o prazo vai até o corte, com pelo menos o tempo mínimo útil;
  - busca: `pode_entrar_fila` falso a partir do fechamento;
  - auditoria: `ENCERRAR_FILA` com `encerrou_em` igual ao fechamento e `NOTIFICAR_FILA` com o prazo novo;
  - parâmetros: GET com os três, POST com 0 recusado em cada um e POST válido auditado;
  - regressão rápida dos testes 6.2, 6.3 e 6.5 com os parâmetros novos.

  Prazos alterados temporariamente pela API e restaurados no fim. Verificação: scripts com o resultado de cada caso.
- [x] 9.8 Reflex no navegador: os três campos em "Parâmetros" (pela API, se o admin principal não puder ser usado no navegador) e o aviso do topo com o prazo novo. Verificação: navegador ou API e revisão do código; o que não for testado fica registrado.
- [x] 9.9 Revisão do guardian dos itens 9.6 a 9.8 antes de marcá-los.
- [x] 9.10 Encerramento do update:
  - `decisions-log.md` e "Verificação do apply" do `design.md` atualizados;
  - limpeza do cenário de teste novo e de qualquer `tst_*`, com pull final;
  - novo relatório de revisão final do guardian, mostrado ao usuário antes de qualquer commit.

  Verificação: relatório apresentado.

## Workflow follow-up

- O usuário mostra o `git diff` e faz os commits em português, no imperativo, depois da aprovação.
- Arquivar a change depois da revisão humana (`/opsx:archive`), conferindo as specs consolidadas de `fila-espera`, `reservas`, `busca-espacos`, `aprovacao-reservas`, `parametros` e `auditoria`.
