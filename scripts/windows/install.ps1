param([string]$EnvFile = '.env')
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile -Quiet -SkipConfigValidation

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'preflight.ps1') -EnvFile $script:ComposeEnvFile -FreshInstall
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building Moodle images...'
Invoke-Compose build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Starting PostgreSQL and Redis...'
Invoke-Compose up -d db redis
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Initialising shared code and starting Moodle PHP-FPM...'
Invoke-Compose up -d --wait app
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Installing Moodle database...'
Invoke-Compose exec -T --user www-data app sh /usr/local/bin/install-database.sh
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Starting web and cron...'
Invoke-Compose up -d --wait web cron
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$resolved = Invoke-Compose config --environment
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$wwwroot = ($resolved | Where-Object { $_ -like 'MOODLE_WWWROOT=*' } | Select-Object -First 1) -replace '^MOODLE_WWWROOT=', ''

Write-Host ''
Write-Host 'Fresh Moodle installation completed.' -ForegroundColor Green
Write-Host "Public URL: $wwwroot"
Write-Host "Run: .\scripts\windows\smoke-test.ps1 -EnvFile `"$script:ComposeEnvFile`""
