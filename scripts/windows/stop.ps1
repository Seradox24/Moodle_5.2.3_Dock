# Stops the selected project. Volumes (database, moodledata, code) are preserved.
param([string]$EnvFile = '.env')
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile
Invoke-Compose down --remove-orphans
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Stopped. Volumes preserved.'
