param([switch]$ConfigOnly)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail 'Docker is not installed.'
}

docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail 'Docker Compose v2 plugin is not available.'
}

if (-not (Test-Path -LiteralPath '.env')) {
    Fail '.env does not exist. Run: Copy-Item .env.example .env'
}

docker compose config --quiet
if ($LASTEXITCODE -ne 0) {
    Fail 'docker compose config failed.'
}

$resolved = docker compose config --environment
if ($LASTEXITCODE -ne 0) { Fail 'Cannot resolve Compose environment.' }
$values = @{}
foreach ($line in $resolved) {
    if ($line -match '^([^=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
}
$missing = @()
foreach ($key in @('MOODLE_WWWROOT', 'POSTGRES_PASSWORD', 'MOODLE_ADMIN_PASSWORD', 'MOODLE_ADMIN_USER', 'MOODLE_ADMIN_EMAIL', 'MOODLE_SITE_FULLNAME', 'MOODLE_SITE_SHORTNAME')) {
    if ([string]::IsNullOrWhiteSpace($values[$key]) -or $values[$key] -match 'CHANGE_ME_|example\.com') {
        $missing += $key
    }
}
if ($missing.Count) { Fail "Complete these values in .env: $($missing -join ', ')" }
if ($values['MOODLE_WWWROOT'] -notmatch '^https?://') { Fail 'MOODLE_WWWROOT must be an absolute http:// or https:// URL.' }
if ($ConfigOnly) { Write-Host 'Configuration OK.'; exit 0 }

docker info | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'Docker daemon is not running. Start Docker Desktop first.' }
$port = 18080
if ($values['MOODLE_HTTP_PORT']) {
    $port = [int]$values['MOODLE_HTTP_PORT']
}

$inUse = $false
try {
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
    if ($listeners) {
        $inUse = $true
    }
}
catch {
    $inUse = $false
}

if ($inUse) {
    Fail "Host port $port is already in use. Choose another MOODLE_HTTP_PORT."
}

Write-Host 'Preflight OK.'
