# Reports the selected project status. Exit 0 only when the five long-running
# services are up.
param([string]$EnvFile = '.env')
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile
Invoke-Compose ps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$running = Invoke-Compose ps --status running --services
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$missing = @()
foreach ($service in @('db', 'redis', 'app', 'web', 'cron')) {
    if ($running -notcontains $service) { $missing += $service }
}
if ($missing.Count) {
    Write-Host "ERROR: services not running: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host 'Status OK: db, redis, app, web and cron are running.'
