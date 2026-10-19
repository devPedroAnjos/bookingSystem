## Context

A C1 deixou prontos os padrões que esta change reutiliza:
- `usuario_ativo` relê o usuário do banco a cada requisição;
- `registrar_auditoria` só insere e recebe os dados já filtrados;
- `db.transaction` tem rollback verificado (tarefa 6.9 da C1);
- `xano_cliente.py` é o único ponto HTTP;
- `AuthState` guarda o token em `_token`, que é só de backend.

O workspace Xano está no plano Free, sem sandbox (branch `v1`, live).

**Restrições descobertas na tentativa anterior desta change** (validador do Xano Developer MCP, documentação 2.7.1):
- `db.transaction` **não** aceita `isolation`;
- `db.bulk.update` e `db.bulk.patch` **não** aceitam `where`, então não há *compare-and-set* nativo;
- são aceitos: `db.bulk.delete` com `where`, `in` em `where`, `join` + `eval` em `db.query`, `throw` e concatenação com `~`;
- `db.direct_query` é aceito pelo validador, mas **recusado em execução** neste workspace (`Access Denied`, tarefa 1.3).

Sem isolamento serializável, "ler, validar e gravar" sofre corrida no isolamento padrão do PostgreSQL (*read committed*). Quase todas as regras desta change são contagens sujeitas a essa corrida (limites, "nunca 0 na origem", pedidos, decisão única). Por isso, D3 é a decisão central, e ela é validada por um teste de execução antes de qualquer outro código.

A motivação está no `proposal.md`. Os requisitos estão nas specs `aprovacao-cadastro`, `coordenacao`, `papeis`, `autorizacao`, `unidades`, `autenticacao` e `auditoria`.

## Goals / Non-Goals

**Goals:**
- Um mecanismo único e verificado de exclusão mútua para todas as operações que contam ou mudam situação. Ele será reutilizado pela change de reservas.
- O padrão de autorização (`exigir_admin`, `autorizar_unidade`) que as próximas changes chamam em toda rota restrita.
- O layout autenticado com menu por papel.

**Non-Goals:**
- Paginação das listagens (o volume da v1 é pequeno).
- Testes automatizados no Reflex (a verificação é manual, como na C1).
- Qualquer regra de administradores, senha ou inativação de conta (C3).

## Decisions

### D1. Divisão entre Xano e Reflex

```
NAVEGADOR <--ws--> REFLEX (servidor)                      --HTTPS+JWT-->  XANO
                   - layout + menu por papel                              - grupo auth: cadastro*, login*,
                   - /cadastro*, /login* (motivo + reenvio)                 situacao_pedido, reenviar_pedido
                   - /aprovacoes, /usuarios, /unidades                    - grupo contas (novo)
                   - AuthState*, PedidoState, ContasState,                - grupo unidades (+ rotas)
                     UnidadesState                                        - funcoes: travar_governanca,
                   - xano_cliente.py (unico)                                exigir_admin, autorizar_unidade,
                                                                            unidades_coordenadas,
                                                                            coordenadores_ativos
 (* = alterado)
```

O Xano decide tudo: papel, escopo, limites, situação e concorrência. O Reflex só:
- esconde itens do menu;
- valida campos vazios;
- exige escolher 1 ou 2 unidades e um destino por coordenador;
- pede confirmação antes de tirar alguém da coordenação.

### D2. Tabelas (DER do `domain-model.md`)

