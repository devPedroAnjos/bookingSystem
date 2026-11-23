# Design: feed de espaços, página do espaço, avaliações, foto de capa e visual

## Context

O motivo e o escopo estão no `proposal.md`; as regras, nas specs desta change. O estado atual que molda a abordagem:

- **Busca:** `buscar_espacos_POST.xs` monta a lista em memória. Lê unidades, espaços, tipos, regras por papel e recursos numa consulta por tabela e descarta, no `$incluir`, os tipos que o papel não pode reservar. Com horário, faz uma consulta por tabela para reservas, filas e bloqueios sobrepostos.
- **Reservas do usuário:** `minhas_reservas_GET.xs` usa a mesma técnica e já devolve a situação efetiva (`situacao_efetiva`), com `CONCLUIDA`, e o `checkin_possivel`.
- **Escopo de gestão:** `carregar_espaco_gerido.xs` resolve quem gere o espaço.
- **Parâmetros:** os de `configuracao_geral` são lidos direto da tabela e preenchidos pelo `bootstrap`.
- **Xano gratuito:** o armazenamento só guarda imagens, é público, permite até 64 MB por arquivo e 1 GB de banda, e aplica marca d'água. A sonda manual de 22/11 mostrou a marca "Powered by Xano" no canto inferior esquerdo (decisão 2). O MCP confirmou o upload com input `file?` (não `image?`), `storage.create_image` (JPEG, PNG, GIF e WEBP) e `storage.delete_file`, e a URL pública como a origem da instância mais o `path`.
- **Frontend:** o Reflex 0.10 tem 17 páginas, sem tema (`rx.App()`). Usa só as cores semânticas do Radix (`color="red"` etc.), sem nenhum hex fixo. O menu fica em `layout.py`, com cerca de 14 links. A Início (`inicio.py`) só mostra a saudação, e a busca fica em `buscar.py` com o `BuscaState`.
- **Design system:** o Figma "Design" traz tokens claros e escuros, a escala tipográfica em Inter, raios de 4 a 24, três sombras, ícones Lucide, o logo com o livro no t e as telas de Login, Início e Escolher horário. Os protótipos HTML enviados pelo usuário servem de referência de layout, e os itens fora do domínio foram cortados (decisão 10).

## Goals / Non-Goals

**Goals:**
- Backend único para o feed: a mesma rota de busca devolve os completos e os restritos, a foto e a média, sem rota nova de listagem.
- Avaliação gravada com atomicidade suficiente: unicidade por reserva garantida pelo índice, mesmo com envios simultâneos.
- Tema claro aplicado de uma vez às 17 páginas, por tokens, sem mudar o comportamento das páginas antigas.
- Componentes novos escritos só com os tokens, para que o tema escuro possa entrar depois sem retrabalho.

**Non-Goals:**
- Tema escuro (decisão 15). Se sobrar tempo, entra por um `/opsx:update` com o requisito antes de ser implementado.
- Paginação, cache de imagens, redimensionamento ou compressão da foto.
- Reescrever os cenários antigos de `aprovacao-reservas` e `fila-espera` que citam "Buscar espaços". O endereço antigo continua levando à Início, então eles seguem verdadeiros.

## Decisions

### Xano

**D1. Dados.**
- **Tabela nova `avaliacao`, conforme o DER:** `id`, `reserva_id` (FK, índice `btree|unique`), `usuario_id` (FK), `nota` (int), `comentario` (text opcional, `trim`) e `criado_em`. Não há `espaco_id`: a média por espaço junta `avaliacao` com `reserva` em memória (D3), para não divergir do DER.
- **Campo novo `espaco.foto_capa`** (`image?`), com o objeto devolvido pelo `storage.create_image` (`path`, `name`, `size`, `mime`, `meta`). É uma divergência do DER, que não tinha foto porque o upload tinha saído da v1. O `domain-model.md` é atualizado na change.
- **Campos novos em `configuracao_geral`:**
  - `prazo_avaliacao_dias` (int opcional), que já estava no DER;
  - `foto_tamanho_max_kb` (int opcional), novo e registrado no `domain-model.md`.

  Os dois são preenchidos pelo `bootstrap` com 7 e 1024 quando nulos.
