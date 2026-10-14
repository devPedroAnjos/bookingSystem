## Context

O repositório tem apenas:
- o template do Reflex 0.10 (`bookingSystem/bookingSystem.py`);
- o arquivo do workspace Xano (`xano/workspace/pedro_dos_anjoss_workspace.xs`), sem tabelas nem rotas.

O ambiente tem Xano CLI 1.3.3 (com `workspace push --dry-run`, `unit_test` e `workflow_test`) e o Xano Developer MCP configurado. A conta Xano está no plano Free: não há sandbox, e o workspace tem uma única branch (`v1`, live). O `.venv` já tem `httpx` 0.28.1 como dependência transitiva do Reflex; `python-dotenv` não está instalado.

Motivação e escopo estão em `proposal.md`, e os requisitos nas specs `autenticacao`, `unidades` e `auditoria`. **Nenhuma sintaxe de XanoScript foi presumida neste documento.** Os pontos marcados com "(confirmar no MCP)" são verificados na primeira tarefa do apply.

## Goals / Non-Goals

**Goals:**
- Definir os padrões que as próximas changes vão copiar:
  - função de auditoria;
  - função "usuário autenticado ativo" para as rotas protegidas;
  - procedimento de bootstrap idempotente;
  - cliente único da API no Reflex;
  - token em variável só de backend do State;
  - fluxo de sincronização pelo workspace, com dry-run e aprovação.
- Criar tabelas apenas com os campos que esta change usa.

**Non-Goals:**
- Testes automatizados no Reflex. A verificação do frontend nesta change é manual (ver `tasks.md`).
- Configurar CORS, deploy ou domínio público. O acesso à API é feito servidor a servidor pelo Reflex.
- Mecanismo genérico de permissões por papel. Ele surge na C2, quando houver a primeira rota restrita a um papel.

## Decisions

### D1. Divisão entre Xano e Reflex

```
NAVEGADOR <--websocket--> REFLEX (servidor)  --HTTPS + JWT-->  XANO
                          - paginas /login,                    - tabelas
                            /cadastro, /inicio                 - grupo de API "auth"
                          - AuthState (_token)                 - grupo de API "unidades"
                          - xano_cliente.py                    - funcoes: auditoria,
                            (unico ponto de                      usuario_ativo, bootstrap
                             chamada HTTP)
```

O Xano faz toda a validação de regra: domínio, papel, unidade, situação da conta e duplicidade. O Reflex só valida usabilidade (campo vazio, confirmação de senha) e exibe a mensagem que a API devolve.

### D2. Tabelas do Xano (DER do `domain-model.md`)

| Tabela | Campos criados agora | Fora desta change | Divergências |
|---|---|---|---|
| `configuracao_geral` | `id`, `dominios_email` | todos os demais parâmetros (cada change cria os seus) | `dominios_email` é uma **lista de texto** em vez de `string`, para evitar análise de texto separado por vírgulas. Fica a lista se o Xano suportar campo lista (confirmar no MCP); se não, volta a `string` separada por vírgulas, como no DER. |
| `unidade` | `id`, `nome` (único), `endereco`, `ativa` | — | `nome` recebe índice único para tornar o seed idempotente; o DER não define. |
| `usuario` | `id`, `nome`, `email` (único), `senha_hash`, `papel`, `status_conta`, `unidade_vinculo_id`, `criado_em` | `aprovado_por_id`, `aprovado_em`, `motivo_recusa_cadastro` (C2) | `senha_hash` usa o tipo de campo de senha do Xano, que guarda só o hash. Se a autenticação nativa exigir outro nome de campo, a divergência é registrada aqui (confirmar no MCP). Os enums `papel` e `status_conta` já nascem com todos os valores do DER. |
| `log_auditoria` | todos os do DER: `id`, `ator_id`, `acao`, `entidade`, `entidade_id`, `unidade_id`, `dados_antes`, `dados_depois`, `criado_em` | — | nenhuma |

- `usuario` é a tabela de autenticação do Xano. Por isso o JWT identifica o usuário.
- Os campos `criado_em` são gravados pelo backend, com fuso (timestamp).
- Não se usa o `created_at` automático com outro nome, para manter os nomes do DER.

**Alternativa considerada:** criar a `configuracao_geral` completa já nesta change. Foi descartada pelo princípio de implementação incremental, e porque os demais parâmetros não têm uso nem tela ainda.

### D3. Rotas da API

