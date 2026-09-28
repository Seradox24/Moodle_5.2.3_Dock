$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Raw passthrough: PowerShell common-parameter binding would otherwise swallow
# Compose flags such as -v (Verbose), -d (Debug) or -p (PipelineVariable).
$envFile = '.env'
$composeArgs = @()
$raw = @($args)
for ($index = 0; $index -lt $raw.Count; $index++) {
    if ($raw[$index] -eq '-EnvFile') {
        if ($index + 1 -ge $raw.Count) { throw '-EnvFile requires a path.' }
        $envFile = $raw[++$index]
    }
    else {
        $composeArgs += $raw[$index]
    }
}

if ($composeArgs.Count -eq 0) {
    throw 'Usage: .\scripts\windows\compose.ps1 [-EnvFile PATH] COMPOSE_ARGS...'
}

Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'compose-env.ps1')
Initialize-ComposeEnvironment -EnvFile $envFile
Invoke-Compose @composeArgs
exit $LASTEXITCODE
