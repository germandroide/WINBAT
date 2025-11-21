<#
    WinBat Suite - Installer Script
    Install-WinBat.ps1

    This script creates the WinBat environment:
    1. Creates VHDX files (Base and Child) in a user-specified folder.
    2. Clones the current Host OS into the Base VHDX (excluding junk).
    3. Configures Native Boot.

    Usage:
    Run as Administrator.
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

# Function to clean up in case of failure
function Cleanup-Install {
    param (
        [string]$InstallPath,
        [string]$MountPath
    )
    Write-Warning "Cleaning up..."

    # Dismount VHDX if mounted
    if ($MountPath) {
        Dismount-DiskImage -ImagePath (Join-Path $InstallPath $Global:WB_VHDXName_Base) -ErrorAction SilentlyContinue
    }

    # Delete VHDX files
    if ($InstallPath) {
        Remove-Item -Path (Join-Path $InstallPath $Global:WB_VHDXName_Base) -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $InstallPath $Global:WB_VHDXName_Child) -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $InstallPath "WimScript.ini") -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $InstallPath "temp_capture.wim") -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host (Get-Tr "INSTALL_STARTING") -ForegroundColor Green

    # ==========================================
    # 1. Check Admin Privileges
    # ==========================================
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error (Get-Tr "INSTALL_ADMIN_REQ")
        exit 1
    }

    # ==========================================
    # 2. Select Installation Path
    # ==========================================
    Write-Host (Get-Tr "INSTALL_SELECT_PATH")
    $InputPath = Read-Host
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        $InstallPath = $Global:WB_InstallPath # Default from config
    } else {
        $InstallPath = $InputPath
    }

    # Ensure path exists
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    # ==========================================
    # 3. Check Free Space
    # ==========================================
    Write-Host (Get-Tr "INSTALL_SPACE_CHECK")
    $Drive = Get-PSDrive -Name (Split-Path $InstallPath -Qualifier).Trim(":")
    $FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)

    if ($FreeSpaceGB -lt 60) {
        Write-Error (Get-Tr "INSTALL_SPACE_FAIL")
        exit 1
    }
    Write-Host (Get-Tr "INSTALL_SPACE_OK") -ForegroundColor Cyan

    # ==========================================
    # 4. Create Exclusion List (WimScript.ini)
    # ==========================================

    # Dynamically calculate path relative to drive root for exclusion
    $InstallDrive = (Split-Path $InstallPath -Qualifier)
    $SystemDrive = (Get-Item env:SystemDrive).Value

    $ExcludedPaths = @(
        "\System Volume Information",
        "\`$Recycle.Bin",
        "\pagefile.sys",
        "\swapfile.sys",
        "\hiberfil.sys",
        "\Windows\SoftwareDistribution"
    )

    # If installing on the same drive as System (Host), exclude the install folder
    if ($InstallDrive -eq $SystemDrive) {
        $RelativeInstallPath = (Split-Path $InstallPath -NoQualifier)
        if (-not $RelativeInstallPath.StartsWith("\")) { $RelativeInstallPath = "\$RelativeInstallPath" }
        $ExcludedPaths += $RelativeInstallPath
    }

    # Construct Exclusion List String
    $WimScriptContent = "[ExclusionList]`r`n" + ($ExcludedPaths -join "`r`n")

    $WimScriptPath = Join-Path -Path $InstallPath -ChildPath "WimScript.ini"
    Set-Content -Path $WimScriptPath -Value $WimScriptContent

    # ==========================================
    # 5. Create & Mount Base VHDX
    # ==========================================
    Write-Host (Get-Tr "INSTALL_CREATE_BASE")
    $BaseVHDXPath = Join-Path -Path $InstallPath -ChildPath $Global:WB_VHDXName_Base

    # Create Dynamic VHDX
    New-VHD -Path $BaseVHDXPath -SizeBytes ($Global:WB_VHDMaxSizeGB * 1GB) -Dynamic -ErrorAction Stop | Out-Null

    # Mount VHDX
    $MountedDisk = Mount-VHD -Path $BaseVHDXPath -Passthru
    $DiskNumber = $MountedDisk.DiskNumber

    # Initialize & Format
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -PassThru | Out-Null
    $Partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition $Partition -FileSystem NTFS -NewFileSystemLabel "WinBat_Base" -Confirm:$false -Force | Out-Null

    $TargetDriveLetter = "$($Partition.DriveLetter):"

    # ==========================================
    # 6. Clone System (Capture & Apply)
    # ==========================================
    Write-Host (Get-Tr "INSTALL_CLONE_START")

    # We use a temporary WIM capture approach for better reliability with exclusions
    $TempWimPath = Join-Path -Path $InstallPath -ChildPath "temp_capture.wim"

    # Capture Host C: to Temp WIM
    # /ConfigFile specifies exclusions
    $DismArgsCapture = "/Capture-Image /ImageFile:`"$TempWimPath`" /CaptureDir:C:\ /Name:`"WinBatBase`" /ConfigFile:`"$WimScriptPath`" /Compress:fast"
    Start-Process -FilePath "dism.exe" -ArgumentList $DismArgsCapture -Wait -NoNewWindow -PassThru | ForEach-Object {
        if ($_.ExitCode -ne 0) { throw (Get-Tr "ERR_DISM_FAIL") }
    }

    Write-Host (Get-Tr "INSTALL_CLONE_PROGRESS")

    # Apply WIM to VHDX
    $DismArgsApply = "/Apply-Image /ImageFile:`"$TempWimPath`" /Index:1 /ApplyDir:$TargetDriveLetter"
    Start-Process -FilePath "dism.exe" -ArgumentList $DismArgsApply -Wait -NoNewWindow -PassThru | ForEach-Object {
        if ($_.ExitCode -ne 0) { throw (Get-Tr "ERR_DISM_FAIL") }
    }

    Write-Host (Get-Tr "INSTALL_CLONE_DONE") -ForegroundColor Green

    # ==========================================
    # 7. Make Bootable & Setup Flags
    # ==========================================
    Write-Host (Get-Tr "INSTALL_MAKE_BOOTABLE")

    # bcdboot to make the VHDX bootable (inside itself mostly, but important for structure)
    # Actually, we need to ensure the VHDX has boot files. bcdboot C:\Windows /s V:\ /f ALL
    Start-Process -FilePath "bcdboot.exe" -ArgumentList "$TargetDriveLetter\Windows /s $TargetDriveLetter /f ALL" -Wait -NoNewWindow

    # Create Setup Flag
    New-Item -Path (Join-Path $TargetDriveLetter "WinBat_Setup_Pending.flag") -ItemType File -Force | Out-Null

    # ==========================================
    # 7b. Inject Optimizer Script & RunOnce
    # ==========================================
    Write-Host (Get-Tr "INSTALL_INJECT_OPTIMIZER")

    # Create Directory in VHDX
    $VHDXOptDir = Join-Path $TargetDriveLetter "WinBat\Optimizer"
    New-Item -Path $VHDXOptDir -ItemType Directory -Force | Out-Null

    # Copy Optimizer Scripts & Config
    # We need global_config.ps1 and Optimizer/WinBat_FirstBoot.ps1 AND language resources
    $SourceOpt = Join-Path $ScriptPath "..\Optimizer\WinBat_FirstBoot.ps1"
    $SourceConfig = Join-Path $ScriptPath "..\global_config.ps1"
    $SourceResources = Join-Path $ScriptPath "..\Resources"

    Copy-Item -Path $SourceOpt -Destination $VHDXOptDir -Force
    Copy-Item -Path $SourceConfig -Destination (Join-Path $TargetDriveLetter "WinBat\global_config.ps1") -Force
    Copy-Item -Path $SourceResources -Destination (Join-Path $TargetDriveLetter "WinBat\Resources") -Recurse -Force

    # Copy Storage Manager
    $SourceStorage = Join-Path $ScriptPath "..\StorageManager"
    $DestStorage = Join-Path $TargetDriveLetter "WinBat\StorageManager"
    Copy-Item -Path $SourceStorage -Destination $DestStorage -Recurse -Force

    # Copy OOBE (Wizard)
    $SourceOOBE = Join-Path $ScriptPath "..\OOBE"
    $DestOOBE = Join-Path $TargetDriveLetter "WinBat\OOBE"
    Copy-Item -Path $SourceOOBE -Destination $DestOOBE -Recurse -Force

    # Setup RetroBat (Mock/Download)
    Write-Host "Setting up RetroBat..."
    $RetroBatDir = Join-Path $TargetDriveLetter "RetroBat"
    if (-not (Test-Path $RetroBatDir)) { New-Item -Path $RetroBatDir -ItemType Directory -Force | Out-Null }

    # Create ROM folders structure based on templates
    $RomsDir = Join-Path $RetroBatDir "roms"
    $Folders = @("vod", "cloud", "multimedia", "windows", "apps")
    foreach ($F in $Folders) {
        $P = Join-Path $RomsDir $F
        if (-not (Test-Path $P)) { New-Item -Path $P -ItemType Directory -Force | Out-Null }
    }

    # Copy System Template if exists
    $SysTemplate = Join-Path $ScriptPath "..\Resources\es_systems_template.xml"
    # In a real scenario, this would be merged into es_systems.cfg inside .emulationstation
    # For now, we place it there for manual reference or future automation
    Copy-Item -Path $SysTemplate -Destination (Join-Path $RetroBatDir "es_systems_winbat.xml") -Force

    # Inject RunOnce via Registry
    # Mount Guest SYSTEM Hive
    $GuestSystemHive = Join-Path $TargetDriveLetter "Windows\System32\config\SYSTEM"
    $GuestSoftwareHive = Join-Path $TargetDriveLetter "Windows\System32\config\SOFTWARE"

    # We use reg.exe to load hive
    reg load HKLM\WB_GUEST_SOFT "$GuestSoftwareHive"

    # Add RunOnce Key
    # Command: PowerShell.exe -ExecutionPolicy Bypass -File "C:\WinBat\Optimizer\WinBat_FirstBoot.ps1"
    $RunCmd = "PowerShell.exe -ExecutionPolicy Bypass -File `"C:\WinBat\Optimizer\WinBat_FirstBoot.ps1`""
    reg add "HKLM\WB_GUEST_SOFT\Microsoft\Windows\CurrentVersion\RunOnce" /v "WinBatOptimizer" /t REG_SZ /d $RunCmd /f

    # Unload Hive
    reg unload HKLM\WB_GUEST_SOFT

    # ==========================================
    # 8. Finalize Base & Create Child
    # ==========================================
    # Dismount Base
    Dismount-VHD -Path $BaseVHDXPath

    # Cleanup Temp WIM
    Remove-Item -Path $TempWimPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $WimScriptPath -Force -ErrorAction SilentlyContinue

    Write-Host (Get-Tr "INSTALL_CREATE_CHILD")
    $ChildVHDXPath = Join-Path -Path $InstallPath -ChildPath $Global:WB_VHDXName_Child
    New-VHD -ParentPath $BaseVHDXPath -Path $ChildVHDXPath -Differencing -ErrorAction Stop | Out-Null

    # ==========================================
    # 9. Add Boot Entry
    # ==========================================
    Write-Host (Get-Tr "INSTALL_ADD_BOOT_ENTRY")

    # Use bcdedit to add entry for the CHILD VHDX
    # 1. Copy current entry
    $BcdOutput = bcdedit /copy "{current}" /d "WinBat Console Mode"
    # Extract GUID (roughly)
    if ($BcdOutput -match '{([0-9a-fA-F-]+)}') {
        $Guid = $matches[0]

        # 2. Set device and osdevice to the VHDX
        # The syntax for native boot is file=[path]filename.vhdx
        # BUT, bcdedit expects [locate]\path\to.vhdx usually.
        # For VHDX boot, typically: device=vhd=[C:]\WinBat\Child.vhdx

        # Get drive letter of InstallPath
        $HostDrive = (Split-Path $InstallPath -Qualifier)
        $RelPath = (Split-Path $InstallPath -NoQualifier)
        $VhdBcdPath = "[$HostDrive]$RelPath\$Global:WB_VHDXName_Child"

        bcdedit /set $Guid device "vhd=$VhdBcdPath"
        bcdedit /set $Guid osdevice "vhd=$VhdBcdPath"

        # 3. Enable hypervisor (usually good for VHDX boot) and detecthal
        bcdedit /set $Guid detecthal on
    } else {
        Write-Warning "Could not parse BCD GUID. You may need to add the boot entry manually."
    }

    Write-Host (Get-Tr "INSTALL_COMPLETE") -ForegroundColor Green

} catch {
    Write-Error ((Get-Tr "ERR_GENERIC") + $_.Exception.Message)
    Cleanup-Install -InstallPath $InstallPath -MountPath $TargetDriveLetter
    exit 1
}
