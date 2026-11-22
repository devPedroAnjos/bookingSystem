## 1. Preparação e confirmações no Xano Developer MCP

- [x] 1.1 O usuário confirma a conta e o workspace do Xano CLI e a branch `change/checkin-faltas`. Rodar `xano workspace pull` numa pasta temporária e confirmar que o workspace está igual a `./xano`, ignorando espaços e as vírgulas já conhecidas. Verificação: resposta do usuário e comparação sem diferenças.
- [x] 1.2 Conferir que as decisões "aguarda o usuário" do `decisions-log.md` (13, 14, 16, 17, 20 e 23) têm resposta registrada e que os artefatos refletem as respostas. Verificação: log sem "aguarda o usuário".
- [x] 1.3 Confirmar no MCP, com arquivos de sonda validados e sem push:
  - no `where` de `db.query`, um campo timestamp opcional preenchido ou vazio (D2);
  - aritmética de instantes em ms com `max` e `min` entre dois inteiros;
  - `|max` sobre uma lista mapeada de timestamps;
  - um input bool opcional com padrão falso;
  - a edição em lote de várias faltas por id dentro de um `foreach`.

  Registrar o que for confirmado na seção "Confirmações do apply" do `design.md`. Verificação: sondas válidas no MCP.
- [x] 1.4 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Documentação do domínio e do roadmap

- [x] 2.1 `docs/project-overview.md`, conforme o D11: §7.8, §8, §10 e §11, com as decisões 2, 3, 4, 13, 14 e 16 como ficarem no item 1.2. Verificação: `git diff docs/project-overview.md` mostrado ao usuário.
- [x] 2.2 `docs/domain-model.md`, conforme o D11:
  - §2.9: "em andamento", e o `USUARIO_TARDIO` só para a `CONFIRMADA`;
  - §2.12: `ocorrida_em`;
  - §2.13: "em vigor" e a anulação só de `ATIVA`;
  - DER: `penalidade.parecer` e `configuracao_geral.comparecimento_desde`, com a nota de divergência.

  Verificação: `git diff docs/domain-model.md`.
- [x] 2.3 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Xano: dados e parâmetros

- [x] 3.1 Criar `xano/table/falta.xs` e `xano/table/penalidade.xs` conforme o D1, com os índices, e acrescentar `check_in_em` em `xano/table/reserva.xs` sem tocar nos demais campos. Verificação: validação do MCP e `git diff xano/table/reserva.xs` só com o campo novo.
- [x] 3.2 Os cinco parâmetros em `configuracao_geral` e no `bootstrap`, com os padrões 15, 15, 2, 30 e 7 em `$parametros_padrao`, no `db.add` e no ajuste, com vírgulas. O campo técnico `comparecimento_desde` é gravado com `now` só quando está vazio (D1). Verificação: validação do MCP.
- [x] 3.3 `parametros_GET` e `parametros_POST`: devolver, validar (>= 1, no `$limites`), gravar e auditar os cinco campos. Verificação: validação do MCP.
- [x] 3.4 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Xano: situação efetiva e ocupação

- [x] 4.1 `situacao_efetiva` com `check_in_em`, `fim` e `checkin_depois_minutos` (D2), e os chamadores `minhas_reservas` e `reservas_unidade` atualizados. Verificação: validação do MCP e uma tabela no `design.md` com os limites (`agora == fim_janela` ainda é CONFIRMADA; `agora == fim` com check-in já é CONCLUIDA).
- [x] 4.2 Trocar o predicado de ocupação (D2) em todos os pontos, partindo de `grep '"CONFIRMADA"' xano/`: `criar_reserva`, `entrar_fila` (dois), `confirmar_fila`, `buscar_espacos`, `processar_fila` e `exigir_limite_ativas`, cada um lendo `checkin_depois_minutos` com a precondição do bootstrap. Verificação: validação do MCP e o `grep` final listado no relatório do grupo, sem predicado antigo.
- [x] 4.3 `selecionar_reservas_a_cancelar`: lê `checkin_depois_minutos` da configuração com a precondição do bootstrap. No modo `espaco`, a NAO_COMPARECEU efetiva não conta como em andamento e não é cancelada (D2). Verificação: validação do MCP e `impacto_reservas` sem mudança de assinatura.
- [x] 4.4 Revisão do guardian do grupo 4 antes de marcar as tarefas.

## 5. Xano: vencimentos, faltas e penalidades

