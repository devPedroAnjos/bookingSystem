## 1. Preparação e prova do token

- [x] 1.1 Confirmar a branch `change/contas-admins-senha` (a partir da `main` com a C2) e rodar `xano workspace pull` para um diretório temporário, comparando com `./xano/`. Verificação: nenhuma diferença; se houver, apresentar ao usuário.
- [x] 1.2 **Sonda do token (D3)**, antes de qualquer outro código:
  - num grupo temporário, uma rota pública emite um token com `extras = {emitido_em: now}` para o admin informado;
  - outra rota autenticada devolve `$auth.emitido_em` lido na própria rota **e** dentro de uma função chamada por ela;
  - publicar a partir do scratchpad com dry-run e aprovação, chamar e registrar o resultado no `design.md`;
  - depois, desativar o grupo e pedir ao usuário que exclua a sonda pelo painel.

  Verificação: se (b) falhar, adotar a forma alternativa de D3 e anotá-la no design; **se (a) falhar, parar e pedir revisão da change**.

  Resultado: (a) funciona via `$auth.extras.emitido_em`, com leitura segura `($auth.extras|get:"emitido_em")|first_notnull:0`; (b) falhou, então foi adotada a forma alternativa (D3 revisado).

## 2. Xano: dados

- [x] 2.1 Acrescentar a `usuario` os campos opcionais `admin_principal` (bool), `senha_provisoria` (bool) e `sessoes_validas_desde` (int), sem padrão `false`. Verificação: `.xs` validado no MCP.
- [x] 2.2 Acrescentar `max_admins` a `configuracao_geral` e incluí-lo em `obter_configuracao`. Verificação: `.xs` validados no MCP.
- [x] 2.3 Alterar o `bootstrap` (D10): `max_admins = 3` onde estiver vazio, marcar como principal o admin ativo mais antigo quando não houver principal, e criar o primeiro admin já principal. Verificação: `.xs` validado no MCP.

## 3. Xano: funções

- [x] 3.1 Alterar `usuario_ativo` (D3, D4): recusar token anterior a `sessoes_validas_desde` (401) e senha provisória sem `permite_senha_provisoria == true` (403); devolver também `admin_principal` e `senha_provisoria`. Se a 1.2 indicar a forma alternativa, atualizar as funções e rotas que chamam `usuario_ativo`. Verificação: `.xs` validados no MCP.
- [x] 3.2 Criar `exigir_principal`, `autorizar_sobre_conta` (D5) e `vaga_de_admin` (D6). Verificação: `.xs` validados no MCP.
- [x] 3.3 Extrair do `cadastro` a função `validar_email_institucional`, usada pelo cadastro e pela criação de admin, sem mudar o comportamento do cadastro. Verificação: `.xs` validados no MCP.

## 4. Xano: rotas de autenticação e senha

- [x] 4.1 Alterar `login`: `extras = {emitido_em: now}` e `senha_provisoria` na resposta. Alterar `me` para passar `permite_senha_provisoria`. Verificação: `.xs` validados no MCP.
- [x] 4.2 Criar `POST /auth/trocar_senha` (D8): senha atual, nova válida e diferente, `sessoes_validas_desde`, token novo e auditoria `TROCAR_SENHA`. Verificação: `.xs` validado no MCP.
- [x] 4.3 Criar `POST /contas/redefinir_senha` (D8, D5), dentro da trava, com auditoria `REDEFINIR_SENHA`. Verificação: `.xs` validado no MCP.

## 5. Xano: administradores, situação de conta e parâmetros

- [x] 5.1 Criar `GET /contas/admins` (principal) e `POST /contas/promover_admin`, `POST /contas/criar_admin`, `POST /contas/rebaixar_admin` (D6), dentro da trava e com auditoria. Verificação: `.xs` validados no MCP.
- [x] 5.2 Criar `POST /contas/inativar` e `POST /contas/reativar` (D7), com a conferência de unidades na reativação e auditoria. Verificação: `.xs` validados no MCP.
- [x] 5.3 Criar `GET /contas/parametros` e `POST /contas/parametros` (D9), com validação e auditoria `ALTERAR_PARAMETROS`. Verificação: `.xs` validados no MCP.
- [x] 5.4 Incluir `admin_principal` em `GET /contas/usuarios`, para a tela saber quem é o principal. Verificação: `.xs` validado no MCP.

## 6. Xano: publicação

- [x] 6.1 Rodar `xano workspace push -d ./xano --dry-run`, mostrar o resultado e fazer o push **só com aprovação explícita**. Executar o `bootstrap` duas vezes. Fazer pull e comparar, ignorando espaços, para pegar padrões descartados. Verificação: o admin da C1 é o principal, `max_admins = 3`, a segunda execução não altera nada e o pull bate com `./xano/`.

## 7. Xano: verificação das specs por chamadas à API

Script descartável fora do repositório, com controle de ritmo (10 requisições a cada 20 s). As credenciais vêm do `.env` e não são impressas.

