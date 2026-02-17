Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-BashFromRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter()]
        [string[]]$ScriptArgs = @()
    )

    $scriptDir = Split-Path -Parent $PSCommandPath
    $repoRoot = Resolve-Path (Join-Path $scriptDir "..")
    $targetScript = Join-Path $repoRoot $ScriptPath.TrimStart("./")

    if (-not (Test-Path -LiteralPath $targetScript)) {
        Write-Error "Target script not found: $targetScript"
        exit 1
    }

    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashCmd) {
        Write-Error "bash not found in PATH. Install Git Bash or enable WSL bash."
        exit 1
    }

    Push-Location $repoRoot
    try {
        & $bashCmd.Source $ScriptPath @ScriptArgs
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($null -ne $exitCode) {
        exit $exitCode
    }

    exit 0
}

