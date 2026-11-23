## 1. Preparação e documentação

- [x] 1.1 O usuário confirma a conta e o workspace do Xano CLI e a branch `change/espaco-feed-avaliacoes`. Rodar `xano workspace pull` numa pasta temporária e confirmar que o workspace está igual a `./xano`. Verificação: resposta do usuário e comparação sem diferenças.
- [x] 1.2 Sondas C1, C2 e C5 do `design.md`: índice único e `try_catch`, `|unaccent` em execução, e as APIs do Reflex pela skill `reflex-docs`. A sintaxe de `|to_lower|unaccent` já passou no validador do MCP durante o propose; falta confirmar o resultado em execução. Se `unaccent` não funcionar em execução, parar e rodar `/opsx:update` para tornar o requisito de acentos condicional. Registrar o resultado em "Confirmações do apply". Verificação: sondas válidas e registro no design.
- [x] 1.3 `docs/project-overview.md`, só a parte de feed, avaliação e visual (a foto fica na 5.7):
  - §6, item 2: busca com os restritos e o texto;
  - §6, item 12: avaliação;
  - §7.9 (`:219-221`): prazo `prazo_avaliacao_dias`, uma por reserva, sem edição, autor como primeiro nome e papel, e "visíveis a todos" trocado por "visíveis na página do espaço a quem pode reservar o tipo";
  - §10: `AVALIAR_RESERVA`;
  - §11: feed na Início e tema escuro em "Trabalho futuro".

  Verificação: `git diff docs/project-overview.md` mostrado ao usuário.
- [x] 1.4 `docs/domain-model.md`:
  - §2.15 (`:296`): "até 7 dias" trocado pelo parâmetro, "visível a todos" pela nova regra, sem edição;
  - tabela de parâmetros (`:331`): "Prazo para avaliar" como padrão de `prazo_avaliacao_dias`;
  - DER e A.1: `prazo_avaliacao_dias` confirmado.

  A §2.6 (foto) fica na 5.7. Verificação: `git diff docs/domain-model.md`.
- [x] 1.5 Revisão do guardian do grupo 1 antes de marcar as tarefas.

## 2. Xano: avaliações e busca

- [x] 2.1 Criar `xano/table/avaliacao.xs` (D1) com índice único em `reserva_id`. Acrescentar `prazo_avaliacao_dias` em `configuracao_geral.xs` e o padrão 7 no `bootstrap`. Verificação: validação do MCP e `git diff` só com os campos novos.
- [x] 2.2 Criar a função `avaliacoes_dos_espacos` (D3). Verificação: validação do MCP.
- [x] 2.3 Criar a rota `avaliar_reserva` (D2) com a auditoria `AVALIAR_RESERVA` (D9). Verificação: validação do MCP.
- [x] 2.4 Alterar `buscar_espacos` (D4: restritos com `restricao`, `texto`, média), `filtros_busca` (D5) e `minhas_reservas` (D8: `pode_avaliar`, `avaliar_ate`, `avaliacao_nota`, `proxima_reserva_id`). Criar `detalhe_espaco` (D6) com nome único no workspace. Verificação: validação do MCP e leitura do diff de `buscar_espacos`, que não pode mudar nada para os não restritos além dos campos novos.
- [x] 2.5 `parametros_GET` e `parametros_POST` com `prazo_avaliacao_dias` (inteiro ≥ 1). Verificação: validação do MCP.
- [x] 2.6 Publicação: `xano workspace push --dry-run`, mostrar o resultado ao usuário e só publicar com aprovação explícita. Rodar o `bootstrap` e conferir com `pull` numa pasta temporária. Verificação: dry-run mostrado, aprovação registrada e pull igual.
- [x] 2.7 Testes da API no sandbox, com os dados preparados e depois limpos ou registrados, cobrindo:
  - **avaliar:**
    - reserva concluída; conclusão ainda não gravada;
    - `NAO_COMPARECEU`, `CANCELADA`, confirmada futura e reserva anterior ao marco do comparecimento;
    - espaço desativado depois do uso;
    - o limite exato do prazo e um minuto depois, com o término num horário de São Paulo;
    - reserva de outro e inexistente com a mesma mensagem;
    - nota 0, 6 e 4,5; comentário de 501 caracteres e só com espaços;
    - segunda avaliação; duas avaliações simultâneas da mesma reserva;
    - sem token e com senha provisória;
  - **auditoria:** `AVALIAR_RESERVA` e nenhum registro nas recusas;
  - **busca, restritos e texto:**
    - aluno com os restritos e o texto da `restricao`; professor e coordenador sem restritos; tipo sem regras de fora; filtro por tipo restrito;
    - texto sem acento e sem maiúsculas, no nome da unidade e do tipo, combinado com o tipo, vazio e com 101 caracteres;
    - restrito só com os campos básicos, sem descrição nem recursos; texto que só aparece na descrição de um restrito não o encontra; filtro de recursos não o encontra;
    - restrito com horário e reserva sobreposta, sem campos de horário; restrito bloqueado;
    - média e quantidade;
  - **busca, regressão dos não restritos:** sobreposição parcial, intervalo encostado, pendente vencida, deslocável e não deslocável, prazo de deslocamento, vaga retida, fila depois do fechamento, já na fila e bloqueado, com os mesmos resultados de antes da change;
  - **opções:** com `pode_reservar`;
  - **detalhe:** completo; restrito, desativado e inexistente com a mesma mensagem; autor com o primeiro nome e o papel; conta do autor inativada; senha provisória;
  - **`minhas_reservas`:**
    - `pode_avaliar`, `avaliar_ate` em São Paulo e a nota;
    - `proxima_reserva_id` com reserva em andamento, com pendente expirada e com confirmada sem check-in depois do fechamento da janela (as duas ignoradas);
    - empate de início decidido pela criada antes;
    - check-in na abertura e no fechamento exatos da janela;
  - **parâmetros:** prazo 0 recusado.

  Verificação: tabela de casos com o resultado esperado e o obtido, e o que não foi possível testar declarado.
