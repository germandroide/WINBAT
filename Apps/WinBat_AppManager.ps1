<#
    WinBat Suite - App Manager
    WinBat_AppManager.ps1

    Unified tool for installing/managing Apps and Stores.
    Can run in OOBE mode (Wizard style) or Panel mode (Management).
#>

# ==========================================
# 0. Initialize
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "..\global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) { exit }
. $GlobalConfigPath

# Ensure Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "App Manager requires Admin."
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# 1. App Catalog
# ==========================================
# Check Logic: Simple file path check or Winget list (slow). Path is faster for UI.
$Apps = @(
    # Gaming
    @{ Name="Steam"; Id="Valve.Steam"; Category="Gaming"; CheckPath="C:\Program Files (x86)\Steam\steam.exe" },
    @{ Name="Epic Games"; Id="EpicGames.EpicGamesLauncher"; Category="Gaming"; CheckPath="C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe" },
    @{ Name="EA App"; Id="ElectronicArts.EADesktop"; Category="Gaming"; CheckPath="C:\Program Files\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe" },
    @{ Name="Ubisoft Connect"; Id="Ubisoft.Connect"; Category="Gaming"; CheckPath="C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\UbisoftGameLauncher.exe" },
    @{ Name="GOG Galaxy"; Id="GOG.Galaxy"; Category="Gaming"; CheckPath="C:\Program Files (x86)\GOG Galaxy\GalaxyClient.exe" },

    # VOD / Cloud (Web Apps)
    @{ Name="Xbox Cloud Gaming"; Type="Web"; Url="https://www.xbox.com/play"; Category="VOD" },
    @{ Name="GeForce Now"; Id="Nvidia.GeForceNow"; Category="VOD"; CheckPath="$env:LOCALAPPDATA\NVIDIA Corporation\GeForceNOW\CEF\GeForceNOW.exe" },
    @{ Name="Netflix"; Type="Web"; Url="https://www.netflix.com"; Category="VOD" },
    @{ Name="Disney+"; Type="Web"; Url="https://www.disneyplus.com"; Category="VOD" },
    @{ Name="YouTube"; Type="Web"; Url="https://www.youtube.com/tv"; Category="VOD" },
    @{ Name="Twitch"; Type="Web"; Url="https://www.twitch.tv"; Category="VOD" },

    # Tools
    @{ Name="Discord"; Id="Discord.Discord"; Category="Tools"; CheckPath="$env:LOCALAPPDATA\Discord\Update.exe" },
    @{ Name="Spotify"; Id="Spotify.Spotify"; Category="Tools"; CheckPath="$env:APPDATA\Spotify\Spotify.exe" },
    @{ Name="VLC"; Id="VideoLAN.VLC"; Category="Tools"; CheckPath="C:\Program Files\VideoLAN\VLC\vlc.exe" },
    @{ Name="CPU-Z"; Id="CPUID.CPU-Z"; Category="Tools"; CheckPath="C:\Program Files\CPUID\CPU-Z\cpuz.exe" }
)

function Get-AppStatus {
    param($App)
    if ($App.Type -eq "Web") {
        # Check if .bat exists in RetroBat
        $BatPath = "C:\RetroBat\roms\vod\$($App.Name).bat"
        if (Test-Path $BatPath) { return $true } else { return $false }
    } elseif ($App.CheckPath) {
        # Expand Environment Variables
        $ExpandedPath = [Environment]::ExpandEnvironmentVariables($App.CheckPath)
        if (Test-Path $ExpandedPath) { return $true }
    }
    return $false
}

# ==========================================
# 2. GUI Setup
# ==========================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = (Get-Tr "AM_TITLE")
$Form.Size = New-Object System.Drawing.Size(900,600)
$Form.StartPosition = "CenterScreen"

$TabControl = New-Object System.Windows.Forms.TabControl
$TabControl.Dock = "Fill"

$Tabs = @{
    "Gaming" = (Get-Tr "AM_TAB_GAMING")
    "VOD"    = (Get-Tr "AM_TAB_VOD")
    "Tools"  = (Get-Tr "AM_TAB_TOOLS")
}

