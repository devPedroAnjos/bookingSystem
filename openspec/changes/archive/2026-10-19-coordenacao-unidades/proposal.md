## Why

A C1 entregou cadastro e login, mas ainda faltam três coisas para o sistema funcionar:
- **Professores** ficam `PENDENTE` para sempre, porque ninguém consegue aprová-los.
- **Coordenadores** não existem: o papel não pode ser pedido nem atribuído.
- **Unidades** só existem pela carga inicial.

Também falta a regra "o coordenador só age nas unidades que coordena", que é a base de toda change seguinte (espaços, bloqueios, aprovação de reservas). Esta change cria a coordenação de unidade, com os limites definidos pela equipe, e o padrão de autorização por papel e por unidade.

A governança de administradores e senhas fica para a próxima change (C3, `contas-admins-senha`). A divisão foi decidida no explore para manter cada change revisável.

## What Changes

**Cadastro e aprovação**
- O cadastro público passa a aceitar **coordenador** (`PENDENTE`, com unidade obrigatória), além de aluno e professor. **Muda a regra do §7.10** do overview e a spec `autenticacao` da C1, que proibiam pedir o papel de coordenador.
- Quem aprova:
  - **professor**: admin ou coordenador ativo da unidade escolhida;
  - **coordenador**: só admin.
  - Ao ser aprovado, o coordenador passa a coordenar a unidade escolhida, se ela estiver ativa e tiver vaga.
- A recusa exige motivo. A pessoa vê o motivo ao tentar entrar, com a senha correta.
- **Reenvio:** a pessoa recusada pode pedir nova análise. Ela pode trocar a unidade e o papel pedido (professor ou coordenador) e escrever uma justificativa, até o limite de **3 pedidos**. Só o admin pode aprovar uma conta `RECUSADA`.
- Decisões simultâneas sobre o mesmo cadastro: vale a primeira.
- Um pedido só pode ser aprovado com a unidade ativa. Ao desativar uma unidade, os pedidos pendentes dela são **recusados automaticamente** ("Unidade desativada"). Essa recusa **não consome** pedido.

**Professor pertence a uma unidade**
- A unidade escolhida no cadastro passa a ser a **unidade do professor**. Ela serve para pertencimento, aprovação e transferência. As reservas continuam valendo em qualquer unidade (overview §4).
- Só o admin **transfere** um professor para outra unidade ativa. O pedido de transferência acontece fora do sistema.
- Todo ingresso no papel de professor exige uma unidade no mesmo ato: aluno promovido ou coordenador rebaixado.
- O aluno pertence à instituição e não a uma unidade.

**Coordenação e papéis**
- Um coordenador tem de **1 a 2 unidades**, e uma unidade tem de **1 a 4 coordenadores**. Só contam contas `ATIVA`.
- O admin pode:
  - **mover** um coordenador (ele sai da origem);
  - **acrescentar** uma unidade a ele (ele fica nas duas);
  - **remover** uma das duas unidades.
  - Nenhuma dessas operações pode deixar a origem sem coordenador.
- O admin muda o papel de alunos, professores e coordenadores. A sequência é aluno → professor → coordenador: o aluno só vira professor, professor e coordenador podem trocar entre si, e **ninguém volta a ser aluno**:
  - virar coordenador exige escolher, no mesmo ato, 1 ou 2 unidades;
  - deixar de ser coordenador remove as coordenações, mesmo que a unidade fique vazia (saída real).
- Uma unidade sem coordenador ativo (no início ou após uma saída) é cuidada pelo admin.

**Unidades**
- Só o admin:
  - cria uma unidade, sempre com 1 coordenador movido ou acrescentado;
  - corrige nome e endereço (nome único, sem diferenciar maiúsculas e minúsculas);
  - desativa e reativa.
- Desativar é um formulário único:
  - quem só coordenava aquela unidade recebe uma unidade de destino obrigatória;
  - cada professor dela também recebe um destino obrigatório;
  - os pedidos pendentes dela são recusados automaticamente, sem consumir pedido.
- Reativada, a unidade volta sem coordenadores e sem professores. Nunca há exclusão.

**Base técnica**
- Parâmetros novos em `ConfiguracaoGeral`, preenchidos pelo bootstrap: máximo de coordenadores por unidade (4), máximo de unidades por coordenador (2) e máximo de pedidos de cadastro (3). A tela de edição vem na C3.
- Autorização reutilizável: "exige admin" e "autoriza unidade".
- Garantia sob concorrência para todas as contagens e para a decisão única, com uma trava transacional. A trava é **validada por um teste de execução antes de qualquer outro código**.
- Auditoria de todas as ações.
- Frontend: cadastro com a opção de coordenador, login com motivo e reenvio, menu por papel e páginas de aprovações, usuários e unidades.

**Fora do escopo**
- Admins secundários, limite de admins, admin principal intocável, conta criada do zero, senha provisória, "trocar minha senha", inativar/reativar contas e a tela de parâmetros (C3).
- Espaços, tipos de espaço e recursos (C4).
- Notificações sobre a decisão do cadastro (change de notificações).
- Consulta do log de auditoria.
- Cancelar as reservas futuras de quem é inativado. A regra está registrada para a change de reservas.

## Capabilities

### New Capabilities
- `aprovacao-cadastro`: pendentes por escopo, aprovação e recusa, decisão única, reenvio com limite de pedidos e aprovação de conta recusada pelo admin.
- `coordenacao`: vínculo coordenador–unidade com limites, mover, acrescentar e remover, unidade sem coordenador ativo.
- `papeis`: mudança de papel de alunos, professores e coordenadores pelo admin, e transferência de professor entre unidades.
- `autorizacao`: acesso por papel e escopo de unidade, com efeito imediato, e o menu por papel.

### Modified Capabilities
- `autenticacao`:
  - o cadastro passa a aceitar `COORDENADOR`;
  - "não atribui papéis privilegiados" passa a valer só para `ADMIN`;
  - o login de conta `RECUSADA` informa o motivo;
  - uma consulta da situação do pedido com e-mail e senha.
- `unidades`: criação com coordenador, edição, desativação com destino, reativação e listagem de unidades geridas.
- `auditoria`: as ações desta change.

## Impact

- **Papéis afetados:**
  - Administrador: aprova cadastros, gerencia coordenação, papéis e unidades.
  - Coordenador: passa a existir; aprova professores das próprias unidades.
  - Professor: é aprovado ou recusado, pode reenviar o pedido, pertence a uma unidade e pode ser transferido pelo admin.
  - Aluno: pode ter o papel alterado pelo admin; continua sem unidade.
- **Regras do `project-overview.md` tocadas:**
  - §4: o coordenador pode ter até 2 unidades; o professor pertence a uma unidade;
  - §7.10: o cadastro de coordenador, a aprovação e o reenvio;
  - §10: autorização por unidade e auditoria.
  - O overview e o `domain-model.md` (§2.1, §2.3, §2.18, A.1) são atualizados nesta change.
- **Xano:**
  - campos novos em `usuario` e `configuracao_geral`;
  - tabela `coordenacao_unidade`;
  - grupo de API `contas`;
  - rotas novas em `unidades` e `auth`;
  - funções de autorização e de trava;
  - alteração de `cadastro`, `login` e `bootstrap`.
  - Push só com dry-run e aprovação (branch live `v1`, plano Free).
- **Reflex:** cliente com as funções novas e `XANO_API_CONTAS_URL`, layout com menu, States e páginas novas, e alteração das páginas de cadastro e login.
- **Dependências:** nenhuma nova.
