## Context

A C2 e a C3 deixaram prontos os padrões que esta change reutiliza:
- **trava por linha:** `travar_governanca` é a primeira instrução de toda transação que confere e grava;
- **autorização:** `usuario_ativo`, `exigir_admin` e `autorizar_unidade`, todos recebendo `emitido_em`, lido na rota com `($auth.extras|get:"emitido_em")|first_notnull:0` (C3, D3);
- **unicidade sem diferenciar maiúsculas:** comparação com `to_lower` na rota e índice único como última defesa (`exigir_nome_unidade_livre`);
- **auditoria:** `registrar_auditoria` na mesma transação, só com os campos alterados;
- **listagem por escopo:** `GET /unidades/geridas` (admin recebe tudo, coordenador só as unidades que coordena, demais 403);
- **carga inicial:** `bootstrap` idempotente, sem auditoria para os dados iniciais.

Restrições conhecidas do Xano (memória do projeto):
- não há isolamento serializável nem `direct_query`, por isso a trava por linha;
- o Xano descarta padrões `false` e `0` ao salvar. Os booleanos novos desta change têm padrão `true`.
- o plano Free limita a 10 requisições a cada 20 s.

A motivação está no `proposal.md`. Os requisitos estão nas specs `tipos-espaco`, `recursos`, `espacos`, `auditoria` e `autorizacao`. As decisões tomadas no explore e no propose estão no `decisions-log.md`.

## Goals / Non-Goals

**Goals:**
- Uma única regra de disponibilidade (`espaco.ativo AND unidade.ativa AND tipo.ativo`), calculada no backend por uma função que a busca (C5) e a reserva (C6) vão reutilizar.
- Toda escrita sob `travar_governanca`, para que criar espaço, desativar unidade, excluir recurso e associar recurso nunca se cruzem.

**Non-Goals:**
- Campos de regra em `tipo_espaco` e a tabela `regra_papel` (C5).
- Paginação, ordenação configurável e filtros na API das listagens. O filtro por unidade da tela de espaços é feito no State do Reflex.
- Cache das listagens.

## Decisions

### D1. Divisão entre Xano e Reflex

```
REFLEX                                   XANO (grupo novo "espacos")
- /espacos (gestor)                      - tabelas: tipo_espaco, espaco, recurso, espaco_recurso
- /tipos-espaco (admin)                  - rotas tipos:    tipos (GET), criar_tipo, editar_tipo,
- /recursos (admin)                                         desativar_tipo, reativar_tipo
- menu* (Espacos; Tipos de espaco;       - rotas recursos: recursos (GET), criar_recurso,
  Recursos)                                                 editar_recurso, excluir_recurso
- xano_cliente* (grupo espacos)          - rotas espacos:  geridos (GET), criar_espaco, editar_espaco,
- EspacosState, TiposEspacoState,                           definir_recursos, desativar_espaco,
  RecursosState                                             reativar_espaco, mover_espaco
                                         - funcoes: disponibilidade_espaco, carregar_espaco_gerido,
                                           exigir_nome_tipo_livre, exigir_nome_recurso_livre,
                                           exigir_codigo_livre
                                         - bootstrap* (tipos iniciais)
(* = alterado)
```

Tipos, recursos e espaços ficam num único grupo, `espacos`. Um grupo por entidade criaria três variáveis de ambiente no Reflex sem ganho. Os nomes das rotas seguem o padrão `<verbo>_<entidade>` (`criar_tipo`, `criar_espaco`, `excluir_recurso`) e são únicos no workspace inteiro, não só no grupo: o Xano CLI casou rotas novas, ainda sem `guid`, com rotas homônimas de outro grupo (ver "Confirmações do apply").

### D2. Dados (DER do `domain-model.md`)

