@echo off
echo ========================================
echo CertWebService Version Switcher
echo ========================================
echo.
echo Current Options:
echo [1] Switch to PowerShell 7.x UTF-8 Enhanced
echo [2] Switch to PowerShell 5.1 ASCII Compatible  
echo [3] Check Service Status
echo [4] Auto Switch Version
echo [5] Exit
echo.
set /p choice="Select option (1-5): "

if "%choice%"=="1" (
    echo.
    echo Switching to PowerShell 7.x UTF-8 Enhanced...
    powershell -ExecutionPolicy Bypass -File "C:\CertWebService\Dual-Version-Manager.ps1" -Action "PS7x-UTF8"
    goto :end
)

if "%choice%"=="2" (
    echo.
    echo Switching to PowerShell 5.1 ASCII Compatible...
    powershell -ExecutionPolicy Bypass -File "C:\CertWebService\Dual-Version-Manager.ps1" -Action "PS51-ASCII"
    goto :end
)

if "%choice%"=="3" (
    echo.
    echo Checking service status...
    powershell -ExecutionPolicy Bypass -File "C:\CertWebService\Dual-Version-Manager.ps1" -Action "Status"
    goto :end
)

if "%choice%"=="4" (
    echo.
    echo Auto switching version...
    powershell -ExecutionPolicy Bypass -File "C:\CertWebService\Dual-Version-Manager.ps1" -Action "Switch"
    goto :end
)

if "%choice%"=="5" (
    echo Exiting...
    goto :end
)

echo Invalid choice. Please select 1-5.
pause
goto :start

:end
echo.
echo ========================================
echo Operation completed!
echo Website URL: http://itscmgmt03.srv.meduniwien.ac.at:9080
echo ========================================
pause