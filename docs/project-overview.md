# Project Overview — BookingSystem

> Sistema de reserva de espaços (salas de aula, laboratórios, bibliotecas e auditórios) de uma instituição de ensino.
> Projeto acadêmico — Innovation Lab, Faculdade Impacta.
> Equipe: Gustavo Ribeiro de Souza, Leonardo Machado da Silva e Pedro Macena dos Anjos. Professor: Leonardo Bontempo.

---

## 1. Visão geral

O BookingSystem permite que alunos e professores de uma instituição de ensino encontrem espaços disponíveis e façam reservas de forma autônoma, com as regras da instituição aplicadas automaticamente pelo sistema.

A instituição é organizada em **unidades** (campus ou prédio). Cada unidade possui espaços de diferentes **tipos** — sala de aula, laboratório, biblioteca e auditório — e cada tipo possui regras próprias de uso: quem pode reservar, duração mínima e máxima, antecedência, limite de reservas e necessidade de aprovação.

Coordenadores de unidade cuidam dos espaços da sua unidade (cadastro, bloqueios e aprovações). Administradores definem as regras gerais, gerenciam papéis, revisam penalidades e acompanham o uso por meio de painel, relatórios e log de auditoria.

## 2. Problema

Hoje a reserva de espaços depende de contato manual com a coordenação, planilhas ou combinações informais. Isso gera:

- **conflitos de horário** — duas pessoas acreditam ter reservado o mesmo espaço;
- **falta de critério claro** quando um aluno e um professor disputam o mesmo horário;
- **espaços reservados e não utilizados**, sem consequência para quem não comparece;
- **pouca visibilidade** sobre ocupação, cancelamentos e faltas;
- **ausência de rastreabilidade** sobre quem criou, aprovou, cancelou ou bloqueou uma reserva.

## 3. Objetivos

- Permitir que o usuário encontre e reserve um espaço disponível em poucos passos.
- Garantir que **nunca existam duas reservas ativas sobrepostas** para o mesmo espaço.
- Resolver disputas por horário de forma **determinística e transparente**, por nível de prioridade do papel e, em empate, por ordem de chegada.
- Aplicar automaticamente as regras de cada tipo de espaço.
- Reduzir reservas não utilizadas por meio de check-in, fila de espera e penalidades.
- Dar à gestão visibilidade de uso (painel e relatórios) e rastreabilidade completa (log de auditoria).

## 4. Usuários e papéis

| Papel | Nível de prioridade | Responsabilidades principais |
|---|---|---|
| **Aluno** | 1 (menor) | Busca espaços, reserva biblioteca e laboratório, cancela, faz check-in, avalia, entra em fila de espera. |
| **Professor** | 2 | Tudo que o aluno faz, e também reserva sala de aula e auditório, inclusive reserva recorrente de sala de aula. |
| **Coordenador de unidade** | 3 | Cadastra e edita espaços, bloqueia espaços (manutenção, evento, feriado), aprova ou recusa reservas pendentes e aprova cadastros de professor — **somente na(s) própria(s) unidade(s)**. Também pode reservar. |
| **Administrador** | 3 | Define regras por tipo de espaço (os parâmetros gerais, só o principal), cria tipos de espaço, mantém o catálogo de recursos, move espaços entre unidades, gerencia unidades, papéis e coordenações, aprova cadastros de professor e de coordenador, revisa e anula penalidades, bloqueia espaços, acessa painel, relatórios e log de auditoria de todas as unidades. Também pode reservar. |

