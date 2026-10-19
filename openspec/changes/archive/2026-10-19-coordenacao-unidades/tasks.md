## 1. Preparação e prova da trava

- [x] 1.1 Confirmar a branch `change/coordenacao-unidades`, criada a partir da `main` com a C1, e a disponibilidade do Xano Developer MCP e da skill `reflex-docs`. Verificação: `git branch --show-current` e uma consulta a cada ferramenta respondem.
- [x] 1.2 Confirmar no MCP e na skill os pontos de que o design depende, e registrar as respostas numa seção "Confirmações do apply" do `design.md`:
  - `db.direct_query` dentro de `db.transaction` e o formato de `arg`;
  - `util.sleep` dentro de transação;
  - filtro `to_lower` dentro de `where`;
  - `join` + `eval` para os coordenadores ativos;
  - `throw` e `precondition` desfazendo a transação;
  - na skill `reflex-docs`: substate lendo `_token` do pai, ou `get_state`, e `rx.alert_dialog`/`rx.dialog`.

  Verificação: um trecho de teste validado no MCP para cada construção do Xano; a seção existe, com uma resposta por item.
- [x] 1.3 **Teste de execução da trava (D3)**, antes de qualquer outro código:
  - criar, num grupo de API temporário, uma rota de sonda que abre `db.transaction`, pega a trava e espera alguns segundos com `util.sleep`;
  - publicar com `--dry-run` e aprovação explícita;
  - disparar 2 e 3 chamadas simultâneas e medir: cada uma precisa terminar só depois da anterior;
  - repetir com uma falha forçada depois da trava e confirmar que a próxima chamada não fica presa.

  Primeira tentativa, com `pg_advisory_xact_lock` via `db.direct_query`: recusada (`Access Denied`). Segunda, com trava por linha (`db.edit` numa tabela de sonda): funcionou. D3 foi revisada.

  Verificação: tempos registrados no `design.md`. Depois, desativar a sonda no workspace (push com dry-run e aprovação) e pedir ao usuário que exclua o grupo `sonda_c2` e a tabela `sonda_trava` pelo painel.
- [x] 1.4 Rodar `xano workspace pull` para um diretório temporário fora do repositório e comparar com `./xano/`. Verificação: nenhuma diferença além da sonda já removida; se houver, apresentar ao usuário.

## 2. Xano: dados e parâmetros

- [x] 2.1 Acrescentar a `usuario` os campos opcionais `aprovado_por_id`, `aprovado_em`, `motivo_recusa_cadastro`, `pedidos_cadastro` (padrão 1), `justificativa_cadastro` e `recusa_sem_custo` (padrão falso) (D2). Verificação: `.xs` validado no MCP; nenhum campo existente alterado.
- [x] 2.2 Criar `coordenacao_unidade` (`usuario_id`, `unidade_id`, `desde`) com índice único do par. Verificação: `.xs` validado no MCP.
- [x] 2.3 Acrescentar a `configuracao_geral` os campos `max_coordenadores_unidade`, `max_unidades_coordenador` e `max_pedidos_cadastro`. Verificação: `.xs` validado no MCP.
- [x] 2.4 Criar a tabela técnica `trava` (`nome` único, `usado_em`), conforme D3. Verificação: `.xs` validado no MCP.
- [x] 2.5 Alterar o `bootstrap` para preencher, só onde estiverem vazios, os três parâmetros (4, 2, 3) e `pedidos_cadastro = 1`, e para criar a linha `"governanca"` da tabela `trava`, mantendo a idempotência. Verificação: `.xs` validado no MCP.

## 3. Xano: funções

- [x] 3.1 Criar `travar_governanca` (D3/D5): `db.edit` na linha `"governanca"` da tabela `trava`, com erro de configuração se a linha não existir. Verificação: `.xs` validado no MCP.
- [x] 3.2 Criar `exigir_admin`, `unidades_coordenadas`, `autorizar_unidade` e `coordenadores_ativos` (D5). Verificação: `.xs` validados no MCP.
- [x] 3.3 Extrair do `login` a função `conferir_credenciais` (D7): normaliza o e-mail, confere a senha e devolve o usuário ou o 401 genérico. Verificação: `.xs` validado no MCP; o comportamento de `login` não muda nesta tarefa.

## 4. Xano: grupo `auth`

