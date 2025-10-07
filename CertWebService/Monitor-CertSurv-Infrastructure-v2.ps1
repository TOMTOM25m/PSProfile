#requires -Version 5.1

<#
.SYNOPSIS
    CertSurv Infrastructure Status Monitor v2.0.0

.DESCRIPTION
    Überwacht den Status aller CertSurv-Komponenten in der Infrastruktur.
    
    - CertWebService auf allen Servern (Port 9080, HTTP)
    - CertSurv Scanner auf ITSCMGMT03
    - Network Connectivity
    - Service Health

.PARAMETER Servers
    Liste der zu überwachenden Server

.PARAMETER Port
    Port für CertWebService (Standard: 9080)

.PARAMETER UseSSL
    Verwende HTTPS statt HTTP

.PARAMETER Detailed
    Detaillierte Fehlerausgabe

.PARAMETER ExportReport
    Exportiert Report als JSON

.VERSION
    2.0.0

.RULEBOOK
    v10.0.2
#>

param(
    [Parameter(Mandatory = $false)]
    [string[]]$Servers = @(),
    
    [Parameter(Mandatory = $false)]
    [int]$Port = 9080,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseSSL,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportReport
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "CertSurv Infrastructure Status Monitor" -Version "v2.0.0 | Regelwerk: v10.0.2" -Color Cyan

# Default Server List
if ($Servers.Count -eq 0) {
    $Servers = @(
        "ITSCMGMT03.srv.meduniwien.ac.at",
        "wsus.srv.meduniwien.ac.at"
    )
}

$protocol = if ($UseSSL) { "HTTPS" } else { "HTTP" }
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Protocol: $protocol" -ForegroundColor Gray
Write-Host "  Port: $Port" -ForegroundColor Gray
Write-Host "  Servers: $($Servers.Count)" -ForegroundColor Gray
Write-Host ""

#region Status Check Functions

function Test-CertWebServiceHealth {
    param(
        [string]$ServerName,
        [int]$ServicePort,
        [bool]$SSL,
        [int]$TimeoutSeconds = 10
    )
    
    $proto = if ($SSL) { "HTTPS" } else { "HTTP" }
    
    $result = @{
        Server = $ServerName
        Timestamp = Get-Date
        Ping = $false
        PortOpen = $false
        Port = $ServicePort
        HTTPResponse = $false
        CertificateCount = 0
        ResponseTime = 0
        Error = $null
        Protocol = $proto
        CertDetails = @()
    }
    
    try {
        # 1. Ping Test
        $result.Ping = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        if (-not $result.Ping) {
            $result.Error = "Server nicht erreichbar (Ping)"
            return $result
        }
        
        # 2. Port Test
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ServerName, $ServicePort, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
            
            if ($wait) {
                $tcpClient.EndConnect($connect)
                $result.PortOpen = $true
                $tcpClient.Close()
            } else {
                $result.Error = "Port $ServicePort nicht erreichbar"
                return $result
            }
        } catch {
            $result.Error = "Port $ServicePort Test fehlgeschlagen: $($_.Exception.Message)"
            return $result
        }
        
        # 3. HTTP/HTTPS API Test
        $startTime = Get-Date
        try {
            $apiUrl = "${proto}://${ServerName}:${ServicePort}/certificates.json"
            
            # Trust all certificates for HTTPS test
            if ($SSL) {
                Add-Type @"
                    using System.Net;
                    using System.Security.Cryptography.X509Certificates;
                    public class TrustAllCertsPolicy : ICertificatePolicy {
                        public bool CheckValidationResult(
                            ServicePoint srvPoint, X509Certificate certificate,
                            WebRequest request, int certificateProblem) {
                            return true;
                        }
                    }
"@
                [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
            }
            
            # DevSkim: ignore DS137138 - HTTP used intentionally (no SSL yet)
            $response = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            $endTime = Get-Date
            $result.ResponseTime = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)
            
            if ($response.StatusCode -eq 200) {
                $result.HTTPResponse = $true
                $certData = $response.Content | ConvertFrom-Json
                
                if ($certData.certificates) {
                    $result.CertificateCount = ($certData.certificates | Measure-Object).Count
                    
                    # Zertifikat-Details extrahieren
                    foreach ($cert in $certData.certificates) {
                        $result.CertDetails += @{
                            Subject = $cert.subject
                            DaysUntilExpiry = $cert.daysUntilExpiry
                            ValidUntil = $cert.validUntil
                            Status = $cert.status
                        }
                    }
                }
            }
        } catch {
            $result.Error = "$proto API Fehler: $($_.Exception.Message)"
            
            # Spezifische Fehlerbehandlung
            if ($_.Exception.Message -match "404") {
                $result.Error += " (Endpoint nicht gefunden - falscher Pfad?)"
            } elseif ($_.Exception.Message -match "Connection refused") {
                $result.Error += " (Service läuft nicht)"
            }
            
            return $result
        }
        
    } catch {
        $result.Error = "Unerwarteter Fehler: $($_.Exception.Message)"
    }
    
    return $result
}