- [x] 5.1 Criar `registrar_falta` (D4) e a geração da penalidade com encadeamento (D5), com o `REGISTRAR_FALTA` e o `APLICAR_PENALIDADE` usando `|set`. Verificação: validação do MCP.
- [x] 5.2 Encerramento das entradas de fila do penalizado quando a penalidade nasce em vigor (D7), com um `ENCERRAR_FILA` de motivo `PENALIDADE` e ator vazio. Verificação: validação do MCP.
- [x] 5.3 Criar `processar_vencimentos_usuario` (D3), com ordenação pelo instante real e o `MARCAR_NAO_COMPARECEU` e o `CONCLUIR_RESERVA`. Verificação: validação do MCP.
- [x] 5.4 `processar_vencimentos`: lote global por usuário e `CUMPRIDA`, na ordem do D3, com `processar_fila` por último. `aplicar_vencimentos` ganha o input opcional `usuario_id`. Atualizar os comentários. Verificação: validação do MCP.
- [x] 5.5 Criar `penalidade_em_vigor` (D6), com o fim da cadeia contígua. Verificação: validação do MCP.
- [x] 5.6 Revisão do guardian do grupo 5 antes de marcar as tarefas.

## 6. Xano: rotas

- [x] 6.1 `cancelar_reserva` na ordem do D8: recusa depois do início e depois do check-in, `aceitar_falta`, `requer_confirmacao` sem gravar, `USUARIO_TARDIO` só na `CONFIRMADA` e `registrar_falta`. Verificação: validação do MCP.
- [x] 6.2 Pontos de extensão de penalidade em `criar_reserva`, `entrar_fila` e `confirmar_fila`: faxina com o `usuario_id`, `processar_vencimentos_usuario` depois da trava e recusa com `penalidade_em_vigor`. Os comentários da C10 ficam resolvidos. Verificação: validação do MCP.
- [x] 6.3 Criar `fazer_checkin` (POST, grupo `reservas`) conforme a spec `comparecimento` e o D8. Verificação: validação do MCP e busca de homônimos em `xano/api`.
- [x] 6.4 `minhas_reservas`: campos do D8 (`cancelavel`, `cancelamento_gera_falta`, check-in, janela e falta). `reservas_unidade`: situações `CONCLUIDA` e `NAO_COMPARECEU`, `CONFIRMADA` sem as vencidas e `check_in_em`. Verificação: validação do MCP.
- [x] 6.5 Criar `minhas_faltas` (GET, grupo `reservas`) com a faxina do usuário. Verificação: validação do MCP e busca de homônimos.
- [x] 6.6 Criar `penalidades` (GET) e `anular_penalidade` (POST) no grupo `contas`, conforme o D6 e o D8, com a antecipação e o `ANULAR_PENALIDADE`. Verificação: validação do MCP e busca de homônimos.
- [x] 6.7 Revisão do guardian do grupo 6 antes de marcar as tarefas.

## 7. Publicação e testes do backend

- [x] 7.1 Publicar em duas etapas, cada uma com `xano workspace push --dry-run`, o resultado mostrado ao usuário e a aprovação explícita dele:
  1. as tabelas, a configuração e o `bootstrap`, sem nenhuma função ou rota que leia os parâmetros novos;
  2. rodar o `bootstrap` e só então publicar as funções e as rotas.

  Conferir os cinco padrões em `parametros_GET`, e que `comparecimento_desde` foi gravado e não muda numa segunda execução do `bootstrap`. Verificação: saídas dos dry-runs aprovadas e o resultado das duas execuções.
- [x] 7.2 Reservas antigas (decisão 20): sem migração de dados. Antes e depois da primeira faxina, contar as `CONFIRMADA` que começaram antes do marco e conferir que nenhuma mudou de situação nem gerou falta. Verificação: as duas contagens iguais e nenhuma falta com `reserva_id` dessas reservas.
- [x] 7.3 Preparar o cenário de teste: unidade, tipos com duração mínima de 10 minutos e antecedência mínima 0, espaços e contas de aluno, professor, coordenador e dois admins. Usar parâmetros curtos para a janela (por exemplo, 1 e 1 minuto) e a duração da penalidade, e restaurá-los no fim. Verificação: ids registrados no log de teste.
- [x] 7.4 Testes de check-in e janela: abertura e fechamento exatos, 1 minuto antes e depois, reserva mais curta que a janela, pendente recusada, aprovada perto do início, repetido, de outra pessoa e reserva das 08h00 e das 22h00 às 22h40. Verificação: log com o resultado de cada caso.
- [x] 7.5 Testes de não comparecimento e conclusão: situação efetiva antes da gravação; horário liberado com sobreposição parcial (conflito, busca e limite de ativas); confirmada sem check-in dentro da janela ainda ocupando; desativação permitida depois da janela e recusada com check-in; gravação com o instante real e a auditoria. Verificação: log com consultas e registros de auditoria.
- [x] 7.6 Testes de cancelamento: exatamente no prazo (sem falta), 1 minuto depois sem confirmar (reserva igual, sem `CANCELAR_RESERVA` nem falta dela, resposta 200 com `requer_confirmacao`), confirmado (falta), confirmado ainda no prazo (sem falta), pendente tardia sem falta, depois do início, depois do check-in, e cancelamento tardio simultâneo à desativação. Verificação: log.
- [x] 7.7 Testes de penalidade:
  - segunda falta (geração);
  - limite exato da janela e 1 minuto além;
  - falta já usada;
  - encadeamento de três;
  - falta gravada depois do vencimento;
  - criação, entrada e confirmação de fila recusadas com a mensagem da cadeia;
  - fim exato;
  - reserva existente mantida;
  - entradas `AGUARDANDO` e `NOTIFICADA` encerradas com a vaga passada ao próximo, incluindo filas de intervalos sobrepostos.

  Verificação: log com as penalidades e a auditoria.
