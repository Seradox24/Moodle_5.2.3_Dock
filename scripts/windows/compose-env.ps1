function Initialize-ComposeEnvironment {
    param([string]$EnvFile = '.env', [switch]$Quiet, [switch]$SkipConfigValidation)

    $script:ComposeRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $releaseCandidate = Join-Path $script:ComposeRepoRoot 'releases\release.env'
    if (-not (Test-Path -LiteralPath $releaseCandidate -PathType Leaf)) {
        throw "Versioned release metadata is missing: $releaseCandidate"
    }
    $script:ComposeReleaseFile = (Resolve-Path -LiteralPath $releaseCandidate).Path
    $candidate = if ([IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $script:ComposeRepoRoot $EnvFile }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Environment file not found: $candidate"
    }
    $script:ComposeEnvFile = (Resolve-Path -LiteralPath $candidate).Path

    $profileProject = 'lms-moodle'
    foreach ($line in [IO.File]::ReadAllLines($script:ComposeEnvFile)) {
        $clean = $line.TrimStart([char]0xFEFF).Trim()
        if ($clean -notmatch '^(?:export\s+)?COMPOSE_PROJECT_NAME\s*=') { continue }
        $projectValue = ($clean -replace '^(?:export\s+)?COMPOSE_PROJECT_NAME\s*=\s*', '').Trim()
        if ($projectValue.Length -ge 2 -and
            (($projectValue.StartsWith("'") -and $projectValue.EndsWith("'")) -or
             ($projectValue.StartsWith('"') -and $projectValue.EndsWith('"')))) {
            $projectValue = $projectValue.Substring(1, $projectValue.Length - 2)
        }
        else {
            $projectValue = ($projectValue -replace '\s+#.*$', '').Trim()
        }
        if ($projectValue) { $profileProject = $projectValue }
    }
    if ($profileProject -cnotmatch '^[a-z0-9][a-z0-9_-]{0,62}$') {
        throw 'COMPOSE_PROJECT_NAME must start with a lowercase letter or digit and contain only lowercase letters, digits, hyphens or underscores (max 63).'
    }

    $managed = @(
        'COMPOSE_PROJECT_NAME', 'COMPOSE_FILE', 'COMPOSE_PROFILES', 'COMPOSE_ENV_FILES', 'IMAGE_NAMESPACE',
        'MOODLE_WWWROOT', 'MOODLE_HTTP_BIND', 'MOODLE_HTTP_PORT',
        'LAUNCHER_VERSION', 'MOODLE_VERSION', 'MOODLE_GIT_TAG', 'MOODLE_GIT_REF', 'RELEASE_IMAGE_TAG',
        'DEBIAN_IMAGE', 'PHP_IMAGE', 'NGINX_IMAGE', 'POSTGRES_IMAGE', 'REDIS_IMAGE',
        'POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'MOODLE_DB_PREFIX', 'MOODLE_SITE_FULLNAME',
        'MOODLE_SITE_SHORTNAME', 'MOODLE_LANG', 'MOODLE_ADMIN_USER', 'MOODLE_ADMIN_PASSWORD',
        'MOODLE_ADMIN_EMAIL', 'MOODLE_PLUGIN_INSTALL', 'MOODLE_REVERSEPROXY',
        'MOODLE_SSLPROXY', 'MOODLE_ROUTER_CONFIGURED', 'MOODLE_REDIS_SESSIONS', 'MOODLE_REDIS_HOST',
        'MOODLE_REDIS_PORT', 'MOODLE_REDIS_DATABASE', 'MOODLE_REDIS_PREFIX', 'MOODLE_MAX_UPLOAD_MB',
        'MOODLE_MAX_REQUEST_MB', 'MOODLE_MEMORY_LIMIT_MB', 'MOODLE_MAX_EXECUTION_SECONDS',
        'MOODLE_FPM_MAX_CHILDREN', 'MOODLE_FASTCGI_READ_TIMEOUT_SECONDS'
    )
    $conflicts = @()
    foreach ($key in $managed) {
        if ($null -ne [Environment]::GetEnvironmentVariable($key, 'Process')) { $conflicts += $key }
    }
    if ($conflicts.Count) {
        throw "Unset template-managed shell variables before running this command: $($conflicts -join ', ')"
    }

    $envModel = Join-Path $script:ComposeRepoRoot 'compose.yaml'
    if (-not $SkipConfigValidation) {
        & docker compose --project-directory $script:ComposeRepoRoot --file (Join-Path $script:ComposeRepoRoot 'compose.yaml') --env-file $script:ComposeEnvFile --env-file $script:ComposeReleaseFile config --quiet
        if ($LASTEXITCODE -ne 0) { throw 'docker compose config failed.' }
    }
    else {
        $envModel = Join-Path $script:ComposeRepoRoot 'scripts\lib\environment-only.yaml'
    }
    $resolved = & docker compose --project-directory $script:ComposeRepoRoot --file $envModel --env-file $script:ComposeEnvFile --env-file $script:ComposeReleaseFile config --environment
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve Compose environment.' }
    $values = @{}
    foreach ($line in $resolved) {
        if ($line -match '^([^=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    $script:ComposeValues = $values
    $project = if ($values['COMPOSE_PROJECT_NAME']) { $values['COMPOSE_PROJECT_NAME'] } else { 'lms-moodle' }
    $url = if ($values['MOODLE_WWWROOT']) { $values['MOODLE_WWWROOT'] } else { 'http://localhost:18080' }
    $launcher = if ($values['LAUNCHER_VERSION']) { $values['LAUNCHER_VERSION'] } else { 'unknown' }
    $moodle = if ($values['MOODLE_VERSION']) { $values['MOODLE_VERSION'] } else { 'unknown' }
    $displayUrl = $url -replace '^(https?://)[^/@]+@', '$1[redacted]@'
    if (-not $Quiet) {
        Write-Host "Environment file: $script:ComposeEnvFile"
        Write-Host "Project: $project"
        Write-Host "Launcher: $launcher"
        Write-Host "Moodle: $moodle"
        Write-Host "URL: $displayUrl"
    }
}

function Invoke-Compose {
    & docker compose --project-directory $script:ComposeRepoRoot --file (Join-Path $script:ComposeRepoRoot 'compose.yaml') --env-file $script:ComposeEnvFile --env-file $script:ComposeReleaseFile @args
}
