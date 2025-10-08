@echo off
REM CertWebService Enhanced Installation
REM Aktiviert PSRemoting und installiert CertWebService v2.5.0

echo === CERTWEBSERVICE ENHANCED INSTALLER ===
echo Aktiviert PSRemoting und installiert v2.5.0
echo.

REM Prüfe Administrator-Rechte
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo FEHLER: Administrator-Rechte erforderlich!
    echo Rechtsklick -^> "Als Administrator ausführen"
    pause
    exit /b 1
)

echo Administrator-Rechte: OK
echo.

REM Führe PowerShell-Installer aus
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Install-Simple.ps1" -EnablePSRemoting

echo.
echo Installation abgeschlossen!
echo Dashboard: http://localhost:9080/
pause