- **Administradores:** até **3 ativos** (parâmetro), contando o **administrador principal** (o primeiro, criado na instalação). Só o principal cria administradores, do zero ou promovendo um coordenador (que perde as coordenações), rebaixa um administrador secundário (somente a coordenador) e altera os parâmetros gerais. Os secundários gerenciam as demais contas, mas não alteram outros administradores. Ninguém altera o principal pelo sistema.
- **Coordenador:** coordena de **1 a 2 unidades** (parâmetro), e cada unidade tem **no máximo 4 coordenadores** (parâmetro). O administrador age em todas as unidades.
- **Professor:** **pertence a uma unidade**, escolhida no cadastro. Ela serve para aprovação e pertencimento, e só o administrador transfere o professor para outra unidade (o pedido de transferência acontece fora do sistema).
- **Aluno:** pertence à instituição, e não a uma unidade.
- **Reservas:** alunos e professores podem reservar espaços de qualquer unidade.
- **Mudança de papel:** segue a sequência **aluno → professor → coordenador**; coordenador pode voltar a professor, e ninguém volta a ser aluno. Virar coordenador exige escolher as unidades no mesmo ato, e deixar de ser coordenador remove as coordenações. Um administrador secundário só é rebaixado a coordenador; depois disso, pode virar professor pela mudança de papel comum.

## 5. Escopo

### Dentro do escopo (v1)

- Cadastro com e-mail institucional e login.
- Aprovação de cadastro de professor.
- Gestão de unidades, tipos de espaço, espaços e recursos.
- Configuração de regras por tipo de espaço e por papel.
- Busca de espaços disponíveis com filtros (unidade, tipo, data/horário, capacidade, recursos).
- Reserva avulsa e reserva recorrente semanal (apenas sala de aula).
- Controle de concorrência e prioridade entre papéis.
- Fluxo de aprovação de reservas pendentes.
- Fila de espera.
- Cancelamento, check-in, registro de falta e penalidade.
- Contestação de penalidade pelo usuário e decisão pelo administrador.
- Avaliação do uso (nota de 1 a 5 e comentário).
- Notificações dentro do sistema (in-app).
- Painel, relatórios e log de auditoria.

### Fora do escopo (v1)

- Notificação por e-mail, SMS ou push (prevista como evolução).
- Integração com calendário externo (Google/Outlook).
- Login social ou SSO institucional.
- Recuperação de senha por e-mail ("esqueci minha senha"). A pessoa pede a um administrador que redefina a senha.
- Aplicativo mobile nativo.
- Reserva de equipamentos avulsos (apenas de espaços).
- Reserva fora do horário de funcionamento ou em finais de semana.

## 6. Principais funcionalidades

1. **Cadastro e login** — o usuário se cadastra informando nome, e-mail institucional, senha e o tipo de vínculo (aluno, professor ou coordenador). Contas de aluno ficam ativas imediatamente. Contas de professor ficam pendentes até a aprovação de um administrador ou do coordenador da unidade indicada; contas de coordenador, até a aprovação de um administrador. Quem é recusado vê o motivo e pode pedir nova análise.
2. **Busca de espaços** — por unidade, tipo, data, horário, capacidade e recursos; mostra apenas os tipos que o papel do usuário pode reservar.
3. **Verificação de disponibilidade** — o sistema verifica penalidade ativa, bloqueios, conflitos de horário e regras do tipo de espaço antes de aceitar o pedido.
4. **Reserva** — confirmada imediatamente ou criada como pendente quando o tipo exige aprovação para aquele papel.
5. **Disputa de concorrência** — quando o horário está ocupado, o sistema decide entre deslocar a reserva de menor prioridade ou colocar o solicitante na fila de espera (ver seção 7.3).
6. **Reserva recorrente** — professores, coordenadores e administradores podem reservar uma sala de aula semanalmente por um período.
7. **Aprovação** — coordenador aprova ou recusa reservas pendentes (motivo obrigatório na recusa). Sem decisão até o início, a reserva expira.
8. **Cancelamento** — pelo usuário, com regra de prazo; ou pelo sistema, em caso de bloqueio ou de deslocamento por prioridade.
9. **Fila de espera** — o primeiro da fila é avisado quando a vaga é liberada e precisa confirmar dentro do prazo.
10. **Check-in e comparecimento** — o usuário confirma presença numa janela em torno do início. A falta de check-in gera falta.
11. **Penalidade** — o acúmulo de faltas bloqueia novas reservas por um período. O usuário pode contestar e só o administrador pode anular.
12. **Avaliação** — após o uso, nota de 1 a 5 e comentário opcional, visíveis a todos.
13. **Cadastro de espaços e bloqueios** — pelo coordenador, na própria unidade.
14. **Gestão** — regras, papéis, penalidades, painel, relatórios e log de auditoria pelo administrador.

