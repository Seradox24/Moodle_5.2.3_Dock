# Shows recent logs for the selected project. Pass -f to follow and optional
# service names, e.g.: .\scripts\windows\logs.ps1 -EnvFile .env -f app cron
param(
    [string]$EnvFile = '.env',
    [Alias('f')] [switch]$Follow,
    [Parameter(ValueFromRemainingArguments = $true)] [string[]]$Services
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile
$arguments = @('logs', '--tail', '100')
if ($Follow) { $arguments += '--follow' }
if ($Services) { $arguments += $Services }
Invoke-Compose @arguments
exit $LASTEXITCODE
