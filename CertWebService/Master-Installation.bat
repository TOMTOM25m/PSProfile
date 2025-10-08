@echo off
:: =================================================================
:: Master-Installation.bat
:: Automatisierte Installation aller Server-Komponenten
:: =================================================================
:: Author:  Flecki (Tom) Garnreiter
:: Version: v1.0.0
:: Date:    2025-10-08
:: =================================================================
:: 
:: Installiert nacheinander:
::   1. PowerShell Profile Reset
::   2. PSRemoting Konfiguration
::   3. CertWebService Setup
::
:: =================================================================

setlocal enabledelayedexpansion

:: Farben und Symbols (Unicode-sicher)
set "SUCCESS=[OK]"
set "ERROR=[ERROR]"
set "INFO=[INFO]"
set "WARN=[WARN]"

:: Zaehler fuer Statistik
set /a TOTAL_STEPS=3
set /a SUCCESS_COUNT=0
set /a ERROR_COUNT=0

:: Log-Datei
set "LOG_DIR=C:\Temp\Installation-Logs"
set "LOG_FILE=%LOG_DIR%\Master-Installation_%DATE:~-4,4%-%DATE:~-7,2%-%DATE:~-10,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%.log"
set "LOG_FILE=%LOG_FILE: =0%"

echo.
echo =====================================================================
echo   MASTER-INSTALLATION - MedUni Wien IT-Infrastructure
echo   Version 1.0.0
echo =====================================================================
echo.
echo   Installiert:
echo     [1] PowerShell Profile Reset
echo     [2] PSRemoting Configuration
echo     [3] CertWebService Setup
echo.
echo =====================================================================
echo.

:: Log-Verzeichnis erstellen
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" 2>nul
    if errorlevel 1 (
        echo %WARN% Konnte Log-Verzeichnis nicht erstellen: %LOG_DIR%
        set "LOG_FILE=nul"
    )
)

:: Admin-Rechte pruefen
echo %INFO% Pruefe Administrator-Rechte...
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo %ERROR% Administrator-Rechte erforderlich!
    echo.
    echo Bitte diese Datei als Administrator ausfuehren:
    echo   - Rechtsklick auf Master-Installation.bat
    echo   - "Als Administrator ausfuehren"
    echo.
    pause
    exit /b 1
)
echo %SUCCESS% Administrator-Rechte vorhanden
echo.

:: Log-Header
echo ===================================================================== >> "%LOG_FILE%" 2>nul
echo Master-Installation gestartet: %DATE% %TIME% >> "%LOG_FILE%" 2>nul
echo Hostname: %COMPUTERNAME% >> "%LOG_FILE%" 2>nul
echo User: %USERNAME% >> "%LOG_FILE%" 2>nul
echo ===================================================================== >> "%LOG_FILE%" 2>nul
echo. >> "%LOG_FILE%" 2>nul

:: Netzwerk-Share Basis-Pfad
set "NETWORK_BASE=\\itscmgmt03.srv.meduniwien.ac.at\iso"

:: Netzwerk-Zugriff pruefen
echo %INFO% Pruefe Netzwerk-Zugriff zu: %NETWORK_BASE%
if not exist "%NETWORK_BASE%" (
    echo.
    echo %ERROR% Netzwerk-Share nicht erreichbar: %NETWORK_BASE%
    echo.
    echo Moeglicherweise:
    echo   - Keine Netzwerk-Verbindung
    echo   - Fehlende Zugriffsrechte
    echo   - Share nicht gemountet
    echo.
    echo [ERROR] Netzwerk-Share nicht erreichbar >> "%LOG_FILE%" 2>nul
    pause
    exit /b 1
)
echo %SUCCESS% Netzwerk-Share erreichbar
echo.
echo. >> "%LOG_FILE%" 2>nul

:: =================================================================
:: INSTALLATION 1: PowerShell Profile Reset
:: =================================================================

echo =====================================================================
echo   [1/3] PowerShell Profile Reset
echo =====================================================================
echo.

set "SCRIPT_1=%NETWORK_BASE%\PROD\ResetProfile\Reset-PowerShellProfiles.ps1"

