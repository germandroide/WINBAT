<#
    WinBat Suite - OOBE Welcome Wizard
    WinBat_Welcome.ps1

    Runs on first launch of the WinBat Console Mode environment (over RetroBat).
    Allows user to install apps and configure the environment.
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
    Write-Warning "Wizard requires Admin."
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# 1. App Definitions
# ==========================================
# Structure: Name, ID (Winget) or Script logic, Category
$Apps = @(
    @{ Name="Steam"; Id="Valve.Steam"; Category="Gaming" },
    @{ Name="Epic Games"; Id="EpicGames.EpicGamesLauncher"; Category="Gaming" },
    @{ Name="EA App"; Id="ElectronicArts.EADesktop"; Category="Gaming" },
    @{ Name="Xbox App"; Id="Microsoft.GamingApp"; Category="Gaming" },
    @{ Name="GeForce Experience"; Id="Nvidia.GeForceExperience"; Category="Gaming" },

    @{ Name="Xbox Cloud Gaming"; Type="Web"; Url="https://www.xbox.com/play"; Category="Cloud" },
    @{ Name="GeForce Now"; Id="Nvidia.GeForceNow"; Category="Cloud" },
    @{ Name="Amazon Luna"; Type="Web"; Url="https://luna.amazon.com"; Category="Cloud" },

    @{ Name="Spotify"; Id="Spotify.Spotify"; Category="Multimedia" },
    @{ Name="VLC"; Id="VideoLAN.VLC"; Category="Multimedia" },
    @{ Name="PotPlayer"; Id="Daum.PotPlayer"; Category="Multimedia" },

    @{ Name="Netflix"; Type="Web"; Url="https://www.netflix.com"; Category="VOD" },
    @{ Name="Disney+"; Type="Web"; Url="https://www.disneyplus.com"; Category="VOD" },
    @{ Name="HBO Max"; Type="Web"; Url="https://play.hbomax.com"; Category="VOD" },
    @{ Name="Prime Video"; Type="Web"; Url="https://www.primevideo.com"; Category="VOD" }
)

# ==========================================
# 2. GUI Setup
# ==========================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = (Get-Tr "WIZ_TITLE")
$Form.Size = New-Object System.Drawing.Size(800,600)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false

# Header
$LblWelcome = New-Object System.Windows.Forms.Label
$LblWelcome.Text = (Get-Tr "WIZ_WELCOME")
$LblWelcome.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$LblWelcome.Location = New-Object System.Drawing.Point(20,20)
$LblWelcome.Size = New-Object System.Drawing.Size(700,40)
$Form.Controls.Add($LblWelcome)

$LblSub = New-Object System.Windows.Forms.Label
$LblSub.Text = (Get-Tr "WIZ_SUBTITLE")
$LblSub.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$LblSub.Location = New-Object System.Drawing.Point(25,60)
$LblSub.Size = New-Object System.Drawing.Size(700,30)
$Form.Controls.Add($LblSub)

# Tab Control for Categories
$TabControl = New-Object System.Windows.Forms.TabControl
$TabControl.Location = New-Object System.Drawing.Point(20,100)
$TabControl.Size = New-Object System.Drawing.Size(740,350)

$Categories = @("Gaming", "Cloud", "Multimedia", "VOD")
$Checkboxes = @{}

foreach ($Cat in $Categories) {
    $Page = New-Object System.Windows.Forms.TabPage
    $Page.Text = (Get-Tr "WIZ_CAT_$($Cat.ToUpper())")
    $Page.UseVisualStyleBackColor = $true

    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $Flow.Dock = "Fill"
    $Flow.AutoScroll = $true
    $Flow.Padding = New-Object System.Windows.Forms.Padding(20)

    $CatApps = $Apps | Where-Object { $_.Category -eq $Cat }

    foreach ($App in $CatApps) {
        $Cb = New-Object System.Windows.Forms.CheckBox
        $Cb.Text = $App.Name
        $Cb.AutoSize = $true
        $Cb.Tag = $App # Store object
        $Cb.Margin = New-Object System.Windows.Forms.Padding(10)
        $Cb.Font = New-Object System.Drawing.Font("Segoe UI", 11)

        $Flow.Controls.Add($Cb)
        $Checkboxes[$App.Name] = $Cb
    }

    $Page.Controls.Add($Flow)
    $TabControl.TabPages.Add($Page)
}

