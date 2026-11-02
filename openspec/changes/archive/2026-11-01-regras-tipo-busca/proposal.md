## Why

A C4 cadastrou tipos de espaço, espaços e recursos, mas os tipos ainda não têm **regras de uso**: não se sabe quem pode reservar cada tipo, quem precisa de aprovação, qual é a duração mínima e máxima, a antecedência permitida nem o horário de funcionamento. Também não existe uma forma de alunos e professores **encontrarem** espaços. Sem regras e sem busca, a reserva (C6) não tem o que validar nem por onde começar.

Esta change (C5) cria as regras por tipo de espaço e por papel e a busca de espaços. A validação de um horário contra as regras fica numa função única, que a C6 reutiliza acrescentando só a checagem de conflito.

## What Changes

**Regras do tipo (qualquer admin)**
- Cada tipo ganha oito regras: duração mínima e máxima (minutos), antecedência mínima (minutos) e máxima (dias), máximo de reservas ativas por usuário, hora de abertura e de fechamento e se permite recorrência.
- Regra por papel (RegraPapel) para **aluno** e **professor**: se o papel pode reservar o tipo e se precisa de aprovação. **Coordenador e administrador** têm regra fixa: reservam todos os tipos, sem aprovação.
- As regras são editadas juntas, num diálogo "Regras" da página "Tipos de espaço", com validação de consistência (mínimo ≤ máximo, múltiplos da granularidade, abertura antes do fechamento).
- Um tipo **sem regras completas não é reservável**: a disponibilidade derivada da C4 ganha o motivo "tipo sem regras".
- Os quatro tipos iniciais recebem, uma única vez, as regras padrão aprovadas no explore. Tipos criados depois, e o Refeitório e o tipo de teste já existentes, nascem sem regras até que um admin as defina.

**Parâmetros globais (só o admin principal)**
- Novos parâmetros em `ConfiguracaoGeral`: **granularidade de horário** (10 min) e **dias de funcionamento** (segunda a sexta).
- O horário 08h00–22h40 deixa de ser um teto global e passa a ser o **valor padrão** de cada tipo.

**Busca de espaços (todos os usuários autenticados)**
- Filtros por unidade, tipo, capacidade mínima e recursos (o espaço precisa ter todos os selecionados), e data e horário opcionais.
- Mostra espaços de **todas as unidades**, só os reserváveis e só dos tipos que o papel de quem busca pode reservar.
- Cada resultado traz código, unidade, tipo, capacidade, localização, recursos e se a reserva exigiria aprovação.
- Com data e horário informados, cada resultado diz se o pedido está **dentro das regras do tipo** e, quando não está, o motivo. A busca **não** diz que o espaço está livre: reservas e bloqueios só existem a partir da C6 e da C10.
- Página "Buscar espaços" no menu de todos os papéis.

**Fora do escopo**
- Reserva, conflito de horário, limite de reservas ativas em uso e expiração (C6 e C7).
- Bloqueios e feriados (C10): a busca pode mostrar como "dentro das regras" um dia que for feriado.
- Fila de espera e prioridade (C8); penalidade (C9).
- Reserva recorrente (C11): a regra "permite recorrência" é só guardada nesta change.
- Página pública do espaço e avaliações (C12).
- Regra por papel configurável para coordenador e administrador.
- Paginação da busca.

## Capabilities

### New Capabilities
- `regras-tipo`: regras de uso de cada tipo de espaço, regra por papel de aluno e professor, regra fixa de coordenador e admin, validações, completude das regras, carga inicial dos tipos iniciais e o diálogo de regras.
- `busca-espacos`: filtros da busca, visibilidade por papel, resultado, validação de data e horário contra as regras do tipo e a página "Buscar espaços".

### Modified Capabilities
- `tipos-espaco`: a listagem e a tela de tipos passam a indicar se o tipo tem regras completas.
- `espacos`: a disponibilidade derivada passa a exigir também que o tipo tenha regras completas (motivo "tipo sem regras").
- `parametros`: granularidade de horário e dias de funcionamento entram na consulta, na edição e na validação dos parâmetros.
- `autorizacao`: o menu de todos os papéis ganha "Buscar espaços".
- `auditoria`: um requisito novo com a ação de alteração das regras do tipo.

## Impact

- **Papéis afetados:**
  - Aluno e professor: passam a buscar espaços.
  - Coordenador: busca espaços de todas as unidades (a gestão continua restrita às unidades que coordena).
  - Administrador: define as regras dos tipos.
  - Administrador principal: define granularidade e dias de funcionamento.
- **Regras do `project-overview.md` tocadas:**
  - §6, itens 2 e 3: busca de espaços e verificação das regras do tipo;
  - §7.1: horário de funcionamento passa de teto global a padrão por tipo; granularidade e dias viram parâmetros;
  - §7.2: regras por tipo de espaço e por papel;
  - §10: auditoria da nova ação.
  - O overview (§7.1, §7.2, §11), o `domain-model.md` (§2.4, §2.5, §2.18, DER e A.1) e a invariante de horário do `openspec/config.yaml` são atualizados nesta change.
- **Xano:**
  - campos de regra em `tipo_espaco`;
  - tabela nova `regra_papel`;
  - parâmetros novos em `configuracao_geral`;
  - funções novas de regra por papel, de completude, de validação de horário e de leitura dos parâmetros de horário (`obter_configuracao` não muda, para não afetar as rotas da C1 à C3);
  - `disponibilidade_espaco`, `parametros`, `tipos`, `geridos` e `bootstrap` alterados;
  - rotas novas no grupo `espacos`.
  - Publicação sempre com dry-run e aprovação.
- **Reflex:** funções novas no cliente; página "Buscar espaços"; diálogo de regras na página de tipos; dois campos novos na página de parâmetros; menu atualizado.
- **Dependências:** nenhuma nova.
