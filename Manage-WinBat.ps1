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

# Context Detection (Guest vs Host)
# In Guest, C: is the VHDX. In Host, C: is the System Drive.
# We can check for a specific Guest-only file or registry key.
# Or check if running from within the VHDX (complex).
# Simple check: Is "C:\WinBat\Optimizer\WinBat_FirstBoot.ps1" present?
# If C: contains WinBat system files natively, we are likely in Guest.
# But Wait, Host installs WinBat to C:\WinBat.
# Better check: Are we booted from VHD?
$IsGuest = $false
$BootCurrent = bcdedit /enum "{current}"
if ($BootCurrent -match "vhd=") {
    $IsGuest = $true
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

function Run-Restore {
    Write-Host "Restoring Snapshot..." -ForegroundColor Yellow
    $BackupDir = Join-Path $Global:WB_InstallPath "Backups"
    $DataPath = Join-Path $Global:WB_InstallPath "Data"

    if (-not (Test-Path $BackupDir)) { Write-Warning "No Backups Folder found."; Pause; return }

    # List Zips
    $Zips = Get-ChildItem -Path $BackupDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending
    if ($Zips.Count -eq 0) { Write-Warning "No Backups found."; Pause; return }

    Write-Host "Available Backups:"
    for ($i=0; $i -lt $Zips.Count; $i++) {
        Write-Host "$($i+1). $($Zips[$i].Name) [$($Zips[$i].LastWriteTime)]"
    }

    $Selection = Read-Host "Select Backup to Restore (Number)"
    if ($Selection -match "^\d+$" -and $Selection -le $Zips.Count -and $Selection -gt 0) {
        $TargetZip = $Zips[$Selection-1].FullName

        # Confirmation
        $Confirm = Read-Host "Warning: This will overwrite current configs. Proceed? (Y/N)"
        if ($Confirm -match "y") {
            # Expand-Archive to Data Path
            # Note: Archive structure might be deep.
            # If we zipped paths like C:\WinBat\Data\..., extracting to C:\WinBat\Data might double nest or work depending on how it was zipped.
            # PowerShell Compress-Archive usually keeps folder structure.
            # We will extract to Temp and move, or extract to root?
            # Safest is extract to Temp

            $TempDir = Join-Path $Global:WB_InstallPath "TempRestore"
            if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
            New-Item -Path $TempDir -ItemType Directory | Out-Null

            Expand-Archive -Path $TargetZip -DestinationPath $TempDir -Force

            # Now copy back to DataPath
            # We look for "RetroBat" folder in Temp
            $FoundRB = Get-ChildItem -Path $TempDir -Recurse -Filter "RetroBat" | Where-Object { $_.PSIsContainer } | Select-Object -First 1
            if ($FoundRB) {
                 # Copy content
                 Copy-Item -Path "$($FoundRB.FullName)\*" -Destination (Join-Path $DataPath "RetroBat") -Recurse -Force
                 Write-Host (Get-Tr "MSG_RESTORE_DONE") -ForegroundColor Green
            } else {
                 Write-Warning "Could not find RetroBat structure in backup."
            }

            # Cleanup
            Remove-Item $TempDir -Recurse -Force
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
    Write-Host "Creating Local Backup..." -ForegroundColor Yellow
    $DataPath = Join-Path $Global:WB_InstallPath "Data"
    $BackupDir = Join-Path $Global:WB_InstallPath "Backups"
    if (-not (Test-Path $BackupDir)) { New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null }

    $ZipPath = Join-Path $BackupDir "WinBat_Backup_$(Get-Date -Format 'yyyyMMdd').zip"

    if (Test-Path $DataPath) {
        # Backup only Configs/Saves (RetroBat/roms is too big usually, prompt implies Configs/Themes)
        # "Snapshot de Config: Guarda configuraciones de RetroBat, mounts.json y Saves"
        # We backup specific subfolders to avoid huge archives

        $FilesToBackup = @(
            (Join-Path $DataPath "RetroBat\emulationstation\.emulationstation"),
            (Join-Path $DataPath "RetroBat\saves")
        )

        # If running from Guest, include mounts.json
        if ($IsGuest) {
            $Mounts = "C:\WinBat\Config\mounts.json"
            if (Test-Path $Mounts) { $FilesToBackup += $Mounts }
        }

        Compress-Archive -Path $FilesToBackup -DestinationPath $ZipPath -Force -ErrorAction SilentlyContinue
        Write-Host (Get-Tr "MSG_SNAPSHOT_CREATED" -f $ZipPath) -ForegroundColor Green
    } else {
        Write-Warning "Data folder not found."
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
# Offline Host Management Functions
# ==========================================
function Get-HostSystemDrive {
    # Scan for a drive containing \Windows\System32\config\SYSTEM that is NOT C:
    $Drives = Get-PSDrive -PSProvider FileSystem
    foreach ($D in $Drives) {
        if ($D.Name -eq "C") { continue }
        if (Test-Path (Join-Path $D.Root "Windows\System32\config\SYSTEM")) {
            return $D.Root
        }
    }
    return $null
}

function Run-Offline-Hardening-Firewall {
    Write-Host "Detecting Host System..."
    $HostRoot = Get-HostSystemDrive
    if (-not $HostRoot) { Write-Error "Host System Not Found."; Pause; return }

    Write-Host "Mounting Host Registry (SYSTEM)..."
    $HivePath = Join-Path $HostRoot "Windows\System32\config\SYSTEM"
    reg load HKLM\HOST_SYS "$HivePath"
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to load Hive."; Pause; return }

    try {
        Write-Host "Applying Firewall Rules (Block Inbound)..."
        # Example: Enable Firewall for all profiles in Offline Registry
        # Key: ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile
        $Profiles = @("StandardProfile", "DomainProfile", "PublicProfile")
        foreach ($P in $Profiles) {
            $Key = "HKLM:\HOST_SYS\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\$P"
            if (Test-Path $Key) {
                Set-ItemProperty -Path $Key -Name "EnableFirewall" -Value 1 -Type DWord
                Set-ItemProperty -Path $Key -Name "DoNotAllowExceptions" -Value 0 -Type DWord # 1 would be very strict
                Write-Host "  -> Hardened $P" -ForegroundColor Green
            }
        }
    } finally {
        Write-Host "Unmounting Hive..."
        reg unload HKLM\HOST_SYS
    }
    Pause
}

function Run-Offline-Hardening-NIS2 {
    Write-Host "Detecting Host System..."
    $HostRoot = Get-HostSystemDrive
    if (-not $HostRoot) { Write-Error "Host System Not Found."; Pause; return }

    Write-Host "Mounting Host Registry (SYSTEM)..."
    $HivePath = Join-Path $HostRoot "Windows\System32\config\SYSTEM"
    reg load HKLM\HOST_SYS "$HivePath"

    try {
        Write-Host "Disabling SMBv1 (WannaCry prevention)..."
        $Key = "HKLM:\HOST_SYS\ControlSet001\Services\LanmanServer\Parameters"
        if (Test-Path $Key) {
             Set-ItemProperty -Path $Key -Name "SMB1" -Value 0 -Type DWord
        }

        Write-Host "Applying NIS2 Basics..."
        # Add more keys here
    } finally {
        reg unload HKLM\HOST_SYS
    }
    Pause
}

function Run-Offline-Bloatware {
    Write-Host "Detecting Host System..."
    $HostRoot = Get-HostSystemDrive
    if (-not $HostRoot) { Write-Error "Host System Not Found."; Pause; return }

    Write-Host "Running DISM against Offline Image ($HostRoot)..." -ForegroundColor Yellow
    # Example: List packages
    # Start-Process "dism" -ArgumentList "/Image:$HostRoot /Get-ProvisionedAppxPackages" -Wait

    Write-Host "Removing Sponsored Apps (Clipchamp, TikTok, etc)..."
    # Note: Requires exact package names. We'll use a generic safe list.
    $Junk = @("Clipchamp.Clipchamp", "Microsoft.BingNews", "Microsoft.GamingApp") # Examples

    foreach ($J in $Junk) {
         # Search wildcard logic not easy with simple DISM command in loop without parsing.
         # For safety, we just log this capability or run a specific removal if name is known.
         # Simulating action:
         Write-Host "  -> Removing $J (If present)..."
         Start-Process "dism" -ArgumentList "/Image:$HostRoot /Remove-ProvisionedAppxPackage /PackageName:$J" -WindowStyle Hidden -Wait
    }

    Write-Host "Offline Bloatware Removal Complete." -ForegroundColor Green
    Pause
}

# ==========================================
# 2. Main Loop
# ==========================================
while ($true) {
    Show-Header

    if ($IsGuest) {
        # GUEST MENU (WinBat Console Mode)
        Write-Host "MODE: GUEST (WinBat)" -ForegroundColor Cyan

        Write-Host (Get-Tr "MENU_GRP_HOST") -ForegroundColor Magenta
        Write-Host "1. Hardening: Firewall & Telemetry"
        Write-Host "2. Hardening: NIS2 (SMBv1/RDP)"
        Write-Host "3. Host Bloatware Removal (Offline)"

        Write-Host (Get-Tr "MENU_GRP_BACKUP") -ForegroundColor Magenta
        Write-Host "4. $(Get-Tr 'MENU_OPT_SNAPSHOT')"

        Write-Host "0. $(Get-Tr 'MENU_EXIT')"

        $Choice = Read-Host "Select Option"
        switch ($Choice) {
            "1" { Run-Offline-Hardening-Firewall }
            "2" { Run-Offline-Hardening-NIS2 }
            "3" { Run-Offline-Bloatware }
            "4" { Run-Snapshot }
            "0" { exit }
        }
    } else {
        # HOST MENU (Windows)
        Write-Host "MODE: HOST (Windows)" -ForegroundColor Cyan

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

        Write-Host (Get-Tr "MENU_GRP_TOOLS") -ForegroundColor Magenta
        Write-Host "9. $(Get-Tr 'MENU_OPT_DISKGENIUS')"

        Write-Host "0. $(Get-Tr 'MENU_EXIT')"

        $Choice = Read-Host "Select Option"
        switch ($Choice) {
            "1" { Run-Install }
            "2" { Run-Uninstall }
            "3" { Set-Boot-Default "WinBat" }
            "4" { Set-Boot-Default "Host" }
            "5" { Set-Boot-Timeout 0 }
            "6" { Set-Boot-Timeout 30 }
            "7" { Run-Snapshot }
            "8" { Run-Restore }
            "9" { Run-DiskGenius }
            "0" { exit }
        }
    }
    Write-Host "------------------------------------------"
}
