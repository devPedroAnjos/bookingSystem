## 1. Preparação

- [x] 1.1 Criar a branch `change/tipos-espacos-recursos` a partir da `main` e rodar `xano workspace pull` para um diretório temporário, comparando com `./xano/`. Verificação: nenhuma diferença; se houver, apresentar ao usuário antes de seguir.
- [x] 1.2 Confirmar no Xano Developer MCP, antes de escrever as tabelas e as rotas:
  - a sintaxe de índice único composto (`espaco (unidade_id, codigo)` e `espaco_recurso (espaco_id, recurso_id)`);
  - a forma de apagar e regravar as linhas de `espaco_recurso` de um espaço (resultado em "Confirmações do apply");
  - a forma de contar unidades distintas dos espaços ativos de um tipo (D6).

  Verificação: resultado anotado em "Confirmações do apply" no `design.md`. Se o índice composto não existir, seguir com a unicidade só na rota, sob a trava (Risks), e registrar no `decisions-log.md`.

## 2. Xano: dados

- [x] 2.1 Criar as tabelas `tipo_espaco` (`nome`, `descricao`, `ativo?=true`, índice único em `nome`) e `recurso` (`nome`, índice único em `nome`), com `trim` nos textos (D2). Verificação: `.xs` validados no MCP.
- [x] 2.2 Criar as tabelas `espaco` (FKs para `unidade` e `tipo_espaco`, `nome`, `codigo`, `capacidade`, `localizacao`, `descricao`, `ativo?=true`, índice único em `unidade_id` + `codigo`) e `espaco_recurso` (`espaco_id`, `recurso_id`, `quantidade`, índice único no par) (D2). Verificação: `.xs` validados no MCP.
- [x] 2.3 Alterar o `bootstrap` (D9): criar os quatro tipos iniciais só quando `tipo_espaco` estiver vazia, sem auditoria, e devolver `tipos_criados`. Verificação: `.xs` validado no MCP.

## 3. Xano: funções

- [x] 3.1 Criar `exigir_nome_tipo_livre`, `exigir_nome_recurso_livre` e `exigir_codigo_livre` (D5), no molde de `exigir_nome_unidade_livre`. Verificação: `.xs` validados no MCP.
- [x] 3.2 Criar `carregar_espaco_gerido` (D4): 404 só para o admin; para o coordenador, espaço inexistente ou fora do escopo dá 403 com a mesma mensagem. Verificação: `.xs` validado no MCP.
- [x] 3.3 Criar `disponibilidade_espaco` (D8), recebendo espaço, unidade e tipo já carregados e devolvendo `{reservavel, motivos}`. Verificação: `.xs` validado no MCP.

## 4. Xano: rotas do grupo `espacos`

- [x] 4.1 Criar o grupo `espacos` e as rotas de tipos: `GET tipos` (gestor; contagens só para o admin), `criar_tipo`, `editar_tipo`, `desativar_tipo` e `reativar_tipo` (admin), com trava, validações de D2/D3 e auditoria. Verificação: `.xs` validados no MCP.
- [x] 4.2 Criar as rotas de recursos: `GET recursos` (gestor; uso só para o admin), `criar_recurso`, `editar_recurso` e `excluir_recurso` (admin; recusa com a contagem quando em uso), com trava e auditoria. Verificação: `.xs` validados no MCP.
- [x] 4.3 Criar `GET geridos` (D8): escopo por papel, uma consulta por tabela, junção em memória, `disponibilidade_espaco` em cada item e ordem por unidade e código. Verificação: `.xs` validado no MCP.
- [x] 4.4 Criar `criar_espaco` e `editar_espaco` (D4, D6): unidade ativa e tipo ativo na criação; tipo ativo só quando o tipo muda na edição; código livre na unidade; a edição não aceita `unidade_id` nem `ativo`. Verificação: `.xs` validados no MCP.
- [x] 4.5 Criar `definir_recursos` (D7): formato antes da trava, recursos relidos dentro dela, substituição da lista e auditoria `ALTERAR_RECURSOS_ESPACO` com as listas antes e depois. Verificação: `.xs` validado no MCP.
- [x] 4.6 Criar `desativar_espaco`, `reativar_espaco` (gestor com escopo) e `mover_espaco` (admin; destino existente, ativo, diferente e com código livre), com auditoria. Verificação: `.xs` validados no MCP.

