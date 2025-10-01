@echo off
title Certificate WebService v2.3.0 - Simple Installer

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

REM Execute installation
echo [INFO] Installing Certificate WebService...
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File "%TEMP_DIR%\Setup-Simple.ps1"

if %errorLevel% equ 0 (
    echo [SUCCESS] Certificate WebService installation completed!
    echo [INFO] Service: http://%COMPUTERNAME%:9080/
    echo [INFO] API: http://%COMPUTERNAME%:9080/certificates.json
    echo.
    echo [INFO] Read-Only Mode: Nur für 3 autorisierte Server
    echo        - ITSCMGMT03.srv.meduniwien.ac.at
    echo        - ITSC020.cc.meduniwien.ac.at  
    echo        - itsc049.uvw.meduniwien.ac.at
) else (
    echo [ERROR] Certificate WebService installation failed!
    echo Please check the error messages above.
)

echo.
echo [INFO] Cleaning up temporary files...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"

echo.
echo Installation process completed.
pause