- [x] 7.1 Senha:
  - trocar com a senha atual errada, com a nova curta ou com a nova igual à atual → 400;
  - troca válida → token novo funciona, e um token antigo da mesma conta (segunda sessão) recebe 401 no `me` e numa rota de gestão;
  - tokens anteriores à change continuam valendo até a primeira troca.
- [x] 7.2 Senha provisória e redefinição:
  - admin criado do zero entra, e qualquer rota de gestão dá 403 "Troque sua senha para continuar.", mas o `me` funciona;
  - depois da troca, tudo funciona;
  - secundário redefine a senha de um professor → o professor tem senha provisória e a sessão dele cai;
  - secundário redefine a senha de outro admin → 403;
  - qualquer admin redefine a senha do principal → 400;
  - coordenador redefine → 403.
- [x] 7.3 Administradores:
  - promover um coordenador de 2 unidades → admin, coordenações removidas e listadas, unidade sem coordenador;
  - promover professor ou aluno → 400;
  - criar admin com domínio inválido ou e-mail repetido → 400;
  - criar e promover acima do limite → 400;
  - rebaixar a coordenador: sem unidade → 400, com unidade lotada → 400, válido → coordena;
  - rebaixar direto a professor ou a aluno → 400;
  - o ex-admin, já coordenador, vira professor pela `alterar_papel` da C2 → aceito;
  - secundário promove, cria ou rebaixa → 403;
  - mexer no principal → 400.
  - **Concorrência:** com 2 admins ativos e limite 3, duas promoções simultâneas → no máximo 3 admins ativos.
- [x] 7.4 Inativação e reativação:
  - inativar sem motivo → 400;
  - inativar conta pendente → 400;
  - coordenador inativa → 403;
  - inativar professor logado → a próxima requisição dele dá 401 e o login com a senha correta dá 403 sem o motivo;
  - inativar o único coordenador de uma unidade → coordenação mantida e unidade `sem_coordenador`;
  - reativar coordenador com uma unidade lotada → volta só com a outra; com a única unidade desativada → sem `unidades_ids` 400, com → coordena;
  - reativar professor com unidade desativada → sem `unidade_id` 400, com → nova unidade;
  - reativar admin acima do limite → 400;
  - secundário inativa admin → 403.
- [x] 7.5 Parâmetros:
  - secundário lê ou edita → 403;
  - principal grava limite 0 ou lista de domínios vazia → 400 e nada muda;
  - reduzir o máximo de coordenadores abaixo do atual → aceito, ninguém removido, novo acréscimo recusado;
  - restaurar os valores no fim.
- [x] 7.6 Auditoria: cada ação bem-sucedida de 7.1 a 7.5 gerou o registro da spec `auditoria`, nenhum registro tem senha, hash ou token e nenhuma tentativa recusada gerou registro. Usar uma função temporária de leitura do log, como na C2, com push aprovado e exclusão depois.

## 8. Reflex

- [x] 8.1 Acrescentar ao `xano_cliente.py` as funções novas (trocar senha, redefinir, admins, inativar, reativar e parâmetros). Verificação: um script descartável chama cada uma contra o workspace.
- [x] 8.2 Atualizar o `AuthState` (D11): `senha_provisoria`, `e_principal`, guarda para `/trocar-senha`, substituição do token após a troca e tratamento de "Troque sua senha para continuar.". Criar `SenhaState`, `AdminsState` e `ParametrosState`. Verificação: `reflex compile --dry`.
- [x] 8.3 Criar `/trocar-senha` e ajustar o menu (provisória: só trocar senha e sair; principal: administradores e parâmetros). Verificação: `reflex compile --dry`.
- [x] 8.4 Criar `/administradores` e `/parametros`, e acrescentar a `/usuarios` inativar (motivo), reativar (pedindo unidades quando preciso) e redefinir senha. Registrar as páginas com guarda por papel. Verificação: `reflex compile --dry` e checagem de nomes sem uso.

## 9. Documentação, verificação no navegador e entrega

- [x] 9.1 Atualizar `docs/project-overview.md` e `docs/domain-model.md` (D12) e mostrar o diff ao usuário.
- [x] 9.2 Verificação manual (usuário):
  - criar um admin do zero → primeiro login leva a trocar senha e o menu fica restrito;
  - trocar a senha numa aba → a outra aba cai para o login;
  - promover, rebaixar, inativar e reativar pela tela;
  - redefinir a senha de um professor;
  - alterar um parâmetro;
  - admin secundário não vê "Administradores" nem "Parâmetros".
- [x] 9.3 Verificar no DevTools que nem o token do Xano nem as senhas (atual, nova e provisória) chegam ao navegador. Verificação: confirmação do usuário.
- [x] 9.4 Revisar o código: PEP 8, sem `print`, sem código morto, sem segredo e sem sonda. Mostrar o `git diff` antes de commitar.
- [x] 9.5 Relatório final: o que foi testado, o que não foi, as divergências do DER e o resultado da sonda do token.