## 7. Regras de negócio e restrições importantes

> Os valores numéricos abaixo são os **valores padrão** definidos pela equipe. Todos são parametrizáveis pelo administrador, salvo quando indicado.

### 7.1 Horário de funcionamento

- Reservas apenas nos **dias de funcionamento**: por padrão, **segunda a sexta-feira** (parâmetro do admin principal).
- Cada tipo de espaço tem horário de abertura e de fechamento. O padrão é **abertura às 08h00** e **fechamento às 22h40**: a reserva começa a partir da abertura e termina no máximo no fechamento, no mesmo dia.
- O fechamento é apenas horário de término: com o padrão, nenhuma reserva pode começar às 22h40 ou depois.
- Os horários de início e fim são múltiplos da **granularidade**: por padrão, **10 minutos** (permite 22h40 e blocos de 50 min). A granularidade é parâmetro do admin principal.
- Todas as regras de horário são avaliadas no fuso **America/Sao_Paulo**.
- Feriados e recessos são tratados como **bloqueios** cadastrados pela coordenação ou administração.

### 7.2 Regras por tipo de espaço e papel

| Tipo de espaço | Duração | Antecedência mínima | Antecedência máxima | Reservas ativas por usuário | Quem pode reservar | Exige aprovação para | Recorrência |
|---|---|---|---|---|---|---|---|
| Biblioteca | 30 a 180 min | 0 min | 7 dias | 2 | Aluno, Professor, Coordenador, Admin | — | Não |
| Laboratório | 30 a 240 min | 0 min | 14 dias | 3 | Aluno, Professor, Coordenador, Admin | **Aluno** | Não |
| Sala de aula | 50 a 300 min | 0 min | 30 dias | 10 | Professor, Coordenador, Admin | — | **Sim** |
| Auditório | 50 a 480 min | 1440 min (1 dia) | 60 dias | 2 | Professor, Coordenador, Admin | **Professor** | Não |

Os quatro tipos funcionam das 08h00 às 22h40. Esses são os valores da carga inicial. O administrador altera, por tipo, todas essas regras, o horário de funcionamento e quem pode reservar ou precisa de aprovação (aluno e professor). Ele pode criar novos tipos de espaço, que só ficam reserváveis depois de receber as regras. Coordenadores e administradores reservam todos os tipos, sem aprovação.

### 7.3 Concorrência e prioridade

- **Nunca** podem existir duas reservas **ativas** (pendente ou confirmada) com horários sobrepostos no mesmo espaço. Sobreposição parcial também é conflito.
- Uma reserva **pendente já ocupa o horário** até o início dela, assim como uma vaga **retida pela fila de espera** (ver seção 7.4). A pendente cujo início chegou sem decisão expirou e não ocupa mais (seção 7.6).
- A prioridade é definida pelo papel: **Coordenador/Admin (3) > Professor (2) > Aluno (1)**.
- Entre papéis de **mesmo nível**, vence **quem reservou primeiro** (data/hora de criação registrada pelo backend).
- **Deslocamento por prioridade:** um solicitante de nível maior pode ocupar um horário já reservado por usuários de nível menor quando:
  1. todas as reservas conflitantes forem de nível estritamente menor (o nível gravado na criação de cada uma, comparado ao papel atual do solicitante);
  2. faltarem **mais de 2 horas** (`prazo_deslocamento_minutos`) para o início **da nova reserva e de cada reserva deslocada**. Exatamente 2 horas não basta, e uma reserva em andamento nunca é deslocada;
  3. a nova reserva **não exigir aprovação**, ou seja, for confirmada na hora.

  As reservas deslocadas são canceladas **inteiras**, mesmo quando a sobreposição é parcial, sem penalidade, e o usuário é notificado com o motivo (a partir da C14; até lá, ele vê o motivo em "Minhas reservas"). O sistema mostra ao solicitante quantas reservas a ação vai deslocar, sem dizer de quem, e pede confirmação. Sem a confirmação, nada é gravado.