| Tabela | Campos criados ou alterados | Divergências do DER |
|---|---|---|
| `usuario` | + `aprovado_por_id` (FK `usuario`), `aprovado_em`, `motivo_recusa_cadastro`, `pedidos_cadastro` (int, padrão 1), `justificativa_cadastro` (texto), `recusa_sem_custo` (bool, padrão falso) | **(1)** `aprovado_por_id` e `aprovado_em` registram quem **decidiu**, inclusive na recusa; um motivo preenchido indica recusa. **(2)** `pedidos_cadastro`, `justificativa_cadastro` e `recusa_sem_custo` não existem no DER; são exigidos pelas regras de reenvio e de recusa por desativação. **(3)** `unidade_vinculo_id` tem dois sentidos: para conta `PENDENTE` ou `RECUSADA`, é a **unidade pedida**; para `PROFESSOR` `ATIVA`, é a **unidade do professor** (pertencimento). Para `ALUNO` e `COORDENADOR` ativos, fica vazia (o coordenador é definido pelas coordenações). O nome do DER é mantido para não migrar dados. |
| `coordenacao_unidade` | `id`, `usuario_id`, `unidade_id`, `desde` | Nenhuma. Índice único (`usuario_id`, `unidade_id`), conforme A.1. A remoção apaga a linha (`db.del`/`db.bulk.delete`). A tabela não está entre os registros que nunca podem ser excluídos, e o histórico fica na auditoria. |
| `configuracao_geral` | + `max_coordenadores_unidade` (4), `max_unidades_coordenador` (2), `max_pedidos_cadastro` (3) | Parâmetros novos, que o `domain-model.md` §2.18 passa a listar. |
| `unidade` | sem campo novo | O nome único sem diferenciar maiúsculas e minúsculas é verificado na rota. O índice único da C1 é a última defesa. |
| `trava` | `id`, `nome` (único), `usado_em` | Tabela técnica, fora do DER, usada só pela exclusão mútua (D3). |

- **Contas existentes:** `pedidos_cadastro` nasce com padrão 1. O `bootstrap` ganha um passo idempotente que grava 1 onde estiver vazio. Com isso, as contas pendentes criadas na C1 passam a contar como "1 pedido".
- **Parâmetros:** o `bootstrap` também preenche os três parâmetros novos, só onde estiverem vazios. O código nunca usa valor padrão embutido: se o parâmetro estiver vazio, a operação falha com erro de configuração.

### D3. Exclusão mútua: trava por linha

*Revisada no apply (tarefa 1.3): a primeira versão usava `pg_advisory_xact_lock` via `db.direct_query`, que o workspace recusa com `Access Denied`.*

Toda operação desta change que **valida uma contagem ou uma situação e depois grava** segue o mesmo formato:

```
db.transaction {
  stack {
    function.run travar_governanca           // 1a instrucao: db.edit na linha "governanca" da tabela trava
    relê do banco tudo o que vai validar      // depois da trava, read committed ve os commits anteriores
    valida (situacao, limites, escopo)        // precondition/throw -> rollback, a trava e solta
    grava + registrar_auditoria
  }
}                                             // commit ou rollback soltam a trava automaticamente
```

- **Por que funciona:** no PostgreSQL, uma transação que atualiza uma linha segura um bloqueio exclusivo nela até o commit ou rollback. Outra transação que tente atualizar a mesma linha **espera**. `travar_governanca` faz um `db.edit` (`usado_em = now`) na linha `nome = "governanca"` da tabela técnica `trava`. Como a releitura acontece **depois** da trava, a segunda transação enxerga o resultado da primeira. Por exemplo, a segunda decisão encontra a conta já `ATIVA` e recebe "este pedido já foi decidido".
- **Comprovado em execução (tarefa 1.3):**
  - sem trava, duas chamadas simultâneas levaram 4,6 s e 4,7 s;
  - com trava, levaram 4,6 s e **8,6 s**, e três chamadas levaram 4,6 s, 8,6 s e **12,8 s**;
  - depois de uma falha forçada com a trava em mãos, a chamada seguinte levou 4,2 s, então o rollback solta a trava.
- **Tabela técnica `trava`** (`id`, `nome` único, `usado_em`):
  - não pertence ao domínio nem ao DER; existe só para a exclusão mútua (divergência registrada aqui e no `domain-model.md`);
  - o `bootstrap` cria a linha `"governanca"` de forma idempotente;
  - se ela não existir, `travar_governanca` falha com erro de configuração, em vez de seguir sem trava.