| Tabela | Campos | Índices | Divergências do DER |
|---|---|---|---|
| `tipo_espaco` | `nome` (text, trim), `descricao` (text, trim, opcional), `ativo` (bool, `?=true`) | `nome` único | Os campos de regra do DER (`duracao_*`, `antecedencia_*`, `max_reservas_ativas_usuario`, `hora_*`, `permite_recorrencia`) ficam para a C5, que os cria junto com a edição das regras. Assim, nenhum tipo fica com valores de regra que ninguém definiu. |
| `espaco` | `unidade_id` (FK `unidade`), `tipo_espaco_id` (FK `tipo_espaco`), `nome`, `codigo`, `capacidade` (int), `localizacao` (opcional), `descricao` (opcional), `ativo` (bool, `?=true`) | (`unidade_id`, `codigo`) único; `tipo_espaco_id` | **`codigo` é único por unidade**, não global (decisão do usuário, Q6 no `decisions-log.md`). Como espaços nunca são excluídos, um código global ficaria preso para sempre e impediria salas de mesmo número em prédios diferentes. A mudança de unidade confere a colisão no destino. |
| `recurso` | `nome` (text, trim) | `nome` único | Nenhuma. O DER não tem `ativo`, e o recurso é excluído fisicamente quando não está em uso (Q4). |
| `espaco_recurso` | `espaco_id`, `recurso_id`, `quantidade` (int) | (`espaco_id`, `recurso_id`) único; `recurso_id` | Nenhuma. A linha é apagada fisicamente ao redefinir os recursos do espaço, como `coordenacao_unidade`. O histórico fica na auditoria (`ALTERAR_RECURSOS_ESPACO`). |

- O índice único composto é a última defesa. A validação principal é feita na rota, com `to_lower`, porque o índice diferencia maiúsculas. A sintaxe de índice composto é confirmada no MCP na tarefa 1.2.
- Tamanhos máximos, validados na rota depois do `trim`:
  - tipo: nome até 60 caracteres e descrição até 300;
  - recurso: nome até 60;
  - espaço: nome até 100, código até 20, localização até 150 e descrição até 500.

  São limites técnicos de formulário, não regras de negócio, e por isso não viram parâmetros (o mesmo critério do motivo de inativação na C3). O Reflex usa os mesmos números no tamanho máximo dos campos, para o erro aparecer antes do envio.

### D3. Trava e ordem das checagens

Toda rota de escrita segue a mesma ordem dentro de `db.transaction`:
1. `travar_governanca`;
2. autorização (`exigir_admin` ou `carregar_espaco_gerido`);
3. releitura do que será validado (unidade, tipo, recurso, espaço);
4. validações de regra;
5. gravação;
6. `registrar_auditoria`.

As validações de formato (campos obrigatórios, tamanhos, capacidade e quantidades ≥ 1, recurso repetido na lista) rodam **antes** da transação, como em `editar` de unidades, para não segurar a trava à toa.

A trava é a mesma da C2 porque as operações se cruzam:
- criar espaço confere a unidade ativa, enquanto a desativação de unidade roda sob a trava;
- excluir recurso confere que ninguém o usa, enquanto `definir_recursos` o associa;
- criar ou trocar o tipo de um espaço confere o tipo ativo, enquanto `desativar_tipo` o desativa.

*Alternativa descartada:* linhas de trava separadas (por exemplo, `"espacos"`). Elas não protegeriam o cruzamento com a desativação de unidade, que já usa `"governanca"`.

### D4. Autorização sobre espaços

- **Tipos e recursos (escrita):** `exigir_admin`. Qualquer admin, porque tipo de espaço não é parâmetro geral (Q3).
- **Tipos e recursos (leitura):** `usuario_ativo` mais papel `ADMIN` ou `COORDENADOR`; senão 403. O coordenador precisa deles nos formulários de espaço.
- **Criar espaço:** `autorizar_unidade(unidade_id)`. Unidade inexistente: 404 para o admin; o coordenador recebe 403 de `autorizar_unidade` antes, porque não coordena uma unidade que não existe.
- **Demais escritas sobre espaço:** a função nova `carregar_espaco_gerido(usuario_id, emitido_em, espaco_id)`, no molde de `carregar_pedido_para_decisao`:
  1. `usuario_ativo`;
  2. papel `ADMIN` ou `COORDENADOR`, senão 403;
  3. `db.get espaco`;
  4. se o ator for `ADMIN`: espaço inexistente → 404;
  5. se for `COORDENADOR`: espaço inexistente **ou** `unidade_id` fora de `unidades_coordenadas` → 403 "Você não tem acesso a este espaço.";
  6. devolve `{ator, espaco}`.

  Para o coordenador, alvo inexistente ou fora do escopo responde 403, nunca 404 (C2, D4). Assim ele não consegue sondar ids de espaços de outras unidades.

  Ela é usada por `editar_espaco`, `definir_recursos`, `desativar_espaco` e `reativar_espaco`. O coordenador só edita espaços de unidade desativada se ainda a coordenasse, o que não acontece porque a desativação remove as coordenações (`desativar_POST.xs`). Assim, "só o admin edita espaço de unidade desativada" sai da regra de escopo, sem checagem extra.
