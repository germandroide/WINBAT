<#
    WinBat Suite - Storage Manager UI
    WinBat_StorageUI.ps1

    GUI Tool to mount Host folders or External Drives as Virtual Drives in WinBat.
    Features:
    - PIN Authentication
    - List/Add/Remove Mounts
    - Persists config to C:\WinBat\Config\mounts.json
#>

# ==========================================
# 0. Initialize
# ==========================================
$ScriptPath = $PSScriptRoot
$GlobalConfigPath = Join-Path -Path $ScriptPath -ChildPath "..\global_config.ps1"

if (-not (Test-Path $GlobalConfigPath)) {
    Write-Error "Critical: global_config.ps1 not found."
    exit 1
}
. $GlobalConfigPath

# Check Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error (Get-Tr "SM_ERR_ADMIN")
    exit 1
}

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Config Path
$ConfigDir = "C:\WinBat\Config"
$ConfigFile = Join-Path $ConfigDir "mounts.json"

if (-not (Test-Path $ConfigDir)) { New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $ConfigFile)) { Set-Content -Path $ConfigFile -Value "[]" }

# ==========================================
# 1. Functions
# ==========================================

function Get-Mounts {
    try {
        $Json = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        if ($Json) { return $Json } else { return @() }
    } catch { return @() }
}

function Save-Mounts {
    param ($Mounts)
    $Json = $Mounts | ConvertTo-Json -Depth 2
    Set-Content -Path $ConfigFile -Value $Json
}

function Refresh-List {
    $ListBox.Items.Clear()
    $Mounts = Get-Mounts
    foreach ($M in $Mounts) {
        $ListBox.Items.Add("$($M.DriveLetter) -> $($M.SourcePath)") | Out-Null
    }

    # Also refresh partitions
    $CmbPartitions.Items.Clear()
    $Partitions = Get-Partition | Where-Object { $_.DriveLetter -eq $null -and $_.Size -gt 1GB }
    foreach ($P in $Partitions) {
        $SizeGB = [math]::Round($P.Size / 1GB, 2)
        $CmbPartitions.Items.Add("Disk $($P.DiskNumber) Part $($P.PartitionNumber) [$($SizeGB) GB]") | Out-Null
    }
}

# ==========================================
# 2. Authenticate (Simple PIN)
# ==========================================
# Default PIN is 0000 if not set in global
$UserPin = ""
$CorrectPin = $Global:WB_SecurityPIN
if (-not $CorrectPin) { $CorrectPin = "0000" }

# Prompt Logic
$AuthForm = New-Object System.Windows.Forms.Form
$AuthForm.Text = (Get-Tr "SM_PIN_REQ")
$AuthForm.Size = New-Object System.Drawing.Size(300,150)
$AuthForm.StartPosition = "CenterScreen"

$LblPin = New-Object System.Windows.Forms.Label
$LblPin.Text = (Get-Tr "SM_PIN_PROMPT")
$LblPin.Location = New-Object System.Drawing.Point(20,20)
$LblPin.Size = New-Object System.Drawing.Size(200,20)
$AuthForm.Controls.Add($LblPin)

$TxtPin = New-Object System.Windows.Forms.TextBox
$TxtPin.PasswordChar = "*"
$TxtPin.Location = New-Object System.Drawing.Point(20,50)
$TxtPin.Size = New-Object System.Drawing.Size(240,20)
$AuthForm.Controls.Add($TxtPin)

$BtnAuth = New-Object System.Windows.Forms.Button
$BtnAuth.Text = "OK"
$BtnAuth.Location = New-Object System.Drawing.Point(100,80)
$BtnAuth.DialogResult = [System.Windows.Forms.DialogResult]::OK
$AuthForm.Controls.Add($BtnAuth)
$AuthForm.AcceptButton = $BtnAuth

$Result = $AuthForm.ShowDialog()