echo %INFO% Script: %SCRIPT_1%
echo [1/3] PowerShell Profile Reset >> "%LOG_FILE%" 2>nul
echo Script: %SCRIPT_1% >> "%LOG_FILE%" 2>nul

:: Pruefe ob Script existiert
if not exist "%SCRIPT_1%" (
    echo %ERROR% Script nicht gefunden: %SCRIPT_1%
    echo [ERROR] Script nicht gefunden >> "%LOG_FILE%" 2>nul
    set /a ERROR_COUNT+=1
    goto :STEP2
)

echo %INFO% Starte PowerShell Script...
echo.

:: Fuehre PowerShell Script aus (mit automatischer Bestaetigung)
echo. | powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_1%" >> "%LOG_FILE%" 2>&1
set "EXIT_CODE_1=%errorLevel%"

echo.
if %EXIT_CODE_1% EQU 0 (
    echo %SUCCESS% PowerShell Profile Reset erfolgreich
    echo [SUCCESS] PowerShell Profile Reset erfolgreich ^(Exit Code: 0^) >> "%LOG_FILE%" 2>nul
    set /a SUCCESS_COUNT+=1
) else (
    echo %ERROR% PowerShell Profile Reset fehlgeschlagen ^(Exit Code: %EXIT_CODE_1%^)
    echo [ERROR] PowerShell Profile Reset fehlgeschlagen ^(Exit Code: %EXIT_CODE_1%^) >> "%LOG_FILE%" 2>nul
    set /a ERROR_COUNT+=1
    
    echo.
    echo Moechten Sie trotzdem fortfahren? [J/N]:
    choice /C JN /N /M "Ihre Wahl: "
    if errorlevel 2 (
        echo Installation abgebrochen durch Benutzer
        echo [INFO] Installation abgebrochen durch Benutzer >> "%LOG_FILE%" 2>nul
        goto :END
    )
)

echo.
echo. >> "%LOG_FILE%" 2>nul

:STEP2
:: =================================================================
:: INSTALLATION 2: PSRemoting Configuration
:: =================================================================

echo =====================================================================
echo   [2/3] PSRemoting Configuration
echo =====================================================================
echo.

set "SCRIPT_2=%NETWORK_BASE%\PSremotingAMServer\Install-PSRemoting.bat"

echo %INFO% Script: %SCRIPT_2%
echo [2/3] PSRemoting Configuration >> "%LOG_FILE%" 2>nul
echo Script: %SCRIPT_2% >> "%LOG_FILE%" 2>nul

:: Pruefe ob Script existiert
if not exist "%SCRIPT_2%" (
    echo %ERROR% Script nicht gefunden: %SCRIPT_2%
    echo [ERROR] Script nicht gefunden >> "%LOG_FILE%" 2>nul
    set /a ERROR_COUNT+=1
    goto :STEP3
)

echo %INFO% Starte PSRemoting Installation...
echo.

:: Fuehre Batch aus (ruft PowerShell intern auf, mit automatischer Bestaetigung)
echo. | call "%SCRIPT_2%" >> "%LOG_FILE%" 2>&1
set "EXIT_CODE_2=%errorLevel%"

echo.
if %EXIT_CODE_2% EQU 0 (
    echo %SUCCESS% PSRemoting Configuration erfolgreich
    echo [SUCCESS] PSRemoting Configuration erfolgreich ^(Exit Code: 0^) >> "%LOG_FILE%" 2>nul
    set /a SUCCESS_COUNT+=1
) else (
    echo %ERROR% PSRemoting Configuration fehlgeschlagen ^(Exit Code: %EXIT_CODE_2%^)
    echo [ERROR] PSRemoting Configuration fehlgeschlagen ^(Exit Code: %EXIT_CODE_2%^) >> "%LOG_FILE%" 2>nul
    set /a ERROR_COUNT+=1
    
    echo.
    echo Moechten Sie trotzdem fortfahren? [J/N]:
    choice /C JN /N /M "Ihre Wahl: "
    if errorlevel 2 (
        echo Installation abgebrochen durch Benutzer
        echo [INFO] Installation abgebrochen durch Benutzer >> "%LOG_FILE%" 2>nul
        goto :END
    )
)

