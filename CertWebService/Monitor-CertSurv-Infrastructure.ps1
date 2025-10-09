#requires -Version 5.1

<#
.SYNOPSIS
    CertSurv Infrastructure Status Monitor v1.0.0

.DESCRIPTION
    Überwacht den Status aller CertSurv-Komponenten in der Infrastruktur.
    
    - CertWebService auf allen Servern
    - CertSurv Scanner auf ITSCMGMT03
    - Network Connectivity
    - Service Health

.VERSION
    1.0.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string[]]$Servers = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportReport
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "CertSurv Infrastructure Status Monitor" -Version "v1.0.0 | Regelwerk: v10.1.0" -Color Cyan

# Default Server List
if ($Servers.Count -eq 0) {
    $Servers = @(
        "ITSCMGMT03.srv.meduniwien.ac.at",
        "ITSC020.cc.meduniwien.ac.at",
        "itsc049.uvw.meduniwien.ac.at"
    )
}

#region Status Check Functions

function Test-CertWebServiceHealth {
    param(
        [string]$ServerName,
        [int]$TimeoutSeconds = 10,
        [int]$Port = 9080,
        [bool]$UseSSL = $false
    )
    
    $protocol = if ($UseSSL) { "HTTPS" } else { "HTTP" }
    
    $result = @{
        Server = $ServerName
        Timestamp = Get-Date
        Ping = $false
        PortOpen = $false
        Port = $Port
        HTTPResponse = $false
        CertificateCount = 0
        ResponseTime = 0
        Error = $null
        Protocol = $protocol
    }
    
    try {
        # Ping Test
        $result.Ping = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        if (-not $result.Ping) {
            $result.Error = "Server nicht erreichbar (Ping)"
            return $result
        }
        
        # Port Test
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($connect)
            $result.PortOpen = $true
            $tcpClient.Close()
        } else {
            $result.Error = "Port $Port nicht erreichbar"
            return $result
        }
        
        # HTTP/HTTPS API Test
        $startTime = Get-Date
        try {
            $apiUrl = "${protocol}://${ServerName}:${Port}/certificates"
            
            # Trust all certificates for HTTPS test
            if ($UseSSL) {
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
            
            $result.HTTPSResponse = ($response.StatusCode -eq 200)
            $result.ResponseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
            
            # Parse Zertifikate
            if ($response.Content) {
                try {
                    $certs = $response.Content | ConvertFrom-Json
                    $result.CertificateCount = ($certs | Measure-Object).Count
                } catch {
                    $result.CertificateCount = -1
                }
            }
            
        } catch {
            $result.Error = "HTTPS API Fehler: $($_.Exception.Message)"
        }
        
    } catch {
        $result.Error = "Health Check Fehler: $($_.Exception.Message)"
    }
    
    return $result
}

