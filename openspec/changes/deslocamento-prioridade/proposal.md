## Why

Desde a C6, o conflito de horário é **sempre recusado**, mesmo quando quem pede tem prioridade maior. Um professor que precisa de um laboratório reservado por um aluno com dias de antecedência não tem como obtê-lo pelo sistema. Isso contraria a §7.3 do `project-overview.md`: a prioridade por papel (Coordenador/Admin > Professor > Aluno) deve resolver as disputas de forma determinística e transparente, deslocando a reserva de nível menor quando há tempo para avisar o deslocado. A C6 deixou o ponto de extensão no passo do conflito, e `nivel_prioridade` e `criado_em` já são gravados.

O item 8 do roadmap juntava deslocamento e fila de espera. No explore, a fila foi separada numa change própria (C9), porque toca a liberação de vagas em pelo menos seis rotas. Esta change trata só do deslocamento.

## What Changes

**Deslocamento por prioridade na criação de reserva**
- Quando o pedido conflita com reservas ativas do espaço (situação efetiva da C7), o solicitante pode deslocá-las se, ao mesmo tempo:
  1. todas as reservas conflitantes têm nível de prioridade **estritamente menor** que o do papel atual dele;
  2. a nova reserva e **cada uma das deslocadas** começam a **mais de** `prazo_deslocamento_minutos` (padrão 120) de agora, então uma reserva em andamento nunca é deslocada;
  3. a nova reserva nasce `CONFIRMADA`, isto é, não exige aprovação para o papel dele.
- Se qualquer condição falhar, o comportamento continua o da C6: "Horário ocupado".
- **Confirmação explícita:** sem a confirmação, a criação não grava nada e responde que o pedido deslocaria N reservas, sem dizer de quem. Com a confirmação, cancela as conflitantes e cria a nova na mesma operação atômica. Se o conflito tiver sumido nesse meio-tempo, a reserva é criada normalmente.
- As deslocadas são canceladas **inteiras**, mesmo com sobreposição parcial, com o motivo `PRIORIDADE`, a referência à reserva que as deslocou, o solicitante como autor do cancelamento e sem falta.

**Busca de espaços**
- Com data e horário, cada espaço ocupado indica também se o usuário poderia deslocar a ocupação e quantas reservas seriam deslocadas, sem identificar ninguém. A indicação é informativa: a criação confere tudo de novo.
- Na tela, um espaço ocupado e deslocável oferece "Deslocar e reservar", com um diálogo que avisa quantas reservas serão canceladas.

**Parâmetro**
- `prazo_deslocamento_minutos` (padrão 120, inteiro >= 1) entra em `ConfiguracaoGeral`, gravado pela carga inicial e editável só pelo admin principal na página "Parâmetros".

**Documentação e roadmap**
- §7.3 do `project-overview.md` e §2.9 do `domain-model.md`: o prazo vale para a nova reserva e para cada deslocada.
- §11 do `project-overview.md`: a fila de espera vira o item 9 (C9). Os itens seguintes são renumerados (penalidades C10, bloqueios C11, recorrência C12, avaliações C13, notificações C14, painel C15), e as pendências do explore são registradas.

**Fora do escopo**
- Fila de espera (C9): entrar, ordem, retenção da vaga, liberação, confirmação e desistência. Até a C9, quem não pode deslocar continua recebendo "Horário ocupado", sem opção de fila.
- Notificar o deslocado (C14, notificações). Até lá, ele vê a reserva cancelada por prioridade em "Minhas reservas".
- Penalidade ativa (C10) e bloqueios (C11) nos pontos de extensão da criação.
- Deslocar parte de uma reserva, ou reduzir o horário dela em vez de cancelar.
- Deslocamento feito pela gestão sem criar reserva, e qualquer "prévia" de deslocamento fora da busca e da própria criação.

## Capabilities

### New Capabilities
<!-- nenhuma: o deslocamento é comportamento da criação de reservas -->

### Modified Capabilities
- `reservas`: o requisito de conflito passa a admitir o deslocamento por prioridade, com as três condições, a confirmação e o cancelamento `PRIORIDADE`. "Minhas reservas" já mostra o motivo, e o deslocado vê só o motivo, sem nome.
- `busca-espacos`: o espaço ocupado indica se é deslocável e quantas reservas seriam deslocadas, e a tela oferece "Deslocar e reservar" com confirmação.
- `parametros`: o prazo para deslocar por prioridade entra na consulta, na validação, na carga inicial e na tela.
- `auditoria`: `CRIAR_RESERVA` passa a listar as reservas deslocadas, e cada deslocada gera um `CANCELAR_RESERVA` com o motivo `PRIORIDADE` e o solicitante como ator.

## Impact

- **Papéis afetados:**
  - Professor: desloca reservas de alunos.
  - Coordenador e admin: deslocam reservas de professores e de alunos, em qualquer unidade, porque reservam como qualquer usuário.
  - Aluno: nunca desloca, porque não há nível menor que o dele. As reservas de alunos e de professores podem ser deslocadas com pelo menos o prazo de antecedência.
- **Regras do `project-overview.md` tocadas:** §6, item 5 (disputa de concorrência); §7.3 (deslocamento, as três condições, aviso e confirmação); §7.8 (cancelamento pelo sistema sem falta); §10 (auditoria do deslocamento); §11 (roadmap).
- **Xano:**
  - tabela `reserva`: campo `deslocada_por_reserva_id`;
  - tabela `configuracao_geral`: campo `prazo_deslocamento_minutos`, com a carga inicial e as rotas de parâmetros;
  - rotas alteradas: `criar_reserva` (entrada `deslocar` e resposta de confirmação) e `buscar_espacos` (indicação de deslocável);
  - publicação sempre com dry-run e aprovação.
- **Reflex:**
  - cliente com `deslocar` em `criar_reserva`;
  - busca com "Deslocar e reservar" e diálogo de confirmação;
  - parâmetros com o campo novo.
- **Documentos:** `project-overview.md` (§7.3, §10 e §11) e `domain-model.md` (§2.9 e §2.18, conferindo o DER).
- **Dependências:** nenhuma nova. Nenhuma variável de ambiente nova.