- *Alternativa descartada:* `espaco_id` denormalizado em `avaliacao` para agregar numa consulta. Na escala do projeto, juntar em memória basta.

**D2. `avaliar_reserva` (POST, grupo `reservas`).**
1. Validar o ator com `usuario_ativo`.
2. Validar a nota (inteira, de 1 a 5) e o comentário (`trim`, até 500 caracteres; vazio vira nulo).
3. Chamar `aplicar_vencimentos` para o próprio usuário, como as demais operações. Assim a conclusão já devida fica gravada.
4. Carregar a reserva. A de outro usuário, ou inexistente, recebe "Reserva não encontrada.".
5. Calcular a situação pela `situacao_efetiva` com os parâmetros de comparecimento. A decisão vale mesmo se a faxina não tiver gravado nada, porque a falha dela não bloqueia.
6. Exigir `CONCLUIDA` e `agora <= fim + prazo_avaliacao_dias × 86.400.000` ms.
7. Recusar se já existir avaliação da reserva.
8. Gravar a avaliação e o `AVALIAR_RESERVA` numa transação.

Duas avaliações simultâneas passam juntas pela checagem do passo 7. O índice único de `reserva_id` recusa a segunda gravação, e o erro é traduzido para "Esta reserva já foi avaliada.". Não é preciso usar a trava por linha (`travar_governanca`), porque não há contagem seguida de gravação: a regra é de unicidade, e o índice a garante. O comportamento do índice e a captura do erro são confirmados no apply (C1).

**D3. Média e lista de avaliações.** Função nova `avaliacoes_dos_espacos`, que recebe uma lista de ids de espaço e devolve, por espaço, a quantidade e a média arredondada a uma casa. São duas consultas: as avaliações, e as reservas avaliadas com `id in` a lista de `reserva_id` para obter o `espaco_id`. O detalhe do espaço lista as avaliações com o autor:
- o primeiro nome vem do primeiro trecho de `usuario.nome`;
- o papel é o atual da conta, em enum. O Reflex mostra o rótulo.

Não sai o e-mail, o id do autor nem a reserva.

**D4. `buscar_espacos`.**
- **Restritos:** o `$incluir` deixa de exigir `$regra.pode_reservar`. O item ganha `restrito` e, quando restrito, `restricao`: o texto montado no Xano com os papéis que podem reservar o tipo, a partir de `regras_do_tipo` (por exemplo, "Reservável por professores, coordenadores e administradores"). O restrito leva só id, nome, código, unidade, tipo, capacidade, localização, `foto_url` e `restricao` (decisão 26): sem descrição, recursos, `exige_aprovacao`, média nem os campos de horário. O filtro de recursos não o encontra, e o texto é comparado só com os campos que ele mostra. Com horário, o laço de validação, ocupação, deslocamento, fila e bloqueio é pulado para ele, o que também reduz o custo.
- **Texto:** input `texto` (até 100 caracteres, `trim`). A comparação usa `|to_lower|unaccent` sobre a concatenação dos seis campos (nome, código, descrição e localização do espaço, nomes da unidade e do tipo) e sobre o texto pedido. A disponibilidade de `unaccent` no pipeline do XanoScript é confirmada no apply (C2). Se faltar, fica só `to_lower`, e a limitação vai para o relatório.
- **Foto e média:** `foto_url` quando houver foto (D7) e, nos não restritos, `media_avaliacoes` e `total_avaliacoes`, de uma chamada a `avaliacoes_dos_espacos` com todos os ids incluídos.
- **Recusa do texto longo:** "O texto da busca deve ter até 100 caracteres.".

**D5. `filtros_busca`.** Devolve todos os tipos ativos com regras completas, com `pode_reservar`. `exige_aprovacao` e as regras de horário só vêm nos tipos que o papel pode reservar.

