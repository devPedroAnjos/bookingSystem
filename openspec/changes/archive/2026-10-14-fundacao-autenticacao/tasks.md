## 1. Preparação e confirmações no MCP

- [x] 1.1 Confirmar que o Xano Developer MCP está carregado na sessão (`/mcp` lista `xano` com ferramentas). Verificação: as ferramentas do MCP respondem a uma consulta de documentação.
- [x] 1.2 Confirmar no MCP cada ponto marcado "(confirmar no MCP)" no `design.md` e registrar as respostas em uma seção "Confirmações do apply" no próprio `design.md`. Os pontos são:
  - tipo de campo de senha e autenticação nativa (nome do campo e verificação de senha);
  - campo do tipo lista de texto;
  - índice único;
  - enum;
  - transação com rollback;
  - criação de token com duração;
  - leitura de variável de ambiente;
  - execução manual de função;
  - URLs de API do workspace.

  Verificação: a seção existe, com uma resposta por item. Se a transação com rollback não existir, ou se algo mudar uma spec, **parar e pedir revisão da change**.
- [x] 1.3 Rodar `xano workspace pull` para um diretório temporário, fora do repositório, e comparar com `./xano/`. Verificação: nenhum objeto do workspace está ausente localmente; se houver, apresentar ao usuário antes de seguir.

## 2. Xano: tabelas

- [x] 2.1 Criar a tabela `configuracao_geral` com `id` e `dominios_email`, conforme D2. Verificação: `.xs` validado no MCP.
- [x] 2.2 Criar a tabela `unidade` (`nome` único, `endereco`, `ativa`). Verificação: `.xs` validado no MCP.
- [x] 2.3 Criar a tabela de autenticação `usuario`:
  - campos: `nome`, `email` único, `senha_hash` do tipo senha, enums `papel` e `status_conta` com todos os valores do DER, `unidade_vinculo_id`, `criado_em`.

  Verificação: `.xs` validado no MCP; qualquer divergência de nome registrada no `design.md`.
- [x] 2.4 Criar a tabela `log_auditoria` com todos os campos do DER. Verificação: `.xs` validado no MCP.

## 3. Xano: funções reutilizáveis

- [x] 3.1 Criar a função `registrar_auditoria` (D6), que recebe `dados_*` já filtrados e só faz inserção. Verificação: `.xs` validado no MCP.
- [x] 3.2 Criar a função `usuario_ativo` (D5), que devolve o usuário ou erro 401 quando a conta não existe ou não está `ATIVA`. Verificação: `.xs` validado no MCP.
- [x] 3.3 Criar a função idempotente `bootstrap` (D7): configuração, unidades provisórias "Paulista" e "Vila Olímpia", e administrador a partir de variáveis de ambiente, com auditoria de ator vazio. Verificação: `.xs` validado no MCP.

## 4. Xano: rotas

- [x] 4.1 Criar `GET /ativas` no grupo `unidades` (pública; só `id` e `nome` das ativas; ordenada por nome). Verificação: `.xs` validado no MCP.
- [x] 4.2 Criar `POST /cadastro` no grupo `auth`, com as validações na ordem de D4, usuário e auditoria na mesma transação, e violação de unicidade de `email` convertida na mensagem genérica. Verificação: `.xs` validado no MCP.
- [x] 4.3 Criar `POST /login` no grupo `auth`: senha verificada antes da situação; 401 genérico; 403 só com senha correta; token com duração de `AUTH_TOKEN_TTL_SEGUNDOS`. Verificação: `.xs` validado no MCP.
- [x] 4.4 Criar `GET /me` no grupo `auth`, usando `usuario_ativo`, sem devolver `senha_hash`. Verificação: `.xs` validado no MCP.

## 5. Xano: publicação no workspace e bootstrap

- [x] 5.1 Rodar `xano workspace push -d ./xano --dry-run` (push parcial, sem `--env`, `--records`, `--sync` ou `--delete`), mostrar o resultado ao usuário e só fazer o push após **aprovação explícita**. Verificação: o push conclui sem erro e o `workspace pull` seguinte, em diretório temporário, não mostra diferenças.
- [x] 5.2 Pedir ao usuário que defina no painel do workspace as variáveis `ADMIN_INICIAL_NOME`, `ADMIN_INICIAL_EMAIL`, `ADMIN_INICIAL_SENHA` e `AUTH_TOKEN_TTL_SEGUNDOS`. O agente não deve ver nem registrar a senha. Verificação: o usuário confirma.
- [x] 5.3 Executar o `bootstrap` duas vezes, com `xano function run bootstrap` ou pelo painel. Se o plano Free não permitir nenhum dos dois, parar e pedir revisão de D7. Verificação:
  - existe 1 registro de configuração, 2 unidades e 1 `ADMIN`;
  - existe 1 registro `CRIAR_CONTA` com ator vazio;
  - a segunda execução não cria nem altera nada.

## 6. Xano: verificação das specs por chamadas à API

Executar contra o workspace, com `curl` ou script descartável fora do repositório. Registrar os resultados para o relatório final.

- [x] 6.1 Unidades: `GET /ativas` sem token devolve só `id` e `nome`, ordenadas. Depois de inativar uma unidade pelo painel, ela some da lista (reativar em seguida).
- [x] 6.2 Cadastro de aluno:
  - domínio aceito com maiúsculas → conta `ATIVA` com e-mail normalizado;
  - `gmail.com` → recusado;
  - subdomínio não listado → recusado;
  - senha com 7 caracteres → recusado;
  - unidade enviada por aluno → ignorada.
