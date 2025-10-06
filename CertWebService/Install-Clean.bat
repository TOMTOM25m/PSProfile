@echo off
title CertWebService v2.3.0 Installer - Read-Only Mode
color 0a

echo =====================================
echo CertWebService v2.3.0 Setup
echo Read-Only Mode fuer 3 Server  
echo =====================================
echo.

REM Handle UNC path issue - copy files to temp directory first
set "INSTALL_DIR=%~dp0"
set "TEMP_DIR=%TEMP%\CertWebService-Install"
set "SCRIPT_FILE=%TEMP_DIR%\Setup-Simple.ps1"

echo [INFO] Source directory: %INSTALL_DIR%
echo [INFO] Temporary directory: %TEMP_DIR%
echo.

REM Create temporary directory and copy files
echo [INFO] Preparing installation files...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%" 2>nul

REM Copy PowerShell script to temp directory
if not exist "%INSTALL_DIR%Setup-Simple.ps1" (
    echo [ERROR] PowerShell script not found: %INSTALL_DIR%Setup-Simple.ps1
    echo [ERROR] Please ensure Setup-Simple.ps1 is in the source directory
    goto :failure
)

copy "%INSTALL_DIR%Setup-Simple.ps1" "%TEMP_DIR%\" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy PowerShell script to temporary directory
    goto :failure
)

echo [INFO] Installation files copied to: %TEMP_DIR%

echo [INFO] Checking PowerShell availability...

REM Test PowerShell availability
powershell.exe -NoProfile -Command "Write-Host 'PowerShell OK'" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell not available or accessible
    echo [ERROR] Please ensure PowerShell is installed and accessible
    goto :failure
)

echo [INFO] PowerShell found - Starting installation...
echo [INFO] Installing Certificate WebService...
echo.

REM Execute the PowerShell script from temp directory with enhanced error handling
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { & '%SCRIPT_FILE%'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } catch { Write-Host '[ERROR] Installation failed:' $_.Exception.Message -ForegroundColor Red; exit 1 }"

set "INSTALL_RESULT=%errorlevel%"

REM Cleanup temporary files
echo.
echo [INFO] Cleaning up temporary files...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" 2>nul

echo.
if %INSTALL_RESULT% equ 0 (
    echo =====================================
    echo Installation completed successfully!
    echo =====================================
    echo.
    echo Service URL: http://localhost:9080
    echo API Endpoint: http://localhost:9080/certificates.json
    echo Health Check: http://localhost:9080/health.json
    echo.
    echo Read-Only Mode: Active for 3 servers
    echo - ITSCMGMT03.srv.meduniwien.ac.at
    echo - ITSC020.cc.meduniwien.ac.at  
    echo - itsc049.uvw.meduniwien.ac.at
    echo.
    goto :success
) else (
    goto :failure
)

:success
echo [SUCCESS] CertWebService v2.3.0 installed successfully!
echo.
goto :end

:failure
echo =====================================
echo Installation failed!
echo =====================================
echo.
echo Please check the error messages above.
echo Make sure you:
echo - Run this as Administrator
echo - Have PowerShell 5.1 or later installed
echo - Have IIS features available
echo.

:end
echo.
echo Installation process completed.
echo Press any key to continue . . .
pause >nul
exit /b %INSTALL_RESULT%