- [x] 4.1 Alterar `cadastro`: aceitar `COORDENADOR` com unidade ativa obrigatória, recusar `ADMIN`, gravar `pedidos_cadastro = 1` e mudar a mensagem do coordenador para "aguarda aprovação da administração". Verificação: `.xs` validado no MCP.
- [x] 4.2 Alterar `login` para usar `conferir_credenciais` e acrescentar o ramo `RECUSADA` com o motivo (D7, spec `autenticacao`). Verificação: `.xs` validado no MCP.
- [x] 4.3 Criar `POST /situacao_pedido` (D7). Ela responde só para `PENDENTE` e `RECUSADA` e devolve 401 genérico nos demais casos. Verificação: `.xs` validado no MCP.
- [x] 4.4 Criar `POST /reenviar_pedido` (D7), dentro da trava: limite de pedidos, troca de papel e unidade, justificativa de até 500 caracteres e auditoria `REENVIAR_CADASTRO`. Verificação: `.xs` validado no MCP.

## 5. Xano: grupo `contas`

- [x] 5.1 Criar o grupo `contas` (canonical `bookingsystem-contas`). Verificação: `.xs` validado no MCP.
- [x] 5.2 Criar `GET /pedidos` (D4). O admin vê `PENDENTE` e `RECUSADA`; o coordenador vê só professores `PENDENTE` do escopo; os demais recebem 403. Verificação: `.xs` validado no MCP.
- [x] 5.3 Criar `POST /aprovar` e `POST /recusar` (D6), dentro da trava: permissões por papel pedido, vaga e unidade ativa para coordenador, "já decidido" e auditoria. Verificação: `.xs` validado no MCP.
- [x] 5.4 Criar `GET /usuarios` (só admin), com filtros e as unidades coordenadas de cada usuário, sem senha. Verificação: `.xs` validado no MCP.
- [x] 5.5 Criar `POST /alterar_papel` (D8), dentro da trava: unidades obrigatórias ao virar coordenador, unidade obrigatória ao virar professor, unidade limpa ao virar coordenador, só as direções permitidas (nunca para aluno), remoção das coordenações ao deixar de ser coordenador e bloqueio de `ADMIN`. Verificação: `.xs` validado no MCP.
- [x] 5.6 Criar `POST /transferir_professor` (D9), dentro da trava: só admin, alvo `PROFESSOR` `ATIVA`, destino ativo e diferente do atual, auditoria `TRANSFERIR_PROFESSOR`. Verificação: `.xs` validado no MCP.

## 6. Xano: grupo `unidades`

- [x] 6.1 Criar `GET /geridas` (D10), com os coordenadores ativos, os professores (para o admin), a contagem de pedidos pendentes e o indicador `sem_coordenador`. Verificação: `.xs` validado no MCP.
- [x] 6.2 Criar `POST /acrescentar_coordenador`, `POST /mover_coordenador` e `POST /remover_coordenador` (D9), dentro da trava. Verificação: `.xs` validados no MCP.
- [x] 6.3 Criar `POST /criar` e `POST /editar` (D10): nome único sem diferenciar caixa, coordenador obrigatório com o modo mover ou acrescentar, tudo dentro da trava. Verificação: `.xs` validados no MCP.
- [x] 6.4 Criar `POST /desativar` e `POST /reativar` (D10):
  - destinos obrigatórios para coordenadores (com vaga, considerando o próprio formulário) e para professores;
  - recusa automática dos pedidos pendentes, com `recusa_sem_custo`;
  - operação repetida recusada sem auditoria.

  Verificação: `.xs` validados no MCP; `GET /ativas` sem alteração.

## 7. Xano: publicação

- [x] 7.1 Rodar `xano workspace push -d ./xano --dry-run` (parcial, sem `--sync`, `--delete`, `--env` ou `--records`), mostrar o resultado e fazer o push **só com aprovação explícita**. Executar o `bootstrap` duas vezes. Verificação: o push conclui sem erro; os parâmetros ficam 4/2/3; as contas existentes ficam com `pedidos_cadastro = 1`; existe exatamente uma linha `"governanca"` em `trava`; a segunda execução não altera nada; o `pull` seguinte não mostra diferenças.

## 8. Xano: verificação das specs por chamadas à API

Executar contra o workspace, com script descartável fora do repositório. Preparar os dados pela própria API (cadastro e aprovação). Registrar os resultados para o relatório.

- [x] 8.1 Cadastro e situação:
  - coordenador com unidade ativa → `PENDENTE`, sem coordenação;
  - coordenador sem unidade ou com unidade inativa → 400;
  - vínculo `ADMIN` → 400;
  - `status_conta=ATIVA` extra → continua `PENDENTE`;
  - `situacao_pedido` com senha errada, e-mail inexistente ou conta `ATIVA` → o mesmo 401 genérico.
