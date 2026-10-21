# AGENTS.md — BookingSystem

Instruções operacionais para agentes de IA (Claude Code) que trabalham neste repositório.
Este arquivo define **como trabalhar**. O que o sistema é está em `docs/`.

> O Claude Code (v2.1.277 ou superior) lê este arquivo automaticamente quando o projeto **não** tem `CLAUDE.md`.
> Se um `CLAUDE.md` for criado, a primeira linha dele deve ser `@AGENTS.md`, para que estas regras continuem valendo.

---

## 1. Antes de qualquer alteração

Leia, nesta ordem:

1. `docs/project-overview.md` — visão, escopo, regras de negócio e arquitetura.
2. `docs/domain-model.md` — entidades, relacionamentos, invariantes, MER e DER.
3. `openspec/config.yaml` — contexto e regras dos workflows.
4. `openspec/specs/` — comportamento já consolidado da área afetada.

Se a tarefa contradizer esses documentos, **pare e pergunte**. Não escolha sozinho.

## 2. Processo (OpenSpec)

- Toda mudança funcional ou estrutural passa por uma **change** do OpenSpec: explore → propose → review humano → apply → archive.
- Não implemente nada fora de uma change aprovada. Não crie arquivos em `openspec/specs/` manualmente; eles são atualizados pelo archive.
- O Explore não cria código nem arquivos.
- Durante o apply, siga `tasks.md` e marque cada tarefa ao concluir. Interrompa e peça revisão da change quando surgir algo que:
  - contradiga o domínio ou uma invariante;
  - altere a arquitetura ou introduza tecnologia nova;
  - exija decisão de negócio não documentada;
  - aumente o escopo da change.
- Não modifique funcionalidades fora do escopo da change atual.

### 2.1 Agente change-guardian

O `change-guardian` (`.claude/agents/change-guardian.md`) é um agente **somente leitura**: lê arquivos, roda comandos git de leitura, consulta a documentação do Xano e testa o app, e responde às perguntas do agente principal. Ele não cria, edita nem apaga arquivos, não faz commit nem push e não altera o Xano. Quem grava qualquer arquivo é sempre o agente principal.

- **MODO DECISÃO:** antes de fazer uma pergunta ao usuário durante explore ou apply, consulte o guardian. Ele responde com a decisão e uma classificação:
  - `TRIVIAL` ou `VALIDADA`: siga com a decisão e registre-a no `decisions-log.md` da change.
  - `PRECISA_HUMANO`: leve a pergunta ao usuário com as opções e a recomendação do guardian, e registre a resposta no `decisions-log.md`.
- A consulta ao guardian **não dispensa** as interrupções desta seção e da seção 1: contradição com o domínio ou uma invariante, arquitetura ou tecnologia nova, decisão de negócio não documentada e aumento de escopo vão sempre ao usuário.
- **MODO REVISÃO FINAL:** ao concluir o apply e antes de qualquer commit ou push da change, peça ao guardian o relatório de revisão e mostre-o ao usuário. O veredito do guardian não substitui a aprovação do usuário.
- **`decisions-log.md`:** fica em `openspec/changes/<change>/`, ao lado de `proposal.md`, `design.md` e `tasks.md`, e vai junto para o archive. Uma linha por decisão: número, data, decisão, classificação, evidência e quem decidiu (guardian ou usuário). Como o Explore não cria arquivos, as decisões do explore são registradas quando a change é criada no propose.
- O guardian só fica restrito à leitura se a pasta do projeto estiver marcada como confiável no Claude Code. Sem isso, o hook `.claude/hooks/guardian-somente-leitura.ps1` é ignorado sem aviso.

## 3. Arquitetura obrigatória

| Camada | Tecnologia | Regra |
|---|---|---|
| Backend | **Xano + XanoScript** | Única fonte de verdade de dados, regras de negócio, autorização, concorrência, tarefas agendadas e auditoria. |
| Frontend | **Reflex (Python)** | Exclusivo. Consome a API do Xano. Não acessa banco de dados e não reimplementa regras de negócio. |

- Não introduza outra tecnologia de backend, banco de dados ou frontend (FastAPI, Django, SQLite, React, Vue etc.) sem uma change que altere explicitamente a decisão arquitetural.
- Validações no Reflex são apenas de usabilidade. O Xano sempre revalida.

## 4. Xano / XanoScript

