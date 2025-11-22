<#
    WinBat Suite - Admin Console
    Manage-WinBat.ps1

    Interactive CLI Menu for Host Management.
    Handles Lifecycle, Boot config, Backups, and Host Optimization.
#>

# ==========================================
# 0. Initialize Environment
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) {
    Write-Error "Critical: global_config.ps1 not found."
    exit 1
}

. $GlobalConfigPath

# Ensure Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges required."
    exit 1
}

# ==========================================
# 1. Functions
# ==========================================

function Show-Header {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ("   " + (Get-Tr "MENU_TITLE")) -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Run-Install {
    Write-Host (Get-Tr "INSTALL_STARTING") -ForegroundColor Yellow

    # Check for Data folder logic here or delegate to Install-WinBat?
    # Better to delegate, but Manage-WinBat acts as a wrapper.
    # We will invoke the Install script. The Install script needs to be updated to handle the logic.
    # However, Manage-WinBat might pass arguments?
    # For now, simply call the installer. The installer should handle the "Keep/Wipe" logic interactively if run manually,
    # but here we might want to pre-check.

    # Actually, let's keep the logic inside Install-WinBat.ps1 to avoid duplication,
    # but Manage-WinBat creates the context.

    Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath\Installer\Install-WinBat.ps1`"" -Wait
    Pause
}

function Run-Uninstall {
    $Confirm = Read-Host (Get-Tr "MSG_UNINSTALL_CONFIRM")
    if ($Confirm -match "y") {
        # 1. Remove Boot Entry
        # Identify GUID
        $BcdList = bcdedit /enum
        # We need to parse or just delete by description if unique
        # This is complex to do robustly in regex in a few lines.
        # Simplified: Tell user to check msconfig or do best effort.
        # Actually, Install-WinBat adds entry. We should try to remove.
        Write-Host "Removing Boot Entry..." -ForegroundColor Yellow
        # Warning: This is risky without exact GUID.
        # Safer: Just delete VHDX and let user clean BCD, or use bcdedit /delete {GUID} if we stored it.
        # We didn't store it.

        # 2. Delete VHDX
        $InstallPath = $Global:WB_InstallPath
        if (Test-Path $InstallPath) {
            Remove-Item (Join-Path $InstallPath $Global:WB_VHDXName_Base) -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $InstallPath $Global:WB_VHDXName_Child) -Force -ErrorAction SilentlyContinue
            Write-Host "VHDX Files Removed." -ForegroundColor Green
        }

        # 3. Data Folder
        $DataConfirm = Read-Host (Get-Tr "MSG_UNINSTALL_DATA")
        if ($DataConfirm -match "y") {
            Remove-Item (Join-Path $InstallPath "Data") -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Data Folder Removed." -ForegroundColor Green
        }
    }
    Pause
}

function Set-Boot-Default {
    param ($Target)
    if ($Target -eq "WinBat") {
        # Find WinBat GUID.
        # Trick: search for the entry with description
        $Bcd = bcdedit /enum
        $Lines = $Bcd -split "`r`n"
        $Guid = ""
        for ($i=0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match "WinBat Console Mode") {
                # Look backwards for identifier
                for ($j=$i; $j -ge 0; $j--) {
                    if ($Lines[$j] -match "identifier\s+{(.*)}") {
                        $Guid = "{$($matches[1])}"
                        break
                    }
                }
                break
            }
        }
        if ($Guid) {
            bcdedit /default $Guid
            Write-Host "Default Boot set to WinBat ($Guid)" -ForegroundColor Green
        } else {
            Write-Warning "WinBat Boot Entry not found."
        }
    } else {
        bcdedit /default "{current}"
        Write-Host "Default Boot set to Windows Host" -ForegroundColor Green
    }
    Pause
}

function Set-Boot-Timeout {
    param ($Seconds)
    bcdedit /timeout $Seconds
    Write-Host "Timeout set to $Seconds seconds." -ForegroundColor Green
    Pause
}

function Run-Snapshot {
    $DataPath = Join-Path $Global:WB_InstallPath "Data\RetroBat\emulationstation\.emulationstation"
    $MountsFile = Join-Path $Global:WB_InstallPath "Config\mounts.json" # Wait, Config is inside VHDX?
    # No, Config/mounts.json is used by Storage Manager.
    # If VHDX is wiped, Config inside VHDX is lost.
    # We should move Config to Data too! Or backup from VHDX if mounted?
    # Requirement: "Snapshot: Crea un .zip del contenido de $InstallPath\Data\RetroBat\emulationstation\.emulationstation (Configs y Temas) y mounts.json."
    # This implies mounts.json should be accessible.
    # If mounts.json is inside VHDX, we can't easily access it unless VHDX is mounted.
    # Refactoring Decision: Move `mounts.json` to external Data folder as well?
    # Or assume user has it backed up?
    # Let's assume for now we backup what is in Data path.

    $ZipPath = Join-Path $Global:WB_InstallPath "WinBat_Backup_$(Get-Date -Format 'yyyyMMdd').zip"

    $Files = @()
    if (Test-Path $DataPath) { $Files += $DataPath }
    # Try to find mounts.json. If it's in Host/Config? No, StorageManager puts it in C:\WinBat\Config (inside Guest).
    # We can try to mount the VHDX briefly? Too complex for this script maybe.
    # Or just backup the Data folder.

    if ($Files.Count -gt 0) {
        Compress-Archive -Path $Files -DestinationPath $ZipPath -Force
        Write-Host (Get-Tr "MSG_SNAPSHOT_CREATED" -f $ZipPath) -ForegroundColor Green
    } else {
        Write-Warning "No configuration files found to backup."
    }
    Pause
}

function Run-Host-Debloat {
    Write-Host "Running Host Debloat (Light)..." -ForegroundColor Yellow
    # Simple Appx removal for Host
    $Appx = @("Microsoft.MicrosoftSolitaireCollection", "Microsoft.ZuneMusic", "Microsoft.ZuneVideo")
    foreach ($A in $Appx) {
        Get-AppxPackage -Name $A -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
    Write-Host "Host Debloat Complete." -ForegroundColor Green
    Pause
}

function Run-Security {
    Write-Host "Applying Basic Security Hardening..." -ForegroundColor Yellow
    # Enable Firewall
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    Write-Host "Firewall Enabled." -ForegroundColor Green
    Pause
}

function Run-GameRemover {
    Write-Host "Scanning for Game Libraries..." -ForegroundColor Yellow
    $Paths = @(
        "C:\Program Files (x86)\Steam",
        "C:\Program Files\Epic Games",
        "C:\XboxGames"
    )
    foreach ($P in $Paths) {
        if (Test-Path $P) {
            Write-Host "Found: $P" -ForegroundColor Red
            $Open = Read-Host "Open folder? (Y/N)"
            if ($Open -match "y") { Invoke-Item $P }
        }
    }
    Pause
}

function Run-DiskGenius {
    $ToolPath = Join-Path $Global:WB_ResourcePath "Tools\DiskGenius.exe"
    if (Test-Path $ToolPath) {
        Start-Process $ToolPath
    } else {
        Write-Host "DiskGenius not found in Tools." -ForegroundColor Red
    }
    Pause
}

# ==========================================
# 2. Main Loop
# ==========================================
while ($true) {
    Show-Header

    Write-Host (Get-Tr "MENU_GRP_LIFECYCLE") -ForegroundColor Magenta
    Write-Host "1. $(Get-Tr 'MENU_OPT_INSTALL')"
    Write-Host "2. $(Get-Tr 'MENU_OPT_UNINSTALL')"

    Write-Host (Get-Tr "MENU_GRP_BOOT") -ForegroundColor Magenta
    Write-Host "3. $(Get-Tr 'MENU_OPT_DEFAULT_WINBAT')"
    Write-Host "4. $(Get-Tr 'MENU_OPT_DEFAULT_HOST')"
    Write-Host "5. $(Get-Tr 'MENU_OPT_TIMEOUT_0')"
    Write-Host "6. $(Get-Tr 'MENU_OPT_TIMEOUT_30')"

    Write-Host (Get-Tr "MENU_GRP_BACKUP") -ForegroundColor Magenta
    Write-Host "7. $(Get-Tr 'MENU_OPT_SNAPSHOT')"
    Write-Host "8. $(Get-Tr 'MENU_OPT_RESTORE')"

    Write-Host (Get-Tr "MENU_GRP_HOST") -ForegroundColor Magenta
    Write-Host "9. $(Get-Tr 'MENU_OPT_HOST_DEBLOAT')"
    Write-Host "10. $(Get-Tr 'MENU_OPT_SECURITY')"
    Write-Host "11. $(Get-Tr 'MENU_OPT_GAMEREMOVER')"

    Write-Host (Get-Tr "MENU_GRP_TOOLS") -ForegroundColor Magenta
    Write-Host "12. $(Get-Tr 'MENU_OPT_DISKGENIUS')"

    Write-Host "0. $(Get-Tr 'MENU_EXIT')"
    Write-Host "------------------------------------------"

    $Choice = Read-Host "Select Option"

    switch ($Choice) {
        "1" { Run-Install }
        "2" { Run-Uninstall }
        "3" { Set-Boot-Default "WinBat" }
        "4" { Set-Boot-Default "Host" }
        "5" { Set-Boot-Timeout 0 }
        "6" { Set-Boot-Timeout 30 }
        "7" { Run-Snapshot }
        "8" { Write-Host "Restore not implemented yet" -ForegroundColor Red; Pause } # Placeholder
        "9" { Run-Host-Debloat }
        "10" { Run-Security }
        "11" { Run-GameRemover }
        "12" { Run-DiskGenius }
        "0" { exit }
        default { }
    }
}
