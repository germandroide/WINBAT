<#
    WinBat Suite - Storage Mount Service
    WinBat_MountService.ps1

    Runs at startup (silently) to restore drive mappings defined in mounts.json.
#>

# ==========================================
# 0. Initialize
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "..\global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) { exit }
. $GlobalConfigPath

$ConfigDir = "C:\WinBat\Config"
$ConfigFile = Join-Path $ConfigDir "mounts.json"

if (-not (Test-Path $ConfigFile)) { exit }

try {
    $JsonContent = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    if (-not $JsonContent) { exit }

    foreach ($Mount in $JsonContent) {
        $Drive = $Mount.DriveLetter
        $Path = $Mount.SourcePath

        if ($Drive -and $Path -and (Test-Path $Path)) {
            # Use subst for folder mapping
            # Remove previous if exists (cleanup)
            Subst $Drive /D | Out-Null
            Subst $Drive $Path | Out-Null
        }
    }
} catch {
    # Silent failure (Service mode)
    exit
}