- **Mover:** `exigir_admin`, depois `db.get espaco` (404).

### D5. Unicidade e normalização

Três funções no molde de `exigir_nome_unidade_livre`, chamadas dentro da trava:
- `exigir_nome_tipo_livre(nome, ignorar_id?)`;
- `exigir_nome_recurso_livre(nome, ignorar_id?)`;
- `exigir_codigo_livre(unidade_id, codigo, ignorar_id?)`, que compara `to_lower(codigo)` dentro da unidade. Ela é usada na criação, na edição (com `ignorar_id`) e na mudança de unidade (com a unidade de destino e `ignorar_id` = o próprio espaço).

O valor é gravado como digitado, depois do `trim`; só a comparação ignora maiúsculas. É o mesmo comportamento das unidades.

*Alternativa descartada:* uma função genérica com o nome da tabela como entrada. O XanoScript não parametriza a tabela de `db.query`, e três funções pequenas são mais legíveis.

### D6. Rotas

| Rota | Quem | Regras principais | Auditoria |
|---|---|---|---|
| `GET tipos` | gestor | todos os tipos por nome; para o admin, `espacos_ativos` e `unidades` (contagem distinta de `unidade_id` dos espaços ativos do tipo) | — |
| `POST criar_tipo` | admin | nome livre (D5) | `CRIAR_TIPO_ESPACO` |
| `POST editar_tipo` | admin | tipo existe (404); nome livre ignorando ele mesmo | `EDITAR_TIPO_ESPACO` |
| `POST desativar_tipo` / `reativar_tipo` | admin | tipo existe; situação atual oposta, senão 400 | `DESATIVAR_` / `REATIVAR_TIPO_ESPACO` |
| `GET recursos` | gestor | catálogo por nome; para o admin, `espacos` (quantos espaços usam) | — |
| `POST criar_recurso` / `editar_recurso` | admin | nome livre (D5) | `CRIAR_` / `EDITAR_RECURSO` |
| `POST excluir_recurso` | admin | recurso existe (404); nenhuma linha em `espaco_recurso` com ele, senão 400 "O recurso é usado por N espaço(s)."; `db.del` | `EXCLUIR_RECURSO` |
| `GET geridos` | gestor | D8 | — |
| `POST criar_espaco` | gestor com escopo | D4; unidade ativa; tipo existe e ativo; código livre na unidade | `CRIAR_ESPACO` |
| `POST editar_espaco` | gestor com escopo | D4; tipo ativo só se `tipo_espaco_id` mudar; código livre ignorando ele mesmo; não aceita `unidade_id` nem `ativo` | `EDITAR_ESPACO` |
| `POST definir_recursos` | gestor com escopo | D7 | `ALTERAR_RECURSOS_ESPACO` |
| `POST desativar_espaco` / `reativar_espaco` | gestor com escopo | situação atual oposta, senão 400; reativar não confere unidade nem tipo | `DESATIVAR_` / `REATIVAR_ESPACO` |
| `POST mover_espaco` | admin | destino existe (404), diferente da atual, ativo; código livre no destino | `MOVER_ESPACO`, com `unidade_id` = destino |

Não existe rota de exclusão de espaço nem de tipo. O `db.add` de tipo e de espaço grava `ativo: true` explicitamente, sem depender do padrão da tabela.

### D7. Recursos do espaço

