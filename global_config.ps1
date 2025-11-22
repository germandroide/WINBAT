<#
    WinBat Suite (Universal Edition)
    Global Configuration File

    This file contains central variables used by all scripts in the WinBat Suite.
    It ensures consistency across Installer, Optimizer, and StorageManager modules.
#>

# ==========================================
# 1. Installation Path & Disk Configuration
# ==========================================
# Base path where VHDX files will be created (User selectable)
$Global:WB_InstallPath          = "C:\WinBat"
# Maximum dynamic size for the VHDX (in GB)
$Global:WB_VHDMaxSizeGB         = 100

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
$Global:WB_BootEntryName        = "WinBat Console Mode"
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
# $Global:WB_SecurityPIN          = "0000" # REMOVED: Storing plaintext PIN is insecure.
$Global:WB_SecureMount_PinLen   = 6
$Global:WB_ConfigPath           = "C:\WinBat\Config\config.json"
$Global:WB_PinHash              = $null

# Helper Functions for Security
function Set-WinBatPin {
    param (
        [string]$NewPin
    )

    # Hash the PIN
    $SHA256 = [System.Security.Cryptography.SHA256]::Create()
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($NewPin)
    $HashBytes = $SHA256.ComputeHash($Bytes)
    $HashString = [BitConverter]::ToString($HashBytes).Replace("-", "")

    # Load or Create Config
    if (Test-Path $Global:WB_ConfigPath) {
        $Config = Get-Content -Path $Global:WB_ConfigPath -Raw | ConvertFrom-Json
    } else {
        # Create Directory if needed
        $ConfigDir = Split-Path $Global:WB_ConfigPath
        if (-not (Test-Path $ConfigDir)) { New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null }
        $Config = [PSCustomObject]@{}
    }

    # Update PIN Hash
    $Config | Add-Member -Name "PinHash" -Value $HashString -MemberType NoteProperty -Force

    # Save Config
    $Config | ConvertTo-Json | Set-Content -Path $Global:WB_ConfigPath

    $Global:WB_PinHash = $HashString
}

function Test-WinBatPin {
    param (
        [string]$InputPin
    )

    # 1. Load Hash from Config if not in memory
    if (-not $Global:WB_PinHash) {
        if (Test-Path $Global:WB_ConfigPath) {
            try {
                $Config = Get-Content -Path $Global:WB_ConfigPath -Raw | ConvertFrom-Json
                if ($Config.PinHash) {
                    $Global:WB_PinHash = $Config.PinHash
                }
            } catch {
                Write-Warning "Failed to load config.json"
            }
        }
    }

    # If no PIN is set, assume default "0000" behavior or return false?
    # For backward compatibility/first run, we might default to a hash of "0000"
    if (-not $Global:WB_PinHash) {
        # Hash of "0000"
        $DefaultHash = "9AF15B336E6A9619928537DF30B2E6A2376569FCF9D7E773ECCEDE65606529A0"
        $Global:WB_PinHash = $DefaultHash
    }

    # 2. Hash Input
    $SHA256 = [System.Security.Cryptography.SHA256]::Create()
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputPin)
    $HashBytes = $SHA256.ComputeHash($Bytes)
    $HashString = [BitConverter]::ToString($HashBytes).Replace("-", "")

    # 3. Compare
    return ($HashString -eq $Global:WB_PinHash)
}

# ==========================================
# 6. Resources
# ==========================================
$Global:WB_ResourcePath         = "$PSScriptRoot\Resources"

# ==========================================
# 7. Localization (i18n)
# ==========================================
$Global:WB_CurrentLanguage = "en-US"
$Global:WB_LangDict = @{}

function Load-WinBatLanguage {
    <#
    .SYNOPSIS
        Detects system language and loads the appropriate JSON translation file.
    .DESCRIPTION
        This function checks the current UI culture of the host system.
        It attempts to load the corresponding JSON file from Resources/Languages.
        If the specific language (e.g., es-ES) is not found, it falls back to en-US.
    #>

    # Detect system language
    $SystemCulture = Get-UICulture
    $LangCode = $SystemCulture.Name # e.g., "en-US", "es-ES"

    $LangFile = Join-Path -Path $Global:WB_ResourcePath -ChildPath "Languages\$LangCode.json"

    # Fallback to en-US if file doesn't exist
    if (-not (Test-Path -Path $LangFile)) {
        Write-Warning "Language '$LangCode' not supported. Falling back to 'en-US'."
        $LangCode = "en-US"
        $LangFile = Join-Path -Path $Global:WB_ResourcePath -ChildPath "Languages\en-US.json"
    }

    if (Test-Path -Path $LangFile) {
        try {
            # Use UTF-8 Explicitly
            $JsonContent = Get-Content -Path $LangFile -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json

            # Convert PSCustomObject to Hashtable for easier lookup
            $Global:WB_LangDict = @{}
            $JsonContent.PSObject.Properties | ForEach-Object {
                $Global:WB_LangDict[$_.Name] = $_.Value
            }

            $Global:WB_CurrentLanguage = $LangCode
        }
        catch {
            Write-Error "Failed to load language file: $LangFile. Error: $_"
            # Emergency Fallback if JSON is corrupt
            if ($LangCode -ne "en-US") {
               Write-Warning "Attempting emergency fallback to en-US."
               Load-WinBatLanguage # This might cause recursion loop if en-US is also bad, but usually safe
            }
        }
    }
    else {
        Write-Error "Critical: Default language file 'en-US.json' not found at $LangFile."
    }
}

function Get-Tr {
    <#
    .SYNOPSIS
        Gets the translation for a specific key.
    .PARAMETER Key
        The key to look up in the translation dictionary.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Key
    )

    if ($Global:WB_LangDict.ContainsKey($Key)) {
        return $Global:WB_LangDict[$Key]
    }
    else {
        return "[$Key]" # Return key in brackets if translation missing
    }
}

# Initialize Language on Load
Load-WinBatLanguage
