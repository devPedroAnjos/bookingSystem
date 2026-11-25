# BookingSystem

Sistema web de reserva de salas de aula, laboratórios, bibliotecas e auditórios de uma instituição de ensino.

Projeto acadêmico do Innovation Lab da Faculdade Impacta.
Equipe: Gustavo Ribeiro de Souza, Leonardo Machado da Silva e Pedro Macena dos Anjos. Professor: Leonardo Bontempo.

## Sumário

1. [Apresentação](#1-apresentação)
2. [Acesso ao aplicativo](#2-acesso-ao-aplicativo)
3. [Perfis de usuários](#3-perfis-de-usuários)
4. [Funcionalidades](#4-funcionalidades)
5. [Manual de utilização](#5-manual-de-utilização)
6. [Exemplos de utilização](#6-exemplos-de-utilização)
7. [Limitações conhecidas](#7-limitações-conhecidas)

---

## 1. Apresentação

O **BookingSystem** permite que alunos e professores encontrem espaços livres e façam reservas sozinhos. As regras da instituição são aplicadas automaticamente pelo sistema.

### Problema que resolve

Em muitas instituições, a reserva de espaços depende de planilhas, de pedidos à coordenação ou de combinações informais. Isso causa:

- **conflitos de horário:** duas pessoas acreditam ter reservado o mesmo espaço;
- **falta de critério** quando um aluno e um professor disputam o mesmo horário;
- **espaços reservados e vazios**, sem consequência para quem não comparece;
- **nenhum registro** de quem criou, aprovou, cancelou ou bloqueou uma reserva.

O BookingSystem resolve esses problemas assim:

- nunca permite duas reservas ativas no mesmo horário e espaço;
- resolve as disputas pela prioridade de cada papel;
- reduz as reservas não usadas com check-in, faltas e penalidades;
- registra toda ação sensível num log de auditoria.

### Público-alvo

Instituições de ensino com uma ou mais unidades (campus ou prédios). Os usuários são alunos, professores, coordenadores de unidade e administradores.

### Tecnologias

| Camada | Tecnologia |
| --- | --- |
| Frontend | [Reflex](https://reflex.dev) (Python) |
| Backend, banco de dados e regras de negócio | [Xano](https://www.xano.com) com XanoScript |

## 2. Acesso ao aplicativo

No momento, o aplicativo não tem uma versão publicada (deploy) e roda localmente. Ele precisa de uma instância do Xano com o backend do projeto, que está na pasta [`xano/`](xano/).

### Como executar localmente

Pré-requisitos: Python 3.10 ou superior e Git.

```bash
# 1. Clonar o repositório
git clone <url-deste-repositorio>
cd bookingSystem

# 2. Criar e ativar o ambiente virtual
python -m venv .venv
.venv\Scripts\activate        # Windows
# source .venv/bin/activate   # Linux ou macOS

# 3. Instalar as dependências
pip install -r requirements.txt

# 4. Configurar as variáveis de ambiente
copy .env.example .env        # Windows
# cp .env.example .env        # Linux ou macOS

# 5. Iniciar o aplicativo
reflex run
```

No arquivo `.env`, preencha as URLs dos cinco grupos de API do Xano (autenticação, unidades, contas, espaços e reservas), seguindo o modelo do [`.env.example`](.env.example).

Depois de iniciar, acesse **http://localhost:3000** no navegador.

### Primeiro acesso

- **Aluno:** crie a conta em **Criar conta**. Ela fica ativa na hora.
- **Professor e coordenador:** crie a conta da mesma forma. Ela fica pendente até um administrador ou o coordenador da unidade aprovar.
- **Administrador:** o administrador principal é criado na instalação do sistema. Os demais são criados por ele.

O cadastro aceita somente e-mails do domínio institucional configurado.

## 3. Perfis de usuários

A prioridade de cada perfil decide quem fica com o horário quando duas pessoas querem o mesmo espaço.

| Perfil | Prioridade | Responsabilidades e permissões |
| --- | --- | --- |
| **Aluno** | 1 (menor) | Busca espaços e reserva biblioteca e laboratório. Cancela as próprias reservas, faz check-in, avalia os espaços usados e entra na fila de espera. |
| **Professor** | 2 | Tudo o que o aluno faz, e também reserva sala de aula e auditório. Pertence a uma unidade, escolhida no cadastro. |
| **Coordenador de unidade** | 3 | Reserva todos os tipos de espaço, sem aprovação. Na própria unidade (até 2 unidades por coordenador), também: cadastra e edita espaços; bloqueia espaços; aprova ou recusa reservas pendentes; aprova cadastros de professor. |
| **Administrador** | 3 | Age em todas as unidades. Gerencia unidades, tipos de espaço e suas regras, recursos, espaços e contas de usuário. Aprova cadastros de professor e de coordenador e anula penalidades. |
| **Administrador principal** | 3 | Tudo o que o administrador faz, e também: cria, promove e rebaixa administradores (até 3 ativos); altera os parâmetros gerais do sistema. |

Em empate de prioridade, vale quem reservou primeiro.

## 4. Funcionalidades

### Para todos os perfis

- **Cadastro e login** com e-mail institucional. Quem tem o cadastro recusado vê o motivo e pode pedir nova análise.
- **Troca de senha** a qualquer momento.
- **Feed de espaços** na página Início, com foto de capa, nota média das avaliações e busca por texto (nome, código, local, unidade ou tipo).
- **Filtros** por unidade, tipo, capacidade mínima, recursos, data e horário.
- **Verificação do horário**: para cada espaço, o sistema diz se o pedido está dentro das regras do tipo e se o espaço está livre, ocupado ou bloqueado.
- **Reserva** confirmada na hora ou pendente, quando o tipo exige aprovação para o papel.
- **Deslocamento por prioridade**: quem tem prioridade maior pode ocupar um horário reservado por alguém de prioridade menor, com confirmação.
- **Fila de espera** para um horário ocupado que não pode ser deslocado.
- **Minhas reservas**: próximas reservas, histórico, faltas e penalidades e fila de espera, com o motivo de cada cancelamento, recusa ou expiração.
- **Check-in** pelo cartão da próxima reserva, na página Início.
- **Cancelamento** das próprias reservas.
- **Avaliação** do espaço depois do uso, com nota de 1 a 5 e comentário.
- **Página do espaço**, com dados, recursos, média e avaliações.

### Para coordenadores e administradores (menu Gestão)

- **Aprovações:** aprova ou recusa pedidos de cadastro.
- **Reservas da unidade:** consulta as reservas e aprova ou recusa as pendentes.
- **Espaços:** cria, edita, desativa e reativa espaços, associa recursos e envia a foto de capa.
- **Bloqueios:** bloqueia um espaço por manutenção, evento ou feriado.

### Somente para administradores

- **Usuários:** muda papel, transfere professor de unidade, redefine senha, inativa e reativa contas.
- **Unidades:** cria, edita, desativa e reativa unidades e consulta os coordenadores.
- **Tipos de espaço:** cria tipos e define as regras de cada um.
- **Recursos:** mantém o catálogo de recursos (projetor, computadores etc.).
- **Penalidades:** consulta e anula penalidades, com parecer.
- **Administradores** e **Parâmetros:** somente o administrador principal.

### Regras iniciais por tipo de espaço

Todos os tipos funcionam de segunda a sexta, das 08h00 às 22h40. O administrador pode alterar todas estas regras.

| Tipo | Duração | Antecedência | Reservas ativas por usuário | Quem pode reservar | Exige aprovação para |
| --- | --- | --- | --- | --- | --- |
| Biblioteca | 30 a 180 min | até 7 dias | 2 | Todos | — |
| Laboratório | 30 a 240 min | até 14 dias | 3 | Todos | Aluno |
| Sala de aula | 50 a 300 min | até 30 dias | 10 | Professor, coordenador e admin | — |
| Auditório | 50 a 480 min | de 1 a 60 dias | 2 | Professor, coordenador e admin | Professor |

## 5. Manual de utilização

O manual está organizado por perfil, na ordem em que cada pessoa usa o sistema.

### 5.1 Criar conta e entrar

1. Na tela inicial, clique em **Criar conta**.
2. Preencha nome, e-mail institucional e senha (mínimo de 8 caracteres), e confirme a senha.
3. Escolha o **vínculo**: aluno, professor ou coordenador. Para professor e coordenador, escolha também a unidade.
4. Clique em **Cadastrar**.

**Resultado esperado:**
- **Aluno:** a conta fica ativa e você já pode entrar.
- **Professor ou coordenador:** a conta fica pendente até a aprovação. Se o cadastro for recusado, ao entrar com a senha correta você verá o motivo e o botão **Pedir nova análise**. É possível pedir até 3 vezes.

Para entrar, clique em **Entrar** na tela inicial e informe e-mail e senha. Se um administrador redefinir a sua senha, o sistema pede que você crie uma nova antes de continuar.

### 5.2 Aluno e professor: encontrar e reservar um espaço

1. Na página **Início**, use a busca por texto ou os filtros.
2. Para reservar, informe **data**, **início** e **fim** e clique em **Buscar**. Cada cartão mostra se o horário está dentro das regras e se o espaço está **Livre**, ocupado ou **Bloqueado**.
3. No cartão de um espaço livre, clique em **Reservar** e confirme.

**Resultado esperado:**
- Se o tipo não exige aprovação para o seu papel, a reserva é **confirmada** na hora.
- Se exige, por exemplo laboratório para aluno, a reserva fica **pendente**. Ela já ocupa o horário até a decisão do coordenador. Sem decisão até o início, ela expira.

Os espaços que o seu papel não pode reservar aparecem como cartão **Restrito**, acinzentado, com os papéis que podem reservá-los. Para ver os detalhes de um espaço, clique no cartão: a página mostra capacidade, localização, recursos e avaliações.
### 5.3 Horário ocupado: deslocar ou entrar na fila

Quando o horário pedido está ocupado, o cartão oferece uma de duas ações.

**Deslocar e reservar** aparece quando todas as condições abaixo valem:
- todas as reservas do horário são de prioridade menor que a sua;
- faltam mais de 2 horas para o início;
- a sua reserva não exige aprovação.

1. Clique em **Deslocar e reservar**.
2. O sistema informa quantas reservas serão canceladas, sem dizer de quem. Confirme.

**Resultado esperado:** a sua reserva é confirmada. As reservas deslocadas são canceladas sem penalidade, e os donos veem o motivo em Minhas reservas.

**Entrar na fila** aparece quando não é possível deslocar.

1. Clique em **Entrar na fila** e confirme.
2. Acompanhe a sua posição em **Minhas reservas › Fila de espera**.
3. Quando a vaga for liberada, um aviso amarelo aparece no topo de todas as páginas, com o prazo para confirmar. Em **Minhas reservas › Fila de espera**, clique em **Confirmar**.

**Resultado esperado:**
- Ao confirmar, a reserva é criada. Ela nasce pendente se o tipo exigir aprovação.
- Se você não confirmar no prazo, a vaga passa para o próximo da fila.
- Você pode desistir a qualquer momento.

### 5.4 Aluno e professor: usar, cancelar e avaliar

**Cancelar**
1. Em **Minhas reservas**, na seção **Próximas**, clique em **Cancelar** na reserva.
2. Até 2 horas antes do início, o cancelamento é livre.
3. Com menos de 2 horas, o cancelamento de uma reserva confirmada **conta como falta**. O sistema avisa e pede confirmação.

**Fazer check-in**
1. No dia, a página **Início** mostra o cartão da próxima reserva.
2. De 15 minutos antes até 15 minutos depois do início, clique em **Fazer check-in**.

**Resultado esperado:** com check-in, a reserva vira **concluída** no fim. Sem check-in, quando a janela fecha, a reserva vira **não compareceu**, gera uma falta e o horário é liberado.

**Faltas e penalidades**
- 2 faltas em 30 dias geram uma penalidade de 7 dias.
- Durante a penalidade, não é possível criar reservas nem entrar em filas. As reservas já confirmadas são mantidas.
- A situação aparece em **Minhas reservas › Faltas e penalidades**.

**Avaliar**
1. Em **Minhas reservas**, na seção **Histórico**, clique em **Avaliar** numa reserva concluída. O prazo é de até 7 dias depois do fim.
2. Escolha a nota de 1 a 5, escreva um comentário opcional e envie.

**Resultado esperado:** a avaliação aparece na página do espaço, com o seu primeiro nome e o seu papel. A média é atualizada no feed. A avaliação não pode ser editada nem excluída.

### 5.5 Coordenador: cuidar da unidade

**Aprovar reservas**
1. Em **Gestão › Reservas da unidade**, filtre por **Pendentes**.
2. Clique em **Aprovar** ou **Recusar**. A recusa exige um motivo.

**Resultado esperado:** a reserva aprovada fica confirmada. Na recusada, o dono vê o motivo em Minhas reservas. Ninguém decide a própria reserva.

**Aprovar cadastros**
1. Em **Gestão › Aprovações**, veja os **Pedidos pendentes**.
2. Clique em **Aprovar** ou **Recusar**. A recusa exige um motivo.

O coordenador aprova cadastros de professor da própria unidade. Cadastros de coordenador são aprovados somente por administradores.

**Cadastrar espaços**
1. Em **Gestão › Espaços**, clique em **Novo espaço**.
2. Informe nome, código (único na unidade), capacidade, tipo, localização, descrição e recursos.
3. Para pôr uma foto de capa, clique em **Foto** na linha do espaço, escolha a imagem e clique em **Salvar foto**.

Na mesma página, cada espaço tem as ações **Editar**, **Desativar** e **Reativar**. O administrador também pode **Mover** um espaço para outra unidade.

**Bloquear um espaço**
1. Em **Gestão › Bloqueios**, clique em **Novo bloqueio**.
2. Escolha o espaço, o tipo (manutenção, evento ou feriado), o período e o motivo.

**Resultado esperado:**
- As reservas do período que ainda não começaram são canceladas sem penalidade, e os donos veem o motivo.
- O espaço aparece como **Bloqueado** na busca.
- O bloqueio é recusado se houver uma reserva confirmada em andamento no período.
- O bloqueio não é editado: para mudar o período, remova-o e crie outro.

### 5.6 Administrador: regras, contas e penalidades

**Definir as regras de um tipo de espaço**
1. Em **Gestão › Tipos de espaço**, clique em **Regras** na linha do tipo.
2. Ajuste as regras de uso: duração mínima e máxima; antecedência mínima e máxima; reservas ativas por usuário; abertura e fechamento.
3. Para aluno e professor, marque **Pode reservar** e **Exige aprovação**.

**Resultado esperado:** as regras valem para os próximos pedidos. Um tipo novo só fica reservável depois de receber as regras.

**Gerenciar contas**
1. Em **Gestão › Usuários**, filtre por papel, situação, nome ou e-mail.
2. Use as ações da linha: **Mudar papel**, **Transferir** (professor), **Redefinir senha**, **Inativar** ou **Reativar**.

A mudança de papel segue a sequência aluno → professor → coordenador. Um coordenador pode voltar a professor. Inativar uma conta cancela as reservas futuras da pessoa.

**Anular uma penalidade**
1. Em **Gestão › Penalidades**, procure a pessoa por nome ou e-mail.
2. Clique em **Anular** e escreva o **parecer**, que é obrigatório.

**Resultado esperado:** a penalidade deixa de valer, e o usuário vê o parecer sem o nome de quem anulou.

**Somente o administrador principal**
- **Gestão › Administradores:** **Criar administrador** do zero, **Promover coordenador** (que perde as coordenações) e **Rebaixar a coordenador** um administrador secundário.
- **Gestão › Parâmetros:** altera os valores gerais. Entre eles: granularidade dos horários (padrão de 10 minutos); dias de funcionamento; prazos de cancelamento, deslocamento e fila; janela de check-in; regras de penalidade.

## 6. Exemplos de utilização

### Cenário 1: reserva com aprovação

1. A aluna Ana reserva um laboratório para amanhã, das 14h00 às 15h00. O laboratório exige aprovação para aluno, então a reserva fica **pendente**.
2. A coordenadora da unidade abre **Reservas da unidade** e aprova.
3. Em **Minhas reservas**, Ana vê a reserva **confirmada**.

### Cenário 2: disputa de horário e fila de espera

1. O professor Carlos busca o mesmo laboratório, no mesmo horário. Faltam mais de 2 horas, e professor tem prioridade sobre aluno. O cartão mostra **Deslocar e reservar**.
2. Carlos confirma. A reserva da Ana é cancelada, com o motivo de prioridade, e sem falta.
3. Ana não pode deslocar um professor, então entra na **fila de espera** desse horário.
4. Carlos cancela a reserva. A vaga fica retida para a Ana, que vê o aviso no topo das páginas e confirma.

### Cenário 3: uso e avaliação

1. Ana reserva uma biblioteca das 10h00 às 10h30. A reserva é confirmada na hora.
2. Às 09h55, o cartão da próxima reserva mostra **Fazer check-in**. Ana faz o check-in.
3. Às 10h30, a reserva vira concluída. Em **Minhas reservas › Histórico**, Ana avalia o espaço com nota 5.
4. A avaliação aparece na página da biblioteca, e a média é atualizada no feed.

### Cenário 4: falta e penalidade

1. O aluno Bruno cancela uma reserva confirmada 1 hora antes do início. O sistema avisa que isso conta como falta, e ele confirma.
2. Bruno já tinha outra falta nos últimos 30 dias. O sistema aplica uma penalidade de 7 dias.
3. Em **Minhas reservas › Faltas e penalidades**, Bruno vê o período da penalidade. Até o fim, ele não consegue reservar.
4. Um administrador anula a penalidade em **Gestão › Penalidades**, com parecer. Bruno volta a reservar.

### Cenário 5: bloqueio para manutenção

1. A coordenadora bloqueia um laboratório amanhã, das 08h00 às 12h00, por manutenção.
2. As reservas desse período são canceladas sem penalidade, com o motivo do bloqueio.
3. Quem buscar esse laboratório nesse horário vê o espaço como **Bloqueado**.

## 7. Limitações conhecidas

### Funcionalidades fora desta versão

Estas funcionalidades estão previstas como evolução e não foram implementadas:

- reserva recorrente semanal de sala de aula;
- notificações por e-mail, SMS ou push, e central de notificações dentro do sistema. Hoje, os avisos aparecem nas próprias telas: em Minhas reservas e no topo das páginas;
- painel de uso, relatórios e tela de consulta do log de auditoria. O log é gravado, mas não há tela para consultá-lo;
- contestação de penalidade pelo usuário. Somente o administrador anula penalidades;
- recuperação de senha por e-mail. Quem esqueceu a senha pede a redefinição a um administrador;
- galeria com várias fotos por espaço. Cada espaço tem uma foto de capa;
- bloqueio de todos os espaços de uma unidade numa só ação;
- edição de bloqueios e de avaliações;
- tema escuro;
- login social ou institucional (SSO) e integração com Google Agenda ou Outlook;
- aplicativo mobile nativo e reserva de equipamentos avulsos.

### Restrições da versão entregue

- **Sem versão publicada:** o aplicativo roda localmente e depende de uma instância do Xano configurada.
- **Horário de funcionamento:** só há reservas nos dias e horários de funcionamento (padrão: segunda a sexta, das 08h00 às 22h40). Fins de semana e feriados não são reserváveis, a menos que o administrador altere os parâmetros.
- **Vencimentos sem tarefas agendadas:** o plano gratuito do Xano não executa tarefas agendadas. Expirações, faltas, penalidades e o andamento da fila são gravados na próxima operação ou ao abrir as páginas. As consultas já mostram a situação correta antes disso.
- **Foto de capa pública:** as fotos ficam numa URL pública do Xano e recebem marca d'água, porque o plano gratuito não tem armazenamento privado. As fotos não têm dados pessoais.
- **Fuso horário único:** todas as regras de horário seguem o fuso de São Paulo (America/Sao_Paulo).
