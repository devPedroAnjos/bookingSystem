## Context

A C2 deixou prontos os padrões que esta change reutiliza:
- **trava por linha:** `travar_governanca` é a primeira instrução de toda transação que conta e grava;
- **autorização:** `usuario_ativo`, `exigir_admin` e `autorizar_unidade`;
- **coordenação:** `validar_destino_coordenador`, `atribuir_coordenacao`, `remover_coordenacao` e `coordenadores_ativos`;
- **parâmetros:** `obter_configuracao`;
- **auditoria:** `registrar_auditoria` na mesma transação.

Toda rota autenticada passa por `usuario_ativo`, direta ou indiretamente. Esse é o ponto único onde entram as checagens novas de sessão e de senha provisória.

Restrições conhecidas do Xano (memória do projeto):
- não há isolamento serializável nem `direct_query`;
- o Xano descarta padrões `false` e `0` ao salvar, então todo booleano novo trata vazio como falso;
- o plano Free limita a 10 requisições a cada 20 s.

Confirmado no MCP durante o explore: os `extras` do token aparecem em `$auth.<campo>` (a documentação usa `$auth.role`). Falta confirmar em execução (tarefa 1.2) se `$auth` também está disponível **dentro** de uma função chamada pela rota.

A motivação está no `proposal.md`. Os requisitos estão nas specs `administradores`, `senha`, `situacao-conta`, `parametros`, `autenticacao`, `coordenacao` e `auditoria`.

## Goals / Non-Goals

**Goals:**
- Um ponto único (`usuario_ativo`) que recusa sessões anteriores à última troca de senha e restringe contas com senha provisória.
- Uma função única de permissão sobre contas-alvo (principal, admins e demais), reutilizada por inativar, reativar, redefinir senha e rebaixar.

**Non-Goals:**
- Lista de tokens revogados ou tabela de sessões. A data de validade das sessões resolve o requisito sem guardar tokens.
- Recuperação por e-mail e 2FA.
- Paginação das listagens.

## Decisions

### D1. Divisão entre Xano e Reflex

```
REFLEX                                   XANO
- /trocar-senha (todos)                  - auth:   login*, me*, trocar_senha
- /administradores (principal)           - contas: admins, promover_admin, criar_admin,
- /parametros (principal)                          rebaixar_admin, inativar, reativar,
- /usuarios* (inativar, reativar,                  redefinir_senha, parametros (GET/POST)
  redefinir senha)                       - funcoes: usuario_ativo*, exigir_principal,
- AuthState* (senha provisoria, token              autorizar_sobre_conta, validar_email_institucional
  novo apos troca)                       - bootstrap*
(* = alterado)
```

Todas as rotas novas de gestão ficam no grupo `contas`. Assim não surge outra variável de ambiente no Reflex.

### D2. Dados (DER do `domain-model.md`)

| Tabela | Campos | Divergências do DER |
|---|---|---|
| `usuario` | + `admin_principal` (bool), `senha_provisoria` (bool), `sessoes_validas_desde` (int, epoch em ms) | Os três não existem no DER. Os booleanos tratam vazio como falso (o Xano descarta `false` como padrão). O motivo da inativação **não** vira campo: fica só em `dados_depois` da auditoria, onde a spec o exige. |
| `configuracao_geral` | + `max_admins` (int) | Parâmetro novo, que o `domain-model.md` §2.18 passa a listar. |

`sessoes_validas_desde` usa o mesmo formato de `now` no Xano (inteiro em milissegundos), para comparar sem conversões.

### D3. Sessões invalidadas pela troca de senha

```
login / trocar_senha:  token.extras = { emitido_em: now }
trocar / redefinir:    usuario.sessoes_validas_desde = now
rota autenticada:      emitido_em = ($auth.extras|get:"emitido_em")|first_notnull:0
usuario_ativo:         recebe emitido_em; recusa (401) se sessoes_validas_desde != null
                                  e emitido_em < sessoes_validas_desde
```

*Revisado no apply (tarefa 1.2):* `$auth` **não existe dentro de funções**, e os extras ficam em `$auth.extras.<campo>`, não em `$auth.<campo>`. Por isso `usuario_ativo` passa a receber `emitido_em` como entrada, e cada rota autenticada o lê com a forma segura acima e o repassa pela cadeia (`exigir_admin`, `exigir_principal`, `autorizar_unidade`, `autorizar_sobre_conta`, `carregar_pedido_para_decisao`). A leitura direta `$auth.extras.emitido_em` derruba a requisição (500) quando o token é anterior à C3; a forma com `get` e `first_notnull:0` não derruba.

