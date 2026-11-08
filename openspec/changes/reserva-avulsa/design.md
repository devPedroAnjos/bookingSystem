## Context

Motivação e escopo: ver `proposal.md`. As decisões do explore estão no `decisions-log.md`.

Estado atual que molda a solução:
- **Concorrência:** o Xano deste projeto não tem isolamento de transação, compare-and-set nem `direct_query`. A única exclusão mútua comprovada é a trava por linha `travar_governanca`, que precisa ser a primeira instrução do `db.transaction` (memória do projeto, C2 D3). Todas as rotas de gestão que agora passam a cancelar reservas já rodam dentro dela.
- **Funções prontas da C4 e da C5**, que recebem registros já carregados:
  - `disponibilidade_espaco` (espaço, unidade, tipo e completude das regras);
  - `tipo_com_regras`;
  - `regra_do_papel` (pode reservar e exige aprovação; regra fixa para coordenador e admin);
  - `validar_horario_reserva` (dias, horário, granularidade, duração e antecedência, com o `agora` injetado);
  - `obter_configuracao_horario` (granularidade e dias).
- **Busca:** `buscar_espacos` converte data e horas inline (regex, `to_timestamp` em America/Sao_Paulo e volta da data para recusar datas inexistentes). A criação de reserva precisa da mesma conversão.
- **Reflex:** um cliente único (`xano_cliente.py`), uma URL base por grupo de API vinda do `.env` e o token no State do servidor. O padrão de diálogo é `dialogo(..., limpar_ao_enviar=False)` com `erro_dialogo`. `tratar_erro_api` manda para o início em 403, então recusas de negócio que o usuário deve ler na mesma tela usam 400.
- **Lições de Xano** (memória do projeto, C5 decisions-log 22 a 24):
  - comparação frouxa com `null`: usar `is_null`;
  - filtros e operadores dentro de literal de objeto: calcular antes ou usar cadeia de `|set`;
  - `&&` com `== true` no `value` de variável: usar `conditional`;
  - nomes de rota únicos no workspace;
  - push com `--force` só no terminal não interativo.

## Goals / Non-Goals

**Goals:**
- Nenhuma ocupação ativa sobreposta no mesmo espaço, sob requisições simultâneas, por meio da trava de governança.
- Uma única função de criação, com pontos de extensão explícitos para penalidade (C9), bloqueio (C10) e vaga retida e deslocamento (C8).
- Uma única função de cancelamento em lote, usada por inativação de conta e pelas cinco ações de gestão.
- Mesma conversão de horário na busca e na reserva.
- Datas e horas exibidas no fuso de São Paulo sem acrescentar dependência ao Reflex.

**Non-Goals:**
- Paginação de "Minhas reservas" e da busca.
- Impedir que um usuário reserve espaços diferentes no mesmo horário. O domínio não proíbe; o limite por tipo é a única restrição.
- Tarefas agendadas: nenhuma nesta change (a expiração de pendentes e a marcação de não comparecimento são da C7 e da C9).

## Decisions

### D1. Tabela `reserva` (subconjunto do DER)

Campos criados nesta change, com os nomes do DER:

| Campo | Tipo | Observação |
|---|---|---|
| `usuario_id` | int, referência a `usuario` | dono da reserva |
| `espaco_id` | int, referência a `espaco` | |
| `inicio`, `fim` | timestamp | instantes absolutos; as regras são avaliadas em America/Sao_Paulo |
| `status` | enum `PENDENTE`, `CONFIRMADA`, `CONCLUIDA`, `NAO_COMPARECEU`, `CANCELADA`, `RECUSADA`, `EXPIRADA` | o enum completo do DER, para as próximas changes não alterarem o tipo |
| `nivel_prioridade` | int | cópia do nível do papel na criação (1, 2 ou 3) |
| `origem` | enum `DIRETA`, `FILA`, `RECORRENTE` | só `DIRETA` nesta change |
| `criado_em` | timestamp | instante do backend; desempate da C8 |
| `cancelado_por_id` | int?, referência a `usuario` | quem executou a ação que cancelou |
| `cancelado_em` | timestamp? | |
| `motivo_cancelamento` | enum? `USUARIO`, `USUARIO_TARDIO`, `BLOQUEIO`, `PRIORIDADE`, `SERIE`, `CONTA_INATIVADA`, `ESPACO_INDISPONIVEL` | os cinco do DER mais os dois desta change |
| `motivo_detalhe` | text? | código do motivo da desativação (D17), só em `ESPACO_INDISPONIVEL` |
| `motivo_descricao` | text? | descrição digitada quando o motivo é `OUTRO` |

