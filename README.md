# WinBat Suite (Universal Edition)

## ¿Qué es WinBat?

**WinBat Suite** es una solución de código abierto que transforma tu PC con Windows 10 u 11 en un sistema híbrido de doble propósito, sin perder tu configuración actual.

1.  **Host (Diario):** Tu sistema operativo actual, limpio, para trabajo y uso general.
2.  **WinBat Console Mode:** Un entorno dedicado a videojuegos y emulación (RetroBat), altamente optimizado y aislado, que se ejecuta mediante **Native Boot VHDX**.

### Características Principales

*   **Rendimiento Nativo:** No es una máquina virtual. El modo consola se ejecuta directamente sobre el hardware (Bare Metal), garantizando máximos FPS y mínima latencia.
*   **Instalación No Destructiva:** Utiliza una estrategia basada en archivos (VHDX). No re-particiona tu disco duro ni modifica tu sistema Host (salvo la entrada de arranque).
*   **Aislamiento de Privacidad:** Al arrancar en modo consola, tus discos personales se ocultan para evitar accesos accidentales o modificaciones.
*   **WinBat Storage Manager:** Una herramienta integrada para montar carpetas de juegos, ISOs o discos externos dentro del modo consola de forma segura y bajo demanda.
*   **Reversibilidad:** Puedes resetear el modo consola a su estado original en segundos simplemente borrando un archivo.

---

## Instalación

### Requisitos Previos
*   Windows 10 o Windows 11 (64 bits).
*   Privilegios de Administrador.
*   Al menos **60 GB** de espacio libre en disco.

### Pasos
1.  **Descargar:** Clona este repositorio o descarga la última versión como ZIP y extráelo en una carpeta accesible.
2.  **Ejecutar Instalador:**
    *   Navega a la carpeta `Installer`.
    *   Haz clic derecho en `Install-WinBat.ps1` y selecciona **"Ejecutar con PowerShell"**.
    *   *Nota: Si se solicitan permisos de ejecución, acepta o ejecuta previamente `Set-ExecutionPolicy Bypass -Scope Process`.*
3.  **Configuración:**
    *   El script te pedirá la ruta de instalación (Por defecto: `C:\WinBat`).
    *   Se iniciará el proceso de clonación y configuración. Esto puede tardar varios minutos dependiendo de la velocidad de tu disco.
4.  **Finalizar:**
    *   Una vez completado, reinicia tu PC.
    *   Verás una nueva opción en el menú de arranque llamada **"WinBat Console Mode"**.

---

## Uso

### Primer Arranque (Optimizador)
La primera vez que inicies en **WinBat Console Mode**, el sistema ejecutará automáticamente el script de optimización (`WinBat_FirstBoot.ps1`).
*   Se aplicará el plan de energía "Ultimate Performance".
*   Se desactivarán servicios innecesarios (Telemetría, Indexado).
*   Se configurará la interfaz de consola (RetroBat).
*   El sistema se reiniciará automáticamente al terminar.

### WinBat Storage Manager
Dentro del modo consola, tus discos del Host estarán ocultos por seguridad. Para acceder a tus juegos:
1.  Desde RetroBat, busca la opción "Storage Manager" (o ejecútala desde la carpeta `WinBat\StorageManager`).
2.  Introduce el PIN de seguridad (Por defecto: `0000`, configurable en `global_config.ps1`).
3.  Usa la interfaz para montar carpetas del Host (ej: `D:\Juegos`) como unidades virtuales (ej: `G:\`).
4.  Estas unidades se volverán a montar automáticamente en cada reinicio.

---

## Desinstalación

Para eliminar WinBat completamente de tu sistema:

1.  **Arranca en tu Windows Host (Normal).**
2.  **Borrar Archivos:** Elimina la carpeta de instalación (Ej: `C:\WinBat`).
3.  **Limpiar Arranque:**
    *   Presiona `Win + R`, escribe `msconfig` y pulsa Enter.
    *   Ve a la pestaña **Arranque (Boot)**.
    *   Selecciona la entrada "WinBat Console Mode" y haz clic en **Eliminar**.
4.  ¡Listo! Tu sistema está limpio.

---

## Disclaimer

**LEER ATENTAMENTE:**

Este software se proporciona "tal cual", sin garantía de ningún tipo. Aunque se han tomado precauciones para garantizar la seguridad (instalación en archivo, puntos de restauración), el uso de herramientas de modificación de sistema conlleva riesgos.

*   Los desarrolladores no se hacen responsables de pérdida de datos.
*   Se recomienda encarecidamente realizar copias de seguridad antes de la instalación.
*   Este proyecto respeta las licencias de Microsoft y no incluye herramientas de activación ilegal.

---

## Estructura del Repositorio

*   `/Installer`: Scripts de despliegue para el Host.
*   `/Optimizer`: Scripts de optimización y configuración para el Guest.
*   `/StorageManager`: Herramientas de gestión de unidades y persistencia.
*   `/Resources`: Archivos de configuración, idiomas (i18n) y assets.
