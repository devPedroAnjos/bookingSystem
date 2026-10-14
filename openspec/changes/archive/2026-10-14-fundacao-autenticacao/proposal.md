## Why

O BookingSystem ainda não tem backend nem telas além do template do Reflex. Nenhuma funcionalidade de domínio (espaços, reservas, aprovações) pode existir sem um usuário identificado com papel conhecido. Esta é a primeira change: ela entrega cadastro e login e estabelece os padrões que todas as próximas vão repetir. Os padrões são: sincronização via Xano CLI, cliente único da API no Reflex, token mantido no servidor, parâmetros em `ConfiguracaoGeral` e auditoria desde a primeira ação registrada.

## What Changes

**Backend (Xano)**
- Tabela `configuracao_geral` (registro único), criada só com o parâmetro que esta change usa: os domínios de e-mail aceitos no cadastro.
- Tabela `log_auditoria` e uma função reutilizável de registro. Nesta change, ela audita a criação de conta.
- Tabela `unidade`, com carga inicial (seed) das unidades, e uma rota **pública** que lista apenas `id` e `nome` das unidades ativas, para o formulário de cadastro.
- Tabela `usuario` e autenticação JWT do Xano:
  - **Cadastro**: o usuário escolhe aluno ou professor. O e-mail precisa pertencer a um domínio aceito. Conta de aluno nasce `ATIVA`. Conta de professor nasce `PENDENTE`, com unidade de vínculo obrigatória. Um e-mail já cadastrado recebe uma mensagem genérica, que não confirma a existência da conta.
  - **Login**: só contas `ATIVA` recebem token. Credenciais inválidas recebem uma mensagem genérica. A mensagem "conta aguardando aprovação" só aparece quando a senha está correta.
  - **Usuário atual** (`me`): devolve os dados do usuário autenticado, sem a senha.
- Administrador inicial criado por um procedimento de bootstrap idempotente. As credenciais vêm de variáveis de ambiente do Xano e nunca são versionadas.

**Frontend (Reflex)**
- Módulo cliente único para a API do Xano. A URL base vem de variável de ambiente.
- `AuthState`, que guarda o token apenas no State do servidor Reflex. Abrir uma nova aba ou reiniciar o servidor exige novo login; isso é aceito na v1.
- Páginas `/login`, `/cadastro` e `/inicio`. A página `/inicio` exige sessão: sem sessão, redireciona para o login. Esse redirecionamento é só para usabilidade; a segurança está no Xano.
- Logout.

**Fora do escopo**
- Aprovação e recusa de cadastro de professor, alteração de papel, atribuição de coordenadores e CRUD de unidades (change C2, `contas-unidades-coordenacao`).
- Edição de `ConfiguracaoGeral` pelo administrador e demais parâmetros globais. Cada change futura acrescenta os parâmetros que usar.
- Recuperação de senha, confirmação de e-mail, login social ou SSO.
- Persistência de sessão entre abas ou reinícios do servidor.
- Qualquer funcionalidade de espaços, reservas ou notificações.

## Capabilities

### New Capabilities
- `autenticacao`: cadastro com e-mail institucional (aluno ou professor), situação da conta, login com JWT, consulta do usuário atual, sessão e logout no frontend, e administrador inicial.
- `unidades`: cadastro inicial de unidades e listagem pública das unidades ativas para o formulário de cadastro. A change C2 amplia com a gestão de unidades.
- `auditoria`: registro imutável de ações sensíveis em `LogAuditoria`, com ator, ação, entidade e dados. Começa auditando a criação de conta.

### Modified Capabilities
- Nenhuma. Ainda não existem specs consolidadas.

## Impact

- **Papéis afetados**:
  - Aluno e Professor: cadastro e login.
  - Administrador: conta inicial e login.
  - Coordenador: não afetado nesta change, porque o papel só é atribuído na C2.
- **Regras do `project-overview.md` tocadas**:
  - §7.10 Cadastro e contas: e-mail institucional com domínio configurável, aluno ativo, professor pendente com unidade de vínculo, conta pendente sem acesso.
  - §10 Segurança e integridade: JWT, senha só como hash, rotas públicas (cadastro, login e unidades ativas), mensagens que não revelam a existência de e-mail, auditoria.
  - Parâmetros em `ConfiguracaoGeral` (§7, nota inicial).
- **Xano**: primeiras tabelas, rotas e funções do workspace em `./xano/`, sincronizadas pelo Xano CLI no workspace (branch live `v1`), sempre com `--dry-run` e aprovação antes do push. O plano Free da conta não oferece sandbox.
- **Reflex**: substitui a página de template em `bookingSystem/bookingSystem.py` e cria o módulo cliente, o State de autenticação e as páginas.
- **Dependências**: `httpx` passa a ser usado diretamente; hoje ele já é instalado como dependência transitiva do Reflex. Pode ser necessário um carregador de `.env`, a decidir no design.
- **Configuração**: um novo `.env` (fora do Git) com a URL base da API, e variáveis de ambiente no Xano para o bootstrap do administrador.
