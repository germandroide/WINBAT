<#
    WinBat Suite - Dependencies Installer
    WinBat_Dependencies.ps1

    Installs critical gaming runtimes (DirectX, VC++, .NET).
#>

# ==========================================
# 0. Initialize
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "..\global_config.ps1"
if (-not (Test-Path $GlobalConfigPath)) { exit }
. $GlobalConfigPath

Write-Host (Get-Tr "DEP_INSTALLING") -ForegroundColor Cyan

try {
    # 1. Visual C++ Redistributable AIO
    # Using TechPowerUp or similar reliable repacks is common, but for cleanliness we stick to Winget or Microsoft sources.
    # Installing latest individual ones via Winget:

    $VC_IDs = @("Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86", "Microsoft.VCRedist.2013.x64", "Microsoft.VCRedist.2013.x86", "Microsoft.VCRedist.2012.x64", "Microsoft.VCRedist.2012.x86", "Microsoft.VCRedist.2010.x64", "Microsoft.VCRedist.2010.x86")

    foreach ($Id in $VC_IDs) {
        Write-Host "Installing $Id..."
        Start-Process -FilePath "winget" -ArgumentList "install --id $Id -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
    }

    # 2. DirectX End-User Runtime
    # Microsoft.DirectX
    Write-Host "Installing DirectX..."
    Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.DirectX -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow

    # 3. .NET Framework 3.5 (Includes 2.0/3.0)
    # Needs DISM usually on Windows 10/11
    Write-Host "Enabling .NET 3.5..."
    Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart -ErrorAction SilentlyContinue

    # 4. .NET Desktop Runtime (Latest)
    Write-Host "Installing .NET Desktop Runtime..."
    Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.DotNet.DesktopRuntime.6 -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
    Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.DotNet.DesktopRuntime.7 -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow

    Write-Host (Get-Tr "DEP_SUCCESS") -ForegroundColor Green

} catch {
    Write-Error (Get-Tr "DEP_FAIL")
}