| Grupo | Rota | Autenticação | Resposta |
|---|---|---|---|
| `auth` | `POST /cadastro` | pública | 200: mensagem (aluno: "Conta criada"; professor: "Conta aguardando aprovação"). 400: validação ou mensagem genérica de duplicidade. |
| `auth` | `POST /login` | pública | 200: `{token, usuario}`. 401: "E-mail ou senha inválidos.". 403: conta pendente, recusada ou inativa, **só depois** de confirmar a senha. |
| `auth` | `GET /me` | token | 200: usuário sem senha. 401: sem token, token inválido ou conta não ativa. |
| `unidades` | `GET /ativas` | pública | 200: `[{id, nome}]` ordenado por nome |

- Grupos separados por área, porque a C2 vai acrescentar rotas autenticadas ao grupo `unidades`.
- Cada grupo do Xano tem uma URL base própria.
- Os códigos HTTP acima são o contrato com o cliente Reflex. Os nomes de rota seguem o português do domínio.

### D4. Validação do cadastro (ordem)

1. **Normalização:** e-mail sem espaços nas pontas e em minúsculas.
2. **Campos obrigatórios:** nome, e-mail, senha com 8 ou mais caracteres e vínculo.
3. **Vínculo:** só `ALUNO` ou `PROFESSOR`. Qualquer outro valor é recusado. Campos extras (`papel`, `status_conta`, aprovação) não são entradas da rota, então não podem ser forçados.
4. **Domínio:** o domínio do e-mail precisa ser exatamente um item de `configuracao_geral.dominios_email`.
5. **Professor:** `unidade_vinculo_id` é obrigatório e precisa ser de uma unidade existente e ativa. Para aluno, o campo é ignorado.
6. **E-mail:** se já existir, a resposta é a mensagem genérica.
7. **Gravação:** usuário e auditoria são gravados na **mesma transação** (D6).

**Concorrência:** dois cadastros simultâneos com o mesmo e-mail podem passar juntos pelo passo 6. O **índice único em `email`** garante que só um seja gravado. O erro de violação de unicidade é convertido na mesma mensagem genérica.

O mínimo de 8 caracteres na senha não vem do overview. É uma premissa desta change, de valor técnico e não de domínio, e fica registrada aqui.

### D5. Login e usuário autenticado ativo

- O login procura o usuário pelo e-mail normalizado e verifica a senha **antes** de olhar `status_conta`. Só então decide entre 200 e 403. E-mail inexistente e senha errada seguem o mesmo caminho de resposta 401.
- Uma **função reutilizável `usuario_ativo`** recebe o id do token, carrega o usuário e devolve 401 se ele não existir ou não estiver `ATIVA`.
  - `GET /me` e **todas as rotas autenticadas futuras** chamam essa função.
  - Assim, inativar uma conta corta o acesso mesmo com token válido.
- **Duração do token:** 24 horas, lida de uma variável de ambiente do Xano (`AUTH_TOKEN_TTL_SEGUNDOS`). É um parâmetro técnico, não de domínio, por isso não fica em `ConfiguracaoGeral`.

**Alternativa considerada:** só validar o JWT, sem consultar o usuário. É mais barato, mas uma conta inativada continuaria acessando até o token expirar.

### D6. Auditoria

- Uma função reutilizável `registrar_auditoria(ator_id?, acao, entidade, entidade_id, unidade_id?, dados_antes?, dados_depois?)` insere em `log_auditoria`.
- Quem chama monta `dados_*` explicitamente, com uma lista de campos permitidos e **nunca** com o registro inteiro. Isso impede que `senha_hash` vaze para o log.
- O cadastro grava usuário e auditoria dentro de uma transação do banco do Xano (confirmar no MCP o mecanismo de transação e se ele faz rollback quando um passo falha).
- **Se o Xano não oferecer transação com rollback, o apply para e pede revisão da change**, conforme o `AGENTS.md`.
- Nenhuma rota de leitura, edição ou exclusão do log é criada nesta change. A consulta pelo administrador fica para a C13.

### D7. Bootstrap (configuração, unidades, administrador)

- Uma **única função idempotente `bootstrap`**, executada manualmente no workspace depois do push, com `xano function run bootstrap` ou pelo painel. Se o plano Free não permitir nenhum dos dois, o apply para e pede revisão desta decisão. Ela faz três coisas:
  1. cria o registro de `configuracao_geral`, se não existir, com os domínios padrão do `domain-model.md` §2.18;
  2. cria as unidades iniciais que não existirem, comparando por `nome`;
  3. se não existir nenhum `ADMIN`, cria o administrador a partir das variáveis de ambiente do Xano `ADMIN_INICIAL_NOME`, `ADMIN_INICIAL_EMAIL` e `ADMIN_INICIAL_SENHA`, e audita `CRIAR_CONTA` com ator vazio. Se uma variável faltar, a função falha sem criar nada.