- Se o deslocamento não for possível, o solicitante pode entrar na **fila de espera**. A fila só é oferecida nesse caso: quem pode deslocar recebe a opção de deslocamento.
- A verificação de conflito e a gravação da reserva acontecem **de forma atômica no backend**. Duas requisições simultâneas nunca podem gerar reservas sobrepostas.

### 7.4 Fila de espera

- A fila vale para **o mesmo espaço e exatamente o mesmo intervalo** solicitado.
- Só é possível entrar na fila quando o intervalo está ocupado por reserva ativa ou vaga retida **e** o solicitante não pode deslocar quem o ocupa (seção 7.3). Não se entra na fila de um intervalo livre (a reserva é direta) nem de um intervalo que sobrepõe um bloqueio.
- A ordem da fila é: **nível de prioridade (maior primeiro)** e, em empate, **ordem de entrada**.
- A vaga é **liberada** para uma fila quando o intervalo dela deixa de ter qualquer reserva ativa sobreposta. Exemplo: o cancelamento de uma reserva das 9h às 12h libera a fila das 10h às 11h.
- Quando a vaga é liberada, o primeiro da fila é notificado e tem até **2 horas** para confirmar. Esse prazo nunca ultrapassa **2 horas antes do início** da reserva. Se não confirmar, a vaga passa para o próximo.
- Durante o prazo de confirmação, o intervalo fica **retido para o notificado**: não pode ser reservado diretamente, nem tomado por deslocamento, nem retido por outra fila sobreposta. Quem entra na fila depois, mesmo com prioridade maior, não toma a retenção; passa a disputar a próxima rodada. A retenção termina quando o notificado confirma, desiste ou o prazo expira.
- Quando uma mesma liberação abre filas de intervalos sobrepostos (ex.: 10h–11h e 10h30–11h30), a retenção vai para a fila cujo primeiro colocado tem **maior prioridade** e, em empate, **entrou antes**. As demais continuam aguardando e são reavaliadas quando a retenção termina sem confirmação.
- O prazo de 2 horas da fila é contado a partir do **início do intervalo da fila**, independentemente da regra de cancelamento de quem liberou a vaga. Exemplo: uma reserva das 9h às 12h cancelada às 7h30 é cancelamento tardio para quem cancelou (gera falta, seção 7.8), mas a fila das 10h às 11h ainda é notificada, com prazo até as 8h.
- Quando a vaga é liberada a **menos de 2 horas do início** do intervalo da fila, a fila é encerrada e o horário fica livre para reserva direta.
- Ao confirmar, a reserva passa novamente por todas as validações (penalidade, regras, aprovação).

### 7.5 Reserva recorrente

- Disponível **apenas para sala de aula** (e, portanto, para professor, coordenador e administrador).
- Recorrência **semanal**: dia da semana, horário de início e fim, data inicial e final. O administrador define o limite máximo do período (padrão: até o fim do semestre letivo, máximo de 6 meses).
- Cada ocorrência é uma reserva independente: tem check-in, falta e cancelamento próprios.
- As ocorrências de uma série são **isentas da antecedência máxima** do tipo de espaço; o limite delas é o período máximo de recorrência. A antecedência mínima continua valendo.
- Antes de confirmar, o sistema mostra as ocorrências que conflitam com bloqueios ou com reservas de prioridade igual ou maior. O usuário escolhe criar apenas as ocorrências livres ou desistir.
- Cancelar a série cancela todas as ocorrências futuras. Ocorrências a **menos de 2 horas** do início são canceladas como cancelamento tardio e **geram falta** (seção 7.8).

### 7.6 Aprovação de reservas

- Reservas que exigem aprovação ficam **pendentes** e ocupam o horário.
- Quem aprova é o **coordenador da unidade do espaço**. O administrador também pode decidir.
- **Ninguém decide a própria reserva.** Isso só acontece quando o dono mudou de papel depois de criá-la, e a reserva fica para outro coordenador da unidade ou para um administrador.
- A **recusa exige motivo**, que é enviado ao usuário.
- Se não houver decisão até o horário de início, a reserva **expira** automaticamente e o usuário é notificado. A partir do início ela deixa de ocupar o horário e aparece como expirada em todas as consultas. A gravação da expiração, e o aviso a partir da C14, acontecem na próxima operação que grava reservas, porque o plano gratuito do Xano não tem tarefas agendadas (seção 8).