- **Uma linha global** serializa todas as operações de governança: decisões, reenvios, papéis, transferência, coordenação e unidades.
  - *Por que não uma trava por unidade:* mover e desativar envolvem várias unidades e o coordenador ao mesmo tempo, e várias travas exigiriam ordem fixa de aquisição para não dar deadlock.
  - O volume da v1 é baixo, então serializar custa pouco.
  - A change de reservas pode usar linhas de trava por espaço, com o mesmo mecanismo.
- **Validação dentro da trava:** checagens baratas que não dependem de estado concorrente (campos vazios, tamanho do motivo, papel válido) ficam antes da transação. Todo o resto fica depois da trava.
- *Alternativas descartadas:*
  - `isolation = "serializable"` e `bulk.update` condicional: não existem na versão atual;
  - `pg_advisory_xact_lock` via `db.direct_query`: recusado pelo workspace (`Access Denied`);
  - trava em Redis (`redis.incr` como mutex): disponibilidade incerta no plano Free, não fica ligada à transação do banco e é frágil para liberar em erro;
  - aceitar a corrida: viola as specs "Decisão única por pedido" e "Limites concorrentes".

### D4. Rotas da API

As rotas autenticadas usam `auth = "usuario"` e chamam `usuario_ativo` (diretamente ou via `exigir_admin`/`autorizar_unidade`). Os parâmetros vão no corpo (POST) ou na query (GET).

| Grupo | Rota | Quem |
|---|---|---|
| `auth` | `POST /cadastro` (alterada: aceita `COORDENADOR` e grava `pedidos_cadastro = 1`) | pública |
| | `POST /login` (alterada: ramo `RECUSADA` com motivo) | pública |
| | `POST /situacao_pedido` `{email, senha}` | pública, exige a senha |
| | `POST /reenviar_pedido` `{email, senha, papel, unidade_vinculo_id, justificativa?}` | pública, exige a senha |
| `contas` (novo, canonical `bookingsystem-contas`) | `GET /pedidos` `?situacao=PENDENTE\|RECUSADA` | admin (ambas); coordenador (só `PENDENTE`, professores do escopo) |
| | `POST /aprovar` `{usuario_id, situacao_esperada?: PENDENTE\|RECUSADA}`, `POST /recusar` `{usuario_id, motivo}` | D6 |
| | `GET /usuarios` `?papel&status_conta&busca` | admin |
| | `POST /alterar_papel` `{usuario_id, papel, unidades_ids?, unidade_id?}` | admin (D8) |
| | `POST /transferir_professor` `{usuario_id, unidade_id}` | admin (D9) |
| `unidades` | `GET /ativas` | pública, **sem mudança** |
| | `GET /geridas` | admin, coordenador |
| | `POST /criar` `{nome, endereco, coordenador_id, modo: MOVER\|ACRESCENTAR, origem_id?}` | admin |
| | `POST /editar` `{unidade_id, nome, endereco}` | admin |
| | `POST /desativar` `{unidade_id, destinos_coordenadores: [{usuario_id, unidade_id}], destinos_professores: [{usuario_id, unidade_id}]}`, `POST /reativar` `{unidade_id}` | admin |
| | `POST /acrescentar_coordenador` `{usuario_id, unidade_id}`, `POST /mover_coordenador` `{usuario_id, origem_id, destino_id}`, `POST /remover_coordenador` `{usuario_id, unidade_id}` | admin |

**Códigos HTTP:**
- 400 (`inputerror`): validação, limite, situação incompatível ou "já decidido";
- 401: sem sessão ou credencial inválida;
- 403 (`accessdenied`): papel ou escopo;
- 404 (`notfound`): conta ou unidade inexistente, **só para o admin**.

Para o coordenador, um alvo fora do escopo responde 403, nunca 404, para que ele não consiga sondar ids de outras unidades.

### D5. Funções reutilizáveis