`definir_recursos(espaco_id, recursos: [{recurso_id, quantidade}])`:
- **Antes da trava:** cada `quantidade` ≥ 1 e nenhum `recurso_id` repetido. Senão 400, indicando o item.
- **Dentro da trava:**
  1. `carregar_espaco_gerido`;
  2. cada `recurso_id` existe (relido dentro da trava, o que fecha a corrida com `excluir_recurso`);
  3. lê as linhas atuais (lista "antes", ordenada por nome do recurso);
  4. apaga cada linha atual com `db.del` por id e grava as novas com `db.add` em `foreach`, dentro da transação (padrão de `remover_coordenacao`; ver "Confirmações do apply");
  5. audita a lista antes e a lista depois, cada item com `{recurso_id, nome, quantidade}`.

Substituir a lista inteira é mais simples que comparar item a item e combina com o diálogo da tela, que edita a lista toda. A operação é sempre gravada e auditada, mesmo quando a lista não muda, como `editar` de unidades.

*Alternativa descartada:* recursos dentro de `criar` e `editar` do espaço. Isso misturaria duas ações de auditoria numa rota e deixaria a edição dos dados básicos sujeita a erros de recurso.

### D8. Disponibilidade e listagem de gestão

A função `disponibilidade_espaco(espaco_ativo, unidade_ativa, tipo_ativo)` devolve `{reservavel, motivos}`, com `motivos` como lista de códigos:
- `ESPACO_DESATIVADO`;
- `UNIDADE_DESATIVADA`;
- `TIPO_DESATIVADO`.

A função recebe a situação já carregada do espaço, da unidade e do tipo, sem consultar o banco, para a listagem não multiplicar as consultas. A C5 e a C6 a reutilizam. O Reflex traduz os códigos para os textos da tela.

`GET geridos`:
1. `usuario_ativo`; papel gestor, senão 403;
2. unidades do escopo: todas para o admin, `unidades_coordenadas` para o coordenador;
3. uma consulta para cada tabela (`espaco` das unidades do escopo, `unidade`, `tipo_espaco`, `espaco_recurso` dos espaços, `recurso`), com a junção feita em memória, em vez de consultas por espaço;
4. cada item com os campos da spec `espacos` e o resultado de `disponibilidade_espaco`;
5. ordem por nome da unidade e depois por código.

### D9. Carga inicial dos tipos

O `bootstrap` ganha um passo depois das unidades: se `tipo_espaco` estiver **vazia** (`db.query ... return = {type: "count"}` igual a 0), cria os quatro tipos iniciais ativos. Cada um tem uma descrição curta: "Aulas e atividades em turma", "Aulas práticas com equipamentos", "Estudo individual ou em grupo" e "Palestras e eventos". A resposta do bootstrap passa a listar `tipos_criados`.

O critério da tabela vazia evita recriar um tipo inicial que o admin tenha renomeado (spec `tipos-espaco`, "Tipo inicial renomeado"). *Alternativa descartada:* checar por nome, como nas unidades. O bootstrap roda depois de todo push, e um tipo renomeado voltaria.

### D10. Reflex

- **Cliente (`xano_cliente.py`):** constante `_ESPACOS = "XANO_API_ESPACOS_URL"` e uma função por rota de D6, com docstring curta, no padrão atual. A variável entra no `.env.example`.
- **States:** `TiposEspacoState`, `RecursosState` e `EspacosState`. Eles obtêm o token com `get_state(AuthState)`, como os States atuais. Cada um tem `abrir` (carrega a lista), os diálogos e o tratamento de erro comum.
  - O `EspacosState` também carrega tipos, recursos e as unidades do escopo, para os formulários.
  - As unidades vêm de `GET /unidades/geridas`, que já devolve o escopo do coordenador. Como ela também traz unidades desativadas, os formulários de criar e mover filtram as ativas.
  - O filtro por unidade é local.
