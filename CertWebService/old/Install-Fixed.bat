@echo off
title Certificate WebService v2.3.0 - Enhanced Installer

echo ========================================
echo Certificate WebService v2.3.0 Installer
echo Read-Only Mode für 3 autorisierte Server
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrator privileges required!
    echo Please right-click and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo [INFO] Administrator privileges confirmed
echo [INFO] Starting installation...
echo.

REM Setup temporary directory
set TEMP_DIR=C:\Temp\CertWebService-Install
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo [INFO] Copying installation files to: %TEMP_DIR%
xcopy "%~dp0*" "%TEMP_DIR%\" /e /i /h /y >nul

REM Execute simplified installation
echo [INFO] Installing Certificate WebService (Simplified Setup)...
PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Setup-Simple.ps1"

if %errorLevel% equ 0 (
    echo [SUCCESS] Certificate WebService installation completed!
    echo [INFO] Dashboard: http://%COMPUTERNAME%:9080/
    echo [INFO] API: http://%COMPUTERNAME%:9080/certificates.json
) else (
    echo [ERROR] Certificate WebService installation failed!
    goto cleanup
)

echo.
echo [INFO] Setting up scheduled task for daily certificate scanning...
if exist "%TEMP_DIR%\Scripts\Setup-ScheduledTask-CertScan.ps1" (
    PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Scripts\Setup-ScheduledTask-CertScan.ps1"
    
    if %errorLevel% equ 0 (
        echo [SUCCESS] Scheduled task installation completed!
        echo [INFO] Daily certificate scan will run at 06:00
    ) else (
        echo [WARNING] Scheduled task installation failed!
        echo [INFO] Certificate WebService will still work, but automatic updates disabled
    )
) else (
    echo [WARNING] Scheduled task script not found - skipping
)

echo.
echo ========================================
echo Installation Summary
echo ========================================
echo.
echo Certificate WebService v2.3.0 is now installed and running:
echo.
echo   🔒 Read-Only Mode: Nur GET/HEAD/OPTIONS erlaubt
echo   👥 Autorisierte Server:
echo      - ITSCMGMT03.srv.meduniwien.ac.at
echo      - ITSC020.cc.meduniwien.ac.at  
echo      - itsc049.uvw.meduniwien.ac.at
echo.
echo   🌐 API Endpoints:
echo      - http://%COMPUTERNAME%:9080/certificates.json
echo      - http://%COMPUTERNAME%:9080/health.json
echo      - http://%COMPUTERNAME%:9080/summary.json
echo.
echo   ⏰ Scheduled Task: Daily certificate scan at 06:00
echo   📊 Log Location: C:\inetpub\CertWebService\Logs\
echo.
echo Integration: Ready for Certificate Surveillance System (CertSurv)
echo.

:cleanup
echo [INFO] Cleaning up temporary files...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

echo.
echo Installation process completed.
pause