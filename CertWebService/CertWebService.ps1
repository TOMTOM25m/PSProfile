#Requires -Version 5.1

<#
.SYNOPSIS
CertWebService - HTTP Web Service
.DESCRIPTION
Einfacher HTTP Web-Service fuer Certificate Monitoring
Regelwerk v10.0.2 | Stand: 02.10.2025 (ASCII only output)
.PARAMETER Port
HTTP Port (Default: 9080)
.PARAMETER ServiceMode
Service Mode Flag (Scheduled Task)
#>

param(
    [int]$Port = 9080,
    [switch]$ServiceMode
)

$ErrorActionPreference = "Stop"

# Lade zentrale Konfiguration
try {
    # Support both legacy and new config naming
    $cfg1 = Join-Path $PSScriptRoot "Config\Config-CertWebService.json"
    $cfg2 = Join-Path $PSScriptRoot "Config\CertSurv-Config.json"
    $configPath = $null
    foreach ($c in @($cfg1,$cfg2)) { if (-not $configPath -and (Test-Path $c)) { $configPath = $c } }
    if ($configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains 'WebServicePort') { $Port = $config.WebServicePort }
        elseif ($config.PSObject.Properties.Name -contains 'WebService') {
            if ($config.WebService.PSObject.Properties.Name -contains 'HttpPort') { $Port = $config.WebService.HttpPort }
            elseif ($config.WebService.PSObject.Properties.Name -contains 'Port') { $Port = $config.WebService.Port }
        }
    }
} catch {
    Write-Warning "Config konnte nicht geladen werden, verwende Default-Port $Port"
}

# Logging-Setup
$logPath = Join-Path $PSScriptRoot "Logs"
try {
    if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force | Out-Null }
} catch {
    Write-Host "WARN: Konnte Logs Verzeichnis nicht erstellen: $($_.Exception.Message)" -ForegroundColor Yellow
}

$logFile = Join-Path $logPath "CertWebService_$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Dummy Certificate Data
function Get-CertificateData {
    return @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        certificates = @(
            @{
                hostname = "itscmgmt03.srv.meduniwien.ac.at"
                port = 443
                subject = "CN=itscmgmt03.srv.meduniwien.ac.at"
                issuer = "MedUni Wien CA"
                validFrom = "2024-01-01T00:00:00Z"
                validUntil = "2025-12-31T23:59:59Z"
                daysUntilExpiry = 90
                status = "Valid"
            },
            @{
                hostname = "webmail.meduniwien.ac.at"
                port = 443
                subject = "CN=webmail.meduniwien.ac.at"
                issuer = "DigiCert Inc"
                validFrom = "2024-06-01T00:00:00Z"
                validUntil = "2025-06-01T23:59:59Z"
                daysUntilExpiry = 242
                status = "Valid"
            }
        )
        summary = @{
            total = 2
            valid = 2
            expired = 0
            expiringSoon = 0
        }
    }
}