- [x] 2.8 Revisão do guardian do grupo 2 antes de marcar as tarefas.

## 3. Reflex: telas funcionais

- [x] 3.1 `xano_cliente.py` com `avaliar_reserva` e `detalhe_espaco`, e `buscar_espacos` com `texto`, sem expor o token. Verificação: `reflex run` compila sem erro.
- [x] 3.2 Início com o feed (D13):
  - componentes do feed extraídos de `buscar.py`;
  - campo de texto com envio por Enter e pelo botão;
  - primeira busca sem filtros ao abrir;
  - cartão completo e cartão restrito (D14), com a faixa por tipo, sem foto ainda;
  - `/buscar` redirecionando para `/inicio`;
  - cartão "Próxima reserva" com o check-in.

  Verificação: compila e a Início abre para aluno, professor e coordenador.
- [x] 3.3 Página do espaço `/espaco/[espaco_id]` (D15), com o `EspacoState` e a recusa "Espaço não encontrado". Verificação: compila e abre pelo cartão.
- [x] 3.4 Diálogo "Avaliar" em "Minhas reservas" (D16), com estrelas, comentário, nota exibida nas avaliadas e recusa no diálogo. "Parâmetros" com o prazo para avaliar. Verificação: compila.
- [x] 3.5 Menu (`layout.py`) sem "Buscar espaços" e com os itens de gestão no menu "Gestão" (D12, ainda sem o estilo final). Verificação: compila e cada papel vê os itens da spec `autorizacao`.
- [x] 3.6 Testes pelo Playwright:
  - feed do aluno com os restritos acinzentados, sem link e sem ações;
  - busca por texto com Enter;
  - `/buscar` levando à Início;
  - cartão abrindo a página do espaço;
  - endereço de espaço restrito com "Espaço não encontrado";
  - reservar, deslocar e entrar na fila pelo feed (regressão);
  - avaliar pela tela, envio indisponível sem nota e recusa no diálogo;
  - cartão "Próxima reserva" com e sem check-in;
  - menus do aluno, do coordenador e do admin secundário;
  - prazo para avaliar na página "Parâmetros".

  Verificação: capturas ou relato de cada caso, com o que não foi possível testar declarado.
- [x] 3.7 Revisão do guardian do grupo 3 antes de marcar as tarefas.

## 4. Visual: tema claro

- [x] 4.1 `assets/tema.css` com os tokens do Figma e as sobrescritas do Radix (D10), `rx.theme` e `stylesheets` em `bookingSystem.py` e a fonte Inter. Verificação: compila, e uma página antiga (ex.: "Recursos") abre com a fonte e as cores novas.
- [x] 4.2 Logotipo positivo e negativo e favicon t-livro em `assets/` (D11), com a posição do livro conferida no navegador. Verificação: captura da barra e da aba.
- [x] 4.3 Barra de navegação no estilo do Figma (D12), com o chip do usuário, "Trocar senha" e "Sair". Verificação: captura com aluno e com admin principal, e com senha provisória.
- [x] 4.4 Tela de boas-vindas e os cartões de login e de cadastro (D18), sem mudar campos nem mensagens. Verificação: login e cadastro funcionam como antes, pelo Playwright.
- [x] 4.5 Acabamento da Início, do cartão do espaço, da página do espaço, do diálogo de avaliação e da página "Espaços", só com tokens, nunca hex no Python. Verificação: `rg "#[0-9a-fA-F]{3,6}" bookingSystem/` sem ocorrências nos arquivos Python novos ou alterados, e capturas das cinco telas.
- [x] 4.6 Verificação das 17 páginas pelo Playwright, cada uma com o papel que a abre, corrigindo o que ficar ilegível. Verificação: lista das páginas com captura e o que foi ajustado.
- [x] 4.7 Revisão do guardian do grupo 4 antes de marcar as tarefas.