**D6. `detalhe_espaco` (GET, grupo `espacos`).**
- **Entrada:** `espaco_id`.
- **Recusa:** reaproveita `tipo_com_regras`, `disponibilidade_espaco` e `regra_do_papel`. Espaço inexistente, não reservável ou de tipo que o papel não pode reservar recebe 404 com "Espaço não encontrado.". A mesma mensagem nos três casos não revela que o espaço restrito existe.
- **Resposta:** os campos do resultado da busca mais as avaliações (D3).
- **Nome:** é único no workspace, porque o CLI casa rotas pelo nome.

**D7. Foto de capa.**
- **`definir_foto_espaco` (POST multipart, grupo `espacos`):**
  1. Receber `int espaco_id` e `file? foto`.
  2. Resolver o escopo com `carregar_espaco_gerido`.
  3. Validar o `mime` (`image/jpeg`, `image/png` ou `image/webp`) e o tamanho contra `foto_tamanho_max_kb`. Se o objeto do input não trouxer o tamanho antes do armazenamento (C3), grava, confere o `size` devolvido e apaga o arquivo recusado com `storage.delete_file`.
  4. Gravar com `storage.create_image`, `access = "public"`.
  5. Numa transação, fazer o `db.edit` de `foto_capa` e registrar o `DEFINIR_FOTO_ESPACO`.
  6. Depois do commit, apagar o arquivo anterior.
- **`remover_foto_espaco` (POST):** recusa espaço sem foto, zera o campo e audita numa transação, e depois apaga o arquivo.
- **Auditoria:** guarda só `name`, `size` e `path`.
- **URL pública:** é a origem da instância mais o `path`. O Xano devolve `foto_url` já montada se o objeto lido do banco trouxer a URL ou se der para obter a origem sem variável nova (C4). Se não der, a rota devolve o `path`, e o cliente Reflex completa com a origem da própria URL da API, já presente no `.env`. Em nenhum dos casos há variável nova.
- *Alternativa descartada:* `storage.create_attachment`, porque o plano gratuito só guarda imagens. Foto privada com URL assinada também foi descartada: não existe no plano gratuito.

**D8. Outras rotas alteradas.**
- **`geridos_GET`:** `foto_url` e `foto_tamanho_max_kb` (para o aviso e a checagem de usabilidade na tela).
- **`parametros_GET` e `parametros_POST`:** os dois campos, com as mesmas validações de inteiro ≥ 1.
- **`bootstrap`:** os dois padrões.
- **`minhas_reservas_GET`:** passa a devolver:
  - por reserva, `pode_avaliar`, `avaliar_ate` (data e hora em São Paulo) e `avaliacao_nota`, com uma consulta a `avaliacao` com `reserva_id in` os ids;
  - `proxima_reserva_id`: a `PENDENTE` ou `CONFIRMADA` efetiva que ainda não terminou, com o menor início; no empate, a de menor `id` (a criada antes). A pendente expirada e a confirmada sem check-in depois da janela ficam de fora porque a situação efetiva já as marca `EXPIRADA` e `NAO_COMPARECEU`. Assim a escolha não é reimplementada no Reflex.

**D9. Auditoria.**
- `AVALIAR_RESERVA` (entidade `avaliacao`): dados depois com `reserva_id`, `espaco_id`, `nota` e `tem_comentario`. O texto do comentário fica fora, porque já é público na página e não precisa ser duplicado.
- `DEFINIR_FOTO_ESPACO` e `REMOVER_FOTO_ESPACO` (entidade `espaco`), com a unidade do espaço.

### Reflex