- **Alternativas consideradas:**
  - registros de tabela enviados com `push --records`: descartado, porque versionaria o hash da senha do administrador e o CLI marca a opção como crítica;
  - rota HTTP de bootstrap protegida por segredo: descartado, porque cria uma superfície de ataque permanente.
- As variáveis de ambiente do Xano são definidas manualmente no painel do workspace. Elas nunca entram no Git nem em artefatos do OpenSpec.

### D8. Reflex: cliente, State e páginas

```
bookingSystem/
  bookingSystem.py        app + registro das paginas (substitui o template)
  api/xano_cliente.py     UNICO modulo com chamadas HTTP ao Xano
  state/auth_state.py     AuthState
  pages/login.py
  pages/cadastro.py
  pages/inicio.py
```

**Cliente (`xano_cliente.py`)**
- Usa `httpx` assíncrono.
- Lê as URLs base dos grupos das variáveis de ambiente `XANO_API_AUTH_URL` e `XANO_API_UNIDADES_URL`.
- Expõe funções de domínio: `cadastrar`, `login`, `obter_usuario_atual` e `listar_unidades_ativas`.
- Converte as respostas em resultado ou em exceções próprias: `NaoAutenticado` (401), `AcessoNegado` (403), `ErroValidacao` (400) e `ErroApi` (demais).
- **Nunca registra o token nem a senha em log.**

**AuthState**
- O token fica em `_token`. Variáveis que começam com `_` são só de backend no Reflex e não são sincronizadas com o navegador, como indica a documentação de Vars.
- O navegador recebe apenas nome, papel e mensagens.
- A página `/inicio` tem um `on_load` que verifica se há sessão e redireciona com `rx.redirect`.
- Se uma chamada levantar `NaoAutenticado`, a sessão é limpa e o usuário vai para `/login` com o aviso de que a sessão expirou.
- O logout limpa `_token` e os dados do usuário.

**Variáveis de ambiente**
- `rxconfig.py` passa a usar `env_file=".env"`.
- A documentação do Reflex informa que esse recurso "requires the python-dotenv package". Por isso `python-dotenv` entra no `requirements.txt`.
- `httpx` também entra no `requirements.txt` com a versão fixada, porque passa a ser importado diretamente.
- É criado um `.env.example` versionado, sem valores secretos.

**Alternativas consideradas:**
- token em `rx.Cookie` ou `LocalStorage`: descartado, porque coloca o token no navegador, o que o `AGENTS.md` proíbe;
- `requests` síncrono: descartado, porque bloquearia o loop de eventos do Reflex.

### D9. Sincronização e ambiente

- A conta está no plano Free, que não oferece sandbox. O trabalho é feito **no workspace**, na branch `v1` (live), que hoje não tem dados nem usuários reais.
- Antes de começar: `xano workspace pull` para um diretório temporário, fora do repositório, e comparação com `./xano/`.
- Publicação: `xano workspace push -d ./xano --dry-run`, apresentação do resultado, aprovação explícita e só então o push (manual §22, `AGENTS.md` §4).
  - O push é parcial (padrão do CLI), que só acrescenta e atualiza.
  - Nesta change não se usam `--sync` nem `--delete`. Também não se usam `--env` nem `--records`, para não enviar nem versionar segredos e dados.
- O `.env` local aponta para as URLs dos grupos de API do workspace (`<URL da instância>/api:<canonical>`).
- **Desvio do `AGENTS.md`:** a regra "Trabalhe no sandbox" não pode ser cumprida no plano Free. A troca pelo workspace foi decisão do usuário em 14/10/2026. O `AGENTS.md` não é alterado por esta change.

## Risks / Trade-offs

- **[MCP não carregado na sessão de planejamento]** → A primeira tarefa do apply confirma no MCP todos os pontos "(confirmar no MCP)". Qualquer divergência que mude spec ou abordagem interrompe o apply para revisão.
- **[Sem transação com rollback no Xano]** → O cadastro e a auditoria poderiam ficar inconsistentes. Mitigação: verificação explícita no MCP; se não houver, o apply para e a change é revisada.
- **[Sessão só em memória no Reflex]** → Abrir nova aba, reiniciar o servidor ou o hot reload no desenvolvimento exige novo login. Isso foi aceito na exploração. Em produção com Redis, o estado sobrevive a reinícios.
- **[Mensagem genérica de duplicidade]** → A diferença entre a resposta de sucesso e a de erro ainda permite deduzir, com esforço, que um e-mail existe. É um vazamento residual aceito na v1, já que não há e-mail de confirmação.
- **[Sem sandbox: trabalho direto na branch live]** → Cada push muda a API publicada. Mitigação: hoje não há usuários nem dados reais, e todo push passa por dry-run e aprovação, inclusive a falha forçada da tarefa 6.9 e a reversão dela.
- **[`xano function run` indisponível no plano Free]** → No perfil da conta, a permissão de "run & debug" parece bloqueada, o que impediria executar o `bootstrap`. Mitigação: tentar o CLI depois do push e, se falhar, o painel. Se nenhum funcionar, o apply para e pede revisão de D7. Uma rota HTTP de bootstrap continua descartada sem nova decisão.
- **[Limite de requisições do plano Xano]** → Pode atrapalhar o teste de cadastros simultâneos. O teste usa poucas requisições paralelas (2 a 5).
- **[Nomes das unidades iniciais]** → Os nomes usados no seed são provisórios até a equipe confirmar.