function Get-CertSurvScannerStatus {
    param(
        [string]$ServerName = "ITSCMGMT03.srv.meduniwien.ac.at"
    )
    
    $result = @{
        Server = $ServerName
        Accessible = $false
        ScannerInstalled = $false
        ScheduledTaskExists = $false
        LastRunTime = $null
        LastLogFile = $null
        LogFileAge = $null
        Error = $null
    }
    
    try {
        # Test Network Access
        $networkPath = "\\$ServerName\iso\CertWebService"
        $result.Accessible = Test-Path $networkPath -ErrorAction SilentlyContinue
        
        if (-not $result.Accessible) {
            $result.Error = "Network share nicht erreichbar: $networkPath"
            return $result
        }
        
        # Check Scanner Installation
        $scannerPath = "$networkPath\Start-CertificateSurveillance.ps1"
        $result.ScannerInstalled = Test-Path $scannerPath -ErrorAction SilentlyContinue
        
        # Check Log Files
        $logPath = "$networkPath\LOG"
        if (Test-Path $logPath) {
            $latestLog = Get-ChildItem -Path $logPath -Filter "*.log" -ErrorAction SilentlyContinue | 
                         Sort-Object LastWriteTime -Descending | 
                         Select-Object -First 1
            
            if ($latestLog) {
                $result.LastLogFile = $latestLog.Name
                $result.LogFileAge = [math]::Round(((Get-Date) - $latestLog.LastWriteTime).TotalHours, 1)
                $result.LastRunTime = $latestLog.LastWriteTime
            }
        }
        
        # Check Scheduled Task (via PSRemoting if available)
        try {
            # DevSkim: ignore DS104456 - Required for remote task check
            $taskInfo = Invoke-Command -ComputerName $ServerName -ScriptBlock {
                Get-ScheduledTask -TaskName "CertSurv*" -ErrorAction SilentlyContinue | 
                    Select-Object TaskName, State, LastRunTime
            } -ErrorAction SilentlyContinue
            
            if ($taskInfo) {
                $result.ScheduledTaskExists = $true
                if ($taskInfo.LastRunTime) {
                    $result.LastRunTime = $taskInfo.LastRunTime
                }
            }
        } catch {
            # PSRemoting nicht verfügbar - nicht kritisch
        }
        
    } catch {
        $result.Error = "Scanner Status Check fehlgeschlagen: $($_.Exception.Message)"
    }
    
    return $result
}

#endregion

#region Main Execution