- **Páginas:**
  - `/espacos` (`exigir_gestor`): tabela com destaque para os não reserváveis e o motivo. Diálogos de criar e editar (só unidades ativas do escopo e tipos ativos no seletor; o tipo atual desativado aparece como valor atual), recursos (lista editável de recurso e quantidade), desativar e reativar. "Mover" aparece só para `e_admin`.
  - `/tipos-espaco` (`exigir_admin`): tabela com destaque para os desativados. Diálogos de criar e editar. A desativação mostra "N espaços de M unidades deixarão de ser reserváveis" a partir dos dados de `GET tipos`.
  - `/recursos` (`exigir_admin`): tabela com a contagem de uso. A exclusão só aparece para recursos sem uso.
- **Menu (`layout.py`):** "Espaços" para `e_gestor`; "Tipos de espaço" e "Recursos" para `e_admin`. A ordem fica: Início, Aprovações, Espaços, Usuários, Unidades, Tipos de espaço, Recursos, Administradores, Parâmetros, Trocar senha.

### D11. Documentos

Esta change atualiza, como tarefa, o que a C2 e a C3 também fizeram:
- **`domain-model.md`:**
  - §2.2: desativar ou reativar a unidade não altera os espaços; enquanto ela estiver desativada, eles não são reserváveis;
  - §2.4: na C4, o tipo só tem nome, descrição e situação; as regras vêm na C5; tipos nunca são excluídos;
  - §2.6: espaços nunca são excluídos, o código é único por unidade, a disponibilidade é derivada e só o admin muda a unidade;
  - §2.7: o admin mantém o catálogo, e o recurso só é excluído sem uso;
  - Apêndice A: `ESPACO.codigo` deixa de ser `UK` global e passa a único por (`unidade_id`, `codigo`); A.1 ganha as restrições de `espaco`, `tipo_espaco` e `recurso`; A.2 ganha os índices `espaco (unidade_id, codigo)`, `espaco (tipo_espaco_id)` e `espaco_recurso (recurso_id)`.
- **`project-overview.md`:**
  - §4: o admin mantém o catálogo de recursos e move espaços entre unidades;
  - §10: incluir "cadastrar e alterar tipos de espaço, espaços e recursos" na lista de ações auditadas;
  - §11: o item 4 passa a "(C4, `tipos-espacos-recursos`)", como os itens 1 a 3, e os itens 5, 6 e 7 recebem as pendências abaixo.

### D12. Sincronização

Mesmo fluxo da C3:
1. pull de comparação;
2. `.xs` validados no MCP;
3. dry-run, aprovação e push;
4. `bootstrap` duas vezes;
5. pull de comparação depois do push, para pegar padrões descartados pelo Xano.

### D13. Pendências para as próximas changes

| Change | Pendência |
|---|---|
| C5 | Criar os campos de regra e a `regra_papel` e definir como os tipos já existentes recebem regras. A C5 não pode depender do nome do tipo, porque o admin renomeia e cria tipos (por exemplo, "recorrência só em sala de aula", §7.5). Um tipo sem regras completas não pode ser reservável. |
| C5 | A busca mostra espaços de todas as unidades a todos os papéis, inclusive coordenadores. A regra "coordenador só visualiza a própria unidade" (§2.2) vale para dados de gestão, não para a busca. |
| C5 | Abrir a leitura do catálogo (tipos ativos e recursos) a alunos e professores, que hoje recebem 403 em `GET tipos` e `GET recursos`, e esconder os tipos desativados dos filtros da busca. |
| C5 | Como o código só é único dentro da unidade, a busca e a reserva mostram o código junto com o nome da unidade. |
| C5/C6 | Usar `disponibilidade_espaco` na busca e na criação de reserva. |
| C6 | `disponibilidade_espaco` recebe registros já carregados. A criação de reserva relê espaço, unidade e tipo dentro da trava antes de chamá-la, para que uma desativação simultânea não passe. |
| C6/C7 | Definir o efeito, sobre reservas ativas e entradas de fila, de desativar um espaço, um tipo ou uma unidade, e de mover um espaço de unidade (o aprovador das pendentes muda, §7.6). O §2.6 sugere manter as reservas já feitas, porque diz só "não aceita novas reservas". A regra é decisão de negócio e vai ao usuário no explore da C6. |

