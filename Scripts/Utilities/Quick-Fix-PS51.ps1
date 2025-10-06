# CertWebService Quick Fix - PowerShell 5.1 Compatible
# Repariert und startet Web-Service sofort
# Version: v1.1.2 | Stand: 02.10.2025

param(
    [switch]$Status,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Test
)

# Funktionen
function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    switch ($Type) {
        "Success" { Write-Host "[OK]  $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        "Info"    { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
        default   { Write-Host "[INFO] $Message" -ForegroundColor White }
    }
}

function Stop-CertWebServiceTasks {
    Write-Status "Stoppe bestehende Tasks..." "Info"
    try {
        Stop-ScheduledTask -TaskName "CertWebService-WebServer" -ErrorAction SilentlyContinue
        Write-Status "Web-Server Task gestoppt" "Success"
    } catch {
        Write-Status "Web-Server Task war bereits gestoppt" "Warning"
    }
}

function Test-Port9080 {
    Write-Status "Pruefe Port 9080..." "Info"
    $portCheck = netstat -an | findstr ":9080"
    if ($portCheck) {
        Write-Status "Port 9080 wird verwendet:" "Warning"
        Write-Host "      $portCheck" -ForegroundColor Gray
        return $false
    } else {
        Write-Status "Port 9080 ist frei" "Success"
        return $true
    }
}

function Start-CertWebServiceDirect {
    Write-Status "Starte Web-Service direkt..." "Info"
    $webServiceScript = "C:\CertWebService\CertWebService.ps1"

    if (-not (Test-Path $webServiceScript)) {
        Write-Status "CertWebService.ps1 nicht gefunden: $webServiceScript" "Error"
        return $null
    }

    Write-Status "Starte CertWebService.ps1 im Hintergrund..." "Info"
    
    try {
        # Einfacher Job-Start ohne komplexe ScriptBlocks
        $job = Start-Job -Name "CertWebService-Direct" -ScriptBlock {
            param($scriptPath)
            Set-Location "C:\CertWebService"
            & $scriptPath
        } -ArgumentList $webServiceScript
        
        Write-Status "Web-Service Job gestartet (ID: $($job.Id))" "Success"
        return $job
    } catch {
        Write-Status "Fehler beim Job-Start: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Test-WebServiceConnection {
    Write-Status "Teste Verbindung zu Web-Service..." "Info"
    try {
        $response = Invoke-WebRequest "http://localhost:9080/" -UseBasicParsing -TimeoutSec 10
        Write-Status "Web-Service erreichbar! Status: $($response.StatusCode)" "Success"
        Write-Host "      URL: http://localhost:9080" -ForegroundColor Cyan
        return $true
    } catch {
        Write-Status "Web-Service nicht erreichbar: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-JobOutput {
    param($Job)
    if ($Job) {
        Write-Status "Job Output:" "Info"
        $output = Receive-Job $Job -ErrorAction SilentlyContinue
        if ($output) {
            $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
        } else {
            Write-Host "      (Kein Output verfuegbar)" -ForegroundColor Gray
        }
    }
}

function Get-ScheduledTaskStatus {
    Write-Status "Scheduled Tasks Status:" "Info"
    try {
        $tasks = Get-ScheduledTask -TaskName "CertWebService*" -ErrorAction SilentlyContinue
        if ($tasks) {
            $tasks | ForEach-Object {
                Write-Host "      $($_.TaskName): $($_.State)" -ForegroundColor Gray
            }
        } else {
            Write-Status "Keine CertWebService Tasks gefunden" "Warning"
        }
    } catch {
        Write-Status "Fehler beim Abrufen der Tasks: $($_.Exception.Message)" "Error"
    }
}

# Hauptlogik
Write-Host "=== CERTWEBSERVICE QUICK FIX (PS5.1 COMPATIBLE) ===" -ForegroundColor Magenta
Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
Write-Host ""

if ($Status) {
    Get-ScheduledTaskStatus
    Test-Port9080 | Out-Null
    Test-WebServiceConnection | Out-Null
    exit
}

if ($Stop) {
    Stop-CertWebServiceTasks
    $jobs = Get-Job -Name "CertWebService-Direct" -ErrorAction SilentlyContinue
    if ($jobs) {
        Stop-Job -Name "CertWebService-Direct" -ErrorAction SilentlyContinue
        Remove-Job -Name "CertWebService-Direct" -Force -ErrorAction SilentlyContinue
        Write-Status "Background-Job gestoppt" "Success"
    }
    exit
}

if ($Test) {
    Test-WebServiceConnection | Out-Null
    exit
}

# Standard-Ablauf: Fix durchfuehren
Stop-CertWebServiceTasks
Test-Port9080 | Out-Null

$job = Start-CertWebServiceDirect
if ($job) {
    Write-Status "Warte 8 Sekunden auf Start..." "Info"
    Start-Sleep -Seconds 8
    
    $success = Test-WebServiceConnection
    if (-not $success) {
        Show-JobOutput $job
    }
} else {
    Write-Status "Job-Start fehlgeschlagen" "Error"
}

Write-Host ""
Write-Host "=== NAECHSTE SCHRITTE ===" -ForegroundColor Yellow
Write-Host "Browser oeffnen: http://localhost:9080" -ForegroundColor White
Write-Host "Job Status:      Get-Job" -ForegroundColor White
Write-Host "Status pruefen:  .\Quick-Fix-PS51.ps1 -Status" -ForegroundColor White
Write-Host "Service stoppen: .\Quick-Fix-PS51.ps1 -Stop" -ForegroundColor White