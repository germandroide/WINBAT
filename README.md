# WinBat Suite (Universal Edition)

## Visión General

**WinBat Suite** es una colección de scripts en PowerShell de código abierto diseñada para transformar cualquier PC con Windows 10 u 11 en un sistema híbrido de doble propósito.

1.  **Host (Diario):** Tu sistema operativo actual, limpio, para trabajo y uso general.
2.  **Guest (Windows-G):** Un entorno de consola de videojuegos de alto rendimiento, aislado, que se ejecuta mediante **Native Boot VHDX**.

> **Nota:** Este sistema **NO** es una máquina virtual. Windows-G se ejecuta directamente sobre el hardware (Bare Metal), garantizando el máximo rendimiento sin la sobrecarga de un hipervisor.

## Arquitectura Técnica

### Native Boot con VHDX Diferenciales

El núcleo de WinBat se basa en la capacidad nativa de Windows para arrancar desde archivos de disco virtual (VHDX). Implementamos una estrategia de discos padre-hijo:

*   **WinBat_Base.vhdx (Imagen Inmutable):** Contiene el sistema base optimizado. Este archivo no se modifica durante el uso normal.
*   **WinBat_Child.vhdx (Disco Diferencial):** Aquí residen todos los cambios del usuario, instalaciones de juegos y configuraciones.

Esta arquitectura permite la **Reversibilidad Instantánea**: Si el sistema "Windows-G" se corrompe o degrada, basta con borrar el archivo `WinBat_Child.vhdx` para resetear la consola a su estado de fábrica en menos de 1 segundo.

### Estrategia de Disco y Particiones

El instalador automatizado gestiona el almacenamiento de la siguiente manera:
1.  Reduce la partición principal (C:) del Host de forma segura.
2.  Crea una partición física dedicada llamada `GAMES_DATA`.
3.  Aloja los archivos VHDX dentro de `GAMES_DATA`.

### Filosofía de Aislamiento "WinUAE/Amiga"

*   **Aislamiento de Datos:** Cuando `Windows-G` arranca, el disco del sistema Host se marca como **Offline**. El entorno de juegos no tiene acceso a tus documentos, claves o datos personales del Host por defecto.
*   **Storage Manager:** Usamos un gestor de almacenamiento integrado (compatible con interfaces como RetroBat) que permite montar carpetas específicas, ISOs o unidades USB bajo demanda, protegido por mecanismos de seguridad (MFA/PIN).

## Optimización y Rendimiento (Windows-G)

El entorno Guest está diseñado bajo un manifiesto estricto para minimizar latencia y maximizar FPS, sin sacrificar funcionalidades críticas del ecosistema Xbox/Microsoft.

*   **Conservado:** Xbox Identity, Store Services (GamePass), Drivers firmados, Microsoft Edge.
*   **Desactivado:** Telemetría, Indexado de búsqueda (en zonas de juego), OneDrive (inicio automático).
*   **Energía:** Plan "Ultimate Performance" forzado, Game Mode activado.
*   **Gráficos:** HAGS (Hardware Accelerated GPU Scheduling) gestionado automáticamente.
*   **Seguridad:** Windows Defender se mantiene **ACTIVO**, pero configurado con exclusiones inteligentes para carpetas de ROMs y juegos para evitar cuellos de botella en I/O.

## Estructura del Repositorio

*   `/Installer`: Scripts que se ejecutan desde el sistema Host para preparar las particiones e instalar el VHDX base.
*   `/Optimizer`: Scripts de post-instalación que corren dentro de Windows-G para aplicar las políticas de rendimiento y limpieza.
*   `/StorageManager`: Herramientas para el montaje dinámico de recursos y gestión de almacenamiento.
*   `/Resources`: Archivos de configuración, iconos, plantillas y assets.
*   `global_config.ps1`: Archivo maestro de configuración y variables.

## Disclaimer de Responsabilidad

**LEER ATENTAMENTE ANTES DE USAR:**

Este software realiza operaciones avanzadas de particionado de disco y modificación de registros del sistema. Aunque se han tomado medidas para garantizar la seguridad y estabilidad:

1.  **WinBat Suite se proporciona "tal cual", sin garantía de ningún tipo.**
2.  El uso de estos scripts es bajo su propia responsabilidad.
3.  Se recomienda encarecidamente realizar una **COPIA DE SEGURIDAD COMPLETA** de sus datos importantes antes de ejecutar el instalador.
4.  Los desarrolladores no se hacen responsables de pérdida de datos, corrupción del sistema o hardware dañado derivado del uso de estas herramientas.
5.  Este proyecto no busca eludir protecciones de software ni activar Windows de forma ilegal. Se asume que el usuario posee licencias válidas.
