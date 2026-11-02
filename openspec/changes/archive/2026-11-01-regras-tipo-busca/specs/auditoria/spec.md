## ADDED Requirements

### Requirement: Regras de tipo de espaço são auditadas
Cada alteração das regras de um tipo de espaço, quando concluída com sucesso, DEVE (MUST) gerar um registro de auditoria com a ação `ALTERAR_REGRAS_TIPO_ESPACO`, a entidade `tipo_espaco`, o identificador do tipo, o admin como ator e a unidade vazia. Os dados antes e depois contêm apenas as regras alteradas, incluindo as regras por papel. Uma alteração que não muda nenhuma regra DEVE ser recusada sem gerar registro. A alteração dos novos parâmetros (granularidade e dias de funcionamento) é auditada pela ação `ALTERAR_PARAMETROS` já existente. A carga inicial das regras e a busca de espaços NÃO DEVEM (MUST NOT) gerar registro. A ação e seu registro DEVEM ser gravados juntos, e tentativas recusadas NÃO DEVEM gerar registro.

#### Scenario: Regras alteradas
- **WHEN** o admin muda a duração máxima de "Laboratório" de 240 para 180 minutos e passa a exigir aprovação do professor
- **THEN** existe um registro `ALTERAR_REGRAS_TIPO_ESPACO` com 240 e a regra anterior do professor nos dados antes, e 180 e a nova regra nos dados depois

#### Scenario: Nada mudou
- **WHEN** o admin salva as regras de "Biblioteca" sem alterar nenhum valor
- **THEN** o sistema recusa informando que nenhuma regra foi alterada e nenhum registro é gerado

#### Scenario: Novo parâmetro auditado
- **WHEN** o principal muda a granularidade de 10 para 5 minutos
- **THEN** existe um registro `ALTERAR_PARAMETROS` com 10 nos dados antes e 5 nos dados depois

#### Scenario: Busca não é auditada
- **WHEN** um aluno busca espaços
- **THEN** nenhum registro de auditoria é gerado
