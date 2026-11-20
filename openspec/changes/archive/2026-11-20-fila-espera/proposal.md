## Why

Desde a C8, quem pede um horário ocupado e não pode deslocar quem o ocupa recebe só "Horário ocupado". Quando a vaga é liberada (cancelamento, recusa, expiração, deslocamento parcial), ela fica livre para quem chegar primeiro, sem respeitar quem a queria antes nem a prioridade por papel. A §7.4 do `project-overview.md` define a fila de espera para isso: ordem por prioridade e entrada, aviso ao primeiro da fila e vaga retida durante o prazo de confirmação. A C6 e a C8 deixaram os pontos de extensão (vaga retida no conflito, `origem` `FILA`, `criado_em`), e o explore da C8 já decidiu parte das regras (decisões 2 a 6 e 15).

Em 18/11/2026, por causa do prazo de entrega, o roadmap foi replanejado: notificações in-app e contestação de penalidade saíram do escopo da v1. Esta change registra esse replanejamento nos documentos, porque ela é a primeira depois da decisão.

## What Changes

**Entrada na fila**
- Na busca, um espaço ocupado e que o usuário não pode deslocar oferece "Entrar na fila" para exatamente aquele intervalo.
- A entrada valida as mesmas regras da criação de reserva (espaço reservável, papel, regras de horário), menos o conflito e o limite de reservas ativas.
- É recusada quando:
  - o intervalo está livre;
  - o usuário pode deslocar quem ocupa;
  - ele já tem uma entrada ativa igual;
  - ele já tem uma reserva ativa sobreposta naquele espaço;
  - a fila já está fechada.
- **Corte:** `prazo_fila_minutos` (padrão 120) antes do início ou, se o tipo tiver antecedência mínima maior, essa antecedência. Nenhuma confirmação passa do corte.
- **Fechamento da fila** (update de 20/11/2026): o corte menos `tempo_minimo_fila_minutos` (padrão 30). A partir do fechamento, ninguém entra na fila do intervalo, ninguém é avisado e quem aguardava sai da fila. Uma vaga liberada nesse trecho fica livre para reserva direta, em vez de ir para alguém que teria poucos minutos para confirmar.

**Liberação e vaga retida**
- A vaga é liberada quando o intervalo da entrada deixa de ter reserva ativa ou vaga retida sobreposta. O primeiro da fila (maior prioridade e, em empate, quem entrou antes) passa a `NOTIFICADA` e **retém a vaga**. Durante a retenção, a vaga não pode ser reservada diretamente, deslocada nem tomada por outra fila.
- **Prazo para confirmar** (update de 20/11/2026): `prazo_confirmacao_fila_minutos` (padrão 720, ou seja, 12 horas) a partir do aviso, limitado ao corte do intervalo. Assim, a vaga liberada de madrugada não se perde antes de a pessoa acordar. Sem confirmação, a entrada fica `EXPIRADA` e a vaga passa ao próximo.
- **Filas de intervalos sobrepostos:** a retenção vai para a fila cujo primeiro colocado tem maior prioridade e, em empate, entrou antes.
- **Quando a fila anda:** o plano gratuito do Xano não tem tarefas agendadas, então a fila anda nas operações:
  - antes de criar, cancelar, aprovar ou recusar reservas e antes das operações da fila;
  - na própria operação que libera a vaga;
  - ao abrir qualquer página autenticada, quando uma verificação rápida encontrar algo a processar. A rota que alimenta o aviso global roda em todas as páginas, então o Início e "Minhas reservas" estão incluídos.
- A confirmação gera a reserva com origem `FILA`, conferindo de novo as regras e o limite de ativas. Num tipo que exige aprovação para o papel, a reserva nasce `PENDENTE`.
- O usuário pode desistir a qualquer momento: sair da fila enquanto aguarda, ou abrir mão da vaga retida, que passa ao próximo. As duas ações levam à situação `DESISTIU`.
- **Gestão:**
  - desativar, mover ou trocar o tipo de um espaço (e desativar o tipo ou a unidade) encerra as entradas dos espaços afetados;
  - inativar a conta encerra as entradas da pessoa e libera as vagas dela para as filas.

**Reservas e busca**
- A vaga retida ocupa o intervalo na criação de reserva e na busca, e nunca é deslocável.
- A busca indica se o usuário pode entrar na fila do espaço ocupado.

**Telas**
- Seção "Fila de espera" em "Minhas reservas": situação, posição, prazo e as ações Confirmar e Desistir.
- Aviso em todas as páginas autenticadas enquanto houver vaga retida para o usuário.

**Parâmetros e auditoria**
- Três parâmetros em `ConfiguracaoGeral`, inteiros >= 1, gravados pela carga inicial e editáveis só pelo admin principal:
  - `prazo_fila_minutos` (padrão 120): o corte;
  - `prazo_confirmacao_fila_minutos` (padrão 720): o prazo para confirmar;
  - `tempo_minimo_fila_minutos` (padrão 30): o tempo mínimo útil antes do corte.