- **Não presuma sintaxe.** Consulte o **Xano Developer MCP** para a sintaxe de XanoScript, a documentação do CLI e as APIs. Valide **todo** arquivo `.xs` com o MCP antes de concluir uma tarefa.
- O código do backend fica em `./xano/` e é sincronizado **somente** via Xano CLI.
- Antes de começar, se houver chance de mudanças feitas direto no Xano: `xano workspace pull -d ./xano`.
- **Nunca** execute `xano workspace push` sem antes:
  1. rodar com `--dry-run`;
  2. mostrar o resultado;
  3. receber aprovação explícita do usuário.
- Trabalhe no **sandbox**. Não use o Xano MCP Server (acesso operacional ao workspace) nem altere o workspace por outro meio sem autorização explícita.
- A verificação de conflito de horário e a gravação de reserva devem ser **atômicas**. Use o mecanismo de transação/consistência do Xano confirmado na documentação via MCP.

## 5. Reflex / Python

- Use as Agent Skills do Reflex (`reflex-docs`, `setup-python-env`, `reflex-process-management`) para dúvidas de API, ambiente e execução.
- Ambiente: **`venv` + `pip`**. Não use `uv` nem crie `uv.lock`. Ative o `.venv` antes de qualquer comando Python.
- Nunca execute `reflex init` novamente. Para rodar, use `reflex run`.
- Ao adicionar dependência: confirme que é necessária, instale no `.venv`, teste e atualize `requirements.txt` na mesma change.
- Centralize as chamadas à API do Xano em **um único módulo cliente**. A URL base e os segredos vêm de variáveis de ambiente.
- O token de autenticação fica no **State** (lado servidor do Reflex). Nunca o exponha em código do cliente nem em logs.
- Use os mecanismos próprios do Reflex (componentes, State, event handlers, páginas). Não adicione outro framework de frontend.

## 6. Regras de domínio que exigem atenção constante

Detalhes em `docs/project-overview.md` (seção 7) e `docs/domain-model.md` (seção 4).

- Nunca permita duas ocupações **ativas** sobrepostas no mesmo espaço: reservas pendentes ou confirmadas e vagas retidas pela fila de espera (entrada `NOTIFICADA`).
- A prioridade é **Coordenador/Admin > Professor > Aluno**. Em empate, vale a ordem de criação **registrada pelo backend**.
- Todos os horários são gravados com fuso. As regras são avaliadas em **America/Sao_Paulo**.
- Prazos, durações e limites são **parâmetros** (ConfiguraçãoGeral / TipoEspaço). Não use valores fixos no código.
- Autorize sempre **por papel e por unidade**: o coordenador só age nas unidades que coordena.
- Toda ação sensível grava em **LogAuditoria** a partir da primeira change que a implementar.
- Reserva, falta, penalidade e auditoria **não são excluídas fisicamente**. Mudam de status.
- Siga os nomes de entidades e campos do `domain-model.md` (português, sem acento, `snake_case`). Se precisar divergir, registre o motivo no `design.md` da change.

## 7. Código

- Reutilize o código existente e evite duplicação.
- Funções pequenas e com nomes de domínio claros. O código Python segue a PEP 8.
- Não deixe código morto, `print` de depuração nem TODO sem dono.

## 8. Segurança

- Segredos (tokens, chaves, URLs privadas) ficam em `.env` (fora do Git). Nunca em código, commit ou artefato do OpenSpec.
- Senhas apenas como hash. Mensagens de erro não revelam se um e-mail existe.
- Toda rota da API do Xano exige autenticação, exceto cadastro, login e a listagem pública de unidades ativas (somente id e nome) usada no formulário de cadastro. As rotas autenticadas validam papel e escopo de unidade no backend.

## 9. Verificação

- Toda change funcional tem estratégia de verificação descrita em `tasks.md`.
- Cubra sempre os casos de borda do domínio que a change tocar:
  - sobreposição parcial de horários;
  - limite das 22h40 e das 08h00;
  - prazo de 2 horas (cancelamento, fila e deslocamento);
  - vaga retida pela fila e filas de intervalos sobrepostos;
  - janela de check-in;
  - empate de prioridade;
  - requisições simultâneas para o mesmo horário.
- Informe o que foi testado e o que **não** foi possível testar.

## 10. Git

- Uma branch por change (`change/<nome-da-change>`). Commits pequenos, mensagem em português no imperativo.
- Não versione `.venv/`, `.env`, `.web/` nem arquivos de cache. Versione `requirements.txt`, `rxconfig.py`, `xano/`, `docs/`, `openspec/` e a pasta de skills.
- Mostre `git diff` antes de commitar alterações relevantes.

## 11. Idioma

Documentação, artefatos do OpenSpec, mensagens ao usuário final e commits em **português brasileiro**.