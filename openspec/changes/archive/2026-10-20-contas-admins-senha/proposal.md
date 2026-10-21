## Why

Depois da C2, o sistema tem coordenadores, unidades e aprovação de cadastro, mas três lacunas de governança continuam abertas:
- **Um único administrador.** Ele é criado no bootstrap e não há como ter outros, nem como impedir que o sistema fique sem quem administra.
- **Senha sem gestão.** Ninguém troca a própria senha. Uma senha esquecida não tem saída, porque a recuperação por e-mail está fora do projeto. Uma sessão aberta num computador alheio continua valendo até o token expirar.
- **Contas sem ciclo de vida.** A situação `INATIVA` existe desde a C1, mas nenhuma tela inativa ou reativa uma conta. Os parâmetros criados na C2 só se alteram pelo painel do Xano.

Esta change (C3) fecha essas lacunas com as regras definidas no explore. Ela reutiliza os padrões da C2: trava por linha, autorização no backend e auditoria na mesma transação.

## What Changes

**Administradores**
- O admin do bootstrap passa a ser o **admin principal**: único, nunca rebaixado nem inativado e não transferível.
- O sistema tem **até 3 admins ativos** (parâmetro novo `max_admins`). Os outros são **admins secundários**.
- **Só o principal** cria, promove, rebaixa, inativa, reativa e redefine a senha de admins:
  - **promover** um coordenador a admin, que perde as coordenações (a unidade pode ficar sem coordenador, e o admin cuida dela);
  - **criar do zero** um admin, com e-mail institucional e **senha provisória**;
  - **rebaixar** um admin secundário **somente a coordenador**, escolhendo 1 ou 2 unidades no mesmo ato. Para chegar a professor, ele segue depois a mudança de papel coordenador → professor da C2. Nunca a aluno.
  - **inativar** um admin secundário é a outra forma de retirá-lo.
- Os admins secundários fazem todo o resto, mas não alteram admins.

**Senha**
- **Trocar minha senha** para todos os usuários. Exige a senha atual, a nova tem no mínimo 8 caracteres e é diferente da atual, e a troca **derruba as outras sessões**: tokens emitidos antes deixam de valer.
- **Senha provisória:** a conta só consegue trocar a senha. Toda outra rota recusa, e isso é garantido no backend.
- **Redefinir senha** pelo admin: define uma senha provisória e derruba as sessões. Qualquer admin pode fazer isso para não-admins; só o principal, para os secundários; a senha do principal só ele mesmo troca.

**Inativação e reativação de contas**
- Só `ATIVA` → `INATIVA` e `INATIVA` → `ATIVA`. Quem pode: qualquer admin para não-admins; só o principal para admins secundários. O **motivo é obrigatório** e fica na auditoria.
- **Coordenador inativado:** mantém o vínculo e deixa de contar. Na reativação:
  - unidades desativadas ou cheias são descartadas;
  - se não sobrar nenhuma, o admin escolhe 1 ou 2 unidades na hora.
- **Professor reativado** cuja unidade foi desativada: o admin escolhe a nova unidade na hora.
- **Admin secundário:** a reativação acima do limite de admins é recusada.

**Parâmetros (só o principal)**
- Tela para editar os domínios de e-mail aceitos, o máximo de coordenadores por unidade, o máximo de unidades por coordenador, o máximo de pedidos de cadastro e o máximo de admins.
- Regras: limites inteiros a partir de 1 e ao menos 1 domínio. Reduzir um limite não remove ninguém. Toda alteração é auditada.

**Frontend:** telas de trocar senha (com redirecionamento obrigatório quando a senha é provisória), gestão de admins, inativação e reativação, redefinição de senha e parâmetros.

**Fora do escopo**
- Recuperação de senha por e-mail e qualquer envio de e-mail ou SMS. A decisão é de fora do projeto; a saída para senha esquecida é a redefinição pelo admin.
- Autenticação em dois fatores.
- Transferir o papel de principal.
- Cancelar as reservas de quem é inativado (regra registrada para a change de reservas).
- Exclusão física de contas.
- Consulta do log de auditoria pela interface (change de painel e relatórios).

## Capabilities

### New Capabilities
- `administradores`: admin principal, limite de admins ativos, promoção de coordenador, criação do zero, rebaixamento e a regra de que só o principal altera admins.
- `senha`: trocar a própria senha, senha provisória com troca obrigatória, redefinição pelo admin e derrubada de sessões.
- `situacao-conta`: inativação e reativação de contas, com motivo obrigatório e conferência das unidades na reativação.
- `parametros`: leitura e edição dos parâmetros pelo admin principal, com validação.

### Modified Capabilities
- `autenticacao`:
  - "Login com token": a resposta informa quando a senha é provisória;
  - "Consulta do usuário atual": tokens emitidos antes da última troca ou redefinição de senha são recusados;
  - "Administrador inicial": o admin do bootstrap é marcado como principal, inclusive o que já existe.
- `coordenacao`: "Unidade sem coordenador ativo" passa a incluir a inativação do último coordenador e a promoção dele a admin.
- `auditoria`: as ações novas desta change.

## Impact

- **Papéis afetados:**
  - Administrador principal: gere os admins e os parâmetros.
  - Administradores secundários: passam a existir; inativam, reativam e redefinem a senha de não-admins.
  - Todos os usuários: trocam a própria senha; as sessões caem após a troca.
  - Coordenador: pode ser promovido a admin, perdendo as coordenações.
- **Regras do `project-overview.md` tocadas:**
  - §4: administradores principal e secundários;
  - §7.10: senha provisória, troca e redefinição;
  - §10: sessões invalidadas pela troca de senha e auditoria das ações novas.
  - O overview e o `domain-model.md` (§2.1 e §2.18, DER) são atualizados nesta change.
- **Xano:**
  - campos novos em `usuario` (principal, senha provisória, início de validade das sessões, motivo de inativação);
  - parâmetro `max_admins`;
  - o login passa a gravar o horário de emissão no token;
  - `usuario_ativo` passa a verificar sessão e senha provisória;
  - rotas novas nos grupos `auth`, `contas` e de parâmetros;
  - `bootstrap` atualizado.
  - Publicação sempre com dry-run e aprovação.
- **Reflex:** cliente, States e páginas novas; o login e a guarda de sessão tratam a senha provisória.
- **Dependências:** nenhuma nova.