## Risks / Trade-offs

- **[Índice composto não suportado como esperado]** → A tarefa 1.2 confirma no MCP a sintaxe de índice único com dois campos. Sem ele, a unicidade fica só na rota, sob a trava, que já é a defesa principal (como nas unidades).
- **[Concorrência entre excluir recurso e associá-lo]** → As duas operações rodam sob `travar_governanca` e releem o recurso dentro da trava. Verificado por chamadas simultâneas na tarefa 7.x.
- **[Mais carga na trava única]** → As escritas desta change são raras (gestão) e curtas. As validações de formato ficam fora da trava (D3).
- **[Listagem grande]** → Sem paginação. As consultas são uma por tabela, não uma por espaço (D8). A paginação fica para quando houver volume real.
- **[Admin desativa um tipo sem perceber o alcance]** → A tela avisa quantos espaços e unidades são afetados antes de confirmar.
- **[Tipo criado na C4 sem regras]** → Pendência da C5 (D13). Até lá, nenhum espaço é reservável, porque a reserva só existe a partir da C6.

## Migration Plan

1. Pull de comparação.
2. Confirmações no MCP (tarefa 1.2): índice composto, `db.del` e contagem distinta.
3. Tabelas, funções, rotas e `bootstrap` validados no MCP.
4. Dry-run, aprovação e push; `bootstrap` duas vezes, conferindo os quatro tipos e que a segunda execução não cria nada.
5. Reflex, `.env` com `XANO_API_ESPACOS_URL` e verificação manual.

**Rollback:** as tabelas, as rotas e o grupo são novos e aditivos. O `bootstrap` volta ao arquivo anterior com novo push. As tabelas novas podem ficar vazias ou ser removidas pelo painel sem afetar a C1 a C3.

## Confirmações do apply