- [x] 8.2 Aprovação:
  - o admin aprova o primeiro coordenador de "Paulista" (que está vazia) → ele coordena "Paulista";
  - esse coordenador aprova um professor de "Paulista" → aceito;
  - o mesmo coordenador tenta aprovar um professor de "Vila Olímpia" → 403;
  - o mesmo coordenador tenta aprovar um coordenador → 403;
  - aprovar um coordenador numa unidade cheia (parâmetro reduzido temporariamente para o teste) → 400, sem mudança;
  - aprovar (como admin) uma conta `RECUSADA` cuja unidade pedida está desativada, de professor ou de coordenador → 400;
  - o professor aprovado passa a ter a unidade pedida como unidade dele.
- [x] 8.3 Recusa e reenvio:
  - recusa sem motivo ou só com espaços → 400;
  - recusa com motivo → o login dá 403 com o motivo, e a mesma senha errada dá 401 genérico;
  - `situacao_pedido` → 2 pedidos restantes;
  - reenvio trocando unidade e papel → `PENDENTE`, `pedidos_cadastro = 2`, motivo limpo e auditoria com antes e depois;
  - terceiro pedido recusado → um novo reenvio dá 400 "procure a administração";
  - reenvio de conta `PENDENTE` ou `ATIVA` → 400;
  - o coordenador tenta aprovar uma conta `RECUSADA` → 403; o admin aprova → `ATIVA`.
- [x] 8.3b Recusa automática sem custo:
  - desativar uma unidade com um pedido pendente de professor (1 pedido) e outro de coordenador (3 pedidos, no limite) → os dois ficam `RECUSADA`, com o motivo "Unidade desativada";
  - `situacao_pedido` dos dois mostra pedidos restantes ≥ 1;
  - o reenvio do professor para uma unidade ativa → `PENDENTE`, `pedidos_cadastro` continua 1;
  - o reenvio do coordenador → aceito, apesar do limite, e `pedidos_cadastro` continua 3;
  - uma nova recusa manual do coordenador → um novo reenvio dá 400 (limite).
- [x] 8.4 **Concorrência na decisão:** aprovação (admin) e recusa (coordenador) simultâneas para o mesmo professor, repetido de 2 a 5 vezes com contas novas. Verificação: cada conta termina numa única situação, com exatamente um registro de decisão; o perdedor recebe "já foi decidido".
- [x] 8.5 Papéis:
  - aluno → professor sem unidade, ou com unidade desativada → 400;
  - aluno → professor com unidade → professor daquela unidade;
  - professor ou coordenador → aluno → 400, nada muda;
  - aluno → coordenador direto → 400, nada muda;
  - conta `PENDENTE` → 400;
  - mesmo papel → 400;
  - para `ADMIN`, ou alterar um `ADMIN` → 400;
  - coordenador tentando alterar papel → 403;
  - professor → coordenador sem unidades → 400;
  - professor → coordenador com uma unidade sem vaga → 400, nada muda;
  - professor → coordenador com 2 unidades válidas → coordena as duas;
  - o coordenador único de uma unidade → professor com uma unidade → aceito, ele passa a pertencer a ela, a unidade fica `sem_coordenador`, a resposta lista as coordenações removidas, e o token antigo dele recebe 403 em `/pedidos`.
  - Transferência:
    - professor para outra unidade ativa → aceito, com auditoria;
    - para unidade desativada ou para a mesma → 400;
    - alvo aluno ou coordenador → 400;
    - coordenador tentando transferir → 403.
- [x] 8.6 Coordenação:
  - acrescentar até o limite de 2 unidades por coordenador; a terceira → 400;
  - mover com a origem coberta → aceito;
  - mover o único coordenador → 400;
  - remover a única unidade → 400;
  - remover a segunda unidade com cobertura → aceito;
  - destino desativado ou já coordenado → 400.
  - **Concorrência:** com uma unidade a 1 vaga do limite, 2 a 5 acréscimos simultâneos de coordenadores diferentes. Verificação: a unidade termina exatamente no limite.
- [x] 8.7 Unidades:
  - criar movendo, com a origem coberta → aceito;
  - criar movendo o único coordenador → 400 e nada criado;
  - criar acrescentando → aceito;
  - criar sem coordenador, com nome repetido (" paulista ") ou sem endereço → 400;
  - editar o endereço → auditoria;
  - renomear para nome existente → 400;
  - desativar sem destino para um coordenador que só tem a unidade, ou para um professor dela → 400 e nada muda;
  - desativar com destinos → coordenações refeitas, professores transferidos, pedidos pendentes recusados automaticamente e a unidade some de `/ativas`;
  - desativar de novo → 400 sem auditoria;
  - reativar → volta a `/ativas`, `sem_coordenador` e sem professores;
  - coordenador tentando criar → 403;
  - `/geridas` do coordenador mostra só as dele.