## Migration Plan

1. `xano workspace pull` para um diretório temporário e comparação com `./xano/`. Hoje o workspace só tem a configuração, mas pode ter sido alterado pelo painel.
2. Criar os arquivos `.xs` e validá-los no MCP.
3. `xano workspace push -d ./xano --dry-run`, mostrar o resultado, obter aprovação e fazer o push.
4. Definir as variáveis de ambiente no painel do workspace e executar o `bootstrap`.
5. Configurar o `.env` local e rodar `reflex run`.

**Rollback:** como não há dados reais, basta reverter os arquivos na branch Git e fazer novo push com dry-run e aprovação. O push parcial não remove objetos; remover algo do workspace exige `--sync --delete`, que só é usado com confirmação explícita do usuário.

## Open Questions

- Nomes e endereços reais das unidades iniciais. Os provisórios são "Paulista" e "Vila Olímpia". Só mudam dados de seed.
- Texto final das mensagens da interface. As mensagens de erro de autenticação já estão fixadas nas specs.

## Confirmações do apply

Consultas feitas no Xano Developer MCP (documentação 2.7.1) e no validador, durante a tarefa 1.2.

| Ponto | Resposta |
|---|---|
| Campo de senha e autenticação nativa | A tabela usa `auth = true` e um campo do tipo `password`. O valor gravado num campo `password` pelo `db.add` é transformado em hash automaticamente. A verificação é feita com `security.check_password` (`text_password`, `hash_password`) e o token com `security.create_auth_token` (`table`, `id`, `extras`, `expiration`). A documentação não exige um nome específico para o campo, então `senha_hash` mantém o nome do DER. Se o Xano recusar o nome no push, a divergência será registrada aqui. |
| Tipo do campo `email` | `usuario.email` usa o tipo `email` do Xano (texto validado como e-mail), com `filters=trim\|lower`, em vez de `string` do DER. O nome do campo não muda. |
| Campo lista de texto | `text[]` é aceito no `schema` de tabela (o validador recusa tipos inexistentes). `dominios_email` fica como lista, conforme D2. |
| Índice único | `{type: "btree\|unique", field: [{name: "email"}]}`. |
| Enum | `enum papel { values = [...] }`. |
| Transação com rollback | `db.transaction { stack { ... } }`, documentado como atômico ("all-or-nothing" entre tabelas), com opção `isolation`. O rollback em caso de falha é verificado em execução na tarefa 6.9. |
| Token com duração | Parâmetro `expiration` (segundos) de `security.create_auth_token`. `extras` é obrigatório, mesmo vazio. |
| Variável de ambiente | Leitura com `$env.NOME`. Os valores são definidos no painel. Eles **não** entram no bloco `env` do arquivo `workspace/*.xs`, porque esse arquivo é versionado. |
| Erro 401 | A tabela de tipos de erro da documentação só lista 400, 403, 404 e 500. O validador aceita também `unauthorized`, `badrequest` e `toomanyrequests`. Rotas com `auth` devolvem 401 sozinhas para token ausente ou inválido. O login e a função `usuario_ativo` usam `error_type = "unauthorized"`; confirmado em execução (tarefas 6.6 e 6.7): `unauthorized` devolve HTTP 401. |
| Nome do grupo de API | O `canonical` precisa ser único **na instância**, não só no workspace. Por isso os grupos usam prefixo do projeto (ex.: `bookingsystem-auth`). |
| Execução manual de função | O CLI oferece `xano function run <nome>`. No perfil da conta, a permissão `workspace:action:rundebug` tem o mesmo valor das permissões bloqueadas (exportação e cobrança), então provavelmente não está disponível no plano atual. A alternativa é o painel. A confirmação é feita na tarefa 5.3 (ver D7 e Risks). |
| URLs de API | `xano sandbox get` respondeu "Access Denied. Not supported with Free plan". A conta está no plano Free (`build`) e o workspace tem só a branch `v1`, que é a live. Por decisão do usuário, D9 foi revisado para usar o workspace. As URLs são `<URL da instância>/api:<canonical>` (formato documentado em `apis`). |