| Função | Faz |
|---|---|
| `travar_governanca` | `db.edit` na linha `nome = "governanca"` da tabela `trava` (D3); erro de configuração se a linha não existir. Só pode ser chamada como primeira instrução de um `db.transaction`. |
| `exigir_admin(usuario_id)` | `usuario_ativo`; papel diferente de `ADMIN` → 403. |
| `unidades_coordenadas(usuario_id)` | ids das unidades em `coordenacao_unidade` do usuário. |
| `autorizar_unidade(usuario_id, unidade_id)` | admin → ok; coordenador com a unidade em `unidades_coordenadas` → ok; senão 403. |
| `coordenadores_ativos(unidade_id)` | `coordenacao_unidade` com `join` em `usuario` (situação `ATIVA`, papel `COORDENADOR`), devolvendo id e nome. A contagem para os limites usa esta função. |

O papel, a situação e as coordenações são sempre lidos do banco, nunca do token. É isso que garante o efeito imediato exigido pela spec `autorizacao`.

### D6. Decisão de cadastro

**Situação esperada** (acrescentada no apply): sem ela, uma recusa do coordenador seguida de uma aprovação do admin passaria duas vezes, porque o admin pode aprovar conta `RECUSADA`. Por isso, `aprovar` recebe `situacao_esperada` (padrão `PENDENTE`), que é a situação que a tela mostrava. Se, depois da trava, a situação real for outra, a resposta é "Este pedido já foi decidido". O admin só aprova uma conta recusada a partir da lista de recusadas (`situacao_esperada = RECUSADA`). A carga e a autorização ficam na função `carregar_pedido_para_decisao`, comum às duas rotas.

Fluxo de `aprovar` e `recusar`, dentro de D3:
1. Releitura do alvo → 404 (admin) ou 403 (coordenador) se não existe.
2. Situação:
   - `PENDENTE` → segue;
   - `RECUSADA` → só `aprovar`, só admin;
   - outra → 400 "Não há pedido pendente para esta conta.". Esse 400 também é o "já decidido" da corrida, com o texto "Este pedido já foi decidido. Atualize a lista." quando a situação lida antes da trava era `PENDENTE`.
3. Permissão:
   - professor → `autorizar_unidade(ator, unidade_vinculo_id)`;
   - coordenador → `exigir_admin`.
4. Aprovação: a unidade pedida precisa estar ativa, para os dois papéis.
   - **Professor:** `unidade_vinculo_id` permanece e passa a ser a unidade do professor.
   - **Coordenador:** a unidade também precisa ter menos ativos que `max_coordenadores_unidade`. Cria a linha em `coordenacao_unidade` com `desde = now` e limpa `unidade_vinculo_id`.
5. Grava `status_conta`, `aprovado_por_id`, `aprovado_em` e `motivo_recusa_cadastro` (preenchido na recusa, limpo na aprovação), mais a auditoria. A aprovação de coordenador gera também `ATRIBUIR_COORDENACAO`. A recusa manual grava `recusa_sem_custo = false`.

O motivo passa por `trim` e precisa ser não vazio, com até 500 caracteres (premissa técnica). Essa validação fica antes da trava.

### D7. Situação do pedido e reenvio (públicos, com senha)

- As duas rotas repetem o início do `login`: e-mail normalizado, `security.check_password` e 401 genérico para e-mail inexistente ou senha errada. Uma função `conferir_credenciais` é extraída do `login` para não duplicar código; as três rotas a usam.
- `situacao_pedido`:
  - só responde para `PENDENTE` ou `RECUSADA`;
  - para qualquer outra situação devolve o mesmo 401 genérico, para não revelar contas ativas;
  - devolve `{status_conta, papel, unidade_vinculo_id, unidade_nome, motivo_recusa_cadastro, pedidos_restantes}`.