if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
    # Simple Check - Ideally compare against a stored hash or specific global
    if ($TxtPin.Text -eq $CorrectPin) {
        # Success
    } else {
        [System.Windows.Forms.MessageBox]::Show((Get-Tr "SM_PIN_INVALID"), (Get-Tr "SM_TITLE"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
} else {
    exit
}

# ==========================================
# 3. Main UI
# ==========================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = (Get-Tr "SM_TITLE")
$Form.Size = New-Object System.Drawing.Size(500,400)
$Form.StartPosition = "CenterScreen"

# List of Mounts
$LblList = New-Object System.Windows.Forms.Label
$LblList.Text = (Get-Tr "SM_LBL_MOUNTS")
$LblList.Location = New-Object System.Drawing.Point(20,20)
$LblList.Size = New-Object System.Drawing.Size(200,20)
$Form.Controls.Add($LblList)

$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.Point(20,50)
$ListBox.Size = New-Object System.Drawing.Size(440,150)
$Form.Controls.Add($ListBox)

# Partition Helper (Unlocker)
$LblPart = New-Object System.Windows.Forms.Label
$LblPart.Text = "Physical Partitions (Hidden):"
$LblPart.Location = New-Object System.Drawing.Point(20, 210)
$LblPart.Size = New-Object System.Drawing.Size(200,20)
$Form.Controls.Add($LblPart)

$CmbPartitions = New-Object System.Windows.Forms.ComboBox
$CmbPartitions.Location = New-Object System.Drawing.Point(20, 230)
$CmbPartitions.Size = New-Object System.Drawing.Size(300, 25)
$Form.Controls.Add($CmbPartitions)

$BtnUnlock = New-Object System.Windows.Forms.Button
$BtnUnlock.Text = "Unlock/Peek"
$BtnUnlock.Location = New-Object System.Drawing.Point(330, 230)
$BtnUnlock.Size = New-Object System.Drawing.Size(100, 23)
$Form.Controls.Add($BtnUnlock)

# Buttons
$BtnMount = New-Object System.Windows.Forms.Button
$BtnMount.Text = (Get-Tr "SM_BTN_MOUNT")
$BtnMount.Location = New-Object System.Drawing.Point(20,300)
$BtnMount.Size = New-Object System.Drawing.Size(150,30)
$Form.Controls.Add($BtnMount)

$BtnUnmount = New-Object System.Windows.Forms.Button
$BtnUnmount.Text = (Get-Tr "SM_BTN_UNMOUNT")
$BtnUnmount.Location = New-Object System.Drawing.Point(180,300)
$BtnUnmount.Size = New-Object System.Drawing.Size(150,30)
$Form.Controls.Add($BtnUnmount)

# ==========================================
# 4. Event Handlers
# ==========================================

$BtnUnlock.Add_Click({
    $Sel = $CmbPartitions.SelectedItem
    if ($Sel) {
        # Extract Disk/Part
        if ($Sel -match "Disk (\d+) Part (\d+)") {
            $DiskNum = $matches[1]
            $PartNum = $matches[2]

            # Assign Temp Letter (T:)
            # First check if T is free, or iterate
            try {
                Set-Partition -DiskNumber $DiskNum -PartitionNumber $PartNum -NewDriveLetter "T" -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Partition mounted to T: temporarily for browsing.", "Unlock", 0, 64)
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to assign T:. It may be in use.", "Error", 0, 16)
            }
        }
    }
})

$BtnMount.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = (Get-Tr "SM_SELECT_FOLDER")

    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SelectedPath = $FolderBrowser.SelectedPath

        # Pick Drive Letter (Simple InputBox simulation)
        # In a full app, a ComboBox with free letters is better.
        # Hardcoding a quick check for now or asking via InputBox (VB style available in PS)
        Add-Type -AssemblyName Microsoft.VisualBasic
        $DriveLetter = [Microsoft.VisualBasic.Interaction]::InputBox((Get-Tr "SM_SELECT_DRIVE"), (Get-Tr "SM_TITLE"), "Z:")

        if ($DriveLetter -match "^[A-Z]:?$") {
            $DriveLetter = $DriveLetter.Substring(0,1) + ":" # Ensure format X:

            try {
                # Attempt Mount (Subst)
                Subst $DriveLetter $SelectedPath

                # Save Config
                $Mounts = Get-Mounts
                $NewMount = [PSCustomObject]@{
                    DriveLetter = $DriveLetter
                    SourcePath = $SelectedPath
                }
                $Mounts += $NewMount
                Save-Mounts $Mounts

                Refresh-List
                [System.Windows.Forms.MessageBox]::Show((Get-Tr "SM_MOUNT_SUCCESS" -f $SelectedPath, $DriveLetter), (Get-Tr "SM_TITLE"), 0, 64)
            } catch {
                [System.Windows.Forms.MessageBox]::Show((Get-Tr "SM_MOUNT_FAIL"), (Get-Tr "SM_TITLE"), 0, 16)
            }
        }
    }
})

$BtnUnmount.Add_Click({
    $Sel = $ListBox.SelectedItem
    if ($Sel) {
        # Format is "X: -> Path"
        $Parts = $Sel -split " -> "
        $DriveLetter = $Parts[0]

        try {
            # Unmount
            Subst $DriveLetter /D

            # Update Config
            $Mounts = Get-Mounts
            $Mounts = $Mounts | Where-Object { $_.DriveLetter -ne $DriveLetter }
            Save-Mounts $Mounts

            Refresh-List
            [System.Windows.Forms.MessageBox]::Show((Get-Tr "SM_UNMOUNT_SUCCESS" -f $DriveLetter), (Get-Tr "SM_TITLE"), 0, 64)
        } catch {
            [System.Windows.Forms.MessageBox]::Show((Get-Tr "SM_UNMOUNT_FAIL"), (Get-Tr "SM_TITLE"), 0, 16)
        }
    }
})

# Initial Load
Refresh-List

$Form.ShowDialog() | Out-Null
