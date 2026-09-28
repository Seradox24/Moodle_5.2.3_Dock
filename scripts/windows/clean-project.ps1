# Removes the containers, networks and volumes of one selected test project.
# Refuses the production project name, requires -Force, never prunes globally
# and only removes the project's built images when -RemoveImages is passed.
param(
    [string]$EnvFile = '.env',
    [switch]$Force,
    [switch]$RemoveImages
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')

Initialize-ComposeEnvironment -EnvFile $EnvFile -Quiet
$project = $script:ComposeValues['COMPOSE_PROJECT_NAME']
if (-not $project) { $project = 'lms-moodle' }
if ($project -eq 'lms-moodle') {
    throw "Refusing to clean the production project 'lms-moodle'. Select a test or client project."
}

$containers = docker ps -a -q --filter "label=com.docker.compose.project=$project"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect project containers.' }
$volumes = docker volume ls -q --filter "label=com.docker.compose.project=$project"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect project volumes.' }

if ($RemoveImages -and -not $Force) {
    throw '-RemoveImages always requires -Force, including empty projects.'
}

function Remove-ProjectImages {
    $namespace = $script:ComposeValues['IMAGE_NAMESPACE']
    if (-not $namespace) { $namespace = 'lms' }
    $releaseTag = $script:ComposeValues['RELEASE_IMAGE_TAG']
    if (-not $releaseTag) { return }
    foreach ($image in @("$namespace/moodle-app:$releaseTag", "$namespace/moodle-web:$releaseTag")) {
        $present = docker image ls -q --filter "reference=$image"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot list images.' }
        if ($present) {
            $users = docker ps -a -q --filter "ancestor=$image"
            if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect image references.' }
            if ($users) { throw "Image $image is referenced by existing containers; preserving it." }
            docker image rm $image | Out-Null
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            Write-Host "Removed image $image"
        }
    }
}

if (-not $containers -and -not $volumes) {
    if ($RemoveImages) { Remove-ProjectImages }
    Write-Host "Nothing to clean for project $project."
    exit 0
}

if (-not $Force) {
    Write-Host "Project $project still owns these resources:" -ForegroundColor Yellow
    if ($containers) {
        docker ps -a --filter "label=com.docker.compose.project=$project" --format '  container {{.Names}}' | Write-Host
    }
    if ($volumes) {
        $volumes | ForEach-Object { Write-Host "  volume $_" }
    }
    throw 'Re-run with -Force to remove them and -RemoveImages to also drop the project''s built images.'
}

Invoke-Compose down -v --remove-orphans
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$remainingContainers = docker ps -a -q --filter "label=com.docker.compose.project=$project"
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify container removal.' }
if ($remainingContainers) { throw "Containers remain for project $project." }
$remainingVolumes = docker volume ls -q --filter "label=com.docker.compose.project=$project"
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify volume removal.' }
if ($remainingVolumes) { throw "Volumes remain for project ${project}: $($remainingVolumes -join ', ')" }

if ($RemoveImages) { Remove-ProjectImages }

Write-Host "Project $project cleaned. Volumes and containers removed."