- Tokens emitidos antes desta change não têm `emitido_em` e valem como 0. Eles continuam válidos até a primeira troca de senha da conta, porque até lá `sessoes_validas_desde` está vazio.
- `trocar_senha` grava `sessoes_validas_desde = now` e, **depois**, emite um token novo com `emitido_em = now`. O token novo vale (`>=`), e o Reflex substitui o token da sessão atual por ele (spec `senha`, "Troca de senha derruba as outras sessões").
- **Pré-requisito verificado na tarefa 1.2.** Rodo uma sonda descartável, publicada com dry-run e aprovação, que emite um token com `extras` e lê o valor **(a)** na própria rota e **(b)** dentro de uma função chamada por ela.
  - Se (b) falhar, `usuario_ativo` ganha a entrada `emitido_em`, e cada chamada passa `$auth.emitido_em`. Isso exige atualizar `exigir_admin`, `autorizar_unidade` e as funções e rotas que chamam `usuario_ativo`. O comportamento não muda, só a assinatura.
  - Se (a) falhar, o apply para e pede revisão.
- *Alternativa descartada:* uma tabela de sessões, com um id por token e revogação. Ela resolve também o "sair de todos os dispositivos", mas acrescenta escrita e leitura em toda requisição e uma tabela nova. O requisito só pede invalidar o que veio antes da troca.

### D4. Senha provisória

- `usuario_ativo` ganha a entrada opcional `permite_senha_provisoria`. Para não depender de padrão `false`, a checagem é `== true`.
  - Com `senha_provisoria` verdadeira e sem permissão, a resposta é 403 "Troque sua senha para continuar.".
  - Só `me` e `trocar_senha` passam a permissão.
- O login devolve `senha_provisoria` junto com os dados do usuário, e o `me` também.
- O Reflex trata essa mensagem 403 como sinal para ir a `/trocar-senha`. Isso fica na função comum `tratar_erro_api` e na guarda das páginas.
- A **criação** de admin e a **redefinição** gravam a senha (o tipo `password` já faz o hash), `senha_provisoria = true` e `sessoes_validas_desde = now`.

### D5. Permissão sobre a conta-alvo

A função `autorizar_sobre_conta(ator_id, alvo_id)` roda dentro da trava e devolve `{ator, alvo}`:
1. `exigir_admin(ator)` → 403 para não-admins.
2. Alvo inexistente → 404.
3. Alvo é o **principal** → 400 "O administrador principal não pode ser alterado por esta operação.".
4. Alvo é `ADMIN` (secundário) e o ator não é principal → 403.

Ela é usada por `inativar`, `reativar`, `redefinir_senha` e `rebaixar_admin`. Já `promover_admin`, `criar_admin` e `parametros` usam `exigir_principal(ator)`, que é `exigir_admin` mais `admin_principal == true`.

### D6. Administradores (dentro da trava)

- **Contagem do limite:** contas `ADMIN` com `ATIVA`, comparadas com `max_admins` de `obter_configuracao`. A função `vaga_de_admin` é reutilizada por promover, criar e reativar.
- **promover_admin:**
  - o alvo é `COORDENADOR` `ATIVA` e há vaga;
  - remove as coordenações (`remover_coordenacao` para cada uma);
  - grava `papel = ADMIN` e `unidade_vinculo_id = null`;
  - audita `PROMOVER_ADMIN`;
  - a resposta traz `coordenacoes_removidas`.
- **criar_admin:**
  - nome, e-mail e senha provisória (8 ou mais caracteres);
  - o e-mail passa por `validar_email_institucional`, extraída do `cadastro` para não duplicar a regra de domínio;
  - e-mail repetido → 400 (o admin pode saber que ele existe);
  - há vaga;
  - `db.add` com `ADMIN`, `ATIVA`, `senha_provisoria = true` e `sessoes_validas_desde = now`;
  - audita `CRIAR_ADMIN`.
- **rebaixar_admin:**
  - D5;
  - novo papel **só** `COORDENADOR`: `unidades_ids` de 1 até `max_unidades_coordenador`, cada uma por `validar_destino_coordenador` e depois `atribuir_coordenacao`. Não há entrada de papel: qualquer tentativa de outro destino é recusada na interface e na spec. Para virar professor, o ex-admin usa depois a `alterar_papel` da C2;
  - audita `REBAIXAR_ADMIN`.