### 7.7 Bloqueios

- Coordenadores (na própria unidade) e administradores bloqueiam espaços por **manutenção, evento ou feriado**.
- Reservas ativas no período do bloqueio são **canceladas automaticamente**, sem penalidade, e os usuários são notificados com o motivo.
- Entradas de fila de espera no período bloqueado são encerradas.

### 7.8 Cancelamento, comparecimento e penalidade

- O usuário pode cancelar **sem penalidade até 2 horas antes** do início, inclusive exatamente no limite. O prazo é um parâmetro (`prazo_cancelamento_minutos`, padrão 120 minutos).
- Cancelamento com **menos** que esse prazo de antecedência **conta como falta**.
- Cancelamentos feitos pelo sistema não geram falta: inativar a conta cancela as reservas dela que ainda não começaram; desativar um espaço, um tipo ou uma unidade, trocar o tipo de um espaço ou movê-lo de unidade cancela as reservas afetadas que ainda não terminaram. Essas ações de gestão são recusadas enquanto houver reserva confirmada em andamento num espaço afetado, para admin e coordenador.
- **Check-in** pelo próprio usuário entre **15 minutos antes e 15 minutos depois** do início. Sem check-in, a reserva é marcada como **não compareceu** e gera falta.
- **2 faltas em 30 dias** geram **penalidade de 7 dias**. Faltas que já geraram uma penalidade não são contadas novamente.
- Faltas cometidas durante uma penalidade ativa (por exemplo, em reservas confirmadas antes dela) contam normalmente. Se gerarem nova penalidade, ela **começa quando a atual termina**: as penalidades de um usuário se encadeiam e nunca se sobrepõem. Se uma penalidade for anulada, as encadeadas depois dela são **antecipadas**: cada uma passa a começar quando teria começado sem a anulada (no mínimo, na data da falta que a gerou).
- Durante a penalidade, o usuário **não pode criar novas reservas nem entrar na fila de espera**. As reservas futuras já confirmadas **são mantidas**.
- O usuário pode enviar **uma contestação com justificativa** por penalidade. **Somente o administrador** pode anular uma penalidade, sempre registrando o parecer.

### 7.9 Avaliação

- Disponível apenas para reservas **concluídas** (com check-in).
- **Opcional**: uma avaliação por reserva, até **7 dias** após o término.
- Nota de 1 a 5 e comentário opcional, **visíveis a todos os usuários** na página do espaço.

### 7.10 Cadastro e contas

- Cadastro somente com **e-mail institucional**. O domínio aceito é configurável.
- No cadastro, o usuário escolhe **aluno**, **professor** ou **coordenador**.
  - Aluno: conta ativa imediatamente.
  - Professor: conta **pendente** até a aprovação de um administrador ou do coordenador da unidade indicada no cadastro.
  - Coordenador: conta **pendente** até a aprovação de um **administrador**. Ao ser aprovado, passa a coordenar a unidade indicada, se ela estiver ativa e tiver vaga.
  - Enquanto pendente, a conta não acessa o sistema.
- A **recusa exige motivo**, que a pessoa vê ao tentar entrar com a senha correta. Ela pode **pedir nova análise**, trocando a unidade e o papel pedido (professor ou coordenador), até o limite de **3 pedidos** (parâmetro). Esgotados os pedidos, só o administrador pode aprovar a conta.
- Ao **desativar uma unidade**, os pedidos pendentes dela são recusados automaticamente e essa recusa **não consome pedido**.
- O papel de administrador é atribuído apenas pelo administrador principal. O cadastro público nunca concede o papel de administrador.
- **Inativação:** um administrador inativa uma conta ativa escolhendo um motivo numa lista (com "Outro" e descrição), que fica só no log de auditoria. A pessoa perde o acesso na hora, as reservas dela que ainda não começaram são canceladas e as coordenações dela ficam guardadas. Na **reativação**, o sistema mantém só as coordenações em unidades ativas e com vaga, pede nova unidade ao professor cuja unidade foi desativada e respeita o limite de administradores.
- **Senha:** todo usuário pode **trocar a própria senha**. O administrador pode **redefinir** a senha de uma conta (os secundários, só de contas que não são de administrador). A senha redefinida é **provisória**: no acesso seguinte, a pessoa só consegue trocá-la antes de usar o sistema. Administradores criados pelo principal também começam com senha provisória.

