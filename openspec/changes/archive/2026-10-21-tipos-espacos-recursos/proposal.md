## Why

Depois da C3, o sistema tem contas, papéis, unidades, coordenação e auditoria, mas ainda não tem **o que reservar**. Não há tipos de espaço, espaços nem recursos. A busca (C5) e a reserva (C6) dependem desse cadastro: sem espaço, não há conflito de horário a verificar.

Esta change (C4) cria o cadastro de tipos de espaço, espaços e do catálogo de recursos, com a autorização por papel e por unidade da C2 e a auditoria na mesma transação. As regras de uso de cada tipo (duração, antecedência, quem reserva, aprovação) ficam para a C5, conforme o item 5 do §11 do `project-overview.md`.

## What Changes

**Tipos de espaço (qualquer admin)**
- Criar, editar (nome e descrição), desativar e reativar tipos. O nome é único, sem diferenciar maiúsculas e minúsculas.
- Os quatro tipos iniciais (Sala de aula, Laboratório, Biblioteca e Auditório) entram pela carga inicial, só quando ainda não existe nenhum tipo.
- Nesta change, o tipo tem só nome, descrição e situação. Os campos de regra e a `RegraPapel` são da C5.
- Desativar um tipo **não altera** os espaços dele, mas eles deixam de ser reserváveis. A tela avisa quantos espaços, e de quantas unidades, ficam indisponíveis.

**Catálogo de recursos (só admin)**
- Criar, renomear e excluir recursos (projetor, computadores, ar-condicionado...). O nome é único, sem diferenciar maiúsculas e minúsculas.
- A exclusão só é permitida se nenhum espaço, ativo ou inativo, usar o recurso.

**Espaços (coordenador nas unidades que coordena, admin em todas)**
- Criar e editar espaços com nome, código, tipo, capacidade, localização e descrição.
- O código é único **dentro da unidade**, sem diferenciar maiúsculas e minúsculas.
- Não se cria espaço em unidade inativa nem com tipo inativo. Trocar o tipo só é permitido para um tipo ativo.
- Definir os recursos do espaço e a quantidade de cada um.
- Desativar e reativar espaços. Espaços **nunca são excluídos**.
- **Mover** o espaço para outra unidade ativa: só o admin, sem colisão de código no destino.
- **Disponibilidade derivada:** um espaço só é reservável quando ele, a unidade dele e o tipo dele estão ativos. A listagem de gestão mostra essa situação e o motivo.

**Frontend:** páginas "Espaços" (gestor), "Tipos de espaço" e "Recursos" (admin), com os itens no menu por papel.

**Fora do escopo**
- Regras por tipo de espaço e `RegraPapel` (C5).
- Busca de espaços disponíveis e catálogo para alunos e professores (C5).
- Página pública do espaço com avaliações (C12).
- Reservas e o efeito da desativação de espaço, tipo ou unidade, ou da mudança de unidade, sobre reservas ativas e filas (C6/C7, registrado como pendência).
- Exclusão física de espaços e de tipos.
- Desativação de recursos (o recurso é excluído quando não está em uso).
- Fotos de espaços e upload de arquivos.
- Paginação das listagens.

## Capabilities

### New Capabilities
- `tipos-espaco`: carga inicial dos tipos, criação, edição, desativação e reativação pelo admin, listagem para gestores e a tela de tipos.
- `recursos`: catálogo global de recursos mantido pelo admin, com exclusão só sem uso, listagem para gestores e a tela de recursos.
- `espacos`: cadastro de espaços por unidade com autorização por escopo, código único por unidade, recursos com quantidade, desativação e reativação, mudança de unidade pelo admin, disponibilidade derivada, listagem de gestão e a tela de espaços.

### Modified Capabilities
- `autorizacao`: "Navegação por papel no frontend" passa a listar o menu completo, com os itens da C3 que faltavam na spec ("Trocar senha", "Administradores", "Parâmetros") e os novos ("Espaços", "Tipos de espaço", "Recursos").
- `auditoria`: um requisito novo com as ações de tipos de espaço, espaços e recursos.

## Impact

- **Papéis afetados:**
  - Administrador (qualquer um): mantém tipos de espaço e o catálogo de recursos; gere espaços de todas as unidades e move espaços entre unidades.
  - Coordenador: cria, edita, desativa e reativa espaços das unidades que coordena e define os recursos deles.
  - Aluno e professor: nada muda nesta change.
- **Regras do `project-overview.md` tocadas:**
  - §4: o coordenador cadastra e edita espaços só nas próprias unidades; o admin cria tipos de espaço e passa a manter o catálogo de recursos;
  - §5 e §6 (itens 13 e 14): gestão de tipos de espaço, espaços e recursos;
  - §7.2: só os tipos iniciais; as regras do tipo ficam para a C5;
  - §10: auditoria das ações novas;
  - §11: pendências registradas para as changes 5, 6 e 7.
  - O overview (§4, §10 e §11) e o `domain-model.md` (§2.2, §2.4, §2.6, §2.7 e Apêndice A) são atualizados nesta change.
- **Xano:**
  - tabelas novas: `tipo_espaco`, `espaco`, `recurso` e `espaco_recurso`;
  - grupo de API novo `espacos`;
  - `bootstrap` atualizado com os tipos iniciais.
  - Publicação sempre com dry-run e aprovação.
- **Reflex:** variável de ambiente nova `XANO_API_ESPACOS_URL`, funções novas no cliente, States e páginas novas e o menu atualizado.
- **Dependências:** nenhuma nova.
