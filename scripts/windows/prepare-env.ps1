param(
    [string]$OutputPath = '.env',
    [string]$ProjectName = 'lms-moodle-dev'
)
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$example = Join-Path $repoRoot '.env.example'
$candidate = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repoRoot $OutputPath }
$target = [IO.Path]::GetFullPath($candidate)
$targetDirectory = Split-Path -Parent $target

if (-not (Test-Path -LiteralPath $example -PathType Leaf)) { throw '.env.example is missing.' }
if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) { throw "Output directory does not exist: $targetDirectory" }
if ($ProjectName -notmatch '^[a-z0-9][a-z0-9_-]{0,62}$') {
    throw 'ProjectName must start with a lowercase letter or digit and contain at most 63 lowercase letters, digits, underscores or hyphens.'
}

$content = [IO.File]::ReadAllText($example)
$projectMarker = 'COMPOSE_PROJECT_NAME=lms-moodle'
$dbMarker = 'POSTGRES_PASSWORD=CHANGE_ME_STRONG_DB_PASSWORD'
$adminMarker = 'MOODLE_ADMIN_PASSWORD=CHANGE_ME_STRONG_ADMIN_PASSWORD'
if ([regex]::Matches($content, [regex]::Escape($projectMarker)).Count -ne 1 -or
    [regex]::Matches($content, [regex]::Escape($dbMarker)).Count -ne 1 -or
    [regex]::Matches($content, [regex]::Escape($adminMarker)).Count -ne 1) {
    throw '.env.example must contain one project marker and one marker for each generated password.'
}

$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $dbBytes = New-Object byte[] 32
    $adminBytes = New-Object byte[] 32
    $rng.GetBytes($dbBytes)
    $rng.GetBytes($adminBytes)
}
finally { $rng.Dispose() }
$dbPassword = [Convert]::ToBase64String($dbBytes)
$adminPassword = [Convert]::ToBase64String($adminBytes)
$content = $content.Replace($projectMarker, "COMPOSE_PROJECT_NAME=$ProjectName").Replace('IMAGE_NAMESPACE=lms', 'IMAGE_NAMESPACE=lmsdev').Replace($dbMarker, "POSTGRES_PASSWORD=$dbPassword").Replace($adminMarker, "MOODLE_ADMIN_PASSWORD=$adminPassword")
$encoding = [Text.UTF8Encoding]::new($false)
$bytes = $encoding.GetBytes($content)

$stream = $null
try {
    $stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $stream.Write($bytes, 0, $bytes.Length)
}
catch {
    if ($null -ne $stream) { $stream.Dispose() }
    if ($null -ne $stream) { [IO.File]::Delete($target) }
    throw "Could not create environment file without overwriting an existing file: $target"
}
finally {
    if ($null -ne $stream) { $stream.Dispose() }
}

try {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($sid)
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $sid,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.AccessControlType]::Allow
    )
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $target -AclObject $acl
}
catch {
    [IO.File]::Delete($target)
    throw 'Could not restrict the private environment file ACL to the current Windows user.'
}

Write-Host "Created private environment file: $target"
