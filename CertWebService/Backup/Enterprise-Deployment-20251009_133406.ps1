#Requires -Version 5.1

<#
.SYNOPSIS
CertWebService - HTTP Web Service v2.5.0
.DESCRIPTION
HTTP Web Service for Certificate Monitoring with REAL Windows Certificate Store Data
Regelwerk v10.1.0 | Last Updated: 09.10.2025

FEATURES v2.5.0:
- Echte Certificatesabfrage aus Windows Certificate Store
- Support f?r LocalMachine\My, LocalMachine\WebHosting, CurrentUser\My
- Filtert Certificatee mit Private Key
- Status-Klassifizierung: Valid, Warning (?90d), Expiring Soon (?30d), Expired
- Erweiterte Dashboard-Anzeige mit Thumbprint, SerialNumber, Store-Path

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

# REAL Certificate Data from Windows Certificate Store
function Get-CertificateData {
    Write-Log "Reading certificates from Windows Certificate Store..." "INFO"
    
    try {
        # Lese Certificatee aus allen wichtigen Stores
        $stores = @(
            'Cert:\LocalMachine\My',           # Personal Certificates
            'Cert:\LocalMachine\WebHosting',   # IIS Web Hosting
            'Cert:\CurrentUser\My'             # Current User Personal
        )
        
        $allCerts = @()
        $now = Get-Date
        
        foreach ($storePath in $stores) {
            try {
                if (Test-Path $storePath) {
                    $certs = Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue | Where-Object {
                        # Nur Certificatee mit Private Key (verwendbare Certificatee)
                        $_.HasPrivateKey -eq $true -and 
                        $_.Subject -notmatch '^CN=localhost' # Filtere localhost-Zerts aus
                    }
                    
                    foreach ($cert in $certs) {
                        $daysUntilExpiry = ($cert.NotAfter - $now).Days
                        
                        # Bestimme Status
                        $status = "Valid"
                        if ($cert.NotAfter -lt $now) {
                            $status = "Expired"
                        } elseif ($daysUntilExpiry -le 30) {
                            $status = "Expiring Soon"
                        } elseif ($daysUntilExpiry -le 90) {
                            $status = "Warning"
                        }
                        
                        # Extrahiere Hostname aus Subject
                        $hostname = if ($cert.Subject -match 'CN=([^,]+)') { $matches[1] } else { $cert.Subject }
                        
                        $allCerts += @{
                            hostname = $hostname
                            thumbprint = $cert.Thumbprint
                            subject = $cert.Subject
                            issuer = $cert.Issuer
                            validFrom = $cert.NotBefore.ToString("yyyy-MM-ddTHH:mm:ssZ")
                            validUntil = $cert.NotAfter.ToString("yyyy-MM-ddTHH:mm:ssZ")
                            daysUntilExpiry = $daysUntilExpiry
                            status = $status
                            storePath = $storePath
                            hasPrivateKey = $cert.HasPrivateKey
                            serialNumber = $cert.SerialNumber
                        }
                    }
                }
            } catch {
                Write-Log "Warning: Could not read from store $storePath - $($_.Exception.Message)" "WARN"
            }
        }
        
        # Sortiere nach Ablaufdatum (kritischste zuerst)
        $allCerts = $allCerts | Sort-Object daysUntilExpiry
        
        # Berechne Summary
        $expired = ($allCerts | Where-Object { $_.status -eq "Expired" }).Count
        $expiringSoon = ($allCerts | Where-Object { $_.status -eq "Expiring Soon" }).Count
        $warning = ($allCerts | Where-Object { $_.status -eq "Warning" }).Count
        $valid = ($allCerts | Where-Object { $_.status -eq "Valid" }).Count
        
        Write-Log "Found $($allCerts.Count) certificates: $valid valid, $warning warning, $expiringSoon expiring soon, $expired expired" "INFO"
        
        return @{
            timestamp = $now.ToString("yyyy-MM-dd HH:mm:ss")
            certificates = $allCerts
            summary = @{
                total = $allCerts.Count
                valid = $valid
                warning = $warning
                expired = $expired
                expiringSoon = $expiringSoon
            }
        }
        
    } catch {
        Write-Log "ERROR reading certificates: $($_.Exception.Message)" "ERROR"
        # Fallback zu leerer Liste bei Fehler
        return @{
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            certificates = @()
            summary = @{
                total = 0
                valid = 0
                warning = 0
                expired = 0
                expiringSoon = 0
            }
            error = $_.Exception.Message
        }
    }
}

