#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService - Konsolidierte Installation
    
.DESCRIPTION
    Einheitliches Installations-Script fuer CertWebService nach Regelwerk v10.0.3
    
    Funktionen:
    - Installations-Verzeichnis Setup
    - Firewall-Konfiguration
    - URL ACL Reservierung
    - Scheduled Tasks (Web Server + Daily Scan)
    - Config-Dateien
    - Log-Verzeichnis
    
.PARAMETER InstallPath
    Installations-Pfad (Default: C:\CertWebService)
    
.PARAMETER WebServicePort
    HTTP Port (Default: 9080)
    
.PARAMETER Mode
    Installation Mode:
    - "Full"     : Vollstaendige Installation (Default)
    - "Update"   : Nur Update (keine Tasks/Firewall)
    - "Repair"   : Repariert bestehende Installation
    - "Remove"   : Deinstalliert CertWebService
    
.EXAMPLE
    .\Install-CertWebService.ps1
    Vollstaendige Installation mit Defaults
    
.EXAMPLE
    .\Install-CertWebService.ps1 -Mode Update
    Nur Scripts und Configs aktualisieren
    
.EXAMPLE
    .\Install-CertWebService.ps1 -Mode Remove
    Deinstalliert CertWebService komplett
    
.NOTES
    Author:  Flecki (Tom) Garnreiter
    Version: v1.0.0
    Date:    2025-10-08
    Regelwerk: v10.0.3 (§5, §14, §19)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\CertWebService",
    
    [Parameter(Mandatory=$false)]
    [int]$WebServicePort = 9080,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Full", "Update", "Repair", "Remove")]
    [string]$Mode = "Full"
)

#region Configuration

$script:Version = "v2.6.0"
$script:Regelwerk = "v10.0.3"

# Files to install
$script:FilesToCopy = @(
    "CertWebService.ps1",
    "ScanCertificates.ps1",
    "Setup-CertWebService-Scheduler.ps1"
)

# Logging
$script:LogFile = Join-Path $PSScriptRoot "Install-CertWebService_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

#endregion

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "FATAL")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to file
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8
    } catch {
        # Ignore logging errors
    }
    
    # Console output
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "FATAL"   { Write-Host $logMessage -ForegroundColor Red -BackgroundColor Black }
        default   { Write-Host $logMessage -ForegroundColor Gray }
    }
}

function Show-Banner {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Installation Functions

function Install-DirectoryStructure {
    Show-Banner "SCHRITT 1: VERZEICHNIS-STRUKTUR"
    Write-Log "Erstelle Verzeichnis-Struktur..." -Level INFO
    
    $directories = @(
        $InstallPath,
        (Join-Path $InstallPath "Logs"),
        (Join-Path $InstallPath "Config"),
        (Join-Path $InstallPath "Backup")
    )
    
    foreach ($dir in $directories) {
        try {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Log "Verzeichnis erstellt: $dir" -Level SUCCESS
            } else {
                Write-Log "Verzeichnis existiert bereits: $dir" -Level INFO
            }
        } catch {
            Write-Log "Fehler beim Erstellen von $dir - $($_.Exception.Message)" -Level ERROR
            return $false
        }
    }
    
    Write-Host ""
    return $true
}

function Install-Files {
    Show-Banner "SCHRITT 2: DATEIEN KOPIEREN"
    Write-Log "Kopiere Dateien..." -Level INFO
    
    $sourceDir = $PSScriptRoot
    $copiedCount = 0
    
    foreach ($file in $script:FilesToCopy) {
        $sourcePath = Join-Path $sourceDir $file
        $targetPath = Join-Path $InstallPath $file
        
        try {
            if (Test-Path $sourcePath) {
                # Backup wenn Zieldatei existiert
                if (Test-Path $targetPath) {
                    $backupDir = Join-Path $InstallPath "Backup"
                    $backupFile = "$file.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
                    $backupPath = Join-Path $backupDir $backupFile
                    
                    Copy-Item -Path $targetPath -Destination $backupPath -Force
                    Write-Log "Backup erstellt: $backupFile" -Level INFO
                }
                
                # Kopiere Datei
                Copy-Item -Path $sourcePath -Destination $targetPath -Force
                Write-Log "Datei kopiert: $file" -Level SUCCESS
                $copiedCount++
            } else {
                Write-Log "Quelldatei nicht gefunden: $file" -Level WARNING
            }
        } catch {
            Write-Log "Fehler beim Kopieren von $file - $($_.Exception.Message)" -Level ERROR
        }
    }
    
    Write-Host ""
    Write-Log "$copiedCount von $($script:FilesToCopy.Count) Dateien kopiert" -Level INFO
    return $copiedCount -gt 0
}

