<#
    WinBat Suite - Optimizer Script
    WinBat_FirstBoot.ps1

    This script runs ONCE inside the WinBat Console Mode environment.
    It transforms the standard Windows installation into a Gaming Console OS.

    Triggers:
    - Presence of C:\WinBat_Setup_Pending.flag

    Actions:
    1. Security/Isolation: Hides Host drives.
    2. Optimization: Disables services, sets Power Plan.
    3. Debloat: Removes Appx packages.
    4. Shell: Sets Custom Shell (RetroBat).
    5. Cleanup: Removes flag and restarts.
#>

# ==========================================
# 0. Initialize Environment
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "..\global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) {
    Write-Error "Critical: global_config.ps1 not found at $GlobalConfigPath"
    exit 1
}

. $GlobalConfigPath

# Check for Setup Flag
$FlagPath = "C:\WinBat_Setup_Pending.flag"
if (-not (Test-Path $FlagPath)) {
    Write-Warning "Setup flag not found. Optimization skipped."
    exit 0
}

# Backup Directory
$BackupDir = "C:\WinBat_Backups"
New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null

try {
    Write-Host (Get-Tr "OPT_STARTING") -ForegroundColor Green

    # ==========================================
    # 1. System Restore Point
    # ==========================================
    Write-Host (Get-Tr "OPT_RESTORE_POINT")
    # Enable System Restore on C: if disabled
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "Pre-WinBat-Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue

    # ==========================================
    # 2. Host Isolation (Hide Drives)
    # ==========================================
    Write-Host (Get-Tr "OPT_ISOLATING_DRIVES")

    # Logic: Get all partitions. If they are NOT the Boot partition or the Current System partition (C:), remove drive letter.
    # Note: In VHD Native Boot, C: is the VHD. Physical drives are visible.

    $SystemPart = Get-Partition | Where-Object { $_.DriveLetter -eq "C" }
    $BootPart = Get-Partition | Where-Object { $_.IsBoot -eq $true }

    $AllPartitions = Get-Partition | Where-Object { $_.DriveLetter -ne $null }

    foreach ($Part in $AllPartitions) {
        # Skip C: (Current System)
        if ($Part.DriveLetter -eq "C") { continue }

        # Skip EFI/Boot partition (if visible)
        if ($Part.IsBoot -eq $true) { continue }

        # Remove Drive Letter
        Write-Host ($Global:WB_LangDict["OPT_HIDING_DRIVE"] -f $Part.DriveLetter) -ForegroundColor Gray
        Remove-PartitionAccessPath -DiskNumber $Part.DiskNumber -PartitionNumber $Part.PartitionNumber -AccessPath "$($Part.DriveLetter):" -ErrorAction SilentlyContinue
    }

    # ==========================================
    # 3. Services Optimization
    # ==========================================
    Write-Host (Get-Tr "OPT_SERVICES")

    $ServicesToDisable = @("DiagTrack", "SysMain", "MapsBroker", "lfsvc", "WerSvc")
    $ServicesToManual = @("wuauserv")

    foreach ($Svc in $ServicesToDisable) {
        if (Get-Service -Name $Svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    foreach ($Svc in $ServicesToManual) {
        if (Get-Service -Name $Svc -ErrorAction SilentlyContinue) {
            Set-Service -Name $Svc -StartupType Manual -ErrorAction SilentlyContinue
        }
    }

    # Xbox & Store Services are Critical - Ensure they are Running/Manual/Auto as needed default
    # (No action needed usually, just don't disable them)

    # ==========================================
    # 4. Power Plan
    # ==========================================
    Write-Host (Get-Tr "OPT_POWER")

    # Duplicate Ultimate Performance scheme if not exists
    $UltimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $CurrentSchemes = powercfg /list

    if ($CurrentSchemes -notmatch $UltimateGuid) {
        powercfg -duplicatescheme $UltimateGuid | Out-Null
    }
    powercfg -setactive $UltimateGuid

    # Disable USB Selective Suspend
    # GUID: 2a737441-1930-4402-8d77-b2beb156f125 -> 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 (USB Settings -> Suspend)
    # 0 = Disabled, 1 = Enabled
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2beb156f125 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2beb156f125 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /setactive SCHEME_CURRENT

    # ==========================================
    # 5. Windows Defender Exclusions
    # ==========================================
    Write-Host (Get-Tr "OPT_DEFENDER")

    $Exclusions = @("C:\Games", "D:\Games", "C:\RetroBat", "C:\WinBat")
    foreach ($Path in $Exclusions) {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force | Out-Null }
        Add-MpPreference -ExclusionPath $Path -ErrorAction SilentlyContinue
    }

    # ==========================================
    # 6. Debloat
    # ==========================================
    Write-Host (Get-Tr "OPT_DEBLOAT")

    $AppxToRemove = @(
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.GetHelp",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.OfficeHub",
        "Microsoft.SkypeApp",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )

    foreach ($App in $AppxToRemove) {
        Get-AppxPackage -Name $App -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    }

    # ==========================================
    # 7. Shell Replacement & User Setup
    # ==========================================

    # 7a. Create AdminRescue User
    Write-Host (Get-Tr "OPT_SHELL_USER")
    $RescueUser = "AdminRescue"
    $RescuePass = "WinBatRescue123!" # Should be changed by user ideally

    # SecureString conversion
    $SecurePass = ConvertTo-SecureString $RescuePass -AsPlainText -Force

    # Create user if not exists
    if (-not (Get-LocalUser -Name $RescueUser -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $RescueUser -Password $SecurePass -Description "Emergency Admin with Standard Explorer Shell" | Out-Null
        Add-LocalGroupMember -Group "Administrators" -Member $RescueUser | Out-Null
    }

    # 7b. Setup RetroBat Placeholder
    $RetroBatPath = "C:\RetroBat"
    $RetroBatExe = Join-Path $RetroBatPath "retrobat.exe"

    if (-not (Test-Path $RetroBatExe)) {
        New-Item -Path $RetroBatPath -ItemType Directory -Force | Out-Null
        # Create a dummy exe for testing if real one is missing
        # In production, this might download/install RetroBat
        Set-Content -Path $RetroBatExe -Value "Placeholder"
    }

    # 7c. Change Shell (Registry)
    Write-Host (Get-Tr "OPT_SHELL_CHANGE")

    $ShellKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"

    # Backup Registry
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" "$BackupDir\Shell_Backup.reg" /y | Out-Null

    if (-not (Test-Path $ShellKey)) {
        New-Item -Path $ShellKey -Force | Out-Null
    }

    Set-ItemProperty -Path $ShellKey -Name "Shell" -Value $RetroBatExe -Type String

    # 7d. Persistence for Mount Service
    # Add WinBat_MountService.ps1 to User Run key so it runs when shell starts
    $MountServicePath = "C:\WinBat\StorageManager\WinBat_MountService.ps1"
    $RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $MountServicePath) {
        Set-ItemProperty -Path $RunKey -Name "WinBatMounts" -Value "PowerShell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$MountServicePath`""
    }

    # ==========================================
    # 8. Finalize
    # ==========================================
    Write-Host (Get-Tr "OPT_COMPLETE") -ForegroundColor Green

    # Remove Flag
    Remove-Item -Path $FlagPath -Force -ErrorAction SilentlyContinue

    Write-Host (Get-Tr "OPT_RESTARTING")
    Start-Sleep -Seconds 5
    Restart-Computer -Force

} catch {
    Write-Error ((Get-Tr "ERR_GENERIC") + $_.Exception.Message)
    # Do not remove flag so script runs again on next boot to retry
    exit 1
}