$Form.Controls.Add($TabControl)

# MFA Section
$GrpMfa = New-Object System.Windows.Forms.GroupBox
$GrpMfa.Text = (Get-Tr "WIZ_MFA_TITLE")
$GrpMfa.Location = New-Object System.Drawing.Point(20, 460)
$GrpMfa.Size = New-Object System.Drawing.Size(350, 80)

$LblMfa = New-Object System.Windows.Forms.Label
$LblMfa.Text = (Get-Tr "WIZ_MFA_DESC")
$LblMfa.Location = New-Object System.Drawing.Point(10, 20)
$LblMfa.Size = New-Object System.Drawing.Size(330, 30)
$GrpMfa.Controls.Add($LblMfa)

$BtnMfa = New-Object System.Windows.Forms.Button
$BtnMfa.Text = (Get-Tr "WIZ_MFA_BTN")
$BtnMfa.Location = New-Object System.Drawing.Point(10, 50)
$BtnMfa.Size = New-Object System.Drawing.Size(120, 25)
$BtnMfa.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("MFA Setup Placeholder: Opening MS Authenticator pairing...", "MFA", 0, 64)
})
$GrpMfa.Controls.Add($BtnMfa)

$Form.Controls.Add($GrpMfa)

# Install Button
$BtnInstall = New-Object System.Windows.Forms.Button
$BtnInstall.Text = (Get-Tr "WIZ_BTN_INSTALL")
$BtnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$BtnInstall.Location = New-Object System.Drawing.Point(560, 480)
$BtnInstall.Size = New-Object System.Drawing.Size(200, 50)
$Form.Controls.Add($BtnInstall)

# ==========================================
# 3. Installation Logic
# ==========================================

$BtnInstall.Add_Click({
    $BtnInstall.Enabled = $false
    $SelectedApps = $Checkboxes.Values | Where-Object { $_.Checked } | ForEach-Object { $_.Tag }

    foreach ($App in $SelectedApps) {
        $AppName = $App.Name
        $BtnInstall.Text = (Get-Tr "WIZ_INSTALLING" -f $AppName)
        [System.Windows.Forms.Application]::DoEvents()

        if ($App.Type -eq "Web") {
            # Create Web Shortcut (.bat for Kiosk mode)
            $TargetDir = "C:\RetroBat\roms\$($App.Category.ToLower())"
            if (-not (Test-Path $TargetDir)) { New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null }

            $BatPath = Join-Path $TargetDir "$AppName.bat"
            # Kiosk command: msedge --kiosk "URL" --edge-kiosk-type=fullscreen
            $Content = "@echo off`r`nstart msedge --kiosk `"$($App.Url)`" --edge-kiosk-type=fullscreen`r`nexit"
            Set-Content -Path $BatPath -Value $Content

        } elseif ($App.Id) {
            # Winget Install
            # Note: Silent install, accept source agreements
            try {
                # Check if winget available, if not skip or warn. Assuming Win 10/11 has it.
                Start-Process -FilePath "winget" -ArgumentList "install --id $($App.Id) -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow

                # Create Shortcut in RetroBat?
                # Native apps usually create desktop shortcuts. We might need to copy them.
                # Simplified: Just rely on OS install. User can add manually or we assume auto-scan if configured.
                # Ideally, we would find the .lnk and copy to C:\RetroBat\roms\windows or similar.
                # For this sprint, installing is the main goal.
            } catch {
                Write-Warning "Failed to install $AppName"
            }
        }
    }

    $BtnInstall.Text = "Done"
    [System.Windows.Forms.MessageBox]::Show((Get-Tr "WIZ_DONE"), "WinBat", 0, 64)
    $Form.Close()

    # Remove from RunOnce so it doesn't run again?
    # It was registered as RunOnce, so Windows removes it automatically after execution.
})

$Form.ShowDialog() | Out-Null