- **Índices:** `espaco_id` com `inicio` (busca de conflito e cancelamento por espaço) e `usuario_id` (minhas reservas, limite e inativação).
- **Ficam para as próximas changes:** `serie_id` (C11), `decidido_por_id`, `decidido_em` e `motivo_recusa` (C7), `deslocada_por_reserva_id` (C8), `bloqueio_id` (C10) e `check_in_em` (C9).
- **Divergências do DER, registradas no `domain-model.md` nesta change:**
  - dois valores novos em `motivo_cancelamento`: `CONTA_INATIVADA` (explore D5) e `ESPACO_INDISPONIVEL` (explore D6);
  - dois campos novos, `motivo_detalhe` e `motivo_descricao`, para mostrar ao usuário por que o espaço ficou indisponível (D17);
  - os campos acima entram de forma incremental, conforme a regra de desenvolvimento do projeto.
- **Alternativa descartada:** reaproveitar `BLOQUEIO` para os cancelamentos automáticos. O motivo ficaria enganoso, e a C10 usará `BLOQUEIO` com `bloqueio_id` preenchido.

### D2. Grupo de API `reservas` e nomes de rota

Grupo novo `reservas`, com URL base em `XANO_API_RESERVAS_URL` no `.env`. As rotas usam nomes únicos no workspace, porque o CLI casa rotas sem guid pelo nome e pelo verbo:

| Rota | Verbo | Quem | O que faz |
|---|---|---|---|
| `criar_reserva` | POST | conta ativa | cria a reserva avulsa (D4) |
| `cancelar_reserva` | POST | dono da reserva | cancela dentro do prazo (D6) |
| `minhas_reservas` | GET | conta ativa | lista as reservas do usuário (D9) |
| `impacto_reservas` | GET | gestor, no escopo da ação | conta as reservas que uma ação cancelaria (D8) |

**Alternativa descartada:** pôr as rotas no grupo `espacos`, para não criar outra variável de ambiente. A reserva é a área central do domínio, e as changes C7 a C11 acrescentam rotas a ela.

### D3. Conversão do horário pedido (função compartilhada)

Uma função nova, `converter_horario_pedido`, recebe data (AAAA-MM-DD) e horas de início e fim (HH:MM) e devolve os instantes de início e fim.
- **Validação:** a mesma regex que a busca usa hoje, a conversão com `to_timestamp:"America/Sao_Paulo"` e a volta da data para recusar datas inexistentes (por exemplo, 30/02).
- **Uso:** `buscar_espacos` passa a chamá-la no lugar do bloco inline, e `criar_reserva` a usa também.
- **Erros:** as mensagens de formato continuam as da busca.

**Alternativa descartada:** a reserva receber instantes prontos do Reflex. O Reflex teria de converter fuso, o que reimplementa regra no frontend e exige uma dependência de fuso no Windows.

### D4. Criação da reserva: ordem das verificações

**Fora da trava** (barato e sem leitura de estado mutável): formato do pedido e conversão (D3).