## 5. Xano: publicação

- [x] 5.1 Rodar `xano workspace push -d ./xano --dry-run`, mostrar o resultado e fazer o push **só com aprovação explícita**. Executar o `bootstrap` duas vezes e fazer pull para comparar, ignorando espaços, a fim de pegar padrões descartados. Verificação: os quatro tipos existem, ativos; a segunda execução não cria nada; o pull bate com `./xano/`.

## 6. Xano: verificação das specs por chamadas à API

Script descartável fora do repositório, com controle de ritmo (10 requisições a cada 20 s). As credenciais vêm do `.env` e não são impressas. Como espaços, tipos e unidades nunca são excluídos, os dados de teste usam o prefixo `TST-` no código ou no nome e terminam desativados. Os recursos de teste são excluídos. No fim, informar ao usuário o que ficou no sandbox.

- [x] 6.0 Checar se objetos que o Xano grava em modo expressão (entre crases) perdem chaves em execução (observação da 5.1: `principal_marcado` ausente na resposta do bootstrap):
  - `definir_recursos` com uma lista válida (1 recurso, quantidade 2) → aceito;
  - `geridos` devolve `motivos` em cada espaço e `quantidade` em cada recurso;
  - o registro `ALTERAR_RECURSOS_ESPACO` traz `quantidade` nas listas antes e depois;
  - só leitura, como admin: `GET contas/usuarios` traz `senha_provisoria` e `GET contas/pedidos` traz `criado_em`.

  Verificação: se tudo vier certo, a falha do bootstrap é isolada e fica registrada. Se faltar alguma chave, parar: corrigir as rotas da C4 com novo dry-run e aprovação, e levar ao usuário a decisão sobre as rotas da C2 e da C3.
- [x] 6.1 Tipos:
  - criar, renomear e alterar a descrição → aceito;
  - nome vazio, repetido com outra caixa ou renome para nome existente → 400;
  - desativar ou reativar duas vezes → 400 sem auditoria;
  - coordenador cria ou desativa → 403;
  - coordenador lista → todos os tipos, sem contagens;
  - professor lista → 403.
- [x] 6.2 Recursos:
  - criar e renomear → aceito;
  - nome vazio, repetido ou renome para nome existente → 400;
  - excluir sem uso → aceito;
  - excluir recurso usado só por espaço desativado → 400 com a contagem;
  - coordenador cria ou exclui → 403;
  - aluno lista → 403.
- [x] 6.3 Criação e edição de espaço:
  - coordenador cria na própria unidade → aceito; em outra → 403; professor → 403;
  - mesmo código em outra unidade → aceito; mesmo código com outra caixa na mesma unidade, inclusive de espaço desativado → 400;
  - unidade desativada, tipo desativado ou capacidade 0 → 400;
  - trocar para tipo ativo → aceito; para tipo desativado → 400;
  - editar outro campo de espaço cujo tipo está desativado → aceito;
  - código repetido na edição → 400;
  - coordenador edita espaço de outra unidade ou um id inexistente → 403 com a mesma mensagem; admin com id inexistente → 404;
  - admin edita espaço de unidade desativada → aceito.
- [x] 6.4 Recursos do espaço:
  - definir lista válida e depois lista vazia → aceito, refletido em `geridos`;
  - trocar uma lista não vazia por outra não vazia → em `geridos`, só a nova ficou;
  - recurso repetido, quantidade 0, item sem quantidade ou recurso inexistente → 400 e nada muda;
  - coordenador em espaço de outra unidade → 403.
- [x] 6.5 Situação, mudança de unidade e disponibilidade:
  - desativar e reativar espaço → aceito; repetir → 400; professor desativa → 403;
  - reativar espaço de tipo desativado → ativo, `reservavel = false`, motivo `TIPO_DESATIVADO`;
  - mover: admin → aceito, com tipo, situação e recursos mantidos; código existente no destino, destino desativado ou destino igual ao atual → 400; coordenador de origem e destino → 403;
  - mover espaço de tipo desativado para unidade ativa → aceito e continua não reservável;
  - desativar uma unidade de teste com espaço ativo → espaço continua ativo, `reservavel = false`, motivo `UNIDADE_DESATIVADA`; reativar a unidade → reservável de novo, sem ação sobre o espaço;
  - espaço desativado de unidade e tipo desativados → os três motivos.