**D10. Tema por tokens.**
- **Folha de estilo:** `assets/tema.css` define os tokens do Figma como variáveis CSS (`--bs-bg`, `--bs-surface`, `--bs-primary`, `--bs-accent`, `--bs-ink`, `--bs-line`, raios e sombras). Também sobrescreve, dentro de `.radix-themes`, as variáveis do Radix que dão a cor de destaque (`--accent-9`, `--accent-10`, `--accent-contrast` e as superfícies), a fonte padrão e o raio.
- **App:** `rx.App(theme=rx.theme(appearance="light", accent_color="grass", radius="medium"), stylesheets=[...])`, com a Inter pelo Google Fonts. As páginas antigas herdam tudo sem mudar o código.
- **Regra para os componentes novos:** só `var(--bs-*)` ou as cores semânticas do Radix, nunca hex no Python. A paleta escura do Figma fica registrada aqui para o update opcional: `bg #0e1411`, `surface #161e1a`, `surface-sunken #1e2823`, `primary #6cc093`, `ink #e8efeb`, `ink-muted #a3b1a9`, `line #33403a`, `brand-deep #154931`.
- *Alternativa descartada:* só escolher um `accent_color` do Radix (por exemplo, `jade`). Fica perto, mas não reproduz o verde do Figma nem o lima.

**D11. Logo e favicon.**
- **Arquivos:** SVGs estáticos em `assets/` (logotipo positivo e negativo, e símbolo t-livro), a partir do markup dos HTMLs e do Figma.
- **Livro no t:** o livro fica numa posição fixa. Os HTMLs posicionam o livro por JavaScript (`getExtentOfChar`). No SVG estático, a posição é medida uma vez no navegador durante o apply e conferida visualmente.
- **Favicon:** substitui o `favicon.ico` atual.

**D12. Navegação (`layout.py`).**
- **Barra:** fixa no topo, com o logotipo (que leva à Início), "Início" e "Minhas reservas".
- **Menu "Gestão":** `rx.menu`, só quando há itens, com os mesmos `rx.cond` por papel de hoje.
- **À direita:** o chip com o nome e o papel, que abre "Trocar senha" e "Sair".
- **Senha provisória:** a barra mostra só "Trocar senha" e "Sair".
- **Aviso da fila:** continua logo abaixo da barra.

**D13. Início com o feed.**
- **Componentes:** os de `buscar.py` viram componentes do feed: filtros, cartão e diálogos de reservar e de entrar na fila.
- **Página:** a Início monta o cartão "Próxima reserva" e o feed.
- **Estado:** o `BuscaState.abrir` carrega as opções e dispara a primeira busca sem filtros. O campo de texto envia no Enter.
- **Rota antiga:** `/buscar` vira uma página que só redireciona para `/inicio`.
- **Cartão "Próxima reserva":** usa `minhas_reservas` (`proxima_reserva_id`) e a ação `fazer_checkin` que já existe.
- **Ordem da Início no `on_load`:** sessão, fila, busca e reservas. A busca do feed e a lista de reservas são duas chamadas paralelas.

**D14. Cartão do espaço.**
- **Topo:** `rx.image` com `loading="lazy"` e `object-fit: cover` quando há foto. Sem foto, uma faixa com a cor e o ícone do tipo. A cor sai de uma lista fixa de tokens, indexada pelo id do tipo, e o ícone de palavras do nome: biblioteca → `book-open`, laboratório → `flask-conical`, sala → `presentation`, auditório → `theater`, outros → `door-open`. É só apresentação.
- **Restrito:** opacidade reduzida e `grayscale`, cadeado, o rótulo "Restrito" e o `restricao` do backend, sem link e sem botões.
- **Não restrito:** o cartão é um link para `/espaco/[espaco_id]`, e as ações de horário ficam no rodapé.

**D15. Página do espaço.** Rota `/espaco/[espaco_id]`, porque `/espacos` já é a gestão, com o `EspacoState` e o `on_load` que chama `detalhe_espaco`. A página tem:
- a foto ou a faixa;
- os dados;
- o destaque escuro (`brand-deep`) com a média em lima;
- a lista de avaliações com estrelas, comentário, data e "Primeiro nome · Papel".

A recusa mostra "Espaço não encontrado" com o link para a Início.

