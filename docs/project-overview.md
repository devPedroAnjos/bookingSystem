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
| **Administrador** | 3 | Define regras por tipo de espaço (os parâmetros gerais, só o principal), cria tipos de espaço, gerencia unidades, papéis e coordenações, aprova cadastros de professor e de coordenador, revisa e anula penalidades, bloqueia espaços, acessa painel, relatórios e log de auditoria de todas as unidades. Também pode reservar. |

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

- Reservas apenas de **segunda a sexta-feira**.
- Uma reserva pode **começar a partir de 08h00** e deve **terminar no máximo às 22h40**.
- 22h40 é apenas horário de término: nenhuma reserva pode começar às 22h40 ou depois.
- Os horários de início e fim são múltiplos de **10 minutos** (permite 22h40 e blocos de 50 min).
- Todas as regras de horário são avaliadas no fuso **America/Sao_Paulo**.
- Feriados e recessos são tratados como **bloqueios** cadastrados pela coordenação ou administração.

### 7.2 Regras por tipo de espaço e papel

| Tipo de espaço | Duração mínima | Quem pode reservar | Exige aprovação para | Recorrência |
|---|---|---|---|---|
| Biblioteca | 30 min | Aluno, Professor, Coordenador, Admin | — | Não |
| Laboratório | 30 min | Aluno, Professor, Coordenador, Admin | **Aluno** | Não |
| Sala de aula | 50 min | Professor, Coordenador, Admin | — | **Sim** |
| Auditório | 50 min | Professor, Coordenador, Admin | **Professor** | Não |

O administrador também configura, por tipo: duração máxima, antecedência mínima e máxima, limite de reservas ativas por usuário, horário de funcionamento e quem pode reservar ou precisa de aprovação. Ele pode criar novos tipos de espaço. Coordenadores e administradores não precisam de aprovação.

### 7.3 Concorrência e prioridade

- **Nunca** podem existir duas reservas **ativas** (pendente ou confirmada) com horários sobrepostos no mesmo espaço. Sobreposição parcial também é conflito.
- Uma reserva **pendente já ocupa o horário**, assim como uma vaga **retida pela fila de espera** (ver seção 7.4).
- A prioridade é definida pelo papel: **Coordenador/Admin (3) > Professor (2) > Aluno (1)**.
- Entre papéis de **mesmo nível**, vence **quem reservou primeiro** (data/hora de criação registrada pelo backend).
- **Deslocamento por prioridade:** um solicitante de nível maior pode ocupar um horário já reservado por usuários de nível menor quando:
  1. todas as reservas conflitantes forem de nível estritamente menor;
  2. faltarem **mais de 2 horas** para o início;
  3. a nova reserva **não exigir aprovação**, ou seja, for confirmada na hora.

  As reservas deslocadas são canceladas sem penalidade e o usuário é notificado com o motivo. O sistema mostra ao solicitante que a ação vai deslocar uma reserva e pede confirmação.
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
- A **recusa exige motivo**, que é enviado ao usuário.
- Se não houver decisão até o horário de início, a reserva **expira** automaticamente e o usuário é notificado.

### 7.7 Bloqueios

- Coordenadores (na própria unidade) e administradores bloqueiam espaços por **manutenção, evento ou feriado**.
- Reservas ativas no período do bloqueio são **canceladas automaticamente**, sem penalidade, e os usuários são notificados com o motivo.
- Entradas de fila de espera no período bloqueado são encerradas.

### 7.8 Cancelamento, comparecimento e penalidade

- O usuário pode cancelar **sem penalidade até 2 horas antes** do início.
- Cancelamento com **menos de 2 horas** de antecedência **conta como falta**.
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
- **Inativação:** um administrador inativa uma conta ativa informando um motivo, que fica só no log de auditoria. A pessoa perde o acesso na hora, e as coordenações dela ficam guardadas. Na **reativação**, o sistema mantém só as coordenações em unidades ativas e com vaga, pede nova unidade ao professor cuja unidade foi desativada e respeita o limite de administradores.
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
                                                          │  • tarefas agendadas         │
                                                          │  • log de auditoria          │
                                                          └──────────────────────────────┘
```

| Camada | Tecnologia | Responsabilidade |
|---|---|---|
| Backend | **Xano** com **XanoScript** | Fonte de verdade de dados e regras. Persistência, API REST, autenticação, autorização, validação das regras de negócio, controle de concorrência, tarefas agendadas (expiração, faltas, penalidades, fila) e auditoria. |
| Frontend | **Reflex** (Python) | Interface do usuário. O State do Reflex consome a API do Xano. O token de autenticação fica no State do servidor Reflex. Não acessa banco de dados diretamente e **não reimplementa regras de negócio**. Faz apenas validações de usabilidade. |
| Linguagem | **Python** | Usado exclusivamente pelo Reflex. Não existe um backend Python separado. |
| Especificação | **OpenSpec** (schema `spec-driven`) | Planejamento e rastreabilidade das mudanças. |
| Agente de IA | **Claude Code** | Desenvolvimento assistido, com o **Xano Developer MCP** (documentação e validação de XanoScript) e as **Agent Skills do Reflex**. |
| Sincronização | **Xano CLI** | Pull e push entre os arquivos `.xs` locais e o workspace Xano (sandbox). |
| Versionamento | **Git + GitHub** | Histórico, colaboração e revisão. |
| Ambiente Python | **venv + pip** (`requirements.txt`) | Sem uso de `uv`. |

Reflex é a **tecnologia exclusiva** do frontend. Não serão introduzidos React, Vue, Angular ou outro framework.

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
- **Log de auditoria** para toda ação sensível: criar, aprovar, recusar, cancelar, deslocar, bloquear, alterar regra, alterar papel, aplicar ou anular penalidade, aprovar cadastro, inativar e reativar conta, trocar e redefinir senha, criar, promover e rebaixar administrador e alterar parâmetros. Nenhum registro guarda senha, hash ou token.
- Registros de reserva, falta e penalidade **não são apagados fisicamente**. Mudam de status.
- Tokens e credenciais nunca são versionados no Git.
- Dados pessoais restritos ao necessário (LGPD): nome, e-mail institucional e vínculo.

## 11. Estratégia de desenvolvimento

Ordem das changes (ajustada durante os Explores):

1. Fundação e autenticação: cadastro, login, auditoria e carga inicial (C1, `fundacao-autenticacao`).
2. Coordenação e unidades: aprovação de professor e coordenador, reenvio de pedido, papéis, coordenação, gestão de unidades e autorização por unidade (C2, `coordenacao-unidades`).
3. Contas, administradores e senha: administradores secundários, senha provisória, troca de senha, inativação de contas e tela de parâmetros (C3, `contas-admins-senha`).
4. Tipos de espaço, espaços e recursos.
5. Regras por tipo de espaço e busca de disponibilidade.
6. Reserva avulsa com verificação de conflito e regras. Inativar uma conta cancela as reservas futuras dela (regra decidida na C2).
7. Aprovação de reservas pendentes e expiração.
8. Prioridade, deslocamento e fila de espera.
9. Cancelamento, check-in, faltas e penalidades (inclui contestação).
10. Bloqueios.
11. Reserva recorrente de sala de aula.
12. Avaliações.
13. Notificações in-app.
14. Painel, relatórios e log de auditoria. O log de auditoria deve ser gravado desde a primeira change que tiver ação sensível.

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