@echo off
:: =================================================================
:: Install-PSRemoting.bat
:: Network Share Installation Launcher
:: =================================================================
:: Author:  Flecki (Tom) Garnreiter
:: Version: v1.0.0
:: Date:    2025-10-07
:: =================================================================

echo.
echo =====================================================================
echo   PSRemoting Installation vom Netzlaufwerk
echo   Version 1.0.0 - Regelwerk v10.0.3
echo =====================================================================
echo.

:: Admin-Rechte pruefen
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Administrator-Rechte erforderlich!
    echo.
    echo Bitte als Administrator ausfuehren:
    echo   - Rechtsklick auf diese Datei
    echo   - "Als Administrator ausfuehren"
    echo.
    pause
    exit /b 1
)

echo [INFO] Administrator-Rechte: OK
echo.

:: Network Share Path
set "NETWORK_SHARE=\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"

echo [INFO] Pruefe Netzwerk-Verbindung...
echo [INFO] Share: %NETWORK_SHARE%
echo.

:: Teste Verbindung
if not exist "%NETWORK_SHARE%" (
    echo [ERROR] Netzwerk-Share nicht erreichbar!
    echo [ERROR] %NETWORK_SHARE%
    echo.
    echo Moeglicherweise:
    echo   - Keine Netzwerk-Verbindung
    echo   - Fehlende Zugriffsrechte
    echo   - Share nicht gemountet
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] Netzwerk-Share erreichbar
echo.

:: PowerShell Script ausfuehren
echo [INFO] Starte PSRemoting-Konfiguration...
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%NETWORK_SHARE%\Configure-PSRemoting.ps1"

if %errorLevel% EQU 0 (
    echo.
    echo =====================================================================
    echo [SUCCESS] PSRemoting-Konfiguration erfolgreich!
    echo =====================================================================
    echo.
) else (
    echo.
    echo =====================================================================
    echo [ERROR] PSRemoting-Konfiguration fehlgeschlagen!
    echo =====================================================================
    echo.
)

pause