**D16. Avaliar.**
- **Onde:** um diálogo em "Minhas reservas", em vez da página "Avaliar locais" dos protótipos, porque a avaliação parte da reserva.
- **Estado:** `AvaliacaoState`, com a nota escolhida (0 = nenhuma) e o comentário. O botão "Enviar" só fica habilitado com nota ≥ 1.
- **Recusa:** fica no diálogo.
- **Sucesso:** recarrega a lista.

**D17. Foto em "Espaços".**
- **Diálogo "Foto":** `rx.upload` com aceitação de JPEG, PNG e WEBP, a prévia do cartão, o aviso de formatos, tamanho e pessoas, e os botões "Salvar foto" e "Remover foto". A remoção pede confirmação.
- **Envio:** o handler lê os bytes, confere o tamanho contra `foto_tamanho_max_kb` (só usabilidade) e chama `xano_cliente.definir_foto_espaco`, que envia multipart pelo `httpx` com o token no cabeçalho, do lado do servidor.
- **Lista:** a miniatura aparece em cada espaço.

**D18. Telas de entrada.**
- **Login e cadastro:** passam a ter a tela verde de boas-vindas com o logotipo negativo, "Entrar" e "Criar conta", e os cartões de formulário no estilo do Figma.
- **O que fica igual:** os campos, as validações e as mensagens. Cadastro com unidade e papel conforme as specs atuais, sem SSO e sem recuperação por e-mail.

### Documentos

**D19.**
- **`project-overview.md`:**
  - §5: as fotos saem de "fora do escopo";
  - §6: itens 2 e 12;
  - §7.9: prazo como parâmetro, autor como primeiro nome e papel, visibilidade só para quem pode reservar o tipo;
  - §10: as três ações novas;
  - §11: a change feita e o tema escuro como trabalho futuro.
- **`domain-model.md`:**
  - §2.6: foto de capa;
  - §2.15: o que a avaliação permite;
  - DER e A.1: `foto_capa`, `foto_tamanho_max_kb` e o índice único de `avaliacao` já previsto.
- **`AGENTS.md` §8:** a exceção da foto pública, com as condições da decisão 3.

## Risks / Trade-offs

- [Banda de 1 GB do plano gratuito se esgota com muitas fotos grandes] → teto padrão de 1024 KB por parâmetro, `loading="lazy"` nos cartões e aviso na tela para usar fotos leves. Se a banda acabar, a imagem não carrega e o cartão mostra a faixa colorida.
- [Arquivo órfão público se a exclusão do anterior falhar depois do commit] → a falha é registrada na resposta e não desfaz a troca. O arquivo fica no armazenamento sem referência. Aceito, porque é a foto de uma sala.
- [Sobrescrever as variáveis do Radix pode deixar ilegível algum componente antigo] → a verificação abre as 17 páginas com o Playwright e corrige com tokens.
- [`unaccent` indisponível no pipeline do XanoScript] → só `to_lower`, com a limitação declarada.
- [O índice único não gera um erro capturável] → checagem prévia do passo 7 mais `try_catch` na gravação. Se o erro não for capturável, a resposta fica genérica, mas a unicidade continua garantida.
- [Prazo de entrega] → os grupos ficam na ordem do `tasks.md`. A foto de capa e o tema escuro são os últimos e podem ser cortados sem quebrar o resto. Os docs ficam no grupo 1, para não ficarem para trás.
- [A média em memória cresce com o número de avaliações] → aceitável na escala do projeto (dezenas de espaços). A evolução é um `espaco_id` denormalizado com índice.

## Migration Plan

1. Pull do Xano e conferência da conta (memória: conferir a conta antes do primeiro comando).
2. Tabelas e campos novos são todos opcionais. Não há migração de dados: os espaços nascem sem foto, e os parâmetros vêm do `bootstrap`, executado depois do push.
3. Push com `--dry-run`, mostrado ao usuário, e só depois o push real com aprovação. Conferência com `pull` numa pasta temporária.
4. Rollback: as rotas antigas não mudam de contrato, exceto `buscar_espacos` (que passa a devolver os restritos) e `filtros_busca`. Para reverter, basta publicar a versão anterior dos dois arquivos.