| Ponto | Resultado |
|---|---|
| **Índice único composto (1.2)** | O MCP (tópico `tables`) documenta índice composto com vários itens em `field`, e o validador aceita `{type: "btree\|unique", field: [{name: "espaco_id"}, {name: "recurso_id"}]}`. A `coordenacao_unidade` da C2 já usa essa forma (`usuario_id` + `unidade_id`) e o pull da 1.1 a mostra preservada no workspace. Se o índice é aplicado nas tabelas novas é conferido na 6.6. |
| **Apagar e regravar várias linhas (1.2)** | `db.del` apaga um registro por campo e valor. `db.bulk.delete` com `where` é aceito pelo validador, mas o exemplo documentado de `db.bulk.add` com `data =` é **recusado** ("The argument 'data' is not valid in this context"); o validador só aceita `items = <lista>`. Nenhum `db.bulk.*` foi executado neste workspace, e a documentação já falhou antes neste projeto (`isolation`, `direct_query`). **Decisão (guardian, opção B):** usar o padrão já comprovado de `remover_coordenacao`: ler as linhas do espaço, apagar cada uma com `db.del` por id e gravar as novas com `db.add` em `foreach`, tudo na transação. As listas são pequenas. |
| **Colisão de nomes de rota (5.1)** | O primeiro dry-run mostrou `criar`, `editar`, `desativar` e `reativar` (POST) do grupo `espacos` como "API endpoint will be **updated** [XS content differs]", casadas com as rotas homônimas de `unidades`: 12 criadas e 4 atualizadas, em vez de 16 criadas. Nada foi publicado. As cinco rotas de espaço passaram a `criar_espaco`, `editar_espaco`, `desativar_espaco`, `reativar_espaco` e `mover_espaco`. Causa provável, não provada: o CLI casa por `guid` quando existe e por nome e verbo quando não existe (`contas/reativar` e `unidades/reativar` convivem no workspace porque ambos têm `guid`). Regra adotada: nome de rota único no workspace inteiro. |
| **Push e pull (5.1)** | O CLI exige `--force` em ambiente não interativo ("Non-interactive environment detected"). O push foi feito com `--force` logo depois do dry-run aprovado, sem `--sync`, `--delete`, `--env` nem `--records`: 88 documentos, 26 `guid` gravados nos arquivos locais. O bootstrap criou os quatro tipos na primeira execução e nada na segunda. O pull diferiu só em formato: `precondition (x == true)` virou `precondition (x)`, objetos de várias linhas passaram ao modo expressão (entre crases) e houve quebras de linha. Os 14 arquivos foram alinhados ao pull, e o diff ficou zero. |
| **Chave ausente no bootstrap (5.1)** | A resposta do bootstrap não traz `principal_marcado`, a última chave do objeto `$resultado`, que está em modo expressão. A falha é anterior à C4 (o código veio da C3) e não tem efeito funcional no bootstrap. Hipótese não provada: objetos em modo expressão perdem a última chave em execução. A tarefa 6.0 confere isso nas rotas da C4 e em rotas de leitura da C3. |
| **Resultado da 6.0** | Confirmado em execução: `definir_recursos` recusou uma lista válida ("pelo menos 1"), porque o `map` de `$lista` em modo expressão, sem vírgulas, perdeu `quantidade`. As rotas da C3 conferidas (`contas/usuarios`, `contas/pedidos` e `contas/admins`) vieram íntegras. **Correção:** vírgulas entre as chaves nos cinco blocos em modo expressão da C4 (`definir_recursos` e `geridos`), no formato de `login_POST`, e no `$resultado` do bootstrap (C3, correção aprovada pelo usuário). Push aprovado (3 atualizações). Depois do push, as rotas mantiveram as vírgulas; o Xano reconverteu o `$resultado` do bootstrap para literal comum. Repetição: lista válida aceita, `geridos` com `quantidade` e `motivos`, bootstrap com `principal_marcado`. Falta conferir a auditoria `ALTERAR_RECURSOS_ESPACO`, feita junto com a 6.7. **Regra:** em objeto com várias linhas dentro de expressão (`push:`, `map:`, `value =` entre crases), separar as chaves por vírgula. |
| **Verificação da API (6.0 a 6.7)** | Scripts descartáveis no scratchpad, a cerca de 2 s por requisição (plano Free), com as credenciais do `.env` sem impressão. **Fixtures:** aluno, professor e coordenador de teste cadastrados e aprovados pelos fluxos reais (e-mails `tst.c4.*`), e a unidade de teste 9 criada acrescentando o coordenador, que também coordena a unidade 1. **Resultados:** 6.1 a 6.5, 71 casos; 6.6, 2 casos de concorrência; 6.7, 29 checagens de auditoria; 0 falhas. A auditoria foi lida pela função temporária `tst_ler_auditoria`, executada só pelo CLI, publicada com aprovação a partir do scratchpad e a ser excluída pelo painel. O CLI avisou "table log_auditoria does not exist ... placeholder" no push dela, mas a função leu o log normalmente e o pull seguinte mostrou `log_auditoria.xs` inalterado. **Dados que ficaram no sandbox:** 7 espaços TST desativados (ids 1 a 7, nas unidades 1, 7 e 9), o tipo TST id 5 e a unidade id 9 desativados, 3 contas de teste inativadas e os registros de auditoria dos testes. Os recursos de teste foram excluídos. |
| **Componentes comuns do Reflex (7.x e 8.2)** | `pages/componentes.py` ganhou dois parâmetros opcionais, com padrão compatível com os usos atuais: `seletor(..., valor_inicial=...)`, que mostra o tipo atual na edição mesmo desativado, e `dialogo(..., limpar_ao_enviar=True)`. Os 8 diálogos da C4 usam `limpar_ao_enviar=False` e mostram o erro de validação dentro do diálogo (`erro_dialogo` nos três States, padrão de `acoes_conta.py` da C3). Na verificação manual, o erro aparecia atrás do diálogo e o formulário era limpo. Corrigido e retestado pelo usuário. |
| **Unidades distintas (1.2)** | Não há agregação distinta em `db.query`. A contagem é feita em memória: `($espacos\|map:$$.unidade_id)\|unique\|count`, sobre os espaços ativos do tipo, que já são lidos para `espacos_ativos`. |

## Open Questions

- Texto final das mensagens da interface e das descrições dos tipos iniciais.
