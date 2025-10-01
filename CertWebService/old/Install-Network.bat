@echo off
title Certificate WebService v2.3.0

echo Certificate WebService v2.3.0 Installer
echo ========================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Administrator privileges required!
    pause
    exit /b 1
)

set TEMP_DIR=C:\Temp\CertWebService
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

xcopy "%~dp0*" "%TEMP_DIR%\" /e /i /h /y >nul

PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Setup.ps1"

if %errorLevel% equ 0 (
    echo Installation completed successfully!
    echo Access: http://%COMPUTERNAME%:9080/
) else (
    echo Installation failed!
)
PowerShell.exe -ExecutionPolicy Bypass -File "%TEMP_DIR%\Setup-ScheduledTask-CertScan.ps1"

if %errorLevel% equ 0 (
    echo Installation TaskScheduler completed successfully!
    
) else (
    echo Installation failed!
)

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
pause