## 5. Foto de capa

- [x] 5.1 Sondas C3 e C4 (tamanho e `mime` do input `file?`, `storage.delete_file`, URL do campo `image`), registradas no design. Verificação: sonda no sandbox e registro.
- [x] 5.2 Campo `foto_capa` em `espaco.xs` e `foto_tamanho_max_kb` em `configuracao_geral.xs`, com o padrão 1024 no `bootstrap` e os campos em `parametros_GET` e `parametros_POST`. Verificação: validação do MCP.
- [x] 5.3 Rotas `definir_foto_espaco` e `remover_foto_espaco` (D7), com a auditoria (D9). `foto_url` em `buscar_espacos`, `detalhe_espaco` e `geridos`, e `foto_tamanho_max_kb` em `geridos` (D8). Verificação: validação do MCP.
- [x] 5.4 Publicação com `--dry-run`, mostrada ao usuário, e só com aprovação. Rodar o `bootstrap` e conferir com `pull`. Verificação: dry-run mostrado, aprovação e pull igual.
- [x] 5.5 Testes da API no sandbox, cobrindo:
  - envio pelo coordenador e pelo admin; troca, com o arquivo anterior apagado (404 se nunca aberto; a cópia de uma foto já aberta pode continuar, decisão 38); remoção; remoção sem foto;
  - arquivo acima do limite; PDF e GIF; arquivo vazio e envio sem arquivo;
  - duas trocas simultâneas no mesmo espaço;
  - coordenador de outra unidade e aluno; sem token; senha provisória;
  - URL aberta sem sessão;
  - auditoria das três situações e nenhum registro nas recusas;
  - `foto_url` na busca, no detalhe e em `geridos`;
  - tamanho 0 recusado nos parâmetros.

  Verificação: tabela de casos e o que não foi testado.
- [x] 5.6 Reflex: `definir_foto_espaco` e `remover_foto_espaco` no cliente, com multipart pelo `httpx`. Diálogo "Foto" em "Espaços" (D17), foto nos cartões e na página do espaço, e tamanho máximo em "Parâmetros". Verificação: compila.
- [x] 5.7 `docs/project-overview.md` (§5: foto sai de "fora do escopo"; §6: foto no feed; §10: `DEFINIR_FOTO_ESPACO` e `REMOVER_FOTO_ESPACO`; §11: "fotos dos espaços" sai dos cortes), `docs/domain-model.md` (§2.6, DER e A.1: `foto_capa` e `foto_tamanho_max_kb`) e `AGENTS.md` §8 (exceção da foto pública, decisão 3). Verificação: `git diff` dos três arquivos mostrado ao usuário.
- [x] 5.8 Testes pelo Playwright:
  - enviar, trocar e remover pela tela;
  - recusa de tamanho no diálogo;
  - foto no cartão do feed e na página do espaço;
  - espaço sem foto com a faixa;
  - tamanho máximo em "Parâmetros".

  Verificação: capturas ou relato.
- [x] 5.9 Revisão do guardian do grupo 5 antes de marcar as tarefas.

## 6. Revisão final

- [x] 6.1 `openspec validate espaco-feed-avaliacoes --strict` sem erros e `decisions-log.md` completo. Verificação: saída do comando.
- [x] 6.2 Relatório de revisão final do guardian (MODO REVISÃO FINAL), mostrado ao usuário antes de qualquer commit. Verificação: relatório entregue e aprovação do usuário.

## Workflow follow-up

- O usuário faz os commits, o push e o PR; o agente entrega os comandos prontos.
- Se o prazo apertar, o grupo 5 (foto de capa) é o primeiro a sair. Antes do archive, um `/opsx:update` tira a foto de:
  - `specs/espacos` (a spec inteira desta change);
  - `specs/auditoria` (requisito "Foto de capa é auditada");
  - `specs/parametros` (tamanho máximo na lista, na validação, na tela e na carga);
  - `specs/busca-espacos` (foto no resultado e no cartão);
  - `specs/pagina-espaco` (foto no conteúdo e na tela);
  - `proposal.md`;
  - `design.md` (D1, D7, D8, D14, D15 e D19);
  - grupo 5 do `tasks.md`.
- As tarefas 4.4 (boas-vindas) e 4.6 (revisão das 17 páginas) não são cortáveis (decisão 27).
- O cartão "Próxima reserva" é o segundo a sair, pelo mesmo caminho: requisito de `interface-web`, `proxima_reserva_id` no D8 e os testes dele na 2.7 e na 3.6.
- Tema escuro (opcional, decisão 15): só se sobrar tempo depois do grupo 5, e por um `/opsx:update` que acrescente o requisito à `interface-web` antes de implementar, com a paleta escura registrada no D10.
- Arquivar a change depois da aprovação do usuário e do merge.