- [x] 8.8 Autorização: aluno e professor chamando cada rota de `contas` e de unidades geridas → 403; sem token → 401.
- [x] 8.9 Auditoria:
  - cada ação bem-sucedida de 8.2 a 8.7 gerou os registros da tabela da spec `auditoria`, com ator e unidade corretos;
  - nenhuma tentativa recusada gerou registro;
  - nenhum `dados_*` contém senha ou hash.
- [x] 8.10 Rollback: forçar temporariamente uma falha na auditoria de `desativar` (push com dry-run e aprovação) e confirmar que a unidade e as coordenações não mudaram; desfazer com novo push. Se não for viável forçar a falha, registrar como **não testado**, com o motivo.

## 9. Reflex: cliente e States

- [x] 9.1 Acrescentar a `xano_cliente.py` as funções de pedido, `contas` e unidades (D4), e `XANO_API_CONTAS_URL` ao `.env.example`, sem logar token nem senha. Verificação: um script descartável com o `.venv` ativo chama cada função e recebe o resultado ou a exceção esperada.
- [x] 9.2 Acrescentar ao `AuthState` as vars de papel e a guarda de página por papel. Criar `PedidoState`, `ContasState` e `UnidadesState` (D12). Verificação: `reflex run` compila sem erro.

## 10. Reflex: páginas

- [x] 10.1 Criar `pages/layout.py` com o menu por papel e passar `/inicio` a usá-lo. Verificação: aluno, coordenador e admin veem exatamente os itens da spec `autorizacao`.
- [x] 10.2 Alterar `/cadastro` (opção Coordenador com unidade) e `/login` (painel de recusa com motivo, "Pedir nova análise" ou aviso de pedidos esgotados). Verificação: os fluxos de cadastro de coordenador, recusa, reenvio e esgotamento funcionam pela tela, e a senha não é guardada no State.
- [x] 10.3 Criar `/aprovacoes`: pedidos, aprovar, recusar com motivo obrigatório e, para o admin, as contas recusadas. Verificação: as mensagens da API aparecem e a lista recarrega; a recusa sem motivo não é enviada.
- [x] 10.4 Criar `/usuarios`: filtros, mudança de papel (1 ou 2 unidades para coordenador, 1 unidade para professor), aviso de perda de coordenação e "Transferir" para professores. Verificação: o aviso lista as unidades antes de enviar, e a transferência reflete na lista.
- [x] 10.5 Criar `/unidades`:
  - criar (coordenador, mover ou acrescentar), editar e reativar;
  - desativar, com destinos para coordenadores e professores e o aviso de pedidos pendentes que serão recusados;
  - acrescentar/mover/remover coordenação;
  - destaque de "sem coordenador".

  Verificação: cada ação reflete na lista com a mensagem da API.
- [x] 10.6 Registrar as páginas em `bookingSystem.py` com a guarda por papel. Verificação: o aluno que abre `/unidades` direto vai para `/inicio`.

## 11. Documentação, verificação integrada e entrega

- [x] 11.1 Atualizar `docs/project-overview.md` e `docs/domain-model.md` conforme D13. Verificação: as seções citadas refletem as regras desta change, e o `git diff` dos documentos é mostrado ao usuário.
- [x] 11.2 Fluxo completo no navegador:
  - coordenador se cadastra em "Paulista" → o admin aprova → o coordenador aprova um professor;
  - outro professor é recusado → vê o motivo → pede nova análise trocando a unidade → é aprovado;
  - o admin cria "Centro" movendo um coordenador e transfere um professor para "Centro";
  - um professor faz um pedido para "Centro", e o admin desativa "Centro" com destinos → o pedido é recusado automaticamente, o titular vê "Unidade desativada" e reenvia sem consumir pedido.

  Verificação: todos os passos se comportam como nas specs.
- [x] 11.3 Papel alterado durante a sessão: com o coordenador logado, o admin muda o papel dele em outra sessão. Verificação: o menu dele passa a mostrar só "Início" e `/aprovacoes` redireciona.
- [x] 11.4 Token e senha não chegam ao navegador: inspecionar cookies, `localStorage`, `sessionStorage` e o websocket durante o login, a recusa e o reenvio. Verificação: nenhum dos dois aparece.
- [x] 11.5 Revisar o código: PEP 8, sem `print`, sem código morto, sem segredo versionado e sem a sonda da 1.3. Verificação: `git diff` mostrado ao usuário antes do commit.
- [x] 11.6 Relatório final: o que foi testado, o que não foi (com o motivo), as divergências do DER e o resultado do teste da trava. Verificação: relatório entregue ao usuário.
