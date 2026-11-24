## Why

A busca atual é uma lista técnica, esconde os espaços que o papel não pode reservar e não deixa ninguém saber como foi usar um espaço. A §7.9 do `project-overview.md` prevê a avaliação de 1 a 5 depois do uso, e o replanejamento de 22/11/2026 juntou nesta change o feed, a página do espaço, as avaliações e o visual do frontend, que são obrigatórios para a entrega de 24/11. No explore, o usuário trouxe de volta a foto de capa dos espaços, aceitou a marca d'água do plano gratuito do Xano depois de uma sonda e decidiu mostrar no feed também os espaços restritos ao papel. Essas decisões mudam regras dos documentos de contexto (decisões 1 a 5 do `decisions-log.md`).

## What Changes

**Feed na Início**
- A página "Início" passa a ser o feed de espaços: campo de busca por texto, os filtros atuais e a lista em cartões. O endereço `/buscar` leva para a Início, e o item "Buscar espaços" sai do menu.
- **BREAKING (regra de busca):** o feed mostra também os espaços de tipos que o papel não pode reservar, só como cartão acinzentado com cadeado e o aviso "Restrito", que diz quais papéis podem reservar. O cartão restrito não abre a página do espaço, não mostra avaliações nem ocupação e não oferece ações.
- Busca por texto no nome, código, descrição e localização do espaço e nos nomes da unidade e do tipo, sem diferenciar maiúsculas, minúsculas e acentos.
- Cada cartão mostra a foto de capa ou, sem foto, uma faixa colorida com o ícone do tipo, além da média das avaliações e da quantidade delas.
- Um cartão "Próxima reserva" no topo da Início mostra a próxima reserva do usuário e oferece o check-in quando a janela está aberta.

**Página do espaço**
- Página nova com os dados, os recursos, a foto, a média e as avaliações do espaço. Abre só para espaço reservável pelo papel de quem pede.

**Avaliações**
- O dono de uma reserva `CONCLUIDA` avalia uma vez, até `prazo_avaliacao_dias` depois do término, com nota inteira de 1 a 5 e comentário opcional. Não há edição nem exclusão.
- As avaliações aparecem na página do espaço com o primeiro nome e o papel do autor, nunca o nome completo.
- "Minhas reservas" oferece "Avaliar" nas reservas que ainda podem ser avaliadas e mostra a nota das já avaliadas.

**Foto de capa**
- O coordenador da unidade do espaço ou o admin envia, troca e remove uma foto de capa por espaço (JPEG, PNG ou WEBP, até `foto_tamanho_max_kb`).
- A foto fica numa URL pública do Xano, sem login, porque o plano gratuito não tem armazenamento privado. A troca e a remoção apagam o arquivo anterior. A tela avisa para não usar fotos com pessoas.

**Parâmetros:** `prazo_avaliacao_dias` (padrão 7) e `foto_tamanho_max_kb` (padrão 1024), na página "Parâmetros".

**Auditoria:** `AVALIAR_RESERVA`, `DEFINIR_FOTO_ESPACO` e `REMOVER_FOTO_ESPACO`.

**Visual (tema claro)**
- Tokens de cor, tipografia, raios e sombras do design system do Figma, fonte Inter, ícones Lucide, logo "Booking System" com o livro no t e favicon.
- Barra de navegação no topo, com os itens de gestão agrupados no menu "Gestão".
- Tela de entrada com boas-vindas e redesenho do login, do cadastro, da Início, da página do espaço, da avaliação e da página "Espaços". As demais páginas herdam o tema.

**Documentos**
- `project-overview.md`: a foto de capa volta ao escopo (§5 e §11), a busca mostra os espaços restritos (§6) e a avaliação muda de lugar (§7.9).
- `domain-model.md`: foto de capa em `espaco`, os dois parâmetros novos e a avaliação.
- `AGENTS.md` §8: a exceção da foto pública.

**Fora do escopo**
- Tema escuro: só entra no fim, se sobrar tempo, e por um update desta change (decisão 15).
- Itens dos protótipos HTML que contradizem o domínio ou a v1 (decisão 10): favoritos, ocupação agora, mapa, notificações, SSO, recuperação de senha por e-mail, "manter conectado", grade de horários por dia, quantidade de pessoas, critérios e etiquetas na avaliação, meia estrela, "quem pode reservar" por espaço e "em manutenção" no cadastro de espaço.
- Galeria com várias fotos, recorte ou compressão da imagem e foto privada.
- Edição e exclusão de avaliação, resposta da gestão, denúncia e moderação.
- Paginação do feed e das avaliações.
- Reserva pela página do espaço: a reserva continua no feed, com data e horário.

## Capabilities

### New Capabilities
- `avaliacoes`: quem avalia, prazo, nota e comentário, unicidade, autor exibido, média e listagem por espaço, e o "Avaliar" em "Minhas reservas".
- `pagina-espaco`: a página de um espaço com dados, recursos, foto, média e avaliações, e quem pode abri-la.
- `interface-web`: identidade visual do tema claro, logo e favicon, barra de navegação, tela de boas-vindas e cartão "Próxima reserva".

### Modified Capabilities
- `busca-espacos`: espaços restritos ao papel aparecem como cartão "Restrito"; filtro de texto; foto e média no resultado; opções de tipos com a indicação de quem pode reservar; a tela de busca vira o feed da Início.
- `espacos`: (requisitos novos) envio, remoção e URL pública da foto de capa; (modificados) a listagem de espaços geridos e a tela "Espaços" passam a ter a foto.
- `avaliacoes` também define os campos de avaliação na listagem das reservas do usuário, e `interface-web` define a próxima reserva indicada pelo backend.
- `parametros`: `prazo_avaliacao_dias` e `foto_tamanho_max_kb` na consulta, na validação e na tela.
- `auditoria`: (requisitos novos) avaliação e foto de capa são auditadas.
- `autorizacao`: o menu perde "Buscar espaços" e agrupa os itens de gestão em "Gestão".

## Impact

- **Papéis afetados:**
  - **aluno e professor:** veem o feed com os restritos, avaliam as próprias reservas concluídas e abrem a página do espaço;
  - **coordenador:** também envia a foto de capa dos espaços das unidades que coordena;
  - **admin:** envia a foto em qualquer unidade;
  - **admin principal:** edita os dois parâmetros novos.
- **Regras do `project-overview.md` tocadas:** §6, itens 2 (busca) e 12 (avaliação); §7.1 (regra por papel, agora mostrada como restrição); §7.6 (situação `CONCLUIDA`, que habilita a avaliação); §7.9 (inteira); §8 (operações com fuso e prazos); §10 (auditoria) e §11.
- **Xano:**
  - tabela nova `avaliacao`, campo novo `espaco.foto_capa` e os campos novos em `configuracao_geral`;
  - rotas novas: avaliar reserva, detalhe do espaço, definir e remover a foto;
  - alterações em `buscar_espacos`, `filtros_busca`, `minhas_reservas`, `geridos`, `parametros` (GET e POST) e `bootstrap`;
  - publicação sempre com dry-run e aprovação.
- **Reflex:** feed na Início, página do espaço, diálogo de avaliação, foto em "Espaços", tema, logo, favicon e barra de navegação. O upload usa o `httpx` que já está no `requirements.txt`.
- **Dependências:** nenhuma nova. Nenhuma variável de ambiente nova.
