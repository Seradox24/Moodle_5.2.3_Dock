param([string]$EnvFile = '.env', [switch]$ConfigOnly, [switch]$QuietContext, [switch]$FreshInstall)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Get-Value([string]$Key, [string]$Default = '') {
    if ($values.ContainsKey($Key)) { return [string]$values[$Key] }
    return $Default
}

function Test-Port([string]$Value) {
    if ($Value -notmatch '^[1-9][0-9]{0,4}$') { return $false }
    return [int]$Value -le 65535
}

function Test-IPv4([string]$Value) {
    if ($Value -notmatch '^[0-9]{1,3}(\.[0-9]{1,3}){3}$') { return $false }
    foreach ($octet in $Value.Split('.')) {
        if ([int]$octet -gt 255) { return $false }
    }
    return $true
}

function Audit-EnvironmentFile {
    $known = @(
        'COMPOSE_PROJECT_NAME', 'IMAGE_NAMESPACE', 'MOODLE_WWWROOT', 'MOODLE_HTTP_BIND', 'MOODLE_HTTP_PORT',
        'POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'MOODLE_DB_PREFIX', 'MOODLE_SITE_FULLNAME',
        'MOODLE_SITE_SHORTNAME', 'MOODLE_LANG', 'MOODLE_ADMIN_USER', 'MOODLE_ADMIN_PASSWORD',
        'MOODLE_ADMIN_EMAIL', 'MOODLE_PLUGIN_INSTALL', 'MOODLE_REVERSEPROXY', 'MOODLE_SSLPROXY',
        'MOODLE_ROUTER_CONFIGURED', 'MOODLE_REDIS_SESSIONS', 'MOODLE_REDIS_HOST', 'MOODLE_REDIS_PORT',
        'MOODLE_REDIS_DATABASE', 'MOODLE_REDIS_PREFIX', 'MOODLE_MAX_UPLOAD_MB', 'MOODLE_MAX_REQUEST_MB',
        'MOODLE_MEMORY_LIMIT_MB', 'MOODLE_MAX_EXECUTION_SECONDS', 'MOODLE_FPM_MAX_CHILDREN',
        'MOODLE_FASTCGI_READ_TIMEOUT_SECONDS', 'COMPOSE_FILE', 'COMPOSE_PROFILES', 'COMPOSE_ENV_FILES', 'MOODLE_GIT_TAG',
        'MOODLE_GIT_REF', 'RELEASE_IMAGE_TAG', 'LAUNCHER_VERSION', 'MOODLE_VERSION', 'DEBIAN_IMAGE',
        'PHP_IMAGE', 'NGINX_IMAGE', 'POSTGRES_IMAGE', 'REDIS_IMAGE', 'MOODLE_DB_HOST', 'MOODLE_DB_PORT',
        'MOODLE_MAIL_ENABLED', 'TZ'
    )
    $obsolete = @(
        'MOODLE_GIT_TAG', 'MOODLE_GIT_REF', 'RELEASE_IMAGE_TAG', 'LAUNCHER_VERSION', 'MOODLE_VERSION',
        'DEBIAN_IMAGE', 'PHP_IMAGE', 'NGINX_IMAGE', 'POSTGRES_IMAGE', 'REDIS_IMAGE', 'MOODLE_DB_HOST',
        'MOODLE_DB_PORT', 'MOODLE_MAIL_ENABLED', 'TZ', 'SSO_ENABLED', 'SSO_ISSUER_URL', 'SSO_CLIENT_ID',
        'INTEGRATION_API_URL'
    )
    $forbidden = @('COMPOSE_FILE', 'COMPOSE_PROFILES', 'COMPOSE_ENV_FILES')
    $seen = @{}
    $lines = [IO.File]::ReadAllLines($script:ComposeEnvFile)
    for ($index = 0; $index -lt $lines.Length; $index++) {
        $line = $lines[$index].TrimStart([char]0xFEFF).Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $line = $line -replace '^export\s+', ''
        $match = [regex]::Match($line, '^([A-Za-z_][A-Za-z0-9_]*)(?:\s*=|\s*$)')
        if (-not $match.Success) { continue }
        $key = $match.Groups[1].Value
        if ($seen.ContainsKey($key)) { Fail "Duplicate variable in $script:ComposeEnvFile`: $key" }
        $seen[$key] = $true

        if ($forbidden -contains $key) { Fail "Do not set $key in the selected environment file; it controls Compose itself." }
        if ($obsolete -contains $key) {
            Write-Warning "$key has no implementation in this release or is release-controlled; remove it from the selected environment file."
        }
        elseif ($known -notcontains $key) {
            Write-Warning "Unknown environment variable in selected profile: $key"
        }
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail 'Docker is not installed.'
}

docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail 'Docker Compose v2 plugin is not available.'
}

