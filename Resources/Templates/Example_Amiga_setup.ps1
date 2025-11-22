<#
    WinBat Package Setup Script (Example: Amiga)

    Este script se ejecuta automáticamente al importar el paquete.
    Usa variables relativas a $PSScriptRoot.
#>

# Use environment variable passed by Package Manager for path independence (Host vs Guest)
if ($env:WB_RETROBAT_PATH) {
    $RetroBatPath = $env:WB_RETROBAT_PATH
} else {
    $RetroBatPath = "C:\RetroBat" # Fallback for Guest execution
}

$BiosPath = Join-Path $RetroBatPath "bios"
$RomsPath = Join-Path $RetroBatPath "roms\amiga1200"

Write-Host "Iniciando instalación de Amiga Ultimate Pack..." -ForegroundColor Cyan

# 1. Crear directorios si no existen
if (-not (Test-Path $RomsPath)) { New-Item -Path $RomsPath -ItemType Directory -Force | Out-Null }

# 2. Copiar Configuraciones
Write-Host "Copiando configuraciones de WinUAE..."
Copy-Item -Path "$PSScriptRoot\configs\*.uae" -Destination "$RetroBatPath\emulators\winuae\" -Force -ErrorAction SilentlyContinue

# 3. Verificar BIOS (Kickstarts)
# Nota: No distribuimos las BIOS, pero verificamos si el usuario las tiene o intentamos copiarlas de una instalación de Amiga Forever si existe.

$AmigaForeverPath = "C:\Program Files (x86)\Cloanto\Amiga Forever\Emulation\shared\rom"
if (Test-Path $AmigaForeverPath) {
    Write-Host "Detectada instalación de Amiga Forever. Importando Kickstarts..." -ForegroundColor Green
    Copy-Item -Path "$AmigaForeverPath\amiga-os-310-a1200.rom" -Destination "$BiosPath\kick31.rom" -Force
} else {
    Write-Warning "No se detectó Amiga Forever. Asegúrate de colocar 'kick31.rom' en $BiosPath manualmente."
}

# 4. Descargar WHDLoad (Freeware)
Write-Host "Descargando WHDLoad..."
try {
    # URL de ejemplo (ficticia para el ejemplo, usar real en producción)
    # Invoke-WebRequest -Uri "http://whdload.de/whdload.lha" -OutFile "$RomsPath\whdload.lha"
    Write-Host "WHDLoad descargado (Simulado)."
} catch {
    Write-Error "Error descargando WHDLoad."
}

Write-Host "Instalación de Amiga Pack completada." -ForegroundColor Green
