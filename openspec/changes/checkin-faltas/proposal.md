## Why

Hoje uma reserva confirmada nunca termina: ela continua `CONFIRMADA` depois do fim, quem não aparece não sofre consequência e quem desiste a menos de 2 horas do início não consegue cancelar. A vaga fica presa sem uso. A §7.8 do `project-overview.md` define o remédio: check-in numa janela em torno do início, falta para quem não comparece ou cancela tarde, e penalidade de 7 dias para quem acumula 2 faltas em 30 dias, que só o admin anula. As changes C6, C7 e C9 deixaram pendências e pontos de extensão para esta change (§11, item 10).

## What Changes

**Check-in e comparecimento**
- O dono faz check-in de uma reserva `CONFIRMADA` de `checkin_antes_minutos` (padrão 15) antes do início até `checkin_depois_minutos` (padrão 15) depois, limitado ao fim da reserva. A pendente não tem check-in.
- **Não comparecimento:** a confirmada sem check-in quando a janela fecha passa a `NAO_COMPARECEU` e gera falta. A partir daí ela não ocupa mais o horário, não conta no limite de ativas e não impede as ações de gestão (pendência da C6).
- **Conclusão:** a confirmada com check-in passa a `CONCLUIDA` no fim, base das avaliações da C13.
- **Sem tarefa agendada:** as duas transições seguem a regra dos vencimentos da C7. Elas valem nas consultas pela situação efetiva e são gravadas nas operações com o instante real.
- **Reservas antigas:** valem só as reservas que começam a partir do momento em que a regra entra em uso. As anteriores continuam `CONFIRMADA`, sem falta (decisão 20).

**Cancelamento depois do prazo**
- O cancelamento com 2 horas ou mais de antecedência continua igual: sem falta, motivo `USUARIO`.
- Depois do prazo e antes do início, a `CONFIRMADA` pode ser cancelada com o motivo `USUARIO_TARDIO`, que gera falta. Só é aceito com confirmação explícita: sem ela, a reserva não muda e a resposta avisa que vai gerar falta.
- A `PENDENTE` é cancelada até o início sempre sem falta, porque quem a deixa expirar também não leva falta (decisão 2).
- Depois do início, ou depois do check-in, não se cancela.

**Faltas e penalidades**
- Cada não comparecimento ou cancelamento tardio gera uma falta (`NAO_COMPARECIMENTO` ou `CANCELAMENTO_TARDIO`), uma por reserva.
- `faltas_para_penalidade` (padrão 2) faltas sem vínculo em `janela_faltas_dias` (padrão 30) geram uma penalidade de `duracao_penalidade_dias` (padrão 7). As penalidades de um usuário se encadeiam e nunca se sobrepõem.
- **Em vigor:** a penalidade é `ATIVA` e o instante está entre o início e o fim dela. Enquanto isso, o usuário não cria reservas, não entra na fila e não confirma vaga retida (pontos de extensão da C6 e da C9). As reservas já existentes são mantidas.
- **Fila:** quando uma penalidade nasce em vigor, as entradas ativas do usuário na fila ficam `ENCERRADA` e a vaga retida passa ao próximo (decisão 4).
- **Fim e anulação:** a penalidade que termina é gravada `CUMPRIDA`. O admin anula uma penalidade `ATIVA` registrando o parecer, e as penalidades encadeadas depois dela são antecipadas (decisão 1).

**Telas**
- "Minhas reservas":
  - botão "Fazer check-in" durante a janela;
  - cancelamento tardio com aviso de falta;
  - a falta indicada na reserva;
  - seção "Faltas e penalidades".
- **"Penalidades" (nova, só admin):** lista as penalidades com as faltas e permite anular com parecer.
- "Reservas da unidade" ganha os filtros de concluídas e não comparecimento, e mostra o check-in.

