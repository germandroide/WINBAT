@echo off
REM WinBat Storage Manager Launcher
REM Place this file in your RetroBat\roms\ports or RetroBat\roms\system folder
REM to access the Storage Manager from the game interface.

powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\WinBat\StorageManager\WinBat_StorageUI.ps1"
exit