function Get-CertSurvScannerStatus {
    param([string]$ServerName = "ITSCMGMT03.srv.meduniwien.ac.at")
    
    $result = @{
        Server = $ServerName
        Timestamp = Get-Date
        Accessible = $false
        ScannerInstalled = $false
        ScheduledTaskExists = $false
        LastRunTime = $null
        LastLogFile = $null
        LogFileAge = $null
        Error = $null
    }
    
    try {
        # SMB Zugriff prüfen
        $certSurvPath = "\\$ServerName\C$\CertSurv"
        $result.Accessible = Test-Path $certSurvPath
        
        if (-not $result.Accessible) {
            $result.Error = "CertSurv-Verzeichnis nicht erreichbar"
            return $result
        }
        
        # Scanner-Installation prüfen
        $mainScript = Join-Path $certSurvPath "Cert-Surveillance-Main.ps1"
        $result.ScannerInstalled = Test-Path $mainScript
        
        # Log-Dateien prüfen
        $logPath = Join-Path $certSurvPath "LOG"
        if (Test-Path $logPath) {
            $latestLog = Get-ChildItem $logPath -Filter "*Cert-Surveillance-Main*.log" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
            
            if ($latestLog) {
                $result.LastLogFile = $latestLog.Name
                $result.LogFileAge = [math]::Round(((Get-Date) - $latestLog.LastWriteTime).TotalHours, 1)
            }
        }
        
        # Scheduled Task prüfen (benötigt PSRemoting)
        try {
            # DevSkim: ignore DS104456 - Required for scheduled task status check
            $taskInfo = Invoke-Command -ComputerName $ServerName -ScriptBlock {
                Get-ScheduledTask | Where-Object { $_.TaskName -like "*CertSurv*" } | Select-Object TaskName, State, LastRunTime
            } -ErrorAction SilentlyContinue
            
            if ($taskInfo) {
                $result.ScheduledTaskExists = $true
                $result.LastRunTime = $taskInfo.LastRunTime
            }
        } catch {
            # PSRemoting nicht verfügbar - kein Fehler
        }
        
    } catch {
        $result.Error = "Status Check Fehler: $($_.Exception.Message)"
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
        
        $status = Test-CertWebServiceHealth -ServerName $server
        $serverStatus += $status
        
        # Ausgabe
        if ($status.HTTPResponse) {
            Write-Host "  [OK] Online - $($status.CertificateCount) certificates - Response: $($status.ResponseTime)ms ($($status.Protocol):$($status.Port))" -ForegroundColor Green
        } elseif ($status.PortOpen) {
            Write-Host "  [WARN] Port $($status.Port) open but API not responding" -ForegroundColor Yellow
        } elseif ($status.Ping) {
            Write-Host "  [WARN] Server online but CertWebService not accessible (Port $($status.Port))" -ForegroundColor Yellow
        } else {
            Write-Host "  [ERROR] Server offline or unreachable" -ForegroundColor Red
        }
        
        if ($status.Error -and $Detailed) {
            Write-Host "  Error: $($status.Error)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-VersionSpecificHost "Checking CertSurv Scanner on ITSCMGMT03..." -IconType 'target' -ForegroundColor Cyan
    Write-Host ""
    
    # CertSurv Scanner Status
    $scannerStatus = Get-CertSurvScannerStatus
    
    Write-Host "ITSCMGMT03 Scanner Status:" -ForegroundColor Yellow
    Write-Host "  Accessible: $($scannerStatus.Accessible)" -ForegroundColor $(if($scannerStatus.Accessible){'Green'}else{'Red'})
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
    
    # Zusammenfassung
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  INFRASTRUCTURE STATUS SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $totalServers = $serverStatus.Count
    $onlineServers = ($serverStatus | Where-Object { $_.HTTPSResponse }).Count
    $partialServers = ($serverStatus | Where-Object { $_.Port8443 -and -not $_.HTTPSResponse }).Count
    $offlineServers = ($serverStatus | Where-Object { -not $_.Ping }).Count
    
    Write-Host "CertWebService Clients:" -ForegroundColor White
    Write-Host "  Total Servers: $totalServers" -ForegroundColor Gray
    Write-Host "  Fully Online: $onlineServers" -ForegroundColor $(if($onlineServers -eq $totalServers){'Green'}else{'Yellow'})
    Write-Host "  Partial: $partialServers" -ForegroundColor $(if($partialServers -gt 0){'Yellow'}else{'Gray'})
    Write-Host "  Offline: $offlineServers" -ForegroundColor $(if($offlineServers -gt 0){'Red'}else{'Gray'})
    Write-Host ""
    
    Write-Host "CertSurv Scanner:" -ForegroundColor White
    Write-Host "  Status: $(if($scannerStatus.ScannerInstalled -and $scannerStatus.ScheduledTaskExists){'Operational'}elseif($scannerStatus.ScannerInstalled){'Installed (Task Missing)'}else{'Not Installed'})" -ForegroundColor $(if($scannerStatus.ScannerInstalled -and $scannerStatus.ScheduledTaskExists){'Green'}elseif($scannerStatus.ScannerInstalled){'Yellow'}else{'Red'})
    
    if ($scannerStatus.LogFileAge) {
        $logStatus = if ($scannerStatus.LogFileAge -lt 24) { "Recent" } elseif ($scannerStatus.LogFileAge -lt 48) { "Older" } else { "Outdated" }
        $logColor = if ($scannerStatus.LogFileAge -lt 24) { "Green" } elseif ($scannerStatus.LogFileAge -lt 48) { "Yellow" } else { "Red" }
        Write-Host "  Last Activity: $logStatus ($($scannerStatus.LogFileAge)h ago)" -ForegroundColor $logColor
    }
    
    Write-Host ""
    
    # Gesamt-Status
    $overallHealthy = ($onlineServers -eq $totalServers) -and $scannerStatus.ScannerInstalled
    
    if ($overallHealthy) {
        Write-VersionSpecificHost "Overall Status: HEALTHY" -IconType 'success' -ForegroundColor Green
    } else {
        Write-VersionSpecificHost "Overall Status: NEEDS ATTENTION" -IconType 'warning' -ForegroundColor Yellow
    }
    
    # Report Export
    if ($ExportReport) {
        $reportPath = "C:\Temp\CertSurv-Status-Report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
        
        $reportData = @{
            Timestamp = Get-Date
            ServerStatus = $serverStatus
            ScannerStatus = $scannerStatus
            Summary = @{
                TotalServers = $totalServers
                OnlineServers = $onlineServers
                PartialServers = $partialServers
                OfflineServers = $offlineServers
                OverallHealthy = $overallHealthy
            }
        }
        
        $reportData | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding UTF8
        Write-Host ""
        Write-VersionSpecificHost "Status report exported: $reportPath" -IconType 'file' -ForegroundColor Green
    }
    
} catch {
    Write-VersionSpecificHost "Status check failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    exit 1
}

#endregion

