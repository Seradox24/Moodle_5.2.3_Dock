$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

if (-not (Test-Path -LiteralPath '.env')) {
    Write-Host 'Missing .env. Copy .env.example to .env first.' -ForegroundColor Red
    exit 1
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'preflight.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building Moodle images...'
docker compose build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Starting PostgreSQL and Redis...'
docker compose up -d db redis
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Initialising shared code and starting Moodle PHP-FPM...'
docker compose up -d --wait app
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Installing Moodle database...'
docker compose exec -T --user www-data app sh /usr/local/bin/install-database.sh
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Starting web and cron...'
docker compose up -d --wait web cron
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$wwwroot = ''
if ((Get-Content -LiteralPath '.env' -Raw) -match '(?m)^MOODLE_WWWROOT=(.+)$') {
    $wwwroot = $Matches[1].Trim()
}

Write-Host ''
Write-Host 'Fresh Moodle installation completed.' -ForegroundColor Green
Write-Host "Public URL: $wwwroot"
Write-Host 'Run: .\scripts\windows\smoke-test.ps1'
