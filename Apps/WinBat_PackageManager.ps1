<#
    WinBat Package Manager
    Apps/WinBat_PackageManager.ps1

    Handles creation, build, and import of .wbpack community packages.
#>

# ==========================================
# 0. Initialize Environment
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "..\global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) {
    Write-Error "Critical: global_config.ps1 not found."
    exit 1
}

. $GlobalConfigPath

# Ensure Admin (Needed for Import usually)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Package Manager works best as Administrator."
}

# Load Assemblies for ZIP
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ==========================================
# 1. Functions
# ==========================================

function Create-Dev-Kit {
    Clear-Host
    Write-Host (Get-Tr "PKG_DEV_INTRO") -ForegroundColor Cyan
    $PackName = Read-Host "Enter Package Name (No spaces recommended)"

    if ([string]::IsNullOrWhiteSpace($PackName)) { return }

    $Desktop = [Environment]::GetFolderPath("Desktop")
    $DevFolder = Join-Path $Desktop "${PackName}_DevKit"

    if (Test-Path $DevFolder) {
        Write-Warning "Folder already exists on Desktop."
        Pause
        return
    }

    # Create Structure
    New-Item -Path $DevFolder -ItemType Directory | Out-Null
    New-Item -Path (Join-Path $DevFolder "assets") -ItemType Directory | Out-Null
    New-Item -Path (Join-Path $DevFolder "configs") -ItemType Directory | Out-Null
    New-Item -Path (Join-Path $DevFolder "roms_placeholder") -ItemType Directory | Out-Null

    # Create Manifest Template
    $Manifest = @{
        id = "winbat.community.$(($PackName).ToLower())"
        name = $PackName
        version = "1.0.0"
        author = "YourName"
        description = "Description of your pack."
        dependencies = @("retrobat")
    }
    $Manifest | ConvertTo-Json -Depth 2 | Set-Content -Path (Join-Path $DevFolder "manifest.json")

    # Copy Guide & Example
    $TemplateDir = Join-Path $Global:WB_ResourcePath "Templates"
    if (Test-Path $TemplateDir) {
        Copy-Item -Path (Join-Path $TemplateDir "Guide_Pack_Creation.md") -Destination $DevFolder
        Copy-Item -Path (Join-Path $TemplateDir "Example_Amiga_setup.ps1") -Destination (Join-Path $DevFolder "setup_example.ps1")
    }

    # Create Empty Setup
    Set-Content -Path (Join-Path $DevFolder "setup.ps1") -Value "# WinBat Pack Setup Script`r`nWrite-Host 'Installing $PackName...'"

    Write-Host "Dev Kit created at: $DevFolder" -ForegroundColor Green
    Invoke-Item $DevFolder
    Pause
}

function Build-Pack {
    Clear-Host
    Write-Host (Get-Tr "PKG_BTN_BUILD") -ForegroundColor Cyan

    # Select Folder
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select Dev Kit Folder"

    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourceDir = $FolderBrowser.SelectedPath

        # Validate
        if (-not (Test-Path (Join-Path $SourceDir "manifest.json"))) {
            Write-Error (Get-Tr "PKG_MANIFEST_ERR")
            Pause
            return
        }

        $PackName = Split-Path $SourceDir -Leaf
        $DestFile = Join-Path $SourceDir "..\$PackName.wbpack"

        if (Test-Path $DestFile) { Remove-Item $DestFile -Force }

        Write-Host "Compressing..."
        [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDir, $DestFile)

        Write-Host "Package Built: $DestFile" -ForegroundColor Green
    }
    Pause
}

function Import-Pack {
    Clear-Host
    Write-Host (Get-Tr "PKG_BTN_IMPORT") -ForegroundColor Cyan

    # Select File
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.Filter = "WinBat Packages (*.wbpack)|*.wbpack"

    if ($FileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $PackFile = $FileBrowser.FileName

        # Temp Extract
        $TempDir = Join-Path $Env:TEMP "WinBat_Import_$(Get-Random)"
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

        try {
            Write-Host "Extracting..."
            [System.IO.Compression.ZipFile]::ExtractToDirectory($PackFile, $TempDir)

            # Validate Manifest
            $ManifestPath = Join-Path $TempDir "manifest.json"
            if (-not (Test-Path $ManifestPath)) {
                throw (Get-Tr "PKG_MANIFEST_ERR")
            }

            $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
            Write-Host "Installing: $($Manifest.name) v$($Manifest.version) by $($Manifest.author)" -ForegroundColor Yellow

            # Run Setup
            $SetupScript = Join-Path $TempDir "setup.ps1"
            if (Test-Path $SetupScript) {
                Write-Host "Running Setup Script..."
                # Pass RetroBat Path from Global Config to ensure correct target (Host vs Guest pathing)
                # We use environment variable injection for the process.
                # Host: $Global:WB_InstallPath\Data\RetroBat
                # Guest: C:\RetroBat

                # Logic: This script runs on Host. So we target Host Path.
                $HostRetroBat = Join-Path $Global:WB_InstallPath "Data\RetroBat"

                $Env:WB_RETROBAT_PATH = $HostRetroBat

                # Note: Start-Process starts a NEW environment block by default unless UseNewEnvironment is used/managed.
                # But PowerShell.exe inherits current environment.
                # So setting $Env:WB_RETROBAT_PATH here should be visible to the child process.

                $Proc = Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$SetupScript`"" -PassThru -Wait
                if ($Proc.ExitCode -ne 0) {
                    Write-Warning "Setup script finished with errors."
                }

                # Clean up env var
                $Env:WB_RETROBAT_PATH = $null
            }

            # Copy Assets (Generic Logic)
            # If assets folder exists, ask where to put it?
            # Usually packs are specific. For now, just Log.
            if (Test-Path (Join-Path $TempDir "assets")) {
                Write-Host "Assets found. Manual copy might be required if setup.ps1 didn't handle it." -ForegroundColor Gray
            }

            Write-Host (Get-Tr "PKG_SUCCESS_IMPORT") -ForegroundColor Green

        } catch {
            Write-Error "Import Failed: $_"
        } finally {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Pause
}

# ==========================================
# 2. Menu
# ==========================================
while ($true) {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ("   " + (Get-Tr "PKG_TITLE")) -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "1. $(Get-Tr 'PKG_BTN_IMPORT')"
    Write-Host "2. $(Get-Tr 'PKG_BTN_CREATE')"
    Write-Host "3. $(Get-Tr 'PKG_BTN_BUILD')"
    Write-Host "0. $(Get-Tr 'MENU_EXIT')"
    Write-Host ""

    $Choice = Read-Host "Select Option"

    switch ($Choice) {
        "1" { Import-Pack }
        "2" { Create-Dev-Kit }
        "3" { Build-Pack }
        "0" { exit }
    }
}
