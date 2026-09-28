param([string]$Destination, [string]$EnvFile = '.env')
$ErrorActionPreference = 'Stop'
# Check dependencies before stopping any writers.
Get-Command Get-FileHash -ErrorAction Stop | Out-Null

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')
Initialize-ComposeEnvironment -EnvFile $EnvFile

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dest = if ($Destination) { $Destination } else { Join-Path 'backups' $timestamp }
if (Test-Path -LiteralPath $dest) { throw "Backup destination already exists: $dest" }
$running = Invoke-Compose ps --status running --services
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
$images = Invoke-Compose images
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect images.' }
Set-Content -LiteralPath $imageList -Value $images -Encoding UTF8
$imageDigests = @()
foreach ($service in @('app','web','cron','db','redis')) {
    $cid = Invoke-Compose ps -a -q $service
    if ($LASTEXITCODE -ne 0 -or -not $cid) { throw "Missing deployed service: $service" }
    $imageRef = docker inspect --format '{{.Image}}' $cid
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect deployed $service image." }
    # Separate calls: a combined template fails on images with nil labels.
    $imageId = docker image inspect --format '{{.Id}}' $imageRef
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect image $imageRef." }
    $repoDigests = docker image inspect --format '{{json .RepoDigests}}' $imageRef
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect image $imageRef." }
    $labels = docker image inspect --format '{{json .Config.Labels}}' $imageRef
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect image $imageRef." }
    $imageDigests += ("{0} {1} {2} {3} {4}" -f $service, $cid, $imageId, $repoDigests, $labels)
    if ($service -eq 'app') { $appCid = $cid; $appImage = $imageId }
}
$imageDigestList = Join-Path $destFull 'image-digests.txt'
Set-Content -LiteralPath $imageDigestList -Value $imageDigests -Encoding UTF8
$releaseSnapshot = Join-Path $destFull 'release.env'
Copy-Item -LiteralPath $script:ComposeReleaseFile -Destination $releaseSnapshot

try {
    Write-Host 'Pausing web, cron and app for a consistent backup...'
    Invoke-Compose stop --timeout 120 web cron app
    if ($LASTEXITCODE -ne 0) { throw 'Cannot pause writers for backup.' }

    # cmd redirects bytes unchanged, including on Windows PowerShell 5.1.
    Write-Host 'Backing up PostgreSQL...'
    $composePrefix = 'docker compose --project-directory "' + $script:ComposeRepoRoot + '" --file "' + (Join-Path $script:ComposeRepoRoot 'compose.yaml') + '" --env-file "' + $script:ComposeEnvFile + '" --env-file "' + $script:ComposeReleaseFile + '" '
    $dbCmd = $composePrefix + 'exec -T db sh -lc "pg_dump -U $POSTGRES_USER -d $POSTGRES_DB -Fc" > "' + $dbDump + '"'
    cmd /d /c $dbCmd
    if ($LASTEXITCODE -ne 0) { throw 'Database backup failed.' }

    Write-Host 'Backing up moodledata...'
    $snapshotPrefix = 'docker run --rm --network none --read-only --volumes-from ' + $appCid + ':ro '
    $dataCmd = $snapshotPrefix + '--user www-data --entrypoint tar ' + $appImage + ' -C /var/moodledata -czf - . > "' + $dataTar + '"'
    cmd /d /c $dataCmd
    if ($LASTEXITCODE -ne 0) { throw 'Moodledata backup failed.' }

    Write-Host 'Backing up code, plugins and themes...'
    $codeCmd = $snapshotPrefix + '--user www-data --entrypoint tar ' + $appImage + ' -C /var/www/moodle/public -czf - . > "' + $codeTar + '"'
    cmd /d /c $codeCmd
    if ($LASTEXITCODE -ne 0) { throw 'Moodle code backup failed.' }

    Write-Host 'Recording the deployed code marker...'
    $markerFile = Join-Path $destFull 'deployment-ref.txt'
    $markerCmd = $snapshotPrefix + '--entrypoint cat ' + $appImage + ' /var/www/moodle/public/.deployment-ref > "' + $markerFile + '"'
    cmd /d /c $markerCmd
    if ($LASTEXITCODE -ne 0) { throw 'Cannot record the deployment reference.' }

    $hashLines = @()
    foreach ($file in @($dbDump, $dataTar, $codeTar, $imageList, $imageDigestList, $markerFile, $releaseSnapshot)) {
        if (-not (Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) {
            throw "Backup file is missing or empty: $file"
        }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLower()
        $hashLines += "$hash  $(Split-Path -Leaf $file)"
    }
    # LF endings so GNU `sha256sum -c` can verify the file from Linux or Git Bash.
    $sums = ($hashLines -join "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $destFull 'SHA256SUMS'), $sums, (New-Object Text.UTF8Encoding($false)))
}
finally {
    Invoke-Compose start app cron web
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not resume the stack. Check docker compose ps and start app, cron and web.'
    }
}

Write-Host "Backup created at $dest"