- [x] 7.8 Testes de anulação:
  - com parecer;
  - sem parecer e com 501 caracteres;
  - de uma cumprida e de uma já anulada;
  - da própria penalidade;
  - por coordenador;
  - duas anulações simultâneas;
  - antecipação simples e limitada pela anterior;
  - duração preservada após mudar o parâmetro;
  - faltas que não voltam a contar.

  Verificação: log com `ANULAR_PENALIDADE` conferido.
- [x] 7.9 Testes de concorrência e volume:
  - check-in contra a gravação de vencimentos perto do fechamento;
  - lote com mais de 50 reservas vencidas, medindo o tempo da faxina;
  - um usuário com 20 vencidas;
  - faxina com falha simulada, com a decisão de penalidade ainda certa.

  Verificação: log com os tempos registrados no `design.md`.
- [x] 7.10 Regressão das changes C6 a C9: criação, deslocamento, aprovação, expiração e fila, com os casos principais de cada spec. Verificação: log sem regressões.
- [x] 7.11 Revisão do guardian do grupo 7 antes de marcar as tarefas.

## 8. Reflex

- [x] 8.1 `xano_cliente.py`: `fazer_checkin`, `minhas_faltas`, `listar_penalidades` e `anular_penalidade`, e o `cancelar_reserva` com `aceitar_falta`, sem expor o token. Verificação: `reflex compile --dry` passa.
- [x] 8.2 "Minhas reservas":
  - "Fazer check-in";
  - cancelamento com aviso de falta e o segundo passo em `requer_confirmacao`;
  - selos de check-in, falta, concluída e não compareceu;
  - rótulos em `motivos.py`;
  - seção "Faltas e penalidades" com o destaque da penalidade em vigor.

  Verificação: teste no navegador (Playwright) dos cenários da spec `reservas` (tela) e da seção.
- [x] 8.3 Página "Penalidades": guarda de admin, filtros, faltas de cada penalidade e diálogo "Anular" com parecer obrigatório; item no menu em `layout.py` e rota em `bookingSystem.py`. Verificação: teste no navegador como admin, e coordenador e aluno levados para "Início" ao digitar o endereço.
- [x] 8.4 "Reservas da unidade" com os filtros novos e o check-in na linha; "Parâmetros" com os cinco campos. Verificação: teste no navegador.
- [x] 8.5 Limpeza de estado ao trocar de conta, como na C9 (decisão 22 da C9), para a seção de faltas não mostrar dados da conta anterior. Verificação: teste no navegador com duas contas seguidas.
- [x] 8.6 Revisão do guardian do grupo 8 antes de marcar as tarefas.

## 9. Integração final e limpeza

- [x] 9.1 Fluxo completo no navegador: aluno com duas faltas recebe a penalidade, não consegue reservar, o admin anula e o aluno volta a reservar. Verificação: capturas e o console do navegador sem erros.
- [x] 9.2 Limpeza sem exclusão física: inativar as contas de teste, desativar as unidades e os tipos de teste, restaurar os parâmetros (15, 15, 2, 30 e 7) e parar o Reflex. Fazer o pull final e compará-lo com `./xano`. Verificação: comparação sem diferenças e parâmetros conferidos.
- [x] 9.3 Relatório de revisão final do guardian (MODO REVISÃO FINAL) mostrado ao usuário antes de qualquer commit. Verificação: relatório entregue e aprovação do usuário.

## Workflow follow-up

- O usuário faz os commits e o PR da branch `change/checkin-faltas`. O agente só fornece os comandos.
- Arquivar a change depois da aprovação do usuário.
