$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$cfgJson = docker compose config --format json
if ($LASTEXITCODE -ne 0) { throw 'docker compose config failed.' }
$project = ($cfgJson | ConvertFrom-Json).name
if ($project -ne 'lms-moodle-dev') {
    throw "Refusing to clean: active COMPOSE_PROJECT_NAME is '$project', not 'lms-moodle-dev'. Activate .env.windows first."
}

Write-Host 'Removing Windows test stack (containers, networks, volumes)...'
docker compose down -v --remove-orphans
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Removing Windows test images...'
foreach ($image in @('lmsdev/moodle-web:5.2.3', 'lmsdev/moodle-app:5.2.3')) {
    docker image inspect $image *> $null
    if ($LASTEXITCODE -eq 0) {
        docker image rm $image | Out-Null
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

Write-Host ''
Write-Host 'Windows test profile removed: lms-moodle-dev containers/networks/volumes and lmsdev/* images.'
Write-Host 'Production names (lms-moodle_*, lms/moodle-*) are never touched by this script.'