# HTML Dashboard
function Get-HTMLDashboard {
    $data = Get-CertificateData
    return @"
<!DOCTYPE html>
<html>
<head>
    <title>CertWebService v2.4.0 - Dashboard</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #111d4e; color: white; padding: 20px; border-radius: 5px; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-box { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); flex: 1; text-align: center; }
        .cert-table { background: white; border-radius: 5px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #111d4e; color: white; }
        .status-valid { color: #28a745; font-weight: bold; }
        .footer { margin-top: 20px; text-align: center; color: #666; }
    </style>
</head>
<body>
    <div class="header">
    <h1>Certificate Surveillance Dashboard</h1>
    <p>MedUni Wien | WindowsServer-Infrastruktur | Port: $Port</p>
    <p>Stand: $($data.timestamp) | Regelwerk v10.0.2</p>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <h3>$($data.summary.total)</h3>
            <p>Total Certificates</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #28a745">$($data.summary.valid)</h3>
            <p>Valid Certificates</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #dc3545">$($data.summary.expired)</h3>
            <p>Expired</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #ffc107">$($data.summary.expiringSoon)</h3>
            <p>Expiring Soon</p>
        </div>
    </div>
    
    <div class="cert-table">
        <table>
            <thead>
                <tr>
                    <th>Hostname</th>
                    <th>Port</th>
                    <th>Subject</th>
                    <th>Valid Until</th>
                    <th>Days Remaining</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@
    foreach ($cert in $data.certificates) {
        $html += @"
                <tr>
                    <td>$($cert.hostname)</td>
                    <td>$($cert.port)</td>
                    <td>$($cert.subject)</td>
                    <td>$($cert.validUntil)</td>
                    <td>$($cert.daysUntilExpiry)</td>
                    <td class="status-valid">$($cert.status)</td>
                </tr>
"@
    }
    
    $html += @"
            </tbody>
        </table>
    </div>
    
    <div class="footer">
        <p>CertWebService v2.4.0 | Regelwerk v10.0.2 | MedUni Wien IT-Security</p>
    <p>API: <a href="/certificates.json">/certificates.json</a> | Health: <a href="/health.json">/health.json</a></p>
    </div>
</body>
</html>
"@
    return $html
}

# HTTP Listener
function Start-WebService {
    param([int]$Port)
    
    # Transcript-Logging für den Service-Modus
    if ($ServiceMode) {
        $transcriptLogPath = Join-Path $PSScriptRoot "Logs"
        $transcriptFile = Join-Path $transcriptLogPath "Transcript_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
        try {
            if (-not (Test-Path $transcriptLogPath)) { New-Item -Path $transcriptLogPath -ItemType Directory -Force | Out-Null }
            Start-Transcript -Path $transcriptFile -Append -Force
            Write-Log "Transcript-Logging gestartet nach: $transcriptFile" "INFO"
        } catch {
            Write-Log "WARN: Konnte Transcript-Logging nicht starten: $($_.Exception.Message)" "WARN"
        }
    }

    try {
        $listener = New-Object System.Net.HttpListener

        # Listener-Präfixe: Verwende Wildcard für maximale Kompatibilität
        # Dies erlaubt Zugriff über alle Hostnamen/IPs
        $httpPrefix = "http://+:$Port/"
        $httpsPrefix = "https://+:9443/" # Fester Port für HTTPS gemäß Regelwerk

        $listener.Prefixes.Add($httpPrefix)
        $listener.Prefixes.Add($httpsPrefix)
        
        try { 
            $listener.Start() 
        } catch {
            Write-Log "FATAL: Listener konnte nicht gestartet werden. Grund: $($_.Exception.Message)" "FATAL"
            Write-Log "HINWEIS: Stellen Sie sicher, dass die URL ACLs korrekt gesetzt sind. Pruefen mit: netsh http show urlacl" "INFO"
            throw
        }
        
        Write-Log ("CertWebService lauscht auf {0} und {1}" -f $httpPrefix, $httpsPrefix) "INFO"
        Write-Log "Dashboard: $($httpPrefix)" "INFO"
        Write-Log "API: $($httpPrefix)certificates.json" "INFO"
        
        while ($listener.IsListening) {
            try {
                $context = $listener.GetContext()
                $request = $context.Request
                $response = $context.Response
                
                $url = $request.Url.AbsolutePath.ToLower()
                Write-Log "Request: $($request.HttpMethod) $url from $($request.RemoteEndPoint)" "INFO"
                
                # Route Handling
                switch ($url) {
                    "/" {
                        $html = Get-HTMLDashboard
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                        $response.ContentType = "text/html; charset=utf-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    "/api/certificates.json" {
                        # Backward compatibility: redirect to new endpoint
                        $response.StatusCode = 301
                        $response.RedirectLocation = "/certificates.json"
                        $msg = '{"message":"Endpoint moved to /certificates.json"}'
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
                        $response.ContentType = "application/json; charset=utf-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    "/certificates.json" {
                        $data = Get-CertificateData
                        $json = $data | ConvertTo-Json -Depth 3
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $response.ContentType = "application/json; charset=utf-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    "/health.json" {
                        $health = @{
                            status = "healthy"
                            version = "v2.4.0"
                            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            port = $Port
                        }
                        $json = $health | ConvertTo-Json
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $response.ContentType = "application/json; charset=utf-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    default {
                        $response.StatusCode = 404
                        $html = "<h1>404 - Not Found</h1><p>CertWebService v2.4.0</p>"
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                }
                
                $response.OutputStream.Close()
                
            } catch {
                Write-Log "Request Error: $($_.Exception.Message)" "ERROR"
                if ($response) {
                    $response.StatusCode = 500
                    $response.OutputStream.Close()
                }
            }
        }
    } catch {
        Write-Log "Fatal Error: $($_.Exception.Message)" "FATAL"
        throw
    } finally {
        if ($listener -and $listener.IsListening) {
            $listener.Stop()
            Write-Log "Web Service gestoppt" "INFO"
        }
        if ($ServiceMode) {
            Stop-Transcript | Out-Null
        }
    }
}

# Main Execution
if ($ServiceMode) {
    Write-Log "=== CERTWEBSERVICE v2.4.0 GESTARTET (SERVICE MODE) ===" "INFO"
} else {
    Write-Host "=== CERTWEBSERVICE v2.4.0 GESTARTET ===" -ForegroundColor Green
    Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
    Write-Host ""
}

# Graceful Shutdown Handler
$shutdown = $false
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $script:shutdown = $true
    Write-Log "Shutdown signal empfangen" "INFO"
}

try {
    Start-WebService -Port $Port
} catch {
    Write-Log "Service konnte nicht gestartet werden: $($_.Exception.Message)" "FATAL"
    exit 1
}