**Dentro de `db.transaction`**, com `travar_governanca` como primeira instrução:
1. `usuario_ativo` (conta ativa e papel atual).
2. Releitura do espaço, da unidade, do tipo, das linhas de `regra_papel` do tipo e de `obter_configuracao_horario`.
3. `disponibilidade_espaco`: espaço não reservável (ou inexistente) é recusado com "Este espaço não está disponível para reserva.", com a mesma mensagem nos dois casos.
4. `regra_do_papel`: sem permissão, a recusa é "Seu papel não pode reservar este tipo de espaço.".
5. `validar_horario_reserva` com `agora` lido dentro da trava. Fora das regras, a recusa lista os motivos em português.
6. *(Ponto de extensão C9: penalidade ativa.)*
7. Limite de reservas ativas (D5).
8. *(Ponto de extensão C10: bloqueio ativo sobreposto.)*
9. Conflito (D7). *(Ponto de extensão C8: vaga retida pela fila e deslocamento por prioridade.)*
10. Gravação: `status` `PENDENTE` se a regra do papel exige aprovação, senão `CONFIRMADA`; `nivel_prioridade` pelo papel (`ALUNO` 1, `PROFESSOR` 2, `COORDENADOR` e `ADMIN` 3); `origem` `DIRETA`; `criado_em` agora.
11. Auditoria `CRIAR_RESERVA` (D11).

**Sobre a ordem:**
- Todas as recusas são 400, com uma mensagem só, na ordem acima. O usuário corrige primeiro o que é mais estrutural.
- O conflito vem por último porque é o único que depende de outras reservas.

**Alternativa descartada:** checar o conflito fora da trava e só gravar dentro dela. Isso abre a corrida que a §7.3 proíbe.

### D5. Limite de reservas ativas por tipo

Conta as reservas do usuário com `status` `PENDENTE` ou `CONFIRMADA`, `fim` maior que o agora e espaço cujo tipo **atual** é o tipo do espaço pedido. A nova reserva é recusada quando a contagem já é igual ao `max_reservas_ativas_usuario` do tipo ("Você já tem o máximo de N reservas ativas neste tipo de espaço.").
- **`fim > agora`:** até a C9, reservas passadas continuam `CONFIRMADA`. Sem esse filtro, o usuário ficaria bloqueado para sempre (explore D3).
- **Tipo atual do espaço:** trocar o tipo de um espaço cancela as reservas dele (D10), então o tipo atual é sempre o mesmo da criação para as reservas ativas.

### D6. Cancelamento pelo próprio usuário

A rota `cancelar_reserva` roda dentro da trava:
1. Relê a reserva. Reserva de outra pessoa ou inexistente dá a mesma recusa, "Reserva não encontrada.".
2. Recusa reserva que não está `PENDENTE` ou `CONFIRMADA` ("Esta reserva não está ativa.").
3. Lê o prazo de cancelamento direto de `configuracao_geral`, com precondição de valor preenchido (D12).
4. Aceita só se `inicio >= agora + prazo × 60000`, comparando em milissegundos, sem truncar em minutos. **Exatamente no limite** (por exemplo, às 12h00 para uma reserva das 14h00) é aceito, porque a §7.8 diz "até 2 horas antes". Depois do prazo, a recusa é "O cancelamento sem penalidade é permitido até N minutos antes do início."
5. Grava `CANCELADA`, `USUARIO`, quem cancelou e quando, e a auditoria `CANCELAR_RESERVA`.

### D7. Conflito de horário

Uma reserva conflita quando é do mesmo espaço, está `PENDENTE` ou `CONFIRMADA` e `existente.inicio < novo.fim` e `novo.inicio < existente.fim`.
- Reservas encostadas (uma termina às 14h00 e a outra começa às 14h00) não conflitam.
- A consulta usa o índice por espaço e início, dentro da trava.
- A mensagem é "Horário ocupado: já existe uma reserva neste espaço nesse intervalo.", sem identificar quem ocupa.

### D8. Impacto antes das ações de gestão

A rota `impacto_reservas` recebe um só destes alvos: `espaco_id`, `tipo_espaco_id`, `unidade_id` ou `usuario_id`.
- **Devolve:** `reservas` (quantas seriam canceladas) e, para os alvos de espaço, tipo e unidade, `em_andamento_ate` (horário de fim, no fuso de São Paulo, da última reserva confirmada em andamento que hoje impediria a ação, ou vazio).
- **Autorização:** a mesma da ação correspondente:
  - espaço: gestor com escopo na unidade do espaço;
  - tipo e unidade: admin;
  - conta: as mesmas regras de quem pode inativar (`autorizar_sobre_conta`).
