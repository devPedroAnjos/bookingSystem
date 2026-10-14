# Especificação: Unidades

## Purpose

Representar as unidades (campus ou prédio) da instituição. Nesta etapa, a capability fornece a carga inicial de unidades e a listagem pública usada no cadastro de professor. A gestão completa (criar, editar e inativar unidades e atribuir coordenadores) é acrescentada por uma change posterior.

## Requirements
### Requirement: Carga inicial de unidades
O sistema DEVE (MUST) ser implantado com um conjunto inicial de unidades ativas, sem exigir cadastro manual pela interface.

#### Scenario: Unidades disponíveis após a implantação
- **WHEN** o backend é implantado pela primeira vez no ambiente
- **THEN** existe ao menos uma unidade ativa, com nome e endereço

#### Scenario: Carga repetida
- **GIVEN** a carga inicial já foi aplicada
- **WHEN** a carga é aplicada novamente
- **THEN** nenhuma unidade é duplicada

### Requirement: Listagem pública de unidades ativas
O sistema DEVE (MUST) oferecer, sem autenticação, a listagem das unidades ativas ordenada por nome. Cada item contém **somente** `id` e `nome`. Unidades inativas NÃO DEVEM (MUST NOT) aparecer.

#### Scenario: Visitante lista unidades
- **GIVEN** existem as unidades ativas "Vila Olímpia" e "Paulista" e a unidade inativa "Centro"
- **WHEN** um visitante sem token chama a listagem pública
- **THEN** o sistema devolve "Paulista" e "Vila Olímpia", nessa ordem, cada uma só com `id` e `nome`
- **AND** "Centro" não aparece

#### Scenario: Dados além de id e nome não são expostos
- **WHEN** a listagem pública é chamada
- **THEN** a resposta não contém endereço, situação, coordenadores nem qualquer outro campo