echo.
echo. >> "%LOG_FILE%" 2>nul

:STEP3
:: =================================================================
:: INSTALLATION 3: CertWebService Setup
:: =================================================================

echo =====================================================================
echo   [3/3] CertWebService Setup
echo =====================================================================
echo.

set "SCRIPT_3=%NETWORK_BASE%\CertWebService\Install.bat"

echo %INFO% Script: %SCRIPT_3%
echo [3/3] CertWebService Setup >> "%LOG_FILE%" 2>nul
echo Script: %SCRIPT_3% >> "%LOG_FILE%" 2>nul

:: Pruefe ob Script existiert
if not exist "%SCRIPT_3%" (
    echo %ERROR% Script nicht gefunden: %SCRIPT_3%
    echo [ERROR] Script nicht gefunden >> "%LOG_FILE%" 2>nul
    set /a ERROR_COUNT+=1
    goto :END
)

echo %INFO% Starte CertWebService Installation...
echo.

:: Fuehre Batch aus (ruft PowerShell intern auf, mit automatischer Bestaetigung)
echo. | call "%SCRIPT_3%" >> "%LOG_FILE%" 2>&1
set "EXIT_CODE_3=%errorLevel%"

echo.
if %EXIT_CODE_3% EQU 0 (
    echo %SUCCESS% CertWebService Setup erfolgreich
    echo [SUCCESS] CertWebService Setup erfolgreich ^(Exit Code: 0^) >> "%LOG_FILE%" 2>nul
    set /a SUCCESS_COUNT+=1
) else (
    echo %ERROR% CertWebService Setup fehlgeschlagen ^(Exit Code: %EXIT_CODE_3%^)
    echo [ERROR] CertWebService Setup fehlgeschlagen ^(Exit Code: %EXIT_CODE_3%^) >> "%LOG_FILE%" 2>nul
    set /a ERROR_COUNT+=1
)

echo.
echo. >> "%LOG_FILE%" 2>nul

:END
:: =================================================================
:: ZUSAMMENFASSUNG
:: =================================================================

echo =====================================================================
echo   INSTALLATION ABGESCHLOSSEN
echo =====================================================================
echo.

echo Statistik:
echo   - Gesamt: %TOTAL_STEPS% Installationen
echo   - Erfolgreich: %SUCCESS_COUNT%
echo   - Fehlgeschlagen: %ERROR_COUNT%
echo.

echo. >> "%LOG_FILE%" 2>nul
echo ===================================================================== >> "%LOG_FILE%" 2>nul
echo Installation abgeschlossen: %DATE% %TIME% >> "%LOG_FILE%" 2>nul
echo Statistik: >> "%LOG_FILE%" 2>nul
echo   - Gesamt: %TOTAL_STEPS% >> "%LOG_FILE%" 2>nul
echo   - Erfolgreich: %SUCCESS_COUNT% >> "%LOG_FILE%" 2>nul
echo   - Fehlgeschlagen: %ERROR_COUNT% >> "%LOG_FILE%" 2>nul
echo ===================================================================== >> "%LOG_FILE%" 2>nul

if %ERROR_COUNT% EQU 0 (
    echo %SUCCESS% Alle Installationen erfolgreich abgeschlossen!
    echo.
    echo Naechste Schritte:
    echo   1. System neu starten empfohlen
    echo   2. Tasks pruefen: Get-ScheduledTask -TaskName "CertWebService*"
    echo   3. PSRemoting testen: Test-WSMan -ComputerName localhost
    echo   4. CertWebService: http://localhost:9080
    echo.
    echo [SUCCESS] Alle Installationen erfolgreich! >> "%LOG_FILE%" 2>nul
) else (
    echo %WARN% Installation mit Fehlern abgeschlossen
    echo.
    echo Bitte Log-Datei pruefen: %LOG_FILE%
    echo.
    echo [WARN] Installation mit Fehlern abgeschlossen >> "%LOG_FILE%" 2>nul
)

echo Log-Datei: %LOG_FILE%
echo.

pause

endlocal
exit /b %ERROR_COUNT%
