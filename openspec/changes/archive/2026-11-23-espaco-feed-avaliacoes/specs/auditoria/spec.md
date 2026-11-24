## ADDED Requirements

### Requirement: Avaliações são auditadas
A avaliação de uma reserva DEVE (MUST) gerar um registro `AVALIAR_RESERVA`, com a entidade `avaliacao`, o autor como ator, a unidade do espaço e, nos dados depois, a reserva, o espaço, a nota e se há comentário. Recusas e as consultas de avaliações NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Avaliação auditada
- **GIVEN** a reserva concluída de Ana é de "BIB-01", de "Paulista"
- **WHEN** Ana avalia a reserva com nota 4 e um comentário
- **THEN** existe um registro `AVALIAR_RESERVA` com Ana como ator, a unidade "Paulista" e a reserva, o espaço, a nota 4 e a indicação de comentário nos dados depois

#### Scenario: Recusa não auditada
- **WHEN** Ana tenta avaliar de novo uma reserva já avaliada
- **THEN** nenhum novo registro `AVALIAR_RESERVA` é gerado

### Requirement: Foto de capa é auditada
O envio da foto de capa DEVE (MUST) gerar um registro `DEFINIR_FOTO_ESPACO`, e a remoção um `REMOVER_FOTO_ESPACO`, com a entidade `espaco`, quem agiu como ator, a unidade do espaço e o nome e o tamanho do arquivo nos dados antes e depois, sem o conteúdo da imagem. Recusas NÃO DEVEM (MUST NOT) gerar registro.

#### Scenario: Troca de foto auditada
- **GIVEN** "LAB-01", de "Paulista", tem a foto "lab1.jpg"
- **WHEN** Rui envia a foto "lab1-nova.png"
- **THEN** existe um registro `DEFINIR_FOTO_ESPACO` com Rui como ator, a unidade "Paulista", "lab1.jpg" nos dados antes e "lab1-nova.png" nos dados depois

#### Scenario: Remoção auditada
- **WHEN** o admin remove a foto de "LAB-01"
- **THEN** existe um registro `REMOVER_FOTO_ESPACO` com o admin como ator e a foto anterior nos dados antes

#### Scenario: Recusa de foto não auditada
- **WHEN** Rui envia uma foto maior que o tamanho máximo
- **THEN** nenhum registro `DEFINIR_FOTO_ESPACO` é gerado