# Helper to create rows
function Add-AppRow {
    param($Panel, $App)

    $Row = New-Object System.Windows.Forms.Panel
    $Row.Size = New-Object System.Drawing.Size(800, 50)
    $Row.Margin = New-Object System.Windows.Forms.Padding(5)
    $Row.BorderStyle = "FixedSingle"

    $LblName = New-Object System.Windows.Forms.Label
    $LblName.Text = $App.Name
    $LblName.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $LblName.Location = New-Object System.Drawing.Point(10, 12)
    $LblName.Size = New-Object System.Drawing.Size(300, 30)
    $Row.Controls.Add($LblName)

    $Installed = Get-AppStatus -App $App

    $LblStatus = New-Object System.Windows.Forms.Label
    $LblStatus.Text = if ($Installed) { (Get-Tr "AM_STATUS_INSTALLED") } else { (Get-Tr "AM_STATUS_NOT_INSTALLED") }
    $LblStatus.ForeColor = if ($Installed) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }
    $LblStatus.Location = New-Object System.Drawing.Point(350, 15)
    $LblStatus.Size = New-Object System.Drawing.Size(150, 30)
    $Row.Controls.Add($LblStatus)

    $BtnAction = New-Object System.Windows.Forms.Button
    $BtnAction.Location = New-Object System.Drawing.Point(550, 10)
    $BtnAction.Size = New-Object System.Drawing.Size(120, 30)
    $BtnAction.Tag = @{ App=$App; Label=$LblStatus; Button=$BtnAction }

    if ($Installed) {
        $BtnAction.Text = (Get-Tr "AM_BTN_UNINSTALL")
        $BtnAction.Add_Click({ Uninstall-App $this.Tag })
    } else {
        $BtnAction.Text = (Get-Tr "AM_BTN_INSTALL")
        $BtnAction.Add_Click({ Install-App $this.Tag })
    }

    $Row.Controls.Add($BtnAction)
    $Panel.Controls.Add($Row)
}

foreach ($Key in $Tabs.Keys) {
    $Page = New-Object System.Windows.Forms.TabPage
    $Page.Text = $Tabs[$Key]
    $Page.UseVisualStyleBackColor = $true

    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $Flow.Dock = "Fill"
    $Flow.AutoScroll = $true
    $Flow.FlowDirection = "TopDown"
    $Flow.WrapContents = $false

    $CategoryApps = $Apps | Where-Object { $_.Category -eq $Key }
    foreach ($A in $CategoryApps) {
        Add-AppRow -Panel $Flow -App $A
    }

    $Page.Controls.Add($Flow)
    $TabControl.TabPages.Add($Page)
}

$Form.Controls.Add($TabControl)

# ==========================================
# 3. Logic
# ==========================================

function Install-App {
    param($Tag)
    $App = $Tag.App
    $Lbl = $Tag.Label
    $Btn = $Tag.Button

    $Btn.Enabled = $false
    $Btn.Text = "..."
    [System.Windows.Forms.Application]::DoEvents()

    if ($App.Type -eq "Web") {
        # Create Shortcut
        $TargetDir = "C:\RetroBat\roms\vod"
        if (-not (Test-Path $TargetDir)) { New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null }

        $BatPath = Join-Path $TargetDir "$($App.Name).bat"
        $Content = "@echo off`r`nstart msedge --kiosk `"$($App.Url)`" --edge-kiosk-type=fullscreen`r`nexit"
        Set-Content -Path $BatPath -Value $Content

        $Success = $true
    } elseif ($App.Id) {
        try {
            Start-Process -FilePath "winget" -ArgumentList "install --id $($App.Id) -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
            $Success = $true

            # Attempt to create shortcut in RetroBat ports?
            # For now, just rely on app installation.
        } catch { $Success = $false }
    }

    if ($Success) {
        $Lbl.Text = (Get-Tr "AM_STATUS_INSTALLED")
        $Lbl.ForeColor = [System.Drawing.Color]::Green
        $Btn.Text = (Get-Tr "AM_BTN_UNINSTALL")
        $Btn.Remove_Click($Btn.Click[0]) # Remove old handler
        $Btn.Add_Click({ Uninstall-App $Tag })
    } else {
        $Btn.Text = (Get-Tr "AM_BTN_INSTALL")
    }
    $Btn.Enabled = $true
}

function Uninstall-App {
    param($Tag)
    $App = $Tag.App
    $Lbl = $Tag.Label
    $Btn = $Tag.Button

    $Btn.Enabled = $false
    $Btn.Text = "..."
    [System.Windows.Forms.Application]::DoEvents()

    if ($App.Type -eq "Web") {
        $BatPath = "C:\RetroBat\roms\vod\$($App.Name).bat"
        if (Test-Path $BatPath) { Remove-Item -Path $BatPath -Force }
        $Success = $true
    } elseif ($App.Id) {
        # Winget Uninstall not always reliable/silent for all apps but we try
        try {
            Start-Process -FilePath "winget" -ArgumentList "uninstall --id $($App.Id) --silent" -Wait -NoNewWindow
            $Success = $true
        } catch { $Success = $false }
    }

    if ($Success) {
        $Lbl.Text = (Get-Tr "AM_STATUS_NOT_INSTALLED")
        $Lbl.ForeColor = [System.Drawing.Color]::Red
        $Btn.Text = (Get-Tr "AM_BTN_INSTALL")
        $Btn.Remove_Click($Btn.Click[0])
        $Btn.Add_Click({ Install-App $Tag })
    } else {
        $Btn.Text = (Get-Tr "AM_BTN_UNINSTALL")
    }
    $Btn.Enabled = $true
}

$Form.ShowDialog() | Out-Null