### 7.11 Notificações

- Na v1, as notificações são **in-app** (central de notificações do usuário).
- Eventos notificados: confirmação, pendência, aprovação, recusa, expiração, cancelamento por bloqueio, deslocamento por prioridade, vaga liberada na fila, lembrete de check-in, falta registrada, penalidade aplicada e decisão de contestação.

## 8. Arquitetura tecnológica

```text
┌──────────────────────────┐      HTTPS / REST + JWT      ┌──────────────────────────────┐
│  Frontend — Reflex       │ ───────────────────────────► │  Backend — Xano (XanoScript) │
│  (Python)                │                              │                              │
│  • páginas e componentes │ ◄─────────────────────────── │  • banco de dados            │
│  • State e eventos       │          JSON                │  • API REST                  │
│  • validações de UX      │                              │  • autenticação (JWT)        │
└──────────────────────────┘                              │  • regras de negócio         │
                                                          │  • concorrência / prioridade │
                                                          │  • vencimentos nas operações │
                                                          │  • log de auditoria          │
                                                          └──────────────────────────────┘
```

| Camada | Tecnologia | Responsabilidade |
|---|---|---|
| Backend | **Xano** com **XanoScript** | Fonte de verdade de dados e regras. Persistência, API REST, autenticação, autorização, validação das regras de negócio, controle de concorrência, processamento de vencimentos (expiração, faltas, penalidades, fila) e auditoria. |
| Frontend | **Reflex** (Python) | Interface do usuário. O State do Reflex consome a API do Xano. O token de autenticação fica no State do servidor Reflex. Não acessa banco de dados diretamente e **não reimplementa regras de negócio**. Faz apenas validações de usabilidade. |
| Linguagem | **Python** | Usado exclusivamente pelo Reflex. Não existe um backend Python separado. |
| Especificação | **OpenSpec** (schema `spec-driven`) | Planejamento e rastreabilidade das mudanças. |
| Agente de IA | **Claude Code** | Desenvolvimento assistido, com o **Xano Developer MCP** (documentação e validação de XanoScript) e as **Agent Skills do Reflex**. |
| Sincronização | **Xano CLI** | Pull e push entre os arquivos `.xs` locais e o workspace Xano (sandbox). |
| Versionamento | **Git + GitHub** | Histórico, colaboração e revisão. |
| Ambiente Python | **venv + pip** (`requirements.txt`) | Sem uso de `uv`. |

Reflex é a **tecnologia exclusiva** do frontend. Não serão introduzidos React, Vue, Angular ou outro framework.

**Vencimentos sem tarefas agendadas.** O plano gratuito do Xano não executa tarefas agendadas (Background Tasks). Enquanto for assim, os vencimentos seguem três regras, definidas na C7 (`design.md`, D4):
- **Uma porta só.** As operações que gravam reservas processam primeiro, dentro da trava, tudo o que já venceu, por exemplo a pendente cujo início chegou sem decisão.
- **Uma verdade só para leitura.** Todas as consultas usam a **situação efetiva**: o que já venceu aparece como vencido mesmo antes de ser gravado, e por isso o `status` gravado no banco pode estar atrasado.
- **O instante real.** Cada vencimento registra quando de fato venceu, não quando foi constatado.

Se o plano mudar, uma tarefa agendada passa a chamar o mesmo processamento, sem outra mudança.

## 9. Princípios de desenvolvimento

