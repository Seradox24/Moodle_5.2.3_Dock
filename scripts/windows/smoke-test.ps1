param([string]$EnvFile = '.env')
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile

$resolved = Invoke-Compose config --environment
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$url = ($resolved | Where-Object { $_ -like 'MOODLE_WWWROOT=*' }) -replace '^MOODLE_WWWROOT=', ''
if (-not $url) { throw 'MOODLE_WWWROOT is missing.' }
$url = $url.TrimEnd('/')

Write-Host '== Containers =='
Invoke-Compose ps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '== PostgreSQL =='
Invoke-Compose exec -T db sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '== Redis =='
Invoke-Compose exec -T redis redis-cli ping
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '== Moodle, database, PHP extensions and plugin permissions =='
Invoke-Compose exec -T --user www-data app php /usr/local/bin/check-runtime.php
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '== HTTP =='
if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $status = curl.exe -fsSL --connect-timeout 10 --max-time 120 --max-redirs 5 -o NUL -w '%{http_code}' "$url/login/index.php"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($status -ne '200') { throw "Unexpected login HTTP status: $status" }
    Write-Host "Login HTTP $status ($url/login/index.php)"
}
else {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "$url/login/index.php" -TimeoutSec 120 -MaximumRedirection 5
    if ($response.StatusCode -ne 200) { throw 'Login page did not return HTTP 200.' }
    Write-Host $response.StatusCode
}

Write-Host ''
Write-Host 'Smoke test completed.'