try { Initialize-ComposeEnvironment -EnvFile $EnvFile -Quiet:$QuietContext -SkipConfigValidation } catch { Fail $_.Exception.Message }
if ($FreshInstall -and $ConfigOnly) { Fail '-FreshInstall cannot be combined with -ConfigOnly.' }
try { Audit-EnvironmentFile } catch { Fail $_.Exception.Message }

$envModel = Join-Path $repoRoot 'scripts\lib\environment-only.yaml'
$resolved = & docker compose --project-directory $script:ComposeRepoRoot --file $envModel --env-file $script:ComposeEnvFile --env-file $script:ComposeReleaseFile config --environment
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
if ($missing.Count) { Fail "Complete these values in $script:ComposeEnvFile`: $($missing -join ', ')" }
$project = Get-Value 'COMPOSE_PROJECT_NAME' 'lms-moodle'
if ($project -cnotmatch '^[a-z0-9][a-z0-9_-]{0,62}$') { Fail 'COMPOSE_PROJECT_NAME must start with a lowercase letter or digit and contain only lowercase letters, digits, hyphens or underscores (max 63).' }
$namespace = Get-Value 'IMAGE_NAMESPACE' 'lms'
if ($namespace -cnotmatch '^[a-z0-9]+([._-][a-z0-9]+)*(:[1-9][0-9]{0,4})?(/[a-z0-9]+([._-][a-z0-9]+)*)*$') { Fail 'IMAGE_NAMESPACE must be a lowercase image namespace (optionally registry:port/path).' }
$registry = ($namespace -split '/', 2)[0]
if ($registry.Contains(':')) {
    $registryPort = $registry.Substring($registry.LastIndexOf(':') + 1)
    if (-not (Test-Port $registryPort)) { Fail 'IMAGE_NAMESPACE registry port must be an integer from 1 to 65535.' }
}

$portText = Get-Value 'MOODLE_HTTP_PORT' '18080'
if (-not (Test-Port $portText)) { Fail 'MOODLE_HTTP_PORT must be an integer from 1 to 65535.' }
$port = [int]$portText
$bind = Get-Value 'MOODLE_HTTP_BIND' '127.0.0.1'
if ($bind -ne '0.0.0.0' -and -not (Test-IPv4 $bind)) { Fail 'MOODLE_HTTP_BIND must be 0.0.0.0, 127.0.0.1 or a valid IPv4 address.' }
if ($bind -match '^127\.' -and $bind -ne '127.0.0.1') { Fail 'Only 127.0.0.1 is supported as a loopback bind address.' }