- **GET /admins** (principal): lista os admins com `admin_principal` e situação.

### D7. Inativação e reativação (dentro da trava)

- **inativar:**
  - D5;
  - alvo `ATIVA`;
  - motivo com `trim`, não vazio, até 500 caracteres (validado antes da trava);
  - grava `INATIVA`;
  - audita `INATIVAR_CONTA` com o motivo.
  - As coordenações **não** são tocadas.
- **reativar:** D5; alvo `INATIVA`. Depois, conforme o papel:
  - **COORDENADOR:** para cada coordenação, mantém se a unidade está ativa e tem menos ativos que `max_coordenadores_unidade` (ele não conta, porque está inativo); senão aplica `remover_coordenacao`.
    - Se não sobrar nenhuma: exige `unidades_ids` (1 até o máximo, `validar_destino_coordenador` com `atribuir_coordenacao`) ou responde 400 "Escolha de 1 a N unidades para o coordenador.".
    - Se sobrar alguma, `unidades_ids` é ignorado.
  - **PROFESSOR:** se a unidade dele não estiver ativa, exige `unidade_id` de uma unidade ativa (grava e audita `TRANSFERIR_PROFESSOR`); senão 400 pedindo a unidade.
  - **ADMIN:** exige vaga (`vaga_de_admin`).
  - Grava `ATIVA` e audita `REATIVAR_CONTA`. A resposta traz `coordenacoes_descartadas`.

### D8. Senha

- **trocar_senha** (`auth`, autenticada com `permite_senha_provisoria = true`):
  - confere a senha atual com `security.check_password`;
  - a nova tem 8 ou mais caracteres e é diferente da atual (comparada com `check_password` contra o hash atual);
  - grava a senha, `senha_provisoria = false` e `sessoes_validas_desde = now`;
  - emite um token novo com `emitido_em = now`;
  - audita `TROCAR_SENHA`;
  - responde `{mensagem, token}`.
- **redefinir_senha** (`contas`): D5; alvo `ATIVA`; senha provisória de 8 ou mais caracteres; grava a senha, `senha_provisoria = true` e `sessoes_validas_desde = now`; audita `REDEFINIR_SENHA`.
- As senhas são entradas `sensitive` e nunca entram em `dados_*` da auditoria.

### D9. Parâmetros

- **GET /parametros** (principal): devolve os cinco parâmetros.
- **POST /parametros** (principal, dentro da trava):
  - inteiros com 1 ou mais;
  - domínios: `trim` e `to_lower`, sem `@` nem espaço, sem repetição, ao menos 1;
  - grava tudo de uma vez;
  - audita `ALTERAR_PARAMETROS` com os valores antes e depois.

### D10. Bootstrap

O bootstrap continua idempotente e passa a fazer três coisas:
- preenche `max_admins = 3` onde estiver vazio;
- se nenhum admin tiver `admin_principal`, marca o admin `ATIVA` mais antigo (o da C1);
- quando cria o primeiro admin, ele já nasce com `admin_principal = true`.

A marcação do admin existente como principal grava `MARCAR_ADMIN_PRINCIPAL` na auditoria, com ator vazio porque é uma ação do sistema. Isso segue a regra de que toda ação sensível é auditada, e a ação foi acrescentada no apply.

### D11. Reflex

- **AuthState:**
  - ganha `senha_provisoria` e `e_principal` (do login e do `me`);
  - a guarda leva para `/trocar-senha` enquanto a senha for provisória;
  - `trocar_senha` substitui `_token` pelo token novo devolvido pela API;
  - `tratar_erro_api` redireciona para `/trocar-senha` ao receber "Troque sua senha para continuar.".
- **Menu:**
  - com senha provisória: só "Trocar senha" e "Sair";
  - para o principal: acrescenta "Administradores" e "Parâmetros";
  - "Trocar senha" aparece para todos.
- **Páginas novas:** `/trocar-senha`, `/administradores` (promover, criar, rebaixar, inativar, reativar e redefinir senha de admins) e `/parametros`.
- **`/usuarios`:** ganha "Inativar" (motivo), "Reativar" (pede unidades quando a API indicar) e "Redefinir senha".
- **States:** `SenhaState`, `AdminsState` e `ParametrosState`, que obtêm o token com `get_state(AuthState)`, como na C2. `ContasState` ganha inativar, reativar e redefinir.