- **Backend como fonte de verdade:** toda regra de negócio e toda autorização são aplicadas no Xano. O frontend nunca é mecanismo de segurança.
- **Desenvolvimento incremental** guiado por changes do OpenSpec (explore → propose → review → apply → archive).
- **Modelo conceitual global, implementação física incremental:** as tabelas são criadas à medida que as changes precisam delas.
- **Parametrização:** prazos, durações e limites ficam em configurações, não fixos no código.
- **Documentação oficial antes de suposição:** sintaxe de XanoScript e APIs do Reflex são confirmadas pelo Xano Developer MCP e pelas skills do Reflex.

## 10. Segurança e integridade

- Autenticação por token (JWT do Xano). Senhas armazenadas apenas como hash.
- Trocar ou redefinir a senha **encerra as sessões abertas** da conta: os tokens emitidos antes deixam de valer.
- Todas as rotas da API do Xano exigem autenticação, exceto cadastro, login e a listagem pública de unidades ativas (somente id e nome) usada no formulário de cadastro.
- Autorização por papel **e por escopo de unidade** (coordenador só enxerga e altera a própria unidade), sempre validada no backend.
- Verificação de conflito e gravação de reserva **atômicas**.
- Horários gravados com fuso horário explícito. As regras são avaliadas em America/Sao_Paulo.
- **Log de auditoria** para toda ação sensível: criar, aprovar, recusar, expirar (ação do sistema, com ator vazio), cancelar, deslocar (registrado como cancelamento com motivo `PRIORIDADE`, com quem deslocou como ator), bloquear, alterar regra, alterar papel, aplicar ou anular penalidade, aprovar cadastro, inativar e reativar conta, trocar e redefinir senha, criar, promover e rebaixar administrador, alterar parâmetros e cadastrar e alterar tipos de espaço, espaços e recursos. Nenhum registro guarda senha, hash ou token.
- Registros de reserva, falta e penalidade **não são apagados fisicamente**. Mudam de status.
- Tokens e credenciais nunca são versionados no Git.
- Dados pessoais restritos ao necessário (LGPD): nome, e-mail institucional e vínculo.

## 11. Estratégia de desenvolvimento

Ordem das changes (ajustada durante os Explores):

1. Fundação e autenticação: cadastro, login, auditoria e carga inicial (C1, `fundacao-autenticacao`).
2. Coordenação e unidades: aprovação de professor e coordenador, reenvio de pedido, papéis, coordenação, gestão de unidades e autorização por unidade (C2, `coordenacao-unidades`).
3. Contas, administradores e senha: administradores secundários, senha provisória, troca de senha, inativação de contas e tela de parâmetros (C3, `contas-admins-senha`).
4. Tipos de espaço, espaços e recursos: cadastro de tipos (só nome, descrição e situação), catálogo de recursos, espaços com código único por unidade, disponibilidade derivada e mudança de unidade pelo admin (C4, `tipos-espacos-recursos`).
5. Regras por tipo de espaço e busca de espaços: regras de uso e RegraPapel por tipo, editadas pelo admin; carga única das regras dos quatro tipos iniciais; tipo sem regras completas não é reservável; granularidade e dias de funcionamento como parâmetros; busca para todos os papéis, com espaços de todas as unidades, que diz se um horário está dentro das regras do tipo, sem verificar ocupação (C5, `regras-tipo-busca`).
6. Reserva avulsa com verificação de conflito e regras: criação atômica com regras do tipo, regra do papel, limite de reservas ativas e conflito; cancelamento pelo usuário no prazo (parâmetro); "Minhas reservas"; busca com livre ou ocupado; inativar conta e desativar, mover ou trocar o tipo de espaços cancelam reservas (recusados com reserva confirmada em andamento), com motivo escolhido numa lista nas desativações e na inativação (C6, `reserva-avulsa`).
7. Aprovação de reservas: aprovar e recusar pendentes (coordenador da unidade do espaço ou admin; ninguém decide a própria reserva; recusa com motivo); expiração da pendente sem decisão até o início, com vencimentos processados nas operações e situação efetiva nas consultas, porque o plano gratuito do Xano não tem tarefas agendadas (seção 8); página "Reservas da unidade" (C7, `aprovacao-reservas`).
8. Deslocamento por prioridade: o solicitante de nível maior desloca, com confirmação, reservas de nível estritamente menor, quando a nova e cada deslocada começam a mais de `prazo_deslocamento_minutos` de agora e a nova nasce confirmada; a busca indica se o espaço é deslocável (C8, `deslocamento-prioridade`). O explore separou a fila de espera na C9.
9. Fila de espera (C9).
   - Pendências da C6: vaga retida pela fila no ponto de extensão do conflito da criação.
   - Pendência da C7: a retenção vencida entra na situação efetiva e no processamento de vencimentos.
   - Decisões do explore da C8 (registradas no `decisions-log.md` da C8):
     - um parâmetro só, `prazo_fila_minutos`, para o prazo de confirmação e para o corte antes do início;
     - o prazo do próximo da fila conta a partir de quando ele é de fato avisado; o vencimento de quem estava antes é gravado com o instante real;
     - a criação de reserva e a entrada na fila processam os vencimentos e a fila do espaço antes de avaliar o conflito, para uma reserva direta não furar a fila; o atraso do aviso sem tráfego é limitação aceita do plano gratuito;
     - aviso em "Minhas reservas" (seção "Fila de espera", com Confirmar, Desistir e o prazo) e no Início, sem a tabela de notificação;
     - a entrada na fila valida as regras da criação, menos o conflito e o limite de ativas, que é conferido na confirmação.
   - Vindas da C8: o deslocamento libera as sobras parciais para a fila; a retenção não é deslocável; a fila só é oferecida a quem não pode deslocar, pela mesma regra do deslocamento.
   - Em aberto para o explore: a confirmação de fila em tipo que exige aprovação gera uma reserva `PENDENTE`.