- `situacao_pedido` calcula `pedidos_restantes` como `max_pedidos_cadastro - pedidos_cadastro` (mínimo 0), **mais 1** quando a conta está `RECUSADA` com `recusa_sem_custo`, porque o próximo reenvio é gratuito. *Corrigido no apply: a versão anterior só garantia "pelo menos 1" e mostrava um pedido a menos (achado na verificação manual).*
- `reenviar_pedido` (dentro de D3):
  - situação `RECUSADA` e (`recusa_sem_custo` **ou** `pedidos_cadastro < max_pedidos_cadastro`), senão 400;
  - papel `PROFESSOR` ou `COORDENADOR`, e unidade ativa;
  - grava `PENDENTE`, o papel, a unidade e a justificativa;
  - `pedidos_cadastro + 1` **só** se `recusa_sem_custo` for falso;
  - limpa `motivo_recusa_cadastro`, `aprovado_por_id`, `aprovado_em` e `recusa_sem_custo`;
  - auditoria `REENVIAR_CADASTRO` com ator = o próprio titular.
- **Frontend:** quando o login devolve `AcessoNegado`, o handler chama `situacao_pedido` com as credenciais que acabou de receber. Elas ficam só em variáveis locais do handler, nunca no State nem em log. O resultado decide se mostra "Pedir nova análise".

### D8. Mudança de papel

Dentro de D3, depois de `exigir_admin`:
1. O alvo existe, está `ATIVA` e não é `ADMIN`. O par (papel atual, novo papel) precisa estar entre as direções permitidas: `ALUNO`→`PROFESSOR`, `PROFESSOR`→`COORDENADOR` e `COORDENADOR`→`PROFESSOR`. Qualquer outro par, inclusive `ALUNO`→`COORDENADOR`, voltar a `ALUNO` ou repetir o papel atual, dá 400.
2. Novo papel `COORDENADOR`:
   - `unidades_ids` com 1 até `max_unidades_coordenador` ids distintos;
   - cada unidade ativa e com vaga;
   - cria as linhas em `coordenacao_unidade` e um `ATRIBUIR_COORDENACAO` para cada uma.
3. Novo papel `PROFESSOR`: `unidade_id` obrigatório, de uma unidade ativa, gravado em `unidade_vinculo_id`. Novo papel `COORDENADOR`: `unidade_vinculo_id` é limpo.
4. Papel anterior `COORDENADOR`: lê as coordenações, apaga todas (`db.bulk.delete`) e gera um `REMOVER_COORDENACAO` para cada uma, mesmo que uma unidade fique vazia, porque é uma saída (spec `coordenacao`).
5. Grava o papel e `ALTERAR_PAPEL`. A resposta traz `coordenacoes_removidas`.

### D9. Coordenação e transferência de professor

**Transferência** (`transferir_professor`, dentro de D3, depois de `exigir_admin`):
- o alvo é `PROFESSOR` `ATIVA`;
- o destino está ativo e é diferente da unidade atual;
- grava `unidade_vinculo_id` e `TRANSFERIR_PROFESSOR`, com a unidade de origem em `dados_antes`.

**Coordenação:** todas as operações rodam dentro de D3, depois de `exigir_admin`. O coordenador-alvo precisa estar `ATIVA` e ter papel `COORDENADOR`.
- **acrescentar:** tem menos de `max_unidades_coordenador` unidades; o destino está ativo, tem vaga e ainda não é dele.
- **mover:** a origem é dele e mantém pelo menos 1 coordenador ativo **além dele**; o destino está ativo, tem vaga e não é dele. Gera `REMOVER_COORDENACAO` + `ATRIBUIR_COORDENACAO`.
- **remover:** ele tem 2 unidades; a unidade removida mantém pelo menos 1 coordenador ativo além dele.

### D10. Unidades

- **criar:**
  - nome e endereço com `trim` e obrigatórios;
  - unicidade por `nome|to_lower` (confirmar na tarefa 1.2 o filtro dentro de `where`; se não for aceito, comparar sobre a lista, que é pequena);
  - depois, dentro de D3: valida o coordenador e o modo (regras de D9, com o destino sendo a unidade nova), insere a unidade, aplica mover ou acrescentar e grava `CRIAR_UNIDADE` mais os registros de coordenação.
  - A violação do índice único em corrida vira a mesma mensagem de nome repetido.
