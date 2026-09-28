# Diagnostic: project, effective release metadata, image identifiers, code
# volume marker and embedded-script parity. Prints no secrets. Exit 0 when the
# deployed pieces match the versioned release in releases/release.env.
param([string]$EnvFile = '.env')
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile
$values = $script:ComposeValues
$namespace = if ($values['IMAGE_NAMESPACE']) { $values['IMAGE_NAMESPACE'] } else { 'lms' }
$releaseTag = $values['RELEASE_IMAGE_TAG']
$launcher = if ($values['LAUNCHER_VERSION']) { $values['LAUNCHER_VERSION'] } else { 'unknown' }
$moodle = if ($values['MOODLE_VERSION']) { $values['MOODLE_VERSION'] } else { 'unknown' }
$coreRef = if ($values['MOODLE_GIT_REF']) { $values['MOODLE_GIT_REF'] } else { '' }

Write-Host ''
Write-Host "Repository release: launcher=$launcher moodle=$moodle tag=$releaseTag"
$running = (Invoke-Compose ps --status running --services | Where-Object { $_ }) -join ' '
Write-Host "Running services: $running"

$status = 0
foreach ($service in @('app', 'web', 'cron')) {
    $cid = Invoke-Compose ps -a -q $service
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect containers.' }
    if (-not $cid) {
        Write-Host "MISSING: $service container"
        $status = 1
        continue
    }
    $image = docker inspect --format '{{.Image}}' $cid
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect deployed image ID.' }
    $runningState = docker inspect --format '{{.State.Running}}' $cid
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect container state.' }
    if ($runningState -ne 'true') { Write-Host "STOPPED: $service"; $status = 1 }
    $imageId = docker image inspect --format '{{.Id}}' $image
    # Full JSON labels avoid embedded quotes, which PowerShell would strip
    # before passing the --format argument to docker.
    $labels = docker image inspect --format '{{json .Config.Labels}}' $image | ConvertFrom-Json
    $imageLauncher = $labels.'io.lms.launcher.version'
    $imageMoodle = $labels.'io.lms.moodle.version'
    $imageRevision = $labels.'org.opencontainers.image.revision'
    Write-Host "IMAGE $service`: $image id=$imageId launcher=$imageLauncher moodle=$imageMoodle core=$imageRevision"
    if ($imageLauncher -cne $launcher -or $imageMoodle -cne $moodle -or $imageRevision -cne $coreRef) {
        Write-Host "MISMATCH: $service image labels do not match the versioned release"
        $status = 1
    }
}

$appCid = Invoke-Compose ps -q app
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect running app.' }
if ($appCid) {
    # compose run prints progress on stderr; with ErrorActionPreference Stop that
    # would abort here, so relax it and keep only real output strings.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $imageHashLine = docker exec $appCid sh -c 'sha256sum /usr/local/bin/check-runtime.php' 2>&1 |
        Where-Object { $_ -is [string] -and $_ -match '^\s*[0-9a-f]{64}' } | Select-Object -Last 1
    $ErrorActionPreference = $previousPreference
    $imageHash = $null
    if ($imageHashLine) { $imageHash = ([regex]::Match([string]$imageHashLine, '[0-9a-f]{64}')).Value }
    $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repoRoot 'docker\install\check-runtime.php')).Hash.ToLower()
    if ($imageHash -and $imageHash -eq $localHash) {
        Write-Host "CHECK-RUNTIME: embedded script matches the repository ($($localHash.Substring(0,12))...)"
    }
    else {
        Write-Host 'DIFFERS: the check-runtime.php embedded in the image does not match the repository.' -ForegroundColor Red
        Write-Host '          Deliver the smoke-test fix by rebuilding the release; copying the file to the server does not update the image.' -ForegroundColor Red
        $status = 1
    }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $marker = (docker exec $appCid sh -c 'cat /var/www/moodle/public/.deployment-ref' 2>&1 |
        Where-Object { $_ -is [string] -and $_ -match '\S' } | Select-Object -Last 1)
    $ErrorActionPreference = $previousPreference
    if ($marker) { $marker = ([string]$marker).Trim() }
    if (-not $marker) {
        Write-Host 'MISSING: moodle-code volume has no .deployment-ref marker (project not initialised?)'
        $status = 1
    }
    elseif ($marker -eq $coreRef) {
        Write-Host 'CODE VOLUME: .deployment-ref matches the versioned core commit'
    }
    else {
        Write-Host "DIFFERS: moodle-code marker '$marker' does not match the release core commit '$coreRef'"
        $status = 1
    }
}

Write-Host ''
if ($status -eq 0) {
    Write-Host "Release check OK: the selected project matches launcher $launcher / Moodle $moodle."
}
else {
    Write-Host 'Release check found mismatches; review the lines above before operating.' -ForegroundColor Red
    exit 1
}
