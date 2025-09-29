@echo off
REM Certificate WebService Installer v2.0.0-FINAL
REM Simplified Installer for Unified Setup Script
REM Author: Flecki (Tom) Garnreiter
REM Build: 2025-09-23
REM Regelwerk: v9.5.0 Compliant

title Certificate WebService Installer v2.0.0-FINAL

echo ================================================
echo Certificate WebService Installer v2.0.0-FINAL
echo Unified Installation System
echo Author: Flecki (Tom) Garnreiter  
echo Build: 2025-09-23
echo ================================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [ERROR] Administrator privileges required!
    echo [ERROR] Please run this installer as Administrator
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] Administrator privileges confirmed
echo.

REM Get server information
echo [INFO] Server: %COMPUTERNAME%
echo [INFO] User: %USERNAME%
echo [INFO] Domain: %USERDOMAIN%
echo.

REM Create local installation directory
set LOCAL_DIR=C:\Temp\CertWebService-Install
echo [SETUP] Creating local installation directory: %LOCAL_DIR%
if not exist "%LOCAL_DIR%" mkdir "%LOCAL_DIR%"

REM Copy files from network to local directory using robocopy (Regelwerk compliant)
echo [COPY] Copying installation files to local directory using robocopy...
set SOURCE_DIR=%~dp0
set SOURCE_DIR=%SOURCE_DIR:~0,-1%
robocopy "%SOURCE_DIR%" "%LOCAL_DIR%" /E /NFL /NDL /NJH /NJS /NC /NS /NP
if %errorLevel% GEQ 8 (
    echo [ERROR] Robocopy failed with error level: %errorLevel%
    echo [ERROR] Failed to copy installation files to local directory
    echo.
    pause
    exit /b 1
)
echo [SUCCESS] Files copied successfully to local directory

REM Change to local directory
cd /d "%LOCAL_DIR%"
echo [INFO] Working directory: %LOCAL_DIR%
echo.

REM Check if setup script exists
if exist "Setup.ps1" (
    echo [FOUND] Using unified Setup.ps1
    set SETUP_SCRIPT=Setup.ps1
) else if exist "Setup-WebService.ps1" (
    echo [FOUND] Using unified Setup-WebService.ps1
    set SETUP_SCRIPT=Setup-WebService.ps1
) else (
    echo [ERROR] Setup.ps1 or Setup-WebService.ps1 not found in current directory
    echo [ERROR] Please ensure the installer is in the same folder as the setup script
    echo.
    pause
    exit /b 1
)

echo [INSTALL] Starting Certificate WebService installation...
echo [INSTALL] Using script: %SETUP_SCRIPT%
echo.

REM Execute PowerShell setup script
powershell.exe -ExecutionPolicy Bypass -File "%SETUP_SCRIPT%"

REM Check if main installation was successful
if %errorLevel% EQU 0 (
    echo.
    echo [SCHEDULE] Setting up daily certificate scan task...
    
    REM Check if scheduled task setup script exists
    if exist "Setup-ScheduledTask-CertScan.ps1" (
        echo [FOUND] Running scheduled task setup...
        powershell.exe -ExecutionPolicy Bypass -File "Setup-ScheduledTask-CertScan.ps1"
        
        if !errorLevel! EQU 0 (
            echo [SUCCESS] Scheduled task created successfully
        ) else (
            echo [WARNING] Scheduled task setup failed - you can run it manually later
        )
    ) else (
        echo [WARNING] Setup-ScheduledTask-CertScan.ps1 not found - skipping scheduled task setup
    )
    echo.
    echo ================================================
    echo [SUCCESS] Installation completed successfully!
    echo ================================================
    echo.
    echo [INFO] Certificate WebService is now ready
    echo [INFO] Daily certificate scan task has been configured
    echo [INFO] Check the endpoints displayed above
    echo.
    echo [NEXT] Configure Certificate Surveillance System to use:
    echo [NEXT] http://%COMPUTERNAME%.domain:PORT/certificates.json
    echo.
    echo [CLEANUP] Removing temporary installation files...
    cd /d C:\
    rmdir /s /q "%LOCAL_DIR%" 2>nul
    echo [INFO] Cleanup completed
    echo.
) else (
    echo.
    echo ================================================
    echo [ERROR] Installation failed!
    echo ================================================
    echo.
    echo [ERROR] Setup script returned error code: %errorLevel%
    echo [ERROR] Please check the error messages above
    echo.
)

echo Press any key to close this window...
pause >nul