- **Execução:** é só leitura, sem trava, e usa a mesma seleção do cancelamento em lote (`selecionar_reservas_a_cancelar`, D10), no modo da ação correspondente (conta para `usuario_id`, espaço para os demais). O número é informativo; a ação recalcula tudo dentro da trava.
- **Pedido inválido:** nenhum alvo ou mais de um alvo é recusado com 400. Um `espaco_id` inexistente pedido por coordenador recebe a mesma recusa de acesso negado de um espaço de outra unidade, como nas rotas de gestão de espaços.
- **No Reflex:** o diálogo de cada ação chama esta rota ao abrir.
  - Com `em_andamento_ate`, o diálogo avisa que a ação será recusada até aquele horário.
  - Sem ele, o diálogo avisa quantas reservas serão canceladas.
  - Na edição de espaço, o aviso vale só se o tipo mudar: "Trocar o tipo cancela N reservas".

**Alternativa descartada:** acrescentar contagens às listagens `geridos`, `tipos`, `geridas` e `usuarios`. Pesaria todas as listagens para um dado usado só no diálogo, e ficaria desatualizado entre a listagem e a confirmação.

### D9. Minhas reservas

A rota `minhas_reservas` devolve as reservas do usuário, ordenadas pelo início, da mais recente para a mais antiga. Cada item traz:
- id;
- espaço (nome e código);
- unidade (nome) e tipo (nome);
- início e fim, como instantes e também formatados no fuso de São Paulo (`data` AAAA-MM-DD, `hora_inicio` e `hora_fim` HH:MM), por uma função `formatar_reserva` que a busca e o impacto também podem usar;
- situação, motivo de cancelamento e, em `ESPACO_INDISPONIVEL`, o código do motivo da desativação e a descrição de "Outro" (D17);
- `pode_cancelar`, calculado pelo backend com o prazo atual e a mesma comparação em milissegundos do D6. É só usabilidade; a rota de cancelar revalida.

**Na tela:**
- "Próximas" mostra as reservas pendentes e confirmadas que ainda não terminaram, da mais próxima para a mais distante.
- "Histórico" mostra as demais.

**A formatação no backend:**
- evita levar a regra de fuso ao Reflex;
- evita a dependência `tzdata` no Windows;
- segue o padrão de o Xano ser a fonte de verdade do fuso.

### D10. Cancelamento em lote

Uma função nova, `cancelar_reservas`, é chamada dentro da transação e da trava das rotas que já existem.
- **Entradas:** alvo (lista de `espaco_id` ou um `usuario_id`), motivo, código e descrição do motivo da desativação (só no modo espaço, D17), ator e agora.
- **Seleção compartilhada:** a escolha fica numa função só de leitura, `selecionar_reservas_a_cancelar`, com dois modos. A consulta de impacto (D8) usa a mesma função, e assim o aviso e a ação nunca divergem na regra.
  - **Modo conta** (alvo `usuario_id`): reservas `PENDENTE` ou `CONFIRMADA` com `inicio > agora`. A reserva em andamento fica de fora e continua (explore D5).
  - **Modo espaço** (alvo lista de espaços): reservas `PENDENTE` ou `CONFIRMADA` com `fim > agora`, exceto as `CONFIRMADA` em andamento (`inicio <= agora < fim`). A função também devolve `em_andamento_ate`, o maior fim entre as confirmadas em andamento.
- **Recusa por reserva em andamento** (explore D6): no modo espaço, a rota de gestão chama a seleção dentro da trava, **antes** de gravar qualquer coisa. Se houver confirmada em andamento, a ação inteira é recusada com 400 e nada muda:
  - espaço: "Há uma reserva em andamento neste espaço até HH:MM. Tente depois que ela terminar.";
  - tipo e unidade: "Há N reserva(s) em andamento nos espaços afetados; a última termina às HH:MM. Tente depois que elas terminarem.".
- **Efeito**, quando não há recusa: grava `CANCELADA`, o motivo, `cancelado_por_id` (o ator) e `cancelado_em`. Gera um `CANCELAR_RESERVA` por reserva (D11). Devolve a quantidade.

| Rota | Alvo | Modo | Motivo |
|---|---|---|---|
| `inativar` (conta) | `usuario_id` | conta: nunca recusa; a reserva em andamento continua | `CONTA_INATIVADA` |
| `desativar_espaco` | o espaço | espaço: recusa com reserva confirmada em andamento | `ESPACO_INDISPONIVEL` |
| `editar_espaco`, só quando o tipo muda | o espaço | espaço | `ESPACO_INDISPONIVEL` |
| `mover_espaco` | o espaço | espaço | `ESPACO_INDISPONIVEL` |
| `desativar_tipo` | todos os espaços do tipo, ativos ou não | espaço | `ESPACO_INDISPONIVEL` |
| `desativar` (unidade) | todos os espaços da unidade | espaço | `ESPACO_INDISPONIVEL` |

**Detalhes:**
- Reservas com `fim <= agora` nunca são tocadas; o fechamento delas é da C9.
- **Reserva pendente** cujo início já passou não impede a ação, porque não foi aprovada e vai expirar na C7. No modo espaço, ela é cancelada junto com as futuras.
- A mensagem de sucesso da ação passa a dizer quantas reservas foram canceladas, por exemplo "Espaço desativado. 3 reservas canceladas."
- Reativações não restauram reservas.
- **Escopo:** admin e coordenador seguem a mesma regra; ninguém encerra uma reserva em andamento. O escopo de cada ação não muda (o coordenador só age nos espaços das unidades que coordena; tipos, unidades e mover continuam só do admin).
- **Na edição de espaço,** a checagem só acontece quando o tipo muda. Editar outros campos nunca é recusado por reserva.

### D11. Auditoria

| Ação | Entidade | Ator | Unidade | Dados |
|---|---|---|---|---|
| `CRIAR_RESERVA` | `reserva` | o dono | unidade do espaço | depois: espaço, início, fim, situação |
| `CANCELAR_RESERVA` | `reserva` | quem cancelou (o dono, ou quem executou a ação de gestão ou a inativação) | unidade do espaço | antes: situação; depois: `CANCELADA` e o motivo |

- **Unidade do registro:** a unidade do espaço no momento do cancelamento. Em `mover_espaco`, o cancelamento acontece antes da mudança, então o `CANCELAR_RESERVA` leva a unidade de origem.
- **Um registro por reserva** cancelada em lote, na mesma transação da ação, como a C2 já faz com `REMOVER_COORDENACAO` por unidade perdida. Isso substitui a ideia do explore (D9) de listar os ids dentro do registro da ação, porque fica mais fácil consultar o histórico de uma reserva.
- Recusas não geram registro.
- A listagem "Minhas reservas", a busca e a consulta de impacto não são auditadas.
- `DESATIVAR_ESPACO`, `DESATIVAR_TIPO_ESPACO`, `DESATIVAR_UNIDADE` e `INATIVAR_CONTA` passam a trazer o código e a descrição do motivo (D17).

### D12. Parâmetro prazo de cancelamento

- **Campo novo:** `prazo_cancelamento_minutos` em `configuracao_geral`, com o nome do DER. O `bootstrap` grava 120 quando estiver vazio.
- **Edição:** entra no GET e no POST de `parametros` como os demais limites, inteiro a partir de 1, e é auditado por `ALTERAR_PARAMETROS`.
- **Leitura:** `cancelar_reserva` e `minhas_reservas` leem o campo direto da tabela, com precondição de valor preenchido ("execute o bootstrap"). `obter_configuracao` e `obter_configuracao_horario` não mudam, pela mesma razão da C5 D18: exigir o campo novo faria as rotas da C1 à C5 falharem entre o push e o bootstrap.
- **Na C9:** o mesmo parâmetro separa o cancelamento sem falta do tardio.

### D13. Busca com ocupação