### D12. Documentos

Esta change atualiza:
- **`project-overview.md`:**
  - §4: admin principal e secundários, até 3 admins;
  - §7.10: trocar senha, senha provisória e redefinição pelo admin; recuperação por e-mail fora do projeto;
  - §10: sessões invalidadas pela troca.
- **`domain-model.md`:**
  - §2.1: campos novos e o ciclo `INATIVA`;
  - §2.18: `max_admins`;
  - DER.

### D13. Sincronização

Mesmo fluxo da C2:
1. pull de comparação;
2. `.xs` validados no MCP;
3. dry-run, aprovação e push parcial;
4. pull de comparação depois do push, para pegar padrões descartados pelo Xano.

A sonda da tarefa 1.2 é publicada a partir do scratchpad e excluída pelo painel.

## Risks / Trade-offs

- **[`$auth` indisponível dentro de funções]** → Confirmado na 1.2. Toda rota autenticada passa `emitido_em` adiante. Uma rota que esqueça de passá-lo trata o token como antigo (0) e recusa sessões após uma troca de senha: o efeito é seguro (nega), e a revisão (9.4) confere rota por rota.
- **[Leitura direta dos extras derruba tokens antigos]** → Só a forma segura (`get` + `first_notnull:0`) é usada, testada com token sem extras.
- **[Relógio]** → `emitido_em` e `sessoes_validas_desde` vêm do `now` do mesmo servidor Xano. Não há relógio do cliente envolvido.
- **[Tokens anteriores à change]** → Continuam válidos até a primeira troca de senha da conta, o que é aceito. A expiração de 24 h limita o efeito.
- **[Senha provisória conhecida pelo admin]** → Mitigada pela troca obrigatória no primeiro acesso. A auditoria registra quem redefiniu.
- **[Duas operações sobre o limite de admins ao mesmo tempo]** → Trava por linha, como na C2, testada na 8.x.

## Migration Plan

1. Pull de comparação.
2. Sonda do token (1.2), com push aprovado, teste e exclusão.
3. Campos, funções e rotas validados no MCP.
4. Dry-run, aprovação e push; `bootstrap` duas vezes, conferindo que o admin da C1 virou principal e que `max_admins` é 3.
5. Reflex e verificação manual.

**Rollback:** os campos novos são opcionais e as rotas novas são aditivas. `usuario_ativo`, `login`, `me` e `bootstrap` voltam ao arquivo anterior com novo push. Sem `sessoes_validas_desde` preenchido, o comportamento é o da C2.

## Confirmações do apply

| Ponto | Resultado |
|---|---|
| **Sonda 1.2: extras do token** | Grupo temporário `sonda_c3`, publicado com dry-run e aprovação. `security.create_auth_token` com `extras = {emitido_em: now}` funcionou. Leituras na rota: `$auth.id` → 1; `$auth.emitido_em` → 500 "Unable to locate auth"; `$auth.extras` → `{"emitido_em": 1792532972199}` (token novo) ou `[]` (token sem extras); `$auth.extras.emitido_em` → valor (token novo) ou **500** (token sem extras); `($auth.extras|get:"emitido_em")|first_notnull:0` → valor ou **0**, sem erro. |
| **`$auth` dentro de função** | Indisponível: "Unable to locate auth" ao ler `$auth` numa função chamada pela rota. D3 adota a forma com `emitido_em` como entrada de `usuario_ativo`. |
| **`now` fora de campo `timestamp`** | Depois do push da 6.1, todas as rotas autenticadas responderam 400 "Value is not a valid integer." para tokens novos. Em `extras = {emitido_em: now}` o Xano grava o texto `"now"`, sem calcular a hora (reproduzido pelo CLI). Corrigido com `var $agora { value = now }` em `emitir_token` e nos três `sessoes_validas_desde` (`trocar_senha`, `redefinir_senha` e `criar_admin`), com novo push aprovado. Tokens anteriores ao push não foram afetados. |
| **Diálogos comuns no Reflex (D11)** | Inativar, reativar e redefinir senha aparecem em `/usuarios` e em `/administradores`. Em vez de ficarem só no `ContasState`, estão em `AcoesContaMixin` (mixin de State do Reflex), herdado por `ContasState` e `AdminsState`. Cada página mantém as próprias mensagens e recarrega a própria lista, sem duplicar código. |

## Open Questions

- Texto final das mensagens da interface.