# HTML Dashboard
function Get-HTMLDashboard {
    $data = Get-CertificateData
    
    # Build certificate table rows
    $tableRows = ""
    foreach ($cert in $data.certificates) {
        $statusClass = switch ($cert.status) {
            "Valid" { "status-valid" }
            "Warning" { "status-warning" }
            "Expiring Soon" { "status-expiring" }
            "Expired" { "status-expired" }
            default { "status-valid" }
        }
        
        $storeName = if ($cert.storePath) {
            $cert.storePath -replace 'Cert:\\LocalMachine\\', 'LM\' -replace 'Cert:\\CurrentUser\\', 'CU\'
        } else { "N/A" }
        
        $issuerShort = if ($cert.issuer -match 'CN=([^,]+)') { $matches[1] } else { $cert.issuer }
        
        # Build each table row
        $tableRows += @"
                <tr>
                    <td><strong>$($cert.hostname)</strong></td>
                    <td style="font-size: 0.9em;">$($cert.subject)</td>
                    <td style="font-size: 0.9em;">$issuerShort</td>
                    <td>$($cert.validUntil)</td>
                    <td><strong>$($cert.daysUntilExpiry)</strong></td>
                    <td class="$statusClass">$($cert.status)</td>
                    <td style="font-size: 0.85em;">$storeName</td>
                </tr>
"@
    }
    
    # Return complete HTML with populated table
    return @"
<!DOCTYPE html>
<html>
<head>
    <title>CertWebService v2.5.0 - Dashboard</title>
    <meta charset="UTF-8">
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
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-expiring { color: #ff6b35; font-weight: bold; }
        .status-expired { color: #dc3545; font-weight: bold; }
        .footer { margin-top: 20px; text-align: center; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Certificate Surveillance Dashboard v2.5.0</h1>
        <p>MedUni Wien | Windows Server Infrastructure | Port: `$Port</p>
        <p>Last Updated: `$(`$data.timestamp) | Regelwerk v10.1.0 | `$(`$data.summary.total) Certificates</p>
    </div>

    <div class="stats">
        <div class="stat-box">
            <h3>`$(`$data.summary.total)</h3>
            <p>Total Certificates</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #28a745">`$(`$data.summary.valid)</h3>
            <p>Valid</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #ffc107">`$(`$data.summary.warning)</h3>
            <p>Warning (&gt;90d)</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #ff6b35">`$(`$data.summary.expiringSoon)</h3>
            <p>Expiring Soon (&le;30d)</p>
        </div>
        <div class="stat-box">
            <h3 style="color: #dc3545">`$(`$data.summary.expired)</h3>
            <p>Expired</p>
        </div>
    </div>

    <div class="cert-table">
        <table>
            <thead>
                <tr>
                    <th>Hostname</th>
                    <th>Subject</th>
                    <th>Issuer</th>
                    <th>Valid Until</th>
                    <th>Days Remaining</th>
                    <th>Status</th>
                    <th>Store</th>
                </tr>
            </thead>
            <tbody>
`$tableRows
            </tbody>
        </table>
    </div>

    <div class="footer">
        <p>CertWebService v2.5.0 | Regelwerk v10.1.0 | MedUni Wien IT-Security</p>
        <p>API: <a href="/certificates.json">/certificates.json</a> | Health: <a href="/health.json">/health.json</a></p>
        <p style="font-size:0.85em; margin-top:10px;">Certificate Stores: LocalMachine\My, LocalMachine\WebHosting, CurrentUser\My</p>
    </div>
</body>
</html>
"@
}



# HTTP Listener
function Start-WebService {
    param([int]$Port)
    
    # Transcript-Logging f?r den Service-Modus
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

        # Listener-Pr?fixe: Verwende Wildcard f?r maximale Kompatibilit?t
        # Dies erlaubt Zugriff ?ber alle Hostnamen/IPs
        $httpPrefix = "http://+:$Port/"
        $httpsPrefix = "https://+:9443/" # Fester Port f?r HTTPS gem?? Regelwerk

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
                        $response.ContentType = "text/html; charset=UTF-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    "/api/certificates.json" {
                        # Backward compatibility: redirect to new endpoint
                        $response.StatusCode = 301
                        $response.RedirectLocation = "/certificates.json"
                        $msg = '{"message":"Endpoint moved to /certificates.json"}'
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
                        $response.ContentType = "application/json; charset=UTF-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    "/certificates.json" {
                        $data = Get-CertificateData
                        
                        # Strukturierte API-Response f?r CertSurv Kompatibilit?t
                        $apiResponse = @{
                            status = "success"
                            total_count = if ($data.certificates -is [array]) { $data.certificates.Count } else { if ($data.certificates) { 1 } else { 0 } }
                            certificates = $data.certificates
                            summary = $data.summary
                            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            version = "v2.5.0"
                        }
                        
                        $json = $apiResponse | ConvertTo-Json -Depth 4
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $response.ContentType = "application/json; charset=UTF-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    "/health.json" {
                        $health = @{
                            status = "healthy"
                            version = "v2.5.0"
                            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            port = $Port
                            certificateStores = @("LocalMachine\My", "LocalMachine\WebHosting", "CurrentUser\My")
                        }
                        $json = $health | ConvertTo-Json
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $response.ContentType = "application/json; charset=UTF-8"
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                    default {
                        $response.StatusCode = 404
                        $html = "<h1>404 - Not Found</h1><p>CertWebService v2.5.0</p>"
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
    Write-Log "=== CERTWEBSERVICE v2.5.0 GESTARTET (SERVICE MODE) ===" "INFO"
} else {
    Write-Host "=== CERTWEBSERVICE v2.5.0 GESTARTET ===" -ForegroundColor Green
    Write-Host "Regelwerk v10.1.0 | Last Updated: 09.10.2025" -ForegroundColor Gray
    Write-Host "Reading REAL certificates from Windows Certificate Store" -ForegroundColor Cyan
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

