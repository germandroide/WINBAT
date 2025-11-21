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
$Global:WB_SecurityPIN          = "0000" # User configurable PIN
$Global:WB_SecureMount_PinLen   = 6

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

    # Check for exact match, if not, check for parent culture (e.g. es-MX -> es-ES)
    if (-not (Test-Path -Path $LangFile)) {
        # Try parent culture (e.g. 'es' from 'es-MX')
        $ParentCode = $SystemCulture.Parent.Name
        $ParentFile = Join-Path -Path $Global:WB_ResourcePath -ChildPath "Languages\$ParentCode.json"

        # Special case mappings if simple parent doesn't work or specific mapping desired
        # For WinBat we have specific files like es-ES, pt-PT, pt-BR.
        # If user is pt-AO (Angola), Parent is pt. We might want to map pt -> pt-PT or pt-BR?
        # For simplicity, let's try to find ANY file starting with the parent code if specific parent doesn't exist.

        # Logic:
        # 1. Exact Match (handled above)
        # 2. Fallback to standard regional variants if available (e.g. fr-CA -> fr-FR)

        $FallbackMap = @{
            "fr" = "fr-FR"
            "de" = "de-DE"
            "it" = "it-IT"
            "es" = "es-ES"
            "pt" = "pt-PT" # Default to PT-PT, unless pt-BR is specific
            "ru" = "ru-RU"
            "zh" = "zh-CN"
            "ja" = "ja-JP"
            "hi" = "hi-IN"
            "ko" = "ko-KR"
        }

        if ($FallbackMap.ContainsKey($ParentCode)) {
            $MappedCode = $FallbackMap[$ParentCode]
            $LangFile = Join-Path -Path $Global:WB_ResourcePath -ChildPath "Languages\$MappedCode.json"
        }
    }

    # Fallback to en-US if still not found
    if (-not (Test-Path -Path $LangFile)) {
        Write-Warning "Language '$LangCode' not supported. Falling back to 'en-US'."
        $LangCode = "en-US"
        $LangFile = Join-Path -Path $Global:WB_ResourcePath -ChildPath "Languages\en-US.json"
    }

    if (Test-Path -Path $LangFile) {
        try {
            $JsonContent = Get-Content -Path $LangFile -Raw -ErrorAction Stop | ConvertFrom-Json

            # Convert PSCustomObject to Hashtable for easier lookup
            $Global:WB_LangDict = @{}
            $JsonContent.PSObject.Properties | ForEach-Object {
                $Global:WB_LangDict[$_.Name] = $_.Value
            }

            $Global:WB_CurrentLanguage = $LangCode
        }
        catch {
            Write-Error "Failed to load language file: $LangFile. Error: $_"
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
