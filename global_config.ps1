<#
    WinBat Suite (Universal Edition)
    Global Configuration File

    This file contains central variables used by all scripts in the WinBat Suite.
    It ensures consistency across Installer, Optimizer, and StorageManager modules.
#>

# ==========================================
# 1. Partition & Disk Configuration
# ==========================================
# The label for the dedicated partition where VHDX files will reside
$Global:WB_PartitionLabel       = "GAMES_DATA"
# Preferred drive letter for the GAMES_DATA partition (if available)
$Global:WB_PartitionDriveLetter = "G"
# Default reserved size for the partition/VHDX (in GB)
$Global:WB_ReservedSizeGB       = 100

# ==========================================
# 2. VHDX Configuration
# ==========================================
# Parent (Base) VHDX - Immutable System Image
$Global:WB_VHDXName_Base        = "WinBat_Base.vhdx"
# Child (Differencing) VHDX - Where user changes/updates happen
$Global:WB_VHDXName_Child       = "WinBat_Child.vhdx"

# Full paths will be constructed dynamically in scripts based on the partition mount point
# but defaults can be defined here relative to the partition root.

# ==========================================
# 3. Boot Configuration
# ==========================================
$Global:WB_BootEntryName        = "Windows-G"
$Global:WB_HostBootEntryName    = "Windows Host"

# ==========================================
# 4. Optimization Flags & Registry Keys
# ==========================================
$Global:WB_Opt_Telemetry        = "Disabled"
$Global:WB_Opt_SysMain          = "Conditional" # Disabled on SSD, Enabled on HDD
$Global:WB_Opt_Defender         = "Optimized"   # ON with exclusions for ROMs/Games
$Global:WB_Opt_GameMode         = "Enabled"
$Global:WB_Opt_HAGS             = "Auto"        # Hardware Accelerated GPU Scheduling

# Registry Paths (Commonly used)
$Global:WB_RegPath_Policies     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
$Global:WB_RegPath_Defender     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"

# ==========================================
# 5. Storage Manager Configuration
# ==========================================
# Security settings for mounting sensitive host drives
$Global:WB_MFA_Enabled          = $true
$Global:WB_SecureMount_PinLen   = 6

# ==========================================
# 6. Resources
# ==========================================
$Global:WB_ResourcePath         = "$PSScriptRoot\Resources"
