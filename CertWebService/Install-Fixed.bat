@echo off@echo off

:: =====================================================================title Certificate WebService v2.3.0 - Enhanced Installer

:: CertWebService Installation Launcher

:: Version: 2.4.1 (Regelwerk v10.0.3)echo ========================================

:: =====================================================================echo Certificate WebService v2.3.0 Installer

echo Read-Only Mode für 3 autorisierte Server

title CertWebService Installation v2.4.1echo ========================================

echo.

echo =====================================================================

echo   CertWebService Installation v2.4.1REM Check for administrator privileges

echo   Regelwerk v10.0.3 Compliantnet session >nul 2>&1

echo =====================================================================if %errorLevel% neq 0 (

echo.    echo [ERROR] Administrator privileges required!

    echo Please right-click and select "Run as Administrator"

:: Admin-Rechte pruefen    echo.

net session >nul 2>&1    pause

if %errorLevel% NEQ 0 (    exit /b 1

    echo [ERROR] Administrator-Rechte erforderlich!)

    echo.

    echo Bitte diese Datei als Administrator ausfuehren:echo [INFO] Administrator privileges confirmed

    echo   - Rechtsklick auf Install.batecho [INFO] Starting installation...

    echo   - "Als Administrator ausfuehren"echo.

    echo.

    pauseREM Setup temporary directory

    exit /b 1set TEMP_DIR=C:\Temp\CertWebService-Install

)if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

mkdir "%TEMP_DIR%"

echo [INFO] Administrator-Rechte: OK

echo.echo [INFO] Copying installation files to: %TEMP_DIR%

xcopy "%~dp0*" "%TEMP_DIR%\" /e /i /h /y >nul

:: Bestimme Script-Verzeichnis (Remove trailing backslash if present)

set "SCRIPT_DIR=%~dp0"REM Execute simplified installation

if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"echo [INFO] Installing Certificate WebService (Simplified Setup)...

PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Setup-Simple.ps1"

:: Installation-Script liegt im gleichen Verzeichnis wie Install.bat

set "INSTALL_SCRIPT=%SCRIPT_DIR%\Install-CertWebService.ps1"if %errorLevel% equ 0 (

    echo [SUCCESS] Certificate WebService installation completed!

:: Pruefe ob Installation-Script existiert    echo [INFO] Dashboard: http://%COMPUTERNAME%:9080/

if not exist "%INSTALL_SCRIPT%" (    echo [INFO] API: http://%COMPUTERNAME%:9080/certificates.json

    echo [ERROR] Installation-Script nicht gefunden!) else (

    echo Erwartet: %INSTALL_SCRIPT%    echo [ERROR] Certificate WebService installation failed!

    echo.    goto cleanup

    echo Aktuelles Verzeichnis: %SCRIPT_DIR%)

    echo.

    dir "%SCRIPT_DIR%\Install*.ps1" 2>nulecho.

    echo.echo [INFO] Setting up scheduled task for daily certificate scanning...

    pauseif exist "%TEMP_DIR%\Scripts\Setup-ScheduledTask-CertScan.ps1" (

    exit /b 1    PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Scripts\Setup-ScheduledTask-CertScan.ps1"

)    

    if %errorLevel% equ 0 (

echo [INFO] Starte CertWebService Installation...        echo [SUCCESS] Scheduled task installation completed!

echo [INFO] Script: %INSTALL_SCRIPT%        echo [INFO] Daily certificate scan will run at 06:00

echo.    ) else (

        echo [WARNING] Scheduled task installation failed!

:: Starte PowerShell Installation        echo [INFO] Certificate WebService will still work, but automatic updates disabled

PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_SCRIPT%"    )

) else (

set "EXIT_CODE=%errorLevel%"    echo [WARNING] Scheduled task script not found - skipping

)

echo.

if %EXIT_CODE% EQU 0 (echo.

    echo =====================================================================echo ========================================

    echo [SUCCESS] CertWebService Installation erfolgreich!echo Installation Summary

    echo =====================================================================echo ========================================

    echo.echo.

    echo CertWebService ist jetzt verfuegbar:echo Certificate WebService v2.3.0 is now installed and running:

    echo   - Dashboard: http://%COMPUTERNAME%:9080/echo.

    echo   - API: http://%COMPUTERNAME%:9080/certificates.jsonecho   🔒 Read-Only Mode: Nur GET/HEAD/OPTIONS erlaubt

    echo   - Health: http://%COMPUTERNAME%:9080/health.jsonecho   👥 Autorisierte Server:

    echo.echo      - ITSCMGMT03.srv.meduniwien.ac.at

    echo Scheduled Tasks:echo      - ITSC020.cc.meduniwien.ac.at  

    echo   - CertWebService-WebServer (At Startup)echo      - itsc049.uvw.meduniwien.ac.at

    echo   - CertWebService-DailyScan (Daily 06:00)echo.

    echo.echo   🌐 API Endpoints:

    echo Logs:echo      - http://%COMPUTERNAME%:9080/certificates.json

    echo   - Installation: C:\inetpub\CertWebService\Logs\echo      - http://%COMPUTERNAME%:9080/health.json

    echo.echo      - http://%COMPUTERNAME%:9080/summary.json

) else (echo.

    echo =====================================================================echo   ⏰ Scheduled Task: Daily certificate scan at 06:00

    echo [ERROR] CertWebService Installation fehlgeschlagen!echo   📊 Log Location: C:\inetpub\CertWebService\Logs\

    echo =====================================================================echo.

    echo.echo Integration: Ready for Certificate Surveillance System (CertSurv)

    echo Exit Code: %EXIT_CODE%echo.

    echo.

):cleanup

echo [INFO] Cleaning up temporary files...

exit /b %EXIT_CODE%if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"


echo.
echo Installation process completed.
pause