# Hook PreToolUse do agente change-guardian: so permite comandos git de leitura.
# Qualquer falha ao ler a chamada nega o comando (fail-closed).
$ErrorActionPreference = 'Stop'

function Deny([string]$reason) {
    @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reason
        }
    } | ConvertTo-Json -Depth 3 -Compress
    exit 0
}

try {
    $callInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $command = ([string]$callInput.tool_input.command).Trim()
} catch {
    Deny 'change-guardian: nao foi possivel ler o comando; chamada negada.'
}

$readOnlyGit = '^git\s+(status|diff|log|show|rev-parse|ls-files|blame|branch\s+--show-current)(\s|$)'
# Bloqueia encadeamento, pipe, redirecionamento, subexpressoes, git diff --output e diff externo.
$forbidden = '[;&|<>`(){}$\r\n]|--output|--ext-diff'

if ($command -notmatch $readOnlyGit -or $command -match $forbidden) {
    Deny "change-guardian e somente leitura. Permitidos apenas: git status, diff, log, show, rev-parse, ls-files, blame, branch --show-current; sem encadeamento, pipe ou redirecionamento. Negado: $command"
}
exit 0
