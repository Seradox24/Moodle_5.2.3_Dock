$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dest = if ($args.Count -ge 1) { $args[0] } else { Join-Path 'backups' $timestamp }
if (Test-Path -LiteralPath $dest) { throw "Backup destination already exists: $dest" }
$running = docker compose ps --status running --services
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect services.' }
foreach ($service in @('db', 'app', 'web', 'cron')) {
    if ($running -notcontains $service) { throw "Service $service must be running before this backup." }
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$destFull = (Resolve-Path -LiteralPath $dest).Path

$dbDump = Join-Path $destFull 'database.dump'
$dataTar = Join-Path $destFull 'moodledata.tar.gz'
$codeTar = Join-Path $destFull 'moodle-code.tar.gz'
$imageList = Join-Path $destFull 'images.txt'
$images = docker compose images
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect images.' }
Set-Content -LiteralPath $imageList -Value $images -Encoding UTF8

try {
    Write-Host 'Pausing web, cron and app for a consistent backup...'
    docker compose stop --timeout 120 web cron app
    if ($LASTEXITCODE -ne 0) { throw 'Cannot pause writers for backup.' }

    # cmd redirects bytes unchanged, including on Windows PowerShell 5.1.
    Write-Host 'Backing up PostgreSQL...'
    $dbCmd = 'docker compose exec -T db sh -lc "pg_dump -U $POSTGRES_USER -d $POSTGRES_DB -Fc" > "' + $dbDump + '"'
    cmd /d /c $dbCmd
    if ($LASTEXITCODE -ne 0) { throw 'Database backup failed.' }

    Write-Host 'Backing up moodledata...'
    $dataCmd = 'docker compose run --rm -T --no-deps --user www-data --entrypoint tar app -C /var/moodledata -czf - . > "' + $dataTar + '"'
    cmd /d /c $dataCmd
    if ($LASTEXITCODE -ne 0) { throw 'Moodledata backup failed.' }

    Write-Host 'Backing up code, plugins and themes...'
    $codeCmd = 'docker compose run --rm -T --no-deps --user www-data --entrypoint tar app -C /var/www/moodle/public -czf - . > "' + $codeTar + '"'
    cmd /d /c $codeCmd
    if ($LASTEXITCODE -ne 0) { throw 'Moodle code backup failed.' }

    $hashLines = @()
    foreach ($file in @($dbDump, $dataTar, $codeTar, $imageList)) {
        if (-not (Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) {
            throw "Backup file is missing or empty: $file"
        }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower()
        $hashLines += "$hash  $(Split-Path -Leaf $file)"
    }
    Set-Content -LiteralPath (Join-Path $destFull 'SHA256SUMS') -Value $hashLines -Encoding ASCII
}
finally {
    docker compose start app cron web
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not resume the stack. Check docker compose ps and start app, cron and web.'
    }
}

Write-Host "Backup created at $dest"