- Auditoria:
  - `ENTRAR_FILA`, `CONFIRMAR_FILA` e `DESISTIR_FILA` têm o usuário como ator;
  - `NOTIFICAR_FILA`, `EXPIRAR_FILA` e `ENCERRAR_FILA` são do sistema, como a expiração de reservas da C7.

**Replanejamento nos documentos (decisão do usuário em 18/11/2026)**
- `project-overview.md`:
  - **§5:** notificações in-app e contestação de penalidade saem de "Dentro do escopo" e vão para "Fora do escopo (v1)", como evolução;
  - **§6:** os itens afetados são ajustados;
  - **§7.3, §7.6 e §7.11:** o aviso ao usuário passa a ser feito pelas telas ("Minhas reservas" e o aviso global), sem central de notificações;
  - **§7.4:** ganha o corte pela antecedência mínima e o limite inclusivo das 2 horas;
  - **§7.8:** perde a contestação;
  - **§11:** passa a ter a lista nova de changes.
- `domain-model.md`:
  - **§2.11:** ganha o corte pela antecedência mínima;
  - **Contestação e Notificação:** ficam marcadas como fora da v1.

**Fora do escopo**
- **Penalidade:** recusar a entrada ou a confirmação de quem tem penalidade ativa fica para a change de check-in e faltas.
- **Bloqueios:** recusar a entrada sobreposta a um bloqueio e encerrar as entradas no período bloqueado ficam para a change de bloqueios.
- **Gestão:** não há listagem nem gestão da fila para gestores.
- **Avisos:** não há aviso por e-mail, push nem central de notificações. O e-mail de "vaga liberada" (por exemplo, pelo Brevo) fica como trabalho futuro, para o fim do projeto (decisão 28).
- **Fila do mesmo intervalo:** a fila vale para o mesmo espaço e exatamente o mesmo intervalo, sem intervalo "parecido" nem outro espaço.
- **Tempo real:** a fila não anda sem tráfego. É uma limitação aceita do plano gratuito, atenuada pelo processamento ao abrir as telas.

## Capabilities

### New Capabilities
- `fila-espera`: entrada, ordem, liberação, vaga retida, prazo e corte, confirmação, desistência, saída, encerramento pela gestão, momento em que a fila anda, lista do próprio usuário e telas (seção em "Minhas reservas" e aviso global).

### Modified Capabilities
- `reservas`: o conflito passa a contar a vaga retida pela fila, que não é deslocável.
- `busca-espacos`: a vaga retida ocupa o espaço. O espaço ocupado e não deslocável indica se o usuário pode entrar na fila, e a tela oferece "Entrar na fila".
- `aprovacao-reservas`: a gravação da expiração também acontece nas operações da fila e ao abrir as páginas autenticadas, quando houver vencimento a gravar.
- `parametros`: o prazo da fila entra na consulta, na validação, na carga inicial e na tela.
- `auditoria`: as ações da fila, do usuário e do sistema, passam a ser auditadas.

## Impact

- **Papéis afetados:** todos.
  - Aluno, professor, coordenador e admin entram na fila quando não podem deslocar. O aluno sempre entra na fila, porque nunca desloca.
  - Coordenadores e admins só não entram na fila contra reservas de nível menor quando podem deslocá-las.
  - O admin principal ganha o parâmetro.
- **Regras do `project-overview.md` tocadas:**
  - §7.3 (fila só para quem não pode deslocar e vaga retida ocupando o horário);
  - §7.4 (toda a fila);
  - §7.6 (expiração libera a fila);
  - §7.8 (cancelamentos que liberam a vaga);
  - §7.11 e §5 (replanejamento das notificações);
  - §10 (auditoria);
  - §11 (roadmap).
- **Xano:**
  - tabela nova `entrada_fila`;
  - campos `prazo_fila_minutos`, `prazo_confirmacao_fila_minutos` e `tempo_minimo_fila_minutos` em `configuracao_geral`, com a carga inicial e as rotas de parâmetros;
  - rotas novas: entrar na fila, confirmar, desistir e listar as próprias entradas;
  - alterações em `processar_vencimentos`, `criar_reserva` (com as validações extraídas em funções), `cancelar_reserva`, `recusar_reserva`, `buscar_espacos` e `cancelar_reservas`, usada pelas rotas de gestão que cancelam reservas;
  - publicação sempre com dry-run e aprovação.
- **Reflex:**
  - cliente com as rotas da fila;
  - botão "Entrar na fila" na busca;
  - seção "Fila de espera" em "Minhas reservas";
  - aviso no layout comum;
  - campo novo em "Parâmetros".
- **Documentos:**
  - `project-overview.md` (§5, §6, §7.3, §7.4, §7.6, §7.8, §7.11, §10 e §11);
  - `domain-model.md` (§2.11, §2.13 e §2.16 ou equivalentes de contestação e notificação, §2.18 e DER).
- **Dependências:** nenhuma nova. Nenhuma variável de ambiente nova.