10. Cancelamento tardio, check-in, faltas e penalidades (inclui contestação).
    - Pendências da C6: penalidade ativa no ponto de extensão da criação; cancelamento tardio com o mesmo prazo; fechamento de reservas passadas; rever o que conta como reserva em andamento se o check-in mudar isso.
    - Pendências da C7: não comparecimento, fechamento e falta entram no processamento de vencimentos com o instante real; penalidade ativa derivada por datas; janela de check-in de uma reserva aprovada a minutos do início.
    - Vinda da C9: penalidade ativa também na entrada da fila.
11. Bloqueios.
    - Pendências da C6: bloqueio ativo no ponto de extensão da criação e cancelamento por bloqueio com `bloqueio_id`.
    - Pendência da C7: procurar as reservas ativas sobrepostas pela situação efetiva.
12. Reserva recorrente de sala de aula.
13. Avaliações.
14. Notificações in-app.
    - Pendência da C6: notificar os cancelamentos automáticos (`CONTA_INATIVADA` e `ESPACO_INDISPONIVEL`).
    - Pendências da C7: notificar aprovação, recusa e expiração; a expiração é notificada só quando gravada, então avaliar processar os vencimentos ao abrir a central de notificações.
    - Pendência da C8: avisar o dono da reserva deslocada por prioridade.
15. Painel, relatórios e log de auditoria. O log de auditoria deve ser gravado desde a primeira change que tiver ação sensível. Pendência da C7: painel e relatórios usam a situação efetiva.

## 12. Fonte de verdade e documentação

| Documento | Conteúdo |
|---|---|
| `docs/project-overview.md` | Este documento: visão, escopo, regras e arquitetura. |
| `docs/domain-model.md` | Conceitos do domínio, MER (conceitual) e DER (lógico de referência). |
| `AGENTS.md` | Regras de trabalho do agente de IA. |
| `openspec/config.yaml` | Contexto e regras dos workflows do OpenSpec. |
| `openspec/specs/` | Comportamento consolidado (gerado pelas changes arquivadas). |
| `openspec/changes/` | Mudanças em andamento e histórico (`archive/`). |

Em caso de divergência, **as specs arquivadas no OpenSpec prevalecem** sobre este documento para o comportamento detalhado. Este documento deve ser atualizado quando uma change alterar uma regra global.