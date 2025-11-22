# Registro de Desarrollo Técnico - WinBat Suite

Este documento detalla la arquitectura, los módulos desarrollados y las especificaciones técnicas del proyecto **WinBat Suite**, un sistema operativo híbrido basado en Windows para emulación y gaming mediante VHDX Native Boot.

## 1. Arquitectura del Sistema

WinBat utiliza una estrategia de **Native Boot VHDX** para crear un entorno de juego ("Guest") aislado del sistema principal ("Host"), pero compartiendo el hardware nativo para máximo rendimiento.

### Componentes Principales
*   **VHDX Base (`WinBat_Base.vhdx`)**: Imagen inmutable del sistema operativo.
*   **VHDX Hijo (`WinBat_Child.vhdx`)**: Disco diferencial donde se guardan los cambios del sistema invitado.
*   **Persistencia Externa (`$InstallPath\Data`)**: Carpeta en el sistema de archivos del Host (NTFS) que almacena configuraciones, ROMs, y BIOS de RetroBat. Esto permite que el VHDX sea "desechable" y reinstalable sin perder datos de usuario.
*   **Mounting System**:
    *   En el arranque del Guest, la carpeta `Data` del Host se detecta y se monta como unidad `B:`.
    *   Se crea un enlace simbólico `C:\RetroBat -> B:\RetroBat`.

## 2. Módulos y Scripts

### 2.1. Instalador (`Installer/Install-WinBat.ps1`)
Script ejecutado en el Host con privilegios administrativos.
*   **Funciones**:
    *   Selección inteligente de disco (sugiere unidades no-sistema para instalación).
    *   Creación de VHDX dinámicos (25GB por defecto).
    *   Clonado del Host al VHDX usando `DISM` con lista de exclusión (`WimScript.ini`).
    *   Inyección de scripts de optimización (`Optimizer/`) y configuración global.
    *   Configuración del Boot Loader (`bcdedit`) para añadir la entrada "WinBat Console Mode".
    *   Creación de la estructura de persistencia externa (`Data` folder) y archivo marcador `.winbat_marker`.
    *   Persistencia de la ruta de instalación en `global_config.ps1`.

### 2.2. Optimizador de Primer Arranque (`Optimizer/WinBat_FirstBoot.ps1`)
Script de ejecución única (`RunOnce`) dentro del Guest.
*   **Lógica "Chicken & Egg"**: Instala dependencias críticas (VC++, DirectX) *antes* de cambiar el Shell.
*   **Activación**: Revalida la licencia digital de Windows (`slmgr /ato`) usando el hardware ID heredado.
*   **Mounting**: Escanea discos físicos buscando `.winbat_marker`, monta la carpeta Data como `B:` y enlaza `C:\RetroBat`.
*   **Aislamiento**: Oculta las particiones del Host (excepto la de Data) para evitar accidentes.
*   **Optimización**: Aplica plan de energía "Ultimate Performance", deshabilita servicios de telemetría y configura exclusiones de Defender.
*   **Shell**: Reemplaza `explorer.exe` con `RetroBat` (vía wrapper `ShellLauncher.ps1`).
*   **Input**: Configura `AntiMicroX` al inicio para soporte de mando en menús de sistema.

### 2.3. Consola de Administración (`Manage-WinBat.ps1`)
Herramienta CLI unificada con detección de contexto (Host vs Guest).
*   **Modo Host**:
    *   **Ciclo de Vida**: Instalar, Reinstalar (conservando Data), Desinstalar (Limpieza VHDX + BCD).
    *   **Boot Manager**: Cambiar sistema por defecto y Timeout.
    *   **Backup**: Crear Snapshots ZIP de `Data\RetroBat\emulationstation` y `saves`.
    *   **Restore**: Restaurar Snapshots sobre la carpeta Data.
    *   **Tools**: Lanzar DiskGenius, Package Manager.
*   **Modo Guest**:
    *   **Offline Hardening**: Monta los hives de registro del Host (`SYSTEM`, `SOFTWARE`) para aplicar políticas de seguridad (Firewall, Deshabilitar SMBv1) sin arrancar el Host.

### 2.4. Gestor de Paquetes (`Apps/WinBat_PackageManager.ps1`)
Sistema para distribuir configuraciones comunitarias (`.wbpack`).
*   **Formato**: Archivo ZIP renombrado con `manifest.json` y `setup.ps1`.
*   **Funciones**:
    *   `Create-Dev-Kit`: Genera estructura de carpetas y guías (`Guide_Pack_Creation.md`) para creadores.
    *   `Build-Pack`: Valida y comprime la carpeta de desarrollo.
    *   `Import-Pack`: Descomprime, valida manifiesto e inyecta variables de entorno (`$env:WB_RETROBAT_PATH`) para que el script de instalación funcione tanto en Host como en Guest.

### 2.5. Gestor de Almacenamiento (`StorageManager/WinBat_StorageUI.ps1`)
Interfaz gráfica (Windows Forms) para montar carpetas adicionales del Host en el Guest.
*   **Seguridad**: Protegido por PIN (Hash SHA-256).
*   **Funcionalidad**: Usa `subst` para mapear carpetas a letras de unidad virtuales. Persiste configuración en `mounts.json`.

## 3. Configuración y Seguridad (`global_config.ps1`)
Archivo central de variables cargado por todos los scripts.
*   **Variables Globales**: Rutas de instalación, nombres de VHDX, tamaños.
*   **Seguridad**: Implementa funciones `Set-WinBatPin` y `Test-WinBatPin` usando criptografía .NET (SHA-256) para evitar almacenamiento de PIN en texto plano.
*   **L10n**: Sistema de localización que carga archivos JSON (`Resources/Languages/*.json`) basado en la cultura del sistema (`Get-UICulture`), con fallback a UTF-8 forzado.

## 4. Recursos
*   **Idiomas**: Soporte para 11 locales (en-US, es-ES, fr-FR, de-DE, it-IT, pt-PT, pt-BR, ru-RU, zh-CN, ja-JP, hi-IN, ko-KR). Se incluye selector manual en el instalador para casos donde la detección automática falle.
*   **Plantillas**: Guías de creación de paquetes y scripts de ejemplo (Amiga).
*   **Perfiles**: Perfil de AntiMicroX para navegación con mando.

## 5. Verificación de Calidad y Licencias
*   **URLs y Dependencias**: Se ha verificado que los scripts apuntan a fuentes oficiales o repositorios mantenidos (GitHub Releases para AntiMicroX, Winget/Microsoft para Runtimes).
*   **Licencia**: El proyecto está protegido bajo licencia **CC BY-NC-SA 4.0** para evitar lucro comercial no autorizado.
*   **Avisos Legales**: Se incluye un archivo `NOTICE.md` con las atribuciones a terceros (RetroBat, Microsoft, etc.).