**Parâmetros e auditoria**
- Cinco parâmetros novos em `ConfiguracaoGeral`, gravados pela carga inicial e editáveis pelo admin principal: `checkin_antes_minutos`, `checkin_depois_minutos`, `faltas_para_penalidade`, `janela_faltas_dias` e `duracao_penalidade_dias`.
- Auditoria:
  - **pelo dono:** `CHECK_IN` e o cancelamento tardio;
  - **pelo sistema, com ator vazio e o instante real:** `MARCAR_NAO_COMPARECEU`, `CONCLUIR_RESERVA`, `REGISTRAR_FALTA`, `APLICAR_PENALIDADE`, `CUMPRIR_PENALIDADE` e o encerramento de entradas de fila por penalidade;
  - **pelo admin:** `ANULAR_PENALIDADE`.

**Documentos**
- `project-overview.md`: §7.8 (pendente sem falta, cancelamento só antes do início, encerramento das entradas de fila, anulação), §8, §10 e §11.
- `domain-model.md`: §2.9, §2.12, §2.13, §2.18 e o DER (`penalidade.parecer`).

**Fora do escopo**
- Contestação de penalidade pelo usuário (fora da v1).
- Notificações (lembrete de check-in, penalidade aplicada); o usuário vê tudo em "Minhas reservas".
- **Check-in:** não há check-in feito pelo gestor em nome do usuário nem prova de presença (QR code, geolocalização). O check-in é declarado pelo próprio usuário.
- **Saída antecipada:** não há "encerrar antes" de uma reserva em andamento.
- Bloqueios (C11), reserva recorrente (C12) e avaliações (C13), que só usam o que esta change grava.
- Painel e relatórios de faltas.

## Capabilities

### New Capabilities
- `comparecimento`: check-in, janela de check-in, não comparecimento, conclusão, efeitos da situação efetiva sobre a ocupação, o limite e a gestão, e a gravação desses vencimentos.
- `penalidades`: faltas, geração e encadeamento de penalidades, penalidade em vigor e seus efeitos (reserva e fila), cumprimento, anulação pelo admin com antecipação, consulta pelo próprio usuário e pelo admin, e as telas.

### Modified Capabilities
- `reservas`: o cancelamento pelo próprio usuário aceita o tardio com confirmação e falta (só `CONFIRMADA`) e é recusado depois do início e depois do check-in; "Minhas reservas" e a tela mostram check-in, falta e cancelamento tardio.
- `aprovacao-reservas`: a listagem da unidade filtra concluídas e não comparecimento e mostra o check-in.
- `parametros`: os cinco parâmetros novos na consulta, na validação, na carga inicial e na tela.
- `autorizacao`: o menu do admin ganha "Penalidades".
- `auditoria`: (requisitos novos) comparecimento, faltas, penalidades e anulação auditados.

## Impact

- **Papéis afetados:**
  - **todos:** fazem check-in, recebem faltas e penalidades e cancelam tardiamente;
  - **admin:** vê e anula penalidades;
  - **admin principal:** ganha os cinco parâmetros;
  - **coordenador:** vê as novas situações em "Reservas da unidade".
- **Regras do `project-overview.md` tocadas:**
  - §7.8 (inteira);
  - §7.3 (a reserva sem check-in deixa de ocupar);
  - §7.4 (penalidade na entrada e na confirmação da fila, encerramento das entradas);
  - §7.9 (base das reservas concluídas);
  - §8 (vencimentos);
  - §10 (auditoria);
  - §11.
- **Xano:**
  - tabelas novas `falta` e `penalidade`;
  - campo `check_in_em` em `reserva`;
  - cinco campos em `configuracao_geral`, com a carga inicial e as rotas de parâmetros;
  - rotas novas: check-in, faltas e penalidades do usuário, listagem de penalidades e anulação;
  - alterações em `situacao_efetiva`, `processar_vencimentos`, `cancelar_reserva`, `criar_reserva`, `entrar_fila`, `confirmar_fila`, `selecionar_reservas_a_cancelar`, `minhas_reservas`, `reservas_unidade`, `buscar_espacos`, `processar_fila` e `exigir_limite_ativas`;
  - publicação sempre com dry-run e aprovação.
- **Reflex:**
  - cliente com as rotas novas;
  - "Minhas reservas" com check-in, cancelamento tardio e a seção de faltas e penalidades;
  - página "Penalidades" no menu do admin;
  - filtros novos em "Reservas da unidade";
  - campos novos em "Parâmetros".
- **Dependências:** nenhuma nova. Nenhuma variável de ambiente nova.