- **editar:** mesmas validações, excluindo a própria unidade; `dados_antes` e `dados_depois` só com nome e endereço.
- **desativar** (dentro de D3):
  - lê os coordenadores ativos, os professores `ATIVA` e os pedidos `PENDENTE` da unidade;
  - cada coordenador que tem só ela precisa ter exatamente um destino em `destinos_coordenadores` (destino ativo, com vaga e diferente da unidade). A vaga é verificada levando em conta os outros destinos do mesmo formulário;
  - cada professor precisa ter exatamente um destino em `destinos_professores` (ativo e diferente da unidade);
  - destinos para quem não precisa, ou faltando para quem precisa → 400, sem mudar nada;
  - remove todas as coordenações da unidade e cria as dos destinos;
  - grava a nova unidade de cada professor;
  - recusa os pendentes: `RECUSADA`, motivo "Unidade desativada", `recusa_sem_custo = true`, `aprovado_por_id` = ator e `aprovado_em` = now;
  - grava `ativa = false`;
  - gera `DESATIVAR_UNIDADE` mais os registros de coordenação, de transferência e de recusa automática.
  - A tela recebe de `GET /geridas` (ou de uma consulta de pré-visualização na mesma rota) os coordenadores, os professores e a contagem de pendentes, para montar o formulário. Os professores de cada unidade vêm de `usuario` filtrado por `PROFESSOR`, `ATIVA` e `unidade_vinculo_id`.
- **reativar:** `ativa = true` e `REATIVAR_UNIDADE`. A operação repetida devolve 400 sem auditoria, e o mesmo vale para desativar.
- **geridas:** admin → todas; coordenador → `unidades_coordenadas`. Cada item traz `coordenadores_ativos` e o indicador `sem_coordenador`.

### D11. Auditoria

Reutiliza `registrar_auditoria` sem alteração. As ações e as unidades seguem a tabela da spec `auditoria`. Os `dados_*` usam listas explícitas de campos:
- conta: `status_conta`, `papel`, `unidade_vinculo_id`, `motivo_recusa_cadastro`, `pedidos_cadastro`, `justificativa_cadastro`, `recusa_sem_custo`;
- unidade: `nome`, `endereco`, `ativa`;
- coordenação: `usuario_id`, `unidade_id`, `desde`.

### D12. Reflex

```
bookingSystem/
  api/xano_cliente.py        + funcoes de contas, unidades e pedido; XANO_API_CONTAS_URL
  state/auth_state.py        + vars de papel (e_admin, e_coordenador), guarda por papel
  state/pedido_state.py      situacao do pedido e reenvio (login), sem guardar a senha
  state/contas_state.py      pedidos, decisoes, usuarios, mudanca de papel
  state/unidades_state.py    unidades, coordenacao, criar/editar/desativar/reativar
  pages/layout.py            layout_autenticado: cabecalho, menu por papel, Sair
  pages/cadastro.py          + opcao Coordenador (com unidade)
  pages/login.py             + painel de recusa: motivo, "Pedir nova analise" ou aviso
  pages/inicio.py            usa o layout
  pages/aprovacoes.py        /aprovacoes
  pages/usuarios.py          /usuarios
  pages/unidades.py          /unidades
```

- **Token nos States novos:** eles obtêm o token com `await self.get_state(AuthState)` (ver "Confirmações do apply") e chamam o tratamento de sessão expirada do `AuthState`.
- **Guarda:** cada página restrita usa um `on_load` que roda `verificar_sessao` (que atualiza o papel via `/me`) e redireciona para `/inicio` se o papel não for permitido.
- **Erros:**
  - `NaoAutenticado` → sessão expirada;
  - `AcessoNegado` → mensagem e `/inicio`;
  - `ErroValidacao` → mensagem e recarga da lista.
- **Diálogos** (confirmar `rx.alert_dialog`/`rx.dialog` na skill): motivo da recusa, unidades ao virar coordenador, aviso de perda de coordenação e destinos da desativação.

### D13. Documentos do projeto