- [x] 6.3 Cadastro de professor:
  - com unidade ativa → `PENDENTE`;
  - sem unidade → recusado;
  - com unidade inativa ou inexistente → recusado;
  - com `status_conta=ATIVA` extra → continua `PENDENTE`.
- [x] 6.4 Papel privilegiado e duplicidade:
  - vínculo `ADMIN` ou `COORDENADOR` → recusado;
  - e-mail repetido com outra caixa → mensagem genérica e conta original intacta;
  - 2 a 5 cadastros **simultâneos** com o mesmo e-mail → exatamente 1 conta criada e 1 registro de auditoria.
- [x] 6.5 Domínio como parâmetro: incluir um domínio novo em `configuracao_geral` pelo painel, cadastrar com ele (aceito) e restaurar o valor.
- [x] 6.6 Login:
  - aluno ativo → token;
  - senha errada e e-mail inexistente → mesma resposta 401;
  - professor pendente com senha correta → 403 "aguardando aprovação";
  - professor pendente com senha errada → 401 genérico;
  - conta alterada pelo painel para `INATIVA` com senha correta → 403;
  - admin inicial → token.
- [x] 6.7 `GET /me`:
  - token válido → dados sem `senha_hash`;
  - sem token, token adulterado → 401;
  - conta inativada com token ainda válido → 401.
- [x] 6.8 Auditoria:
  - cada cadastro bem-sucedido gerou `CRIAR_CONTA` com ator = novo usuário e sem senha ou hash em `dados_depois`;
  - cadastros recusados não geraram registro;
  - não existe rota de leitura, edição ou exclusão de `log_auditoria`.
- [x] 6.9 Rollback da transação: forçar uma falha na gravação da auditoria, temporariamente no workspace (push com dry-run e aprovação), e confirmar que a conta não foi criada. Desfazer a alteração e refazer o push com dry-run e aprovação. Se não for viável forçar a falha, registrar como **não testado** com o motivo.

## 7. Reflex: base

- [x] 7.1 Instalar `python-dotenv` no `.venv` e fixar `httpx==0.28.1` e `python-dotenv` no `requirements.txt`. Verificação: `pip install -r requirements.txt` sem erro no `.venv` ativado.
- [x] 7.2 Configurar `env_file=".env"` no `rxconfig.py` e criar `.env.example` com `XANO_API_AUTH_URL` e `XANO_API_UNIDADES_URL`, sem valores secretos. Verificação: `.env` continua ignorado pelo Git (`git check-ignore .env`) e `.env.example` é rastreado.
- [x] 7.3 Criar `bookingSystem/api/xano_cliente.py` com `cadastrar`, `login`, `obter_usuario_atual` e `listar_unidades_ativas`, e as exceções `NaoAutenticado`, `AcessoNegado`, `ErroValidacao` e `ErroApi`. Sem logar token nem senha. Verificação: um script descartável, executado com o `.venv` ativo, chama cada função contra o workspace e recebe o resultado ou a exceção esperada.
- [x] 7.4 Criar `bookingSystem/state/auth_state.py`:
  - `_token` só de backend; dados públicos limitados a nome e papel;
  - handlers de login, cadastro, carregamento de unidades, verificação de sessão e logout;
  - `NaoAutenticado` limpa a sessão e redireciona.

  Verificação: `reflex run` compila sem erro.

## 8. Reflex: páginas

- [x] 8.1 Criar a página `/login`, com mensagens da API exibidas e redirecionamento para `/inicio` no sucesso. Verificação: login de aluno ativo leva a `/inicio`; senha errada mostra "E-mail ou senha inválidos."
- [x] 8.2 Criar a página `/cadastro`, com escolha de vínculo, lista de unidades carregada da rota pública ao escolher professor e mensagem de resultado. Verificação: os cadastros de aluno e de professor pela tela produzem as mensagens das specs.
- [x] 8.3 Criar a página `/inicio`, com `on_load` que exige sessão, exibição de nome e papel e botão "Sair". Substituir a página de template em `bookingSystem/bookingSystem.py`. Verificação: sem sessão, `/inicio` redireciona para `/login`; depois de "Sair", `/inicio` volta a redirecionar.

## 9. Verificação integrada e entrega

- [x] 9.1 Fluxo completo no navegador:
  - cadastro de aluno → login → `/inicio` → logout;
  - cadastro de professor → login bloqueado com "aguardando aprovação";
  - login do admin inicial.

  Verificação: todos os passos se comportam como nas specs.
- [x] 9.2 Verificar que o token não chega ao navegador: inspecionar cookies, `localStorage`, `sessionStorage` e as mensagens do websocket do Reflex nas DevTools durante um login. Verificação: o token não aparece em nenhum lugar.
- [x] 9.3 Sessão expirada: usar um TTL curto de teste no workspace (por exemplo 60 s), esperar expirar e navegar. Verificação: redireciona para `/login` com o aviso de sessão expirada. Restaurar o TTL depois.
- [x] 9.4 Revisar o código: PEP 8, sem `print` de depuração, sem código morto e sem segredo versionado (`git diff` e `git status` não mostram `.env`). Verificação: revisão concluída e `git diff` mostrado ao usuário antes do commit.
- [x] 9.5 Relatório final: listar o que foi testado, o que não pôde ser testado (com o motivo) e as divergências do DER registradas no `design.md`. Verificação: relatório entregue ao usuário.