$url = $values['MOODLE_WWWROOT']
$uri = $null
if ($url -notmatch '^https?://' -or -not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or
    $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -notin @('', '/')) {
    Fail 'MOODLE_WWWROOT must be an absolute http(s) URL with a DNS name or IPv4 host, optional valid port and no path/query/userinfo.'
}
$rawUrlMatch = [regex]::Match($url, '^https?://[^:/?#@]+(?::([0-9]+))?/?$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
if (-not $rawUrlMatch.Success) { Fail 'MOODLE_WWWROOT host/port syntax is invalid.' }
if ($rawUrlMatch.Groups[1].Success -and -not (Test-Port $rawUrlMatch.Groups[1].Value)) { Fail 'MOODLE_WWWROOT port must be an integer from 1 to 65535 without leading zeroes.' }
if ($uri.HostNameType -notin @([UriHostNameType]::Dns, [UriHostNameType]::IPv4) -or $uri.Host -match '\.\.|^\.|\.$') {
    Fail 'MOODLE_WWWROOT host must be a valid DNS name or IPv4 address.'
}
foreach ($label in $uri.Host.Split('.')) {
    if ($label.Length -gt 63 -or $label.StartsWith('-') -or $label.EndsWith('-')) { Fail 'MOODLE_WWWROOT contains an invalid DNS label.' }
}
if ($uri.HostNameType -eq [UriHostNameType]::IPv4 -and -not (Test-IPv4 $uri.Host)) { Fail 'MOODLE_WWWROOT contains an invalid IPv4 host.' }
if ($uri.Host -eq '0.0.0.0') { Fail 'MOODLE_WWWROOT cannot use the wildcard address 0.0.0.0.' }
if ($uri.Port -lt 1 -or $uri.Port -gt 65535) { Fail 'MOODLE_WWWROOT contains an invalid port.' }

$booleans = @{
    MOODLE_PLUGIN_INSTALL = 'true'; MOODLE_REVERSEPROXY = 'true'; MOODLE_SSLPROXY = 'false'
    MOODLE_ROUTER_CONFIGURED = 'true'; MOODLE_REDIS_SESSIONS = 'false'
}
$booleanKeys = @($booleans.Keys)
foreach ($key in $booleanKeys) {
    if ($values.ContainsKey($key)) { $value = [string]$values[$key] }
    else { $value = $booleans[$key] }
    if ($value -cnotin @('true','false')) { Fail "$key must be exactly 'true' or 'false'." }
    $booleans[$key] = $value
}
if ($booleans.MOODLE_REVERSEPROXY -ne 'true') { Fail 'MOODLE_REVERSEPROXY must be true for the published internal Nginx port.' }
if ($booleans.MOODLE_ROUTER_CONFIGURED -ne 'true') { Fail 'MOODLE_ROUTER_CONFIGURED must remain true for the configured internal Nginx router.' }
if ($booleans.MOODLE_SSLPROXY -eq 'true') {
    if ($uri.Scheme -cne 'https') { Fail 'MOODLE_SSLPROXY=true requires an https:// MOODLE_WWWROOT.' }
    if ($bind -ne '127.0.0.1') { Fail 'MOODLE_SSLPROXY=true requires MOODLE_HTTP_BIND=127.0.0.1 so the internal web port is not exposed on the LAN.' }
}
else {
    if ($uri.Scheme -cne 'http') { Fail 'An https:// MOODLE_WWWROOT requires MOODLE_SSLPROXY=true.' }
    if ($uri.Port -ne $port) { Fail 'For direct HTTP access, the MOODLE_WWWROOT port must match MOODLE_HTTP_PORT.' }
}
$loopbackUrl = $uri.Host -eq 'localhost' -or $uri.Host -eq '127.0.0.1'
if ($booleans.MOODLE_SSLPROXY -eq 'false' -and $bind -eq '127.0.0.1' -and -not $loopbackUrl) {
    Fail 'A loopback-only MOODLE_HTTP_BIND requires a local MOODLE_WWWROOT unless SSL terminates at the central proxy.'
}
if ($booleans.MOODLE_SSLPROXY -eq 'false' -and $bind -ne '127.0.0.1' -and $bind -ne '0.0.0.0' -and $loopbackUrl) {
    Fail 'A localhost MOODLE_WWWROOT cannot use a LAN-only MOODLE_HTTP_BIND.'
}
if ($booleans.MOODLE_SSLPROXY -eq 'false' -and $bind -ne '0.0.0.0' -and $uri.HostNameType -eq [UriHostNameType]::IPv4 -and $uri.Host -ne $bind) {
    Fail 'MOODLE_HTTP_BIND and the IPv4 host in MOODLE_WWWROOT must match for direct access.'
}
if ($bind -eq '0.0.0.0' -and $uri.Host -eq 'localhost') {
    Write-Warning 'MOODLE_WWWROOT=localhost is only suitable for clients on the server; use its LAN IP for remote access.'
}

foreach ($key in @('POSTGRES_DB','POSTGRES_USER')) {
    $sqlIdentifier = Get-Value $key 'moodle'
    if ($sqlIdentifier -notmatch '^[A-Za-z_][A-Za-z0-9_]{0,62}$') { Fail "$key must be a SQL identifier (letters, digits or underscores; max 63)." }
}
$dbPrefix = Get-Value 'MOODLE_DB_PREFIX' 'mdl_'
if ($dbPrefix -notmatch '^[A-Za-z][A-Za-z0-9_]{0,9}$') { Fail 'MOODLE_DB_PREFIX must start with a letter and contain only letters, digits or underscores (max 10 for Moodle 5.2).' }
$redisPort = Get-Value 'MOODLE_REDIS_PORT' '6379'
if (-not (Test-Port $redisPort)) { Fail 'MOODLE_REDIS_PORT must be an integer from 1 to 65535.' }
$redisDatabase = Get-Value 'MOODLE_REDIS_DATABASE' '0'
if ($redisDatabase -notmatch '^[0-9]+$' -or [int]$redisDatabase -gt 15) { Fail 'MOODLE_REDIS_DATABASE must be an integer from 0 to 15.' }

function Get-Limit([string]$Key, [int]$Default, [int]$Minimum, [int]$Maximum) {
    $current = Get-Value $Key ([string]$Default)
    if ($current -notmatch '^[0-9]+$') { Fail "$Key must be an integer." }
    $number = [int]$current
    if ($number -lt $Minimum -or $number -gt $Maximum) { Fail "$Key must be between $Minimum and $Maximum." }
    return $number
}
$uploadMb = Get-Limit 'MOODLE_MAX_UPLOAD_MB' 256 1 10240
$requestMb = Get-Limit 'MOODLE_MAX_REQUEST_MB' 300 1 10240
$memoryMb = Get-Limit 'MOODLE_MEMORY_LIMIT_MB' 512 128 65536
$executionSeconds = Get-Limit 'MOODLE_MAX_EXECUTION_SECONDS' 30 5 7200
$fpmChildren = Get-Limit 'MOODLE_FPM_MAX_CHILDREN' 5 3 512
$fastcgiSeconds = Get-Limit 'MOODLE_FASTCGI_READ_TIMEOUT_SECONDS' 120 5 3600
if ($requestMb -le $uploadMb) { Fail 'MOODLE_MAX_REQUEST_MB must be greater than MOODLE_MAX_UPLOAD_MB so the full request (with form overhead) fits.' }
if ($values['MOODLE_ADMIN_EMAIL'] -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { Fail 'MOODLE_ADMIN_EMAIL must be a valid email address.' }
foreach ($key in @('MOODLE_ADMIN_USER','MOODLE_SITE_FULLNAME','MOODLE_SITE_SHORTNAME')) {
    if ([string]::IsNullOrWhiteSpace($values[$key])) { Fail "$key must not be empty or whitespace-only." }
}
$lang = Get-Value 'MOODLE_LANG' 'es'
if ($lang -notmatch '^[A-Za-z0-9_-]+$') { Fail "MOODLE_LANG may contain only letters, digits, '_' or '-'." }

$releaseTag = $values['MOODLE_GIT_TAG']
$releaseRef = $values['MOODLE_GIT_REF']
$moodleVersion = $values['MOODLE_VERSION']
$launcherVersion = $values['LAUNCHER_VERSION']
if ($releaseTag -cne "v$moodleVersion") { Fail 'Release metadata mismatch: MOODLE_GIT_TAG must correspond to MOODLE_VERSION.' }
if ($releaseRef -cnotmatch '^[0-9a-f]{40}$') { Fail 'Release metadata MOODLE_GIT_REF must be a 40-character lowercase commit hash.' }
if ($values['RELEASE_IMAGE_TAG'] -cne "moodle-$moodleVersion-launcher-$launcherVersion") { Fail 'Release metadata RELEASE_IMAGE_TAG must encode the Moodle and launcher versions.' }
foreach ($key in @('DEBIAN_IMAGE','PHP_IMAGE','NGINX_IMAGE','POSTGRES_IMAGE','REDIS_IMAGE')) {
    if ($values[$key] -cnotmatch '^.+@sha256:[0-9a-f]{64}$') { Fail "Release metadata $key must pin an image to a SHA256 digest." }
}
Invoke-Compose config --quiet
if ($LASTEXITCODE -ne 0) { Fail 'The resolved Compose configuration is invalid; review the variable named in the Compose error.' }
if ($ConfigOnly) { Write-Host 'Configuration OK.'; exit 0 }

docker info | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'Docker daemon is not running. Start Docker Desktop first.' }

if ($FreshInstall) {
    $existingContainers = docker ps -a -q --filter "label=com.docker.compose.project=$project"
    if ($LASTEXITCODE -ne 0) { Fail "Cannot inspect containers for project $project." }
    if ($existingContainers) { Fail "Project $project already has containers; install.ps1 is only for a fresh project." }
    $existingVolumes = docker volume ls -q --filter "label=com.docker.compose.project=$project"
    if ($LASTEXITCODE -ne 0) { Fail "Cannot inspect volumes for project $project." }
    if ($existingVolumes) { Fail "Project $project already has data volumes; refusing a fresh install." }
}

$runningServices = Invoke-Compose ps --status running --services
if ($LASTEXITCODE -ne 0) { Fail "Cannot inspect running services for project $project." }

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

if ($inUse -and $runningServices -notcontains 'web') {
    Fail "Host port $port is already in use outside project $project. Choose another MOODLE_HTTP_PORT."
}

Write-Host 'Preflight OK.'