A change altera regras globais. Por isso, atualiza:
- `docs/project-overview.md`:
  - §4: coordenador com até 2 unidades, aprovação de cadastro de coordenador pelo admin, professor pertencente a uma unidade (com transferência pelo admin; reservas em qualquer unidade) e aluno pertencente à instituição;
  - §6.1 e §7.10: cadastro de coordenador, reenvio e limite de pedidos;
  - §11: a ordem das changes (C2 coordenação, C3 contas, admins e senha, C4 espaços...).
- `docs/domain-model.md`:
  - §2.1: campos de pedido e decisão, e o duplo sentido de `unidade_vinculo_id`;
  - §2.3: limites 1..2 e 1..4 e a unidade sem coordenador;
  - §2.18: parâmetros novos;
  - DER e A.1: campos e restrições;
  - uma nota sobre a tabela técnica `trava`, que fica fora do modelo de domínio (D3).
- Regra registrada para a change de reservas: **inativar conta cancela as reservas futuras.**

### D14. Sincronização

Mesmo fluxo da C1:
1. `xano workspace pull` para um diretório temporário e comparação com `./xano/`;
2. arquivos `.xs` validados no MCP;
3. `push --dry-run`, apresentação do resultado, aprovação explícita e push parcial, sem `--sync`, `--delete`, `--env` ou `--records`.

A sonda da tarefa 1.3 segue o mesmo fluxo e é removida depois. A remoção exige `--sync --delete` restrito, ou o painel, sempre com confirmação explícita.

## Risks / Trade-offs

- **[Trava por linha depende do comportamento do `db.edit`]** → Comprovado em execução na tarefa 1.3. Os testes de concorrência das rotas reais (8.4 e 8.6) confirmam também a releitura depois da trava.
- **[Uma operação esquecer a trava]** → Toda rota de escrita desta change chama `travar_governanca` como primeira instrução da transação. A revisão (11.5) confere isso rota por rota.
- **[Trava global serializa toda a governança]** → É aceito pelo volume da v1. Se virar gargalo, troca-se por chaves por unidade com ordem de aquisição.
- **[Sem sandbox: branch live]** → Sem dados reais; dry-run e aprovação em todo push, inclusive para a sonda.
- **[Exclusão física em `coordenacao_unidade`]** → O histórico só existe na auditoria, aceito porque ela é gravada na mesma transação.
- **[`unidade_vinculo_id` com duplo sentido]** → Documentado em D2 e no `domain-model.md`.
- **[Motivo da recusa visível ao titular]** → A tela de recusa avisa que o motivo será mostrado à pessoa.
- **[Senha usada duas vezes no fluxo de recusa]** → Ela fica só em variáveis locais do handler. A verificação do token e da senha no navegador (tarefa 10.x) cobre isso.

## Migration Plan

1. `xano workspace pull` em diretório temporário e comparação.
2. Teste de execução da trava (tarefa 1.3), com push da sonda via dry-run e aprovação, seguido de remoção.
3. Tabelas (campos opcionais, sem impacto nos registros atuais), funções e rotas, todos validados no MCP.
4. `push --dry-run`, aprovação e push. Executar o `bootstrap` para preencher os parâmetros e `pedidos_cadastro`.
5. `XANO_API_CONTAS_URL` no `.env` e no `.env.example`, `reflex run` e verificação manual.

**Rollback:** os campos novos são opcionais e as rotas novas são aditivas. As rotas antigas alteradas são `cadastro`, `login` e `bootstrap`: reverter os arquivos restaura o comportamento da C1, com novo push e dry-run. Remover a tabela ou as rotas do workspace exige `--sync --delete`, só com confirmação explícita.

## Confirmações do apply

Tarefa 1.2 (18/10/2026). Fontes: Xano Developer MCP (documentação 2.7.1 e validador) e documentação do Reflex (skill `reflex-docs`).

