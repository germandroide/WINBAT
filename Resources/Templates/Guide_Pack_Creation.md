# Guía de Creación de Paquetes WinBat (.wbpack)

¡Bienvenido, creador! Esta guía te enseñará a crear paquetes comunitarios para WinBat Suite.

## 1. ¿Qué es un Pack WinBat?

Un archivo `.wbpack` es un contenedor (ZIP renombrado) que permite distribuir configuraciones, assets, bios y scripts de instalación para sistemas específicos (ej: Amiga, X68000, PC-98) de forma automatizada.

## 2. Estructura del Paquete

Tu carpeta de desarrollo debe tener esta estructura exacta:

```
MiPack_v1.0/
├── manifest.json       # (Obligatorio) Metadatos del paquete
├── setup.ps1           # (Opcional) Script de instalación
├── assets/             # (Opcional) Imágenes, logos, videos para el tema
├── configs/            # (Opcional) Archivos .cfg, .ini, .opt
└── roms_placeholder/   # (Opcional) Carpetas vacías para indicar dónde van las ROMs
```

## 3. Paso 1: Editar manifest.json

Este archivo le dice a WinBat qué es tu paquete.

```json
{
    "id": "winbat.community.amiga",
    "name": "Amiga Ultimate Experience",
    "version": "1.0.0",
    "author": "TuNombre",
    "description": "Configuración optimizada para Amiga 1200 con WHDLoad y Kickstarts.",
    "dependencies": ["retrobat_v5"]
}
```

## 4. Paso 2: Script setup.ps1

Este script PowerShell se ejecuta con permisos de Administrador al importar el paquete. Úsalo para:
- Copiar archivos de BIOS.
- Descargar herramientas freeware (ej: WHDLoad).
- Mover configuraciones a la carpeta correcta.

**IMPORTANTE**: No incluyas archivos con Copyright (ROMs comerciales, BIOS propietarias) dentro del paquete si vas a distribuirlo públicamente. Tu script puede pedir al usuario que los proporcione o descargarlos de fuentes legales/archive.org si aplica.

Ejemplo de comando en setup.ps1:
```powershell
# Usa la variable de entorno para soportar instalaciones en el Host y en el Guest
$RetroBat = if ($env:WB_RETROBAT_PATH) { $env:WB_RETROBAT_PATH } else { "C:\RetroBat" }

Write-Host "Instalando Configuración de Amiga..."
Copy-Item -Path "$PSScriptRoot\configs\amiga.uae" -Destination "$RetroBat\emulators\winuae\conf\" -Force
```

## 5. Paso 3: Assets y Temas

Coloca imágenes de fondo, logotipos o videos en la carpeta `assets`.
El script `setup.ps1` debería copiarlos a:
`$RetroBat\emulationstation\.emulationstation\themes\WinBat_Theme\assets\`

## 6. Paso 4: Empaquetar

1. Abre la Consola de Administración WinBat.
2. Ve al Gestor de Paquetes.
3. Selecciona "Compilar Paquete".
4. Elige tu carpeta de desarrollo.
5. ¡Listo! Obtendrás un archivo `.wbpack` para compartir.
