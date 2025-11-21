<#
    Test Script for WinBat Suite Localization
    Verifies that the correct language file is loaded and Get-Tr works.
#>

# Determine script path to correctly load global_config
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) {
    Write-Error "global_config.ps1 not found at $GlobalConfigPath"
    exit 1
}

# Import Global Config (This triggers Load-WinBatLanguage)
. $GlobalConfigPath

Write-Host "--------------------------------------------------"
Write-Host "WinBat Suite - Localization Test"
Write-Host "--------------------------------------------------"
Write-Host "Detected System Language: $(Get-UICulture).Name"
Write-Host "Loaded Language: $Global:WB_CurrentLanguage"
Write-Host "--------------------------------------------------"

# Test Translation Keys
$KeysToTest = @("SETUP_WELCOME", "SETUP_NO_PARTITION", "BTN_NEXT", "NON_EXISTENT_KEY")

foreach ($Key in $KeysToTest) {
    $TranslatedValue = Get-Tr -Key $Key
    Write-Host "Key: $Key`t-> Value: $TranslatedValue"
}

Write-Host "--------------------------------------------------"