| Ponto | Resposta |
|---|---|
| `db.direct_query` dentro de `db.transaction` | Aceito pelo validador: `sql = "SELECT pg_advisory_xact_lock(?)"`, `arg = [<int>]`, `response_type = "single"`. Se ele roda na mesma transação, só a tarefa 1.3 responde. |
| `util.sleep` dentro de transação | Aceito: `util.sleep { value = <segundos> }`. |
| `to_lower` dentro de `where` | Aceito: `($db.unidade.nome\|to_lower) == $nome_normalizado`. D10 usa essa forma. |
| `join` + `eval` | Aceito: `join = {usuario: {table: "usuario", type: "inner", where: ...}}`, `eval = {usuario_nome: $db.usuario.nome}`, com filtro por campos de `usuario` no `where`. |
| `throw` e `precondition` na transação | Aceitos pelo validador. O rollback de `db.transaction` quando um passo falha foi verificado em execução na C1 (tarefa 6.9). O rollback por `precondition`/`throw` desta change é verificado na tarefa 8.10. |
| Error types | `inputerror` (400), `accessdenied` (403), `notfound` (404), `unauthorized` (401, confirmado na C1). |
| Substate e `_token` | A documentação diz que um substate "pode ler e alterar as vars do pai", mas **não** confirma o caso das vars de backend (`_`). Decisão: os States novos usam `await self.get_state(AuthState)` para obter o token, a forma documentada que não depende de herança. Ajuste em D12: `PedidoState`, `ContasState` e `UnidadesState` herdam de `rx.State`, não de `AuthState`. |
| Diálogos | `rx.alert_dialog.root(trigger, content(title, description, cancel, action))`, com `open` controlado por uma var do State e `on_open_change`. Para os formulários (motivo, unidades, destinos), usar `rx.dialog`, que aceita conteúdo livre. |
| **Teste 1.3: trava via `direct_query`** | **Falhou.** A sonda publicada no workspace (grupo `sonda_c2`) mostrou: sem trava, 2 chamadas simultâneas em 4,6 s e 5,1 s (a medição funciona); com trava, toda chamada devolve `Access Denied` em menos de 1,5 s. O `db.direct_query` não é permitido neste workspace (plano Free). |
| **Teste 1.3: trava por linha (`db.edit`)** | **Funcionou** (opção escolhida pelo usuário). Sem trava: 4,58 s / 4,65 s. Com trava, 2 simultâneas: 4,57 s / 8,61 s. Com trava, 3 simultâneas: 4,58 s / 8,61 s / 12,78 s. Falha forçada seguida de chamada normal: 4,63 s / 4,22 s (a trava é solta no rollback). D3 revisada para esse mecanismo. |
| **Testes da API (8.1 a 8.9)** | 113 verificações funcionais e 19 de auditoria, todas aprovadas. O plano Free limita a 10 requisições a cada 20 s, então o script de teste controla o ritmo. Concorrência real: 3 rodadas de aprovação e recusa simultâneas (sempre uma única decisão) e 2 acréscimos simultâneos na última vaga (só um entrou). |
| **Teste 8.10: rollback** | Feito com uma função temporária, executada só pelo CLI, em vez de quebrar a auditoria de `desativar` no workspace live. A função edita o endereço de uma unidade de teste e força a falha de `registrar_auditoria` na mesma transação. Resultado: o endereço ficou igual e nenhum registro foi gravado. |
| **Padrões falsos descartados** | Ao salvar, o Xano remove padrões `?=0` e `?=false` de inputs e campos. `validar_destino_coordenador` passou a tratar o vazio com `first_notnull:0`, e `recusa_sem_custo` vazio equivale a falso. Achado no pull de comparação da 7.1. |
| Push da sonda | O push parcial "adds and updates but makes no destructive changes". A sonda é publicada a partir de um diretório no scratchpad, com `--dry-run` e aprovação antes. Para retirá-la, faz-se novo push com `active = false` no grupo, e o usuário exclui o grupo pelo painel. Não se usa `--sync --delete`, que apagaria tudo o que não está no diretório. |

## Open Questions

- Texto final das mensagens da interface. As mensagens funcionais estão em D4 a D10 e podem ser polidas sem mudar as specs.