try {
    Write-Host ""
    Write-VersionSpecificHost "Checking CertWebService on $($Servers.Count) server(s)..." -IconType 'network' -ForegroundColor Cyan
    Write-Host ""
    
    # Server Status sammeln
    $serverStatus = @()
    
    foreach ($server in $Servers) {
        Write-Host "Checking $server..." -ForegroundColor Yellow
        
        $status = Test-CertWebServiceHealth -ServerName $server -ServicePort $Port -SSL $UseSSL.IsPresent
        $serverStatus += $status
        
        # Ausgabe
        if ($status.HTTPResponse) {
            Write-Host "  [OK] Online - $($status.CertificateCount) certificates - Response: $($status.ResponseTime)ms ($($status.Protocol):$($status.Port))" -ForegroundColor Green
            
            # Zertifikat-Details im Detailed-Modus
            if ($Detailed -and $status.CertDetails.Count -gt 0) {
                Write-Host "  Certificates:" -ForegroundColor Cyan
                foreach ($cert in $status.CertDetails) {
                    $color = if ($cert.DaysUntilExpiry -lt 30) { 'Red' } elseif ($cert.DaysUntilExpiry -lt 90) { 'Yellow' } else { 'Green' }
                    Write-Host "    - $($cert.Subject): $($cert.DaysUntilExpiry) days" -ForegroundColor $color
                }
            }
        } elseif ($status.PortOpen) {
            Write-Host "  [WARN] Port $($status.Port) open but API not responding" -ForegroundColor Yellow
        } elseif ($status.Ping) {
            Write-Host "  [WARN] Server online but CertWebService not accessible (Port $($status.Port))" -ForegroundColor Yellow
        } else {
            Write-Host "  [ERROR] Server offline or unreachable" -ForegroundColor Red
        }
        
        if ($status.Error) {
            Write-Host "  Error: $($status.Error)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host ""
    Write-VersionSpecificHost "Checking CertSurv Scanner on ITSCMGMT03..." -IconType 'target' -ForegroundColor Cyan
    Write-Host ""
    
    # CertSurv Scanner Status
    $scannerStatus = Get-CertSurvScannerStatus
    
    Write-Host "ITSCMGMT03 Scanner Status:" -ForegroundColor Yellow
    Write-Host "  Network Share Accessible: $($scannerStatus.Accessible)" -ForegroundColor $(if($scannerStatus.Accessible){'Green'}else{'Red'})
    Write-Host "  Scanner Installed: $($scannerStatus.ScannerInstalled)" -ForegroundColor $(if($scannerStatus.ScannerInstalled){'Green'}else{'Red'})
    Write-Host "  Scheduled Task: $($scannerStatus.ScheduledTaskExists)" -ForegroundColor $(if($scannerStatus.ScheduledTaskExists){'Green'}else{'Yellow'})
    
    if ($scannerStatus.LastLogFile) {
        Write-Host "  Last Log: $($scannerStatus.LastLogFile) ($($scannerStatus.LogFileAge)h ago)" -ForegroundColor Gray
    }
    
    if ($scannerStatus.LastRunTime) {
        Write-Host "  Last Run: $($scannerStatus.LastRunTime)" -ForegroundColor Gray
    }
    
    if ($scannerStatus.Error) {
        Write-Host "  Error: $($scannerStatus.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Summary
    $onlineServers = ($serverStatus | Where-Object { $_.HTTPResponse }).Count
    $offlineServers = ($serverStatus | Where-Object { -not $_.Ping }).Count
    $partialServers = ($serverStatus | Where-Object { $_.PortOpen -and -not $_.HTTPResponse }).Count
    
    # Total Certificates (safe calculation)
    $totalCerts = 0
    foreach ($status in $serverStatus) {
        if ($status.CertificateCount) {
            $totalCerts += $status.CertificateCount
        }
    }
    
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INFRASTRUCTURE SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "CertWebService Status:" -ForegroundColor White
    Write-Host "  Online (Full): $onlineServers / $($Servers.Count)" -ForegroundColor $(if($onlineServers -eq $Servers.Count){'Green'}else{'Yellow'})
    Write-Host "  Partial: $partialServers" -ForegroundColor $(if($partialServers -gt 0){'Yellow'}else{'Green'})
    Write-Host "  Offline: $offlineServers" -ForegroundColor $(if($offlineServers -gt 0){'Red'}else{'Green'})
    Write-Host "  Total Certificates: $totalCerts" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "CertSurv Scanner:" -ForegroundColor White
    Write-Host "  Status: $(if($scannerStatus.ScannerInstalled){'Installed'}else{'Not Installed'})" -ForegroundColor $(if($scannerStatus.ScannerInstalled){'Green'}else{'Red'})
    if ($scannerStatus.LastRunTime) {
        $hoursSinceRun = [math]::Round(((Get-Date) - $scannerStatus.LastRunTime).TotalHours, 1)
        Write-Host "  Last Run: $hoursSinceRun hours ago" -ForegroundColor $(if($hoursSinceRun -lt 24){'Green'}elseif($hoursSinceRun -lt 48){'Yellow'}else{'Red'})
    }
    Write-Host ""
    
    # Export Report
    if ($ExportReport) {
        $reportPath = ".\Reports\Infrastructure-Status-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"
        
        $reportData = @{
            Timestamp = Get-Date -Format "o"
            Configuration = @{
                Port = $Port
                Protocol = $protocol
                UseSSL = $UseSSL.IsPresent
            }
            ServerStatus = $serverStatus
            ScannerStatus = $scannerStatus
            Summary = @{
                TotalServers = $Servers.Count
                OnlineServers = $onlineServers
                PartialServers = $partialServers
                OfflineServers = $offlineServers
                TotalCertificates = $totalCerts
            }
        }
        
        # Ensure Reports directory exists
        $reportsDir = Split-Path $reportPath -Parent
        if (-not (Test-Path $reportsDir)) {
            New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
        }
        
        $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-VersionSpecificHost "Report exported: $reportPath" -IconType 'file' -ForegroundColor Green
        Write-Host ""
    }
    
    # Exit Code basierend auf Status
    if ($offlineServers -gt 0 -or ($onlineServers -eq 0 -and $Servers.Count -gt 0)) {
        exit 1  # Kritischer Fehler
    } elseif ($partialServers -gt 0) {
        exit 2  # Warnung
    } else {
        exit 0  # Alles OK
    }
    
} catch {
    Write-VersionSpecificHost "Monitoring failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 99
}

#endregion
