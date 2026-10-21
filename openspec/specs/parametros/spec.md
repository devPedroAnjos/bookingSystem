# Especificação: Parâmetros

## Purpose
Permitir que o admin principal ajuste, sem mexer no código nem no painel do Xano, os parâmetros globais que as changes já usam: domínios de e-mail aceitos e os limites de coordenação, de pedidos de cadastro e de administradores.

## Requirements

### Requirement: Consulta e edição dos parâmetros
Somente o admin principal DEVE (MUST) poder consultar e editar estes parâmetros de `ConfiguracaoGeral`:
- domínios de e-mail aceitos;
- máximo de coordenadores por unidade;
- máximo de unidades por coordenador;
- máximo de pedidos de cadastro;
- máximo de admins ativos.

Admins secundários e demais papéis NÃO DEVEM (MUST NOT) consultar nem editar essa área.

#### Scenario: Principal altera um limite
- **WHEN** o principal altera o máximo de coordenadores por unidade de 4 para 5
- **THEN** o novo valor passa a valer para todas as unidades a partir da próxima operação

#### Scenario: Secundário tenta editar
- **WHEN** um admin secundário tenta editar os parâmetros
- **THEN** o sistema responde com acesso negado e nada muda

### Requirement: Validação dos parâmetros
Cada limite DEVE (MUST) ser um número inteiro maior ou igual a 1. A lista de domínios DEVE ter ao menos um domínio, sem `@`, sem espaços e sem repetição, gravado em minúsculas. Reduzir um limite abaixo da quantidade atual NÃO DEVE (MUST NOT) remover ninguém: só impede novas entradas. Se qualquer valor for inválido, nada é gravado.

#### Scenario: Limite zero
- **WHEN** o principal tenta gravar o máximo de admins igual a 0
- **THEN** o sistema recusa indicando o campo inválido e nenhum parâmetro muda

#### Scenario: Lista de domínios vazia
- **WHEN** o principal tenta remover todos os domínios aceitos
- **THEN** o sistema recusa informando que é preciso ao menos um domínio

#### Scenario: Redução abaixo do atual
- **GIVEN** "Paulista" tem 4 coordenadores ativos
- **WHEN** o principal reduz o máximo de coordenadores por unidade para 2
- **THEN** a alteração é aceita e os 4 coordenadores continuam
- **AND** "Paulista" não aceita novos coordenadores enquanto tiver 2 ou mais

### Requirement: Tela de parâmetros
O frontend DEVE (MUST) oferecer ao admin principal uma página "Parâmetros", com os valores atuais preenchidos, e mostrar a mensagem da API depois de salvar.

#### Scenario: Salvar pela página
- **WHEN** o principal altera o máximo de pedidos de cadastro para 4 e salva
- **THEN** a página mostra a confirmação e o novo valor