function Install-Config {
    Show-Banner "SCHRITT 3: KONFIGURATION"
    Write-Log "Erstelle Konfiguration..." -Level INFO
    
    $configPath = Join-Path $InstallPath "Config\Config-CertWebService.json"
    
    try {
        # Config Object
        $config = @{
            Version = $script:Version
            Regelwerk = $script:Regelwerk
            InstallDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            InstallPath = $InstallPath
            WebService = @{
                HttpPort = $WebServicePort
                HttpsPort = 9443
                EnableHTTPS = $false
            }
            Logging = @{
                LogPath = (Join-Path $InstallPath "Logs")
                RetentionDays = 30
                Level = "INFO"
            }
            Certificates = @{
                Stores = @("LocalMachine\My", "LocalMachine\WebHosting", "CurrentUser\My")
                MinDaysWarning = 90
                MinDaysCritical = 30
            }
            ScheduledTasks = @{
                WebServerTaskName = "CertWebService-WebServer"
                DailyScanTaskName = "CertWebService-DailyScan"
                ScanTime = "06:00"
            }
        }
        
        # Write Config
        $config | ConvertTo-Json -Depth 4 | Out-File -FilePath $configPath -Encoding UTF8 -Force
        Write-Log "Config erstellt: $configPath" -Level SUCCESS
        
        Write-Host "  InstallPath: $InstallPath" -ForegroundColor Gray
        Write-Host "  WebServicePort: $WebServicePort" -ForegroundColor Gray
        Write-Host "  Version: $script:Version" -ForegroundColor Gray
        Write-Host "  Regelwerk: $script:Regelwerk" -ForegroundColor Gray
        
        Write-Host ""
        return $true
    } catch {
        Write-Log "Fehler beim Erstellen der Config: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Install-FirewallRule {
    Show-Banner "SCHRITT 4: FIREWALL-REGEL"
    Write-Log "Konfiguriere Firewall..." -Level INFO
    
    $ruleName = "CertWebService-HTTP-$WebServicePort"
    
    try {
        # Entferne alte Regel falls vorhanden
        $existingRule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
        if ($existingRule) {
            Remove-NetFirewallRule -Name $ruleName -ErrorAction Stop
            Write-Log "Alte Firewall-Regel entfernt" -Level INFO
        }
        
        # Erstelle neue Regel
        New-NetFirewallRule `
            -Name $ruleName `
            -DisplayName "CertWebService HTTP (Port $WebServicePort)" `
            -Description "CertWebService Certificate Surveillance - Regelwerk $script:Regelwerk" `
            -Protocol TCP `
            -LocalPort $WebServicePort `
            -Direction Inbound `
            -Action Allow `
            -Profile Any `
            -ErrorAction Stop | Out-Null
        
        Write-Log "Firewall-Regel erstellt: $ruleName (Port $WebServicePort)" -Level SUCCESS
        
        Write-Host "  Name: $ruleName" -ForegroundColor Gray
        Write-Host "  Port: $WebServicePort/TCP" -ForegroundColor Gray
        Write-Host "  Direction: Inbound" -ForegroundColor Gray
        Write-Host "  Action: Allow" -ForegroundColor Gray
        
        Write-Host ""
        return $true
    } catch {
        Write-Log "Fehler bei Firewall-Konfiguration: $($_.Exception.Message)" -Level WARNING
        return $false
    }
}

function Install-URLACL {
    Show-Banner "SCHRITT 5: URL ACL RESERVIERUNG"
    Write-Log "Konfiguriere URL ACL..." -Level INFO
    
    $httpUrl = "http://+:$WebServicePort/"
    
    try {
        # Entferne existierende ACL
        $existingAcl = netsh http show urlacl url=$httpUrl 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Entferne existierende ACL..." -ForegroundColor Cyan
            netsh http delete urlacl url=$httpUrl | Out-Null
        }
        
        # Erstelle neue ACL
        Write-Host "  Erstelle URL ACL..." -ForegroundColor Cyan
        $result = netsh http add urlacl url=$httpUrl user="NT AUTHORITY\SYSTEM" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "URL ACL reserviert: $httpUrl" -Level SUCCESS
            Write-Host "  URL: $httpUrl" -ForegroundColor Gray
            Write-Host "  User: NT AUTHORITY\SYSTEM" -ForegroundColor Gray
        } else {
            Write-Log "Fehler bei URL ACL Reservierung: $result" -Level WARNING
        }
        
        Write-Host ""
        return $true
    } catch {
        Write-Log "Fehler bei URL ACL Konfiguration: $($_.Exception.Message)" -Level WARNING
        return $false
    }
}

function Install-ScheduledTasks {
    Show-Banner "SCHRITT 6: SCHEDULED TASKS"
    Write-Log "Erstelle Scheduled Tasks..." -Level INFO
    
    $schedulerScript = Join-Path $InstallPath "Setup-CertWebService-Scheduler.ps1"
    
    if (-not (Test-Path $schedulerScript)) {
        Write-Log "Scheduler-Script nicht gefunden: $schedulerScript" -Level ERROR
        return $false
    }
    
    try {
        Write-Host "  Starte Scheduler-Setup..." -ForegroundColor Cyan
        Write-Host ""
        
        # Fuehre Scheduler-Setup aus
        & $schedulerScript -InstallPath $InstallPath -WebServicePort $WebServicePort
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Scheduled Tasks erfolgreich erstellt" -Level SUCCESS
            return $true
        } else {
            Write-Log "Scheduler-Setup mit Fehlern beendet" -Level WARNING
            return $false
        }
    } catch {
        Write-Log "Fehler beim Erstellen der Scheduled Tasks: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

#endregion

#region Removal Functions

function Remove-CertWebService {
    Show-Banner "CERTWEBSERVICE DEINSTALLATION"
    Write-Log "Starte Deinstallation..." -Level INFO
    
    # Stop and remove tasks
    Write-Host "[REMOVE 1] Scheduled Tasks..." -ForegroundColor Yellow
    try {
        $tasks = Get-ScheduledTask -TaskName "CertWebService*" -ErrorAction SilentlyContinue
        foreach ($task in $tasks) {
            if ($task.State -eq "Running") {
                Stop-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
            }
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Task entfernt: $($task.TaskName)" -Level SUCCESS
        }
    } catch {
        Write-Log "Fehler beim Entfernen der Tasks: $($_.Exception.Message)" -Level ERROR
    }
    
    # Remove firewall rule
    Write-Host ""
    Write-Host "[REMOVE 2] Firewall-Regel..." -ForegroundColor Yellow
    try {
        $ruleName = "CertWebService-HTTP-$WebServicePort"
        Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
        Write-Log "Firewall-Regel entfernt: $ruleName" -Level SUCCESS
    } catch {
        Write-Log "Fehler beim Entfernen der Firewall-Regel: $($_.Exception.Message)" -Level ERROR
    }
    
    # Remove URL ACL
    Write-Host ""
    Write-Host "[REMOVE 3] URL ACL..." -ForegroundColor Yellow
    try {
        $httpUrl = "http://+:$WebServicePort/"
        netsh http delete urlacl url=$httpUrl 2>&1 | Out-Null
        Write-Log "URL ACL entfernt: $httpUrl" -Level SUCCESS
    } catch {
        Write-Log "Fehler beim Entfernen der URL ACL: $($_.Exception.Message)" -Level ERROR
    }
    
    # Remove files
    Write-Host ""
    Write-Host "[REMOVE 4] Installations-Verzeichnis..." -ForegroundColor Yellow
    Write-Host "  Moechten Sie das Installations-Verzeichnis loeschen?" -ForegroundColor Yellow
    Write-Host "  Path: $InstallPath" -ForegroundColor Gray
    Write-Host "  (J/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -eq "J" -or $response -eq "j") {
        try {
            if (Test-Path $InstallPath) {
                Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop
                Write-Log "Installations-Verzeichnis geloescht: $InstallPath" -Level SUCCESS
            }
        } catch {
            Write-Log "Fehler beim Loeschen des Verzeichnisses: $($_.Exception.Message)" -Level ERROR
        }
    } else {
        Write-Log "Installations-Verzeichnis behalten" -Level INFO
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host "  DEINSTALLATION ABGESCHLOSSEN" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host ""
}

#endregion

#region Main Execution

# Script Start
Show-Banner "CERTWEBSERVICE INSTALLATION $script:Version"

Write-Host "Hostname: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "User: $env:USERNAME" -ForegroundColor Gray
Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Mode: $Mode" -ForegroundColor Gray
Write-Host "InstallPath: $InstallPath" -ForegroundColor Gray
Write-Host "Port: $WebServicePort" -ForegroundColor Gray
Write-Host "Log-Datei: $script:LogFile" -ForegroundColor Gray
Write-Host ""

Write-Log "=== INSTALLATION GESTARTET ===" -Level INFO
Write-Log "Version: $script:Version | Regelwerk: $script:Regelwerk" -Level INFO
Write-Log "Hostname: $env:COMPUTERNAME | User: $env:USERNAME" -Level INFO
Write-Log "Mode: $Mode | InstallPath: $InstallPath | Port: $WebServicePort" -Level INFO

# Mode Handling
switch ($Mode) {
    "Remove" {
        Remove-CertWebService
        exit 0
    }
    
    "Full" {
        Write-Host "[MODE] Vollstaendige Installation" -ForegroundColor Cyan
        Write-Host ""
        
        $step1 = Install-DirectoryStructure
        if (-not $step1) { Write-Log "Abbruch: Verzeichnis-Struktur fehlgeschlagen" -Level FATAL; exit 1 }
        
        $step2 = Install-Files
        if (-not $step2) { Write-Log "Abbruch: Dateien kopieren fehlgeschlagen" -Level FATAL; exit 1 }
        
        $step3 = Install-Config
        if (-not $step3) { Write-Log "Warnung: Config fehlgeschlagen" -Level WARNING }
        
        $step4 = Install-FirewallRule
        if (-not $step4) { Write-Log "Warnung: Firewall fehlgeschlagen" -Level WARNING }
        
        $step5 = Install-URLACL
        if (-not $step5) { Write-Log "Warnung: URL ACL fehlgeschlagen" -Level WARNING }
        
        $step6 = Install-ScheduledTasks
        if (-not $step6) { Write-Log "Warnung: Scheduled Tasks fehlgeschlagen" -Level WARNING }
    }
    
    "Update" {
        Write-Host "[MODE] Update-Installation (nur Dateien)" -ForegroundColor Cyan
        Write-Host ""
        
        $step1 = Install-DirectoryStructure
        $step2 = Install-Files
        $step3 = Install-Config
        
        if (-not $step2) {
            Write-Log "Update fehlgeschlagen" -Level ERROR
            exit 1
        }
    }
    
    "Repair" {
        Write-Host "[MODE] Reparatur-Installation" -ForegroundColor Cyan
        Write-Host ""
        
        $step1 = Install-DirectoryStructure
        $step2 = Install-Files
        $step3 = Install-Config
        $step4 = Install-FirewallRule
        $step5 = Install-URLACL
        $step6 = Install-ScheduledTasks
    }
}

# Final Summary
Show-Banner "INSTALLATION ABGESCHLOSSEN"

Write-Host "NAECHSTE SCHRITTE:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Tasks pruefen:" -ForegroundColor White
Write-Host "     Get-ScheduledTask -TaskName 'CertWebService*'" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Web Service im Browser oeffnen:" -ForegroundColor White
Write-Host "     http://localhost:$WebServicePort" -ForegroundColor Cyan
Write-Host "     http://$env:COMPUTERNAME:$WebServicePort" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. API testen:" -ForegroundColor White
Write-Host "     Invoke-RestMethod -Uri 'http://localhost:$WebServicePort/certificates.json'" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Logs pruefen:" -ForegroundColor White
Write-Host "     Get-Content '$InstallPath\Logs\*.log' -Tail 50" -ForegroundColor Gray
Write-Host ""
Write-Host "  5. Task manuell starten:" -ForegroundColor White
Write-Host "     Start-ScheduledTask -TaskName 'CertWebService-WebServer'" -ForegroundColor Gray
Write-Host ""

Write-Log "=== INSTALLATION BEENDET ===" -Level SUCCESS

#endregion