Com data e horário informados, `buscar_espacos` faz uma consulta extra:
- busca as reservas `PENDENTE` ou `CONFIRMADA` que se sobrepõem ao intervalo, entre os espaços do resultado;
- marca cada espaço com `ocupado` (verdadeiro ou falso), sem dizer quem ocupa.

A conversão do horário passa a usar a função da D3. Sem horário, nada muda.

**Na tela:**
- cada resultado mostra "Livre" ou "Ocupado" ao lado de "dentro das regras";
- o botão "Reservar" aparece quando o espaço está livre e dentro das regras;
- o aviso fixo passa a ser "A disponibilidade é conferida de novo no momento da reserva.".

### D14. Reflex

- **Cliente:** `criar_reserva`, `cancelar_reserva`, `minhas_reservas` e `impacto_reservas`, com `_RESERVAS = "XANO_API_RESERVAS_URL"`.
- **Busca:** o `BuscaState` guarda o último pedido (data e horas). "Reservar" abre um diálogo de confirmação com espaço, unidade, data, horário e "exige aprovação". Ao confirmar:
  - sucesso: o diálogo fecha e aparece a mensagem ("Reserva confirmada." ou "Reserva criada e aguardando aprovação.");
  - recusa: o erro fica dentro do diálogo;
  - a busca é refeita para atualizar livre e ocupado.
- **Página `/minhas-reservas`:** usa `ReservasState`, com guarda de sessão para todos os papéis. Mostra as listas "Próximas" e "Histórico" e o botão "Cancelar" com confirmação quando `pode_cancelar`.
- **Avisos de impacto (D8):**
  - espaços: um diálogo de confirmação novo para desativar (hoje a ação é direta) e avisos nos diálogos de editar e mover;
  - tipos: aviso no diálogo de desativar;
  - unidades: aviso no formulário de desativar;
  - contas: aviso no diálogo de inativar, compartilhado pelas páginas de usuários e administradores.
- **Formato do aviso:**
  - sem reserva em andamento: "N reserva(s) serão canceladas";
  - com reserva confirmada em andamento (ações de espaço, tipo e unidade): "Há reserva em andamento até HH:MM; a ação só será aceita depois desse horário". O botão de confirmar continua disponível, e o backend decide.
- **Motivo (D17):** caixa de seleção com o campo "Descreva o motivo" para "Outro" nos diálogos de desativar espaço, tipo e unidade e no de inativar conta, que hoje tem um campo de texto livre. Em "Minhas reservas", o motivo da desativação aparece ao lado de "espaço indisponível".
- **Parâmetros e menu:** o campo de prazo de cancelamento entra na página de parâmetros. O menu ganha "Minhas reservas" para todos, logo depois de "Buscar espaços".

### D15. Documentos

- **`domain-model.md`:**
  - §2.9: corrigir as regras estruturais, que ainda dizem "dia útil" e "múltiplos de 10 minutos" desde a C5; registrar os motivos novos e o cancelamento por indisponibilidade;
  - §2.2, §2.4, §2.6 e §2.1: o efeito da desativação e da inativação sobre as reservas;
  - §2.18: o prazo de cancelamento;
  - DER: `RESERVA` (motivos novos, `motivo_detalhe` e `motivo_descricao`) e `CONFIGURACAO_GERAL`;
  - §2.1, §2.2, §2.4 e §2.6: o motivo obrigatório da lista ao inativar conta e ao desativar espaço, tipo e unidade.
- **`project-overview.md`:**
  - §7.8: o prazo parametrizado;
  - §11: item 6 identificado como C6, com as pendências passadas às changes seguintes.

### D16. Pendências para as próximas changes

| Change | Pendência |
|---|---|
| C7 | Aprovar, recusar e expirar pendentes; listagem de reservas da unidade; mover espaço muda o aprovador das pendentes (as pendentes de espaço movido já são canceladas nesta change). |
| C8 | Vaga retida pela fila e deslocamento por prioridade no ponto de extensão do conflito; `nivel_prioridade` e `criado_em` já gravados. |
| C9 | Penalidade ativa no ponto de extensão; cancelamento tardio com falta usando o mesmo prazo; fechamento de reservas passadas; a regra "em andamento" do D10 passa a considerar o check-in, se a C9 mudar o que conta como reserva em uso. |
| C10 | Bloqueio ativo no ponto de extensão; cancelamento por bloqueio com `bloqueio_id`. |
| C13 | Notificar os cancelamentos automáticos (`CONTA_INATIVADA`, `ESPACO_INDISPONIVEL`). |

### D17. Motivo das desativações e da inativação de conta

Ao desativar um espaço, um tipo ou uma unidade, e ao inativar uma conta, o gestor escolhe o motivo numa caixa de seleção (decisions-log 20 a 22). Mover espaço e trocar o tipo não pedem motivo.

| Lista | Códigos |
|---|---|
| Desativação de espaço, tipo ou unidade | `MANUTENCAO_REFORMA`, `INFRAESTRUTURA`, `SEGURANCA_INTERDICAO`, `EQUIPAMENTOS_INDISPONIVEIS`, `MUDANCA_DE_USO`, `BAIXA_UTILIZACAO`, `ENCERRAMENTO_ATIVIDADES`, `OUTRO` |
| Inativação de conta | `DESLIGAMENTO_INSTITUICAO`, `CONCLUSAO_CURSO`, `TRANCAMENTO_AFASTAMENTO`, `USO_INDEVIDO`, `CONTA_DUPLICADA`, `PEDIDO_TITULAR`, `OUTRO` |

- **Entrada das rotas:** `motivo_codigo` e `motivo_descricao`. A descrição é obrigatória (até 500 caracteres) só com `OUTRO` e é ignorada nos demais.
  - Na `inativar`, isso substitui o campo de texto livre `motivo` da C3, que continua com o limite de 500 caracteres.
  - O cliente Reflex é atualizado na mesma change, porque é o único consumidor.
- **Validação:** uma função `validar_motivo` recebe a lista ("desativacao" ou "conta"), o código e a descrição. Ela recusa código fora da lista e "Outro" sem descrição. É chamada fora da trava, porque só depende da entrada.
- **Onde o motivo fica:**
  - **Auditoria:** nos dados depois de `DESATIVAR_ESPACO`, `DESATIVAR_TIPO_ESPACO`, `DESATIVAR_UNIDADE` e `INATIVAR_CONTA`, com o código e a descrição.
  - **Reservas canceladas por desativação:** `motivo_detalhe` e `motivo_descricao` (D1), mostrados em "Minhas reservas", por exemplo "Cancelada: espaço indisponível (Manutenção ou reforma)".
  - **Reservas canceladas por mudança de unidade ou troca de tipo:** `ESPACO_INDISPONIVEL` sem detalhe (`motivo_detalhe` vazio); `minhas_reservas` devolve o detalhe vazio, e o Reflex mostra só "espaço indisponível".
  - **Reservas canceladas por inativação de conta:** sem detalhe. A spec `situacao-conta` diz que a pessoa inativada não vê o motivo, e uma reativação posterior revelaria o motivo pela reserva.
- **Rótulos:** o backend guarda e valida códigos. O Reflex traduz código em rótulo, como já faz com `MOTIVOS` (disponibilidade) e `MOTIVOS_HORARIO` (busca). As listas do backend e do Reflex mudam juntas.
- **Na tela:**
  - a caixa de seleção vem antes do aviso de impacto, e o campo de descrição aparece com "Outro";
  - nas desativações, o diálogo avisa que o texto de "Outro" fica visível para quem teve a reserva cancelada.
- **Fora desta change:** listas editáveis pelo admin e o motivo da desativação exibido na listagem de gestão.

## Risks / Trade-offs