- [x] 6.6 Concorrência:
  - duas criações simultâneas com o mesmo código na mesma unidade → só uma é criada;
  - exclusão de um recurso sem uso simultânea com a associação dele a um espaço → uma das duas é recusada e nenhum espaço aponta para recurso inexistente.
- [x] 6.7 Auditoria: cada ação bem-sucedida de 6.1 a 6.6 gerou o registro da spec `auditoria`, com a unidade certa (vazia para tipos e recursos; destino em `MOVER_ESPACO`, com a origem nos dados antes). Nenhuma tentativa recusada gerou registro, e o bootstrap não gerou registro dos tipos. Usar uma função temporária de leitura do log, como na C2 e na C3, com push aprovado e exclusão depois.

## 7. Reflex

- [x] 7.1 Acrescentar ao `xano_cliente.py` a constante `XANO_API_ESPACOS_URL` e uma função por rota do grupo `espacos` (D10); incluir a variável no `.env.example` e pedir ao usuário que a preencha no `.env`. Verificação: um script descartável chama cada função de leitura contra o workspace.
- [x] 7.2 Criar `TiposEspacoState`, `RecursosState` e `EspacosState` (D10), com token via `get_state(AuthState)` e erros pelo tratamento comum. Verificação: `reflex compile --dry`.
- [x] 7.3 Criar as páginas `/tipos-espaco` (aviso de N espaços de M unidades na desativação) e `/recursos` (exclusão só sem uso), com tamanho máximo nos campos igual ao de D2. Verificação: `reflex compile --dry`.
- [x] 7.4 Criar a página `/espacos`:
  - filtro por unidade;
  - destaque e motivo dos não reserváveis;
  - criar e editar só com unidades ativas e tipos ativos, com o tipo atual visível mesmo desativado;
  - diálogo de recursos;
  - desativar e reativar;
  - mover só para admin.

  Verificação: `reflex compile --dry`.
- [x] 7.5 Registrar as páginas com guarda (`exigir_gestor` para `/espacos`, `exigir_admin` para as outras duas) e atualizar o menu em `layout.py` conforme a spec `autorizacao`. Verificação: `reflex compile --dry` e checagem de nomes sem uso.

## 8. Documentação, verificação no navegador e entrega

- [x] 8.1 Atualizar `docs/domain-model.md` e `docs/project-overview.md` (D11) e mostrar o diff ao usuário.
- [x] 8.2 Verificação manual (usuário):
  - o menu do admin, do admin secundário, do coordenador e do professor confere com a spec `autorizacao`;
  - o coordenador abre `/tipos-espaco` pelo endereço e volta para "Início";
  - criar tipo, recurso e espaço pela tela; definir os recursos;
  - desativar um tipo, ver o aviso e o destaque na tela de espaços;
  - editar um espaço de tipo desativado sem que o campo de tipo apareça vazio;
  - abrir "Editar" em dois espaços seguidos (um deles de tipo desativado) → nome, código, capacidade e tipo mudam a cada abertura;
  - abrir "Recursos" em dois espaços seguidos → as quantidades mudam a cada abertura;
  - criar espaço sem escolher o tipo → a mensagem de erro aparece. Se ficar escondida pelo diálogo, mostrar o erro dentro do diálogo, como em `acoes_conta.py` (C3), e registrar no `decisions-log.md`;
  - mover um espaço como admin.
- [x] 8.3 Verificar no DevTools que o token do Xano não chega ao navegador. Verificação: confirmação do usuário.
- [x] 8.4 Revisar o código: PEP 8, sem `print`, sem código morto, sem segredo e sem a função temporária de auditoria. Mostrar o `git diff` antes de commitar.
- [x] 8.5 Pedir ao `change-guardian` o relatório em MODO REVISÃO FINAL e mostrá-lo ao usuário antes de qualquer commit ou push.
- [x] 8.6 Relatório final:
  - o que foi testado e o que não foi;
  - a divergência do DER (código por unidade e campos de regra adiados);
  - os dados de teste que ficaram no sandbox;
  - os casos de borda do AGENTS.md §9 que não se aplicam a esta change (horários, prazos, fila, check-in e prioridade), com o motivo.
