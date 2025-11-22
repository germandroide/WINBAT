# Manual de Usuario - WinBat Suite

¡Bienvenido a WinBat Suite! La solución definitiva para transformar tu PC en una consola de videojuegos sin perder tu Windows original.

---

## Índice

1.  [Introducción y Concepto](#1-introducción-y-concepto)
2.  [Instalación](#2-instalación)
3.  [Primer Arranque y Optimización](#3-primer-arranque-y-optimización)
4.  [Modo Consola (RetroBat)](#4-modo-consola-retrobat)
5.  [Gestión de Almacenamiento](#5-gestión-de-almacenamiento)
6.  [Consola de Administración (Manage-WinBat)](#6-consola-de-administración)
7.  [Gestor de Paquetes](#7-gestor-de-paquetes)
8.  [Preguntas Frecuentes (FAQ)](#8-preguntas-frecuentes-faq)

---

## 1. Introducción y Concepto

WinBat no es un simple programa, es un **Sistema Operativo Híbrido**. Utiliza una tecnología avanzada de Microsoft llamada *Native Boot VHDX* para crear un entorno paralelo en tu ordenador.

*   **Tu Windows Actual (Host):** Se mantiene intacto. Aquí trabajas, navegas y usas tus programas habituales.
*   **WinBat (Guest):** Un entorno Windows super-optimizado, limpio y aislado, dedicado exclusivamente a jugar. Arranca directamente sobre el hardware de tu PC para obtener el máximo rendimiento (FPS), pero no ve tus archivos privados del Host.

---

## 2. Instalación

### Requisitos
*   Windows 10 o Windows 11 (64 bits).
*   Al menos 20 GB de espacio libre (recomendado en disco SSD).
*   Privilegios de Administrador.

### Paso a Paso
1.  **Descarga**: Obtén la última versión de WinBat Suite.
2.  **Ejecutar Instalador**:
    *   Ve a la carpeta `Installer`.
    *   Ejecuta `Install-WinBat.ps1` (Click derecho -> Ejecutar con PowerShell).
3.  **Asistente**:
    *   El script te sugerirá instalarse en un disco secundario (D:, E:) si existe, para separar los juegos del sistema. Puedes aceptar o escribir otra ruta (ej: `C:\WinBat`).
    *   Selecciona tu idioma preferido si se solicita.
    *   El proceso clonará tu sistema base. Esto puede tardar entre 10 y 30 minutos.
4.  **Reinicio**: Al finalizar, reinicia tu PC. Verás un nuevo menú de arranque con dos opciones: "Windows Host" y "WinBat Console Mode".

---

## 3. Primer Arranque y Optimización

La primera vez que entres en **WinBat Console Mode**, verás una pantalla de carga o consola negra durante unos minutos. **No apagues el PC.**

El sistema está realizando automáticamente:
*   Instalación de Drivers (DirectX, Visual C++).
*   Activación de Windows (Heredada del Host).
*   Optimización agresiva (Plan de Energía, desactivación de Telemetría).
*   Configuración de RetroBat.

Al terminar, el sistema se reiniciará solo y arrancará directamente en la interfaz de juegos (RetroBat).

---

## 4. Modo Consola (RetroBat)

WinBat utiliza **RetroBat** como interfaz principal. Desde aquí puedes lanzar emuladores, juegos de PC, y apps de streaming.

*   **Navegación**: Usa tu mando (Xbox/PlayStation) o teclado.
*   **Salir al Escritorio**: WinBat está diseñado para no usar el escritorio de Windows. Si sales de RetroBat, el sistema se apagará o reiniciará (comportamiento tipo Kiosk). Si necesitas gestión avanzada, usa las herramientas incluidas en el menú "Ports" o "Apps".

---

## 5. Gestión de Almacenamiento

Por seguridad, WinBat oculta tus discos duros personales (C:, D: del Host) para evitar que borres documentos por error mientras juegas.

### ¿Cómo accedo a mis juegos instalados en el Host?
Usa la herramienta **WinBat Storage Manager**:
1.  Dentro de RetroBat, ve a la sección **Apps** o **System**.
2.  Lanza "Storage Manager".
3.  Introduce el PIN de seguridad (Por defecto `0000`, o el hash configurado).
4.  **Montar Carpeta**:
    *   Selecciona "Montar Nuevo Recurso".
    *   Elige la carpeta de tu disco Host (ej: `D:\Juegos\Steam`).
    *   Asignale una letra (ej: `G:`).
5.  ¡Listo! Ahora esa carpeta es visible permanentemente en WinBat como disco `G:`.

---

## 6. Consola de Administración

El script `Manage-WinBat.ps1` es el centro de control. Tiene funciones diferentes según dónde lo ejecutes.

### Modo Host (Desde tu Windows normal)
Ejecútalo para mantenimiento del sistema WinBat.
*   **1. Instalar / Reinstalar**: Si WinBat falla, puedes reinstalar el VHDX ("Guest") sin perder tus configuraciones y ROMs (que se guardan en la carpeta `Data` externa).
*   **2. Desinstalar**: Borra WinBat y limpia el arranque.
*   **3. Gestor de Arranque**: Define qué sistema arranca por defecto y el tiempo de espera.
*   **7. Snapshot (Backup)**: Crea una copia de seguridad de tus configuraciones y partidas guardadas en un archivo ZIP.
*   **11. Sincronización de Drivers**: Copia drivers específicos (Volantes, VR) de tu Host al WinBat Guest.

### Modo Guest (Desde WinBat)
Accesible desde RetroBat -> Ports -> "Configuración Avanzada".
*   **Hardening (Seguridad)**: Permite aplicar reglas de Firewall y seguridad al sistema Host de forma offline (para usuarios avanzados preocupados por la ciberseguridad).

---

## 7. Gestor de Paquetes

WinBat permite instalar "Packs" creados por la comunidad (archivos `.wbpack`) que contienen configuraciones listas para usar de emuladores complejos (Amiga, PC-98, etc.).

*   **Instalar Pack**: Abre el Gestor de Paquetes (desde la Consola de Administración) -> Selecciona "Instalar Paquete" -> Elige el archivo `.wbpack`.
*   **Crear Pack**: Si eres creador, usa la opción "Crear Dev Kit" para generar una plantilla y una guía de cómo empaquetar tus configuraciones.

---

## 8. Preguntas Frecuentes (FAQ)

**P: ¿WinBat es legal?**
R: Sí. WinBat no incluye Windows ni claves piratas. Utiliza tu propia instalación de Windows y licencia para crear una instancia secundaria permitida.

**P: ¿Puedo usar mi cuenta de Microsoft / Game Pass?**
R: Sí. WinBat mantiene los servicios de Xbox y Store activos para que puedas jugar a tus títulos de Game Pass.

**P: He roto algo en WinBat, ¿tengo que formatear?**
R: No. Simplemente entra en tu Windows normal (Host), abre la Consola de Administración y elige "Reinstalar". Se regenerará el sistema WinBat en 10 minutos conservando tus juegos y datos.

**P: ¿Cómo conecto mi mando si no funciona en los menús?**
R: WinBat incluye **AntiMicroX** preconfigurado. Si tu mando es XInput (Xbox), debería funcionar automáticamente para mover el ratón en las ventanas de configuración.