- **[Trava única serializa reservas e gestão]** → Escala acadêmica e plano Free já limitado a 10 requisições a cada 20 s. As validações de formato e a conversão ficam fora da trava, e a transação lê só o necessário.
- **[Corrida entre criar e desativar]** → As duas rotas usam a mesma trava, e a criação relê espaço, unidade e tipo dentro dela (C4 D13). O teste da tarefa de concorrência dispara as duas ao mesmo tempo.
- **[Pendente ocupa o horário sem prazo até a C7]** → Aceito e documentado no proposal. O próprio usuário pode cancelar dentro do prazo.
- **[Desativar unidade ou tipo cancela muitas reservas de uma vez]** → O aviso de impacto mostra o número antes da confirmação; a auditoria registra cada reserva. O teste usa um volume moderado (cerca de 20 reservas) numa só transação.
- **[Unidade ou tipo nunca livres em horário de uso]** → Basta uma reserva confirmada em andamento em qualquer espaço afetado para recusar a ação. Na prática, o admin desativa fora do horário dos tipos ou num dia sem funcionamento. Sempre existe uma janela diária, porque o fechamento de qualquer tipo é antes da meia-noite. O fechamento emergencial com gente no espaço fica para o bloqueio (C10).
- **[Lições de Xano]** → Objetos montados com valores calculados antes ou com `|set`, `is_null` nas checagens e `conditional` para booleanos compostos. Cada chave que a tela usa é testada em execução, e o pull depois de cada push é comparado.
- **[Histórico sem paginação]** → Uma consulta por tabela, sem consulta por reserva. A paginação fica para quando houver volume.
- **[Fuso perto da meia-noite]** → A conversão é a mesma da busca, já testada na C5 com a virada do dia em São Paulo, e os testes desta change repetem esse caso na criação.

## Migration Plan

1. Push com dry-run e aprovação: tabela `reserva`, campo novo em `configuracao_geral`, funções novas e rotas novas e alteradas.
2. Executar o `bootstrap` pelo CLI, para gravar `prazo_cancelamento_minutos = 120`. A segunda execução não deve alterar nada.
3. Obter a URL base do grupo `reservas` e acrescentar `XANO_API_RESERVAS_URL` ao `.env`, sem imprimir o valor.
4. **Rollback:** as rotas antigas continuam compatíveis, porque só ganham o cancelamento. Desfazer exige novo push com os arquivos anteriores. As reservas gravadas não são apagadas, conforme o domínio.

## Confirmações do apply

Confirmado no Xano Developer MCP (documentação 2.7.1) com arquivos de sonda validados, sem push (tarefa 1.2):

| Item | Sintaxe confirmada | Evidência |
|---|---|---|
| `enum` opcional | `enum? motivo_cancelamento? { values = [...] }` | sonda de tabela válida; `enumx?` recusado no controle negativo |
| `timestamp` opcional | `timestamp? cancelado_em?` | sonda de tabela válida; mesmo padrão de `usuario.aprovado_em` |
| Índice composto | `{type: "btree", field: [{name: "espaco_id"}, {name: "inicio"}]}` | sonda válida; mesmo formato do índice único de `espaco` |
| Grupo de API | arquivo `xano/api/reservas/reservas.xs` com `api_group reservas { canonical = "bookingsystem-reservas" }`; o guid é atribuído pelo Xano no push | documentação `apis` (canonical obrigatório e único na instância); nome do arquivo segue o padrão dos grupos já puxados |
| Situação em lista | `$db.reserva.status in ["PENDENTE", "CONFIRMADA"]` | sonda válida, também combinada com a comparação de `timestamp` na sonda complementar; já em produção em `pedidos_GET` (`papel in $papeis`) |
| Intervalo | `$db.reserva.inicio < $fim && $db.reserva.fim > $inicio` | sonda complementar válida no MCP, com entradas `timestamp` e `fim > $input.inicio` (feita na revisão do guardian); o comportamento em execução é verificado na tarefa 7.3 |
| Contagem | `return = {type: "count"}` | documentação `database` e sonda válida |
| Data e hora em São Paulo | `format_timestamp:"Y-m-d":"America/Sao_Paulo"` e `format_timestamp:"H:i":"America/Sao_Paulo"` | documentação do filtro (formato no padrão PHP, fuso como 2º argumento); `Y-m-d` já em produção na busca |