## Confirmações do apply

Sondas no Xano Developer MCP (e no sandbox, quando o comportamento só aparece em execução), registradas aqui antes de usar cada recurso:

- **C1.** O índice `btree|unique` de `avaliacao.reserva_id` recusa a segunda gravação, e o erro pode ser capturado com `try_catch`.
- **C2.** `|unaccent` funciona no pipeline de filtros do XanoScript (`$texto|to_lower|unaccent`). No propose, a sintaxe passou no validador do MCP (função de sonda com `|to_lower|unaccent` e `|contains`, sem erros nem avisos); falta o resultado em execução.

**Resultados das sondas da tarefa 1.2 (23/11):**
- O plano gratuito não tem sandbox (MCP `cli_docs/sandbox`), e o `xano function run` só executa funções já publicadas. Por isso, as confirmações em execução da C1 e da C2 ficam para os testes da 2.7, logo depois do push, como na C11. Criar uma função de sonda no workspace exigiria autorização (AGENTS §4).
- **Resultado em execução (tarefa 2.7, 23/11):** C1 e C2 confirmadas. Duas avaliações simultâneas deram uma 200 e uma 400 ("Esta reserva já foi avaliada."), e as buscas "SALA IPE" e "bloco a" encontraram "Sala Ipê" e "Bloco Á".
- **C1, confirmada por precedente:** `cadastro_POST.xs:108-163` usa exatamente o padrão do D2 (índice único, `try_catch` em volta de `db.transaction` e, no `catch`, uma nova checagem para devolver a mensagem de duplicidade). Foi testado com cadastros simultâneos na C2. A `avaliar_reserva` segue o mesmo desenho.
- **C2, sintaxe confirmada:** `$texto|to_lower|unaccent` e `|contains` passam no validador. O resultado em execução é o primeiro caso da 2.7 (busca "sala ipe" contra "Sala Ipê"). Se falhar, parar e rodar `/opsx:update`.
- **C5, confirmada no pacote instalado (`reflex 0.10.0`):**
  - `rx.upload`, `rx.UploadFile` (`filename`, `content_type`, `size`, `read`), `rx.upload_files`, `rx.selected_files` e `rx.clear_selected_files` existem;
  - `rx.App` aceita `theme`, `style`, `stylesheets` e `head_components`;
  - `rx.menu` e `rx.color_mode_cond` existem;
  - a rota dinâmica `/espaco/[espaco_id]` cria a variável de estado `espaco_id` (texto), lida de `rx_router_page.params` (`reflex/state.py:1451`). Ela não pode ter o mesmo nome de uma variável existente.
- **Workspace (tarefa 1.1):** o pull trouxe 149 documentos contra 148 locais. Sem espaços e vírgulas, os 148 são idênticos aos locais; o documento a mais é a tabela `teste123456` (campo `image? fotos`), da sonda manual da marca d'água de 22/11. O usuário a apaga quando quiser, porque o push parcial com `-i` a ignora. No `--dry-run`, conferir que ela não aparece. No fim da change, confirmar que o workspace voltou a 148 documentos ou registrar que ela continua lá.
- **Senha provisória:** as rotas novas usam `usuario_ativo`, como as existentes, e por isso recusam a senha provisória (spec `senha`). Conferir na leitura de `usuario_ativo` antes da 2.3.
- **C3.** O objeto do input `file?` traz `size` e `mime` antes do `storage.create_image`. Sintaxe de `storage.delete_file`.
- **C4.** O campo `image` lido do banco traz uma URL absoluta, ou há como obter a origem da instância sem variável nova.
- **C5.** No Reflex 0.10, pela skill `reflex-docs`: `rx.upload` e o handler com `rx.UploadFile`, rota dinâmica `/espaco/[espaco_id]`, `rx.theme` com `stylesheets` e `rx.menu`.
