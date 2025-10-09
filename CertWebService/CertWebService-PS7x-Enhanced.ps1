#Requires -Version 7.0

<#
.SYNOPSIS
CertWebService - HTTP Web Service v2.6.0 - PowerShell 7.x Edition
.DESCRIPTION
HTTP Web Service for Certificate Monitoring with Windows Certificate Store Data
Regelwerk v10.1.0 | PowerShell 7.x Enhanced | UTF-8 Optimized | Last Updated: 09.10.2025

FEATURES v2.6.0 (PowerShell 7.x Edition):
- Enhanced UTF-8 encoding support with PowerShell 7.x
- Real Certificate queries from Windows Certificate Store
- Support for LocalMachine\My, LocalMachine\WebHosting, CurrentUser\My
- Filters Certificates with Private Key
- Status Classification: Valid, Warning (≤90d), Expiring Soon (≤30d), Expired
- Enhanced Dashboard Display with proper Unicode support

.PARAMETER Port
HTTP Port (Default: 9080)
.PARAMETER ServiceMode
Service Mode Flag (Scheduled Task)
#>

param(
    [int]$Port = 9080,
    [switch]$ServiceMode
)

# PowerShell 7.x UTF-8 Configuration
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

# Load central configuration
try {
    $cfg1 = Join-Path $PSScriptRoot "Config\Config-CertWebService.json"
    $cfg2 = Join-Path $PSScriptRoot "Config\CertSurv-Config.json"
    $configPath = $null
    foreach ($c in @($cfg1,$cfg2)) { if (-not $configPath -and (Test-Path $c)) { $configPath = $c } }
    if ($configPath) {
        $config = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains 'WebServicePort') { $Port = $config.WebServicePort }
        elseif ($config.PSObject.Properties.Name -contains 'WebService') {
            if ($config.WebService.PSObject.Properties.Name -contains 'HttpPort') { $Port = $config.WebService.HttpPort }
            elseif ($config.WebService.PSObject.Properties.Name -contains 'Port') { $Port = $config.WebService.Port }
        }
    }
} catch {
    Write-Warning "Config could not be loaded, using default port $Port"
}

# Logging Setup
$logPath = Join-Path $PSScriptRoot "Logs"
try {
    if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force | Out-Null }
} catch { }

function Write-ServiceLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    try {
        $logEntry | Out-File (Join-Path $logPath "CertWebService.log") -Append -Encoding UTF8
    } catch { }
    if (-not $ServiceMode) { Write-Host $logEntry }
}

# Certificate Store Helper Functions
function Get-CertificateData {
    param([string]$StorePath)
    
    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StorePath.Split('\')[1], $StorePath.Split('\')[0])
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        
        $certs = @()
        foreach ($cert in $store.Certificates) {
            # Only include certificates with private keys
            if ($cert.HasPrivateKey) {
                $daysRemaining = ($cert.NotAfter - (Get-Date)).Days
                
                # Status determination
                $status = "Valid"
                $statusColor = "green"
                if ($cert.NotAfter -lt (Get-Date)) { 
                    $status = "Expired"
                    $statusColor = "red"
                } elseif ($daysRemaining -le 30) { 
                    $status = "Expiring Soon"
                    $statusColor = "orange"
                } elseif ($daysRemaining -le 90) { 
                    $status = "Warning"
                    $statusColor = "yellow"
                }
                
                $certs += [PSCustomObject]@{
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    Thumbprint = $cert.Thumbprint
                    SerialNumber = $cert.SerialNumber
                    NotBefore = $cert.NotBefore
                    NotAfter = $cert.NotAfter
                    DaysRemaining = $daysRemaining
                    Status = $status
                    StatusColor = $statusColor
                    Store = $StorePath
                    HasPrivateKey = $cert.HasPrivateKey
                }
            }
        }
        $store.Close()
        return $certs
    } catch {
        Write-ServiceLog "Error accessing store $StorePath`: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Get-HTMLDashboard {
    $allCerts = @()
    
    # Query multiple certificate stores
    $stores = @(
        "LocalMachine\My",
        "LocalMachine\WebHosting", 
        "CurrentUser\My"
    )
    
    foreach ($store in $stores) {
        $allCerts += Get-CertificateData -StorePath $store
    }
    
    # Statistics
    $totalCount = $allCerts.Count
    $validCount = ($allCerts | Where-Object { $_.Status -eq "Valid" }).Count
    $warningCount = ($allCerts | Where-Object { $_.Status -eq "Warning" }).Count
    $expiringSoonCount = ($allCerts | Where-Object { $_.Status -eq "Expiring Soon" }).Count
    $expiredCount = ($allCerts | Where-Object { $_.Status -eq "Expired" }).Count
    
    # Generate HTML with proper UTF-8 encoding
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Certificate Surveillance Dashboard v2.6.0 - PowerShell 7.x</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .header { 
            background: linear-gradient(45deg, #1a237e, #3949ab); 
            color: white; 
            padding: 20px; 
            text-align: center; 
            box-shadow: 0 4px 8px rgba(0,0,0,0.3);
        }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header .version { color: #ffeb3b; font-weight: bold; }
        .info { color: #e3f2fd; margin-top: 10px; font-size: 1.1em; }
        .ps7-badge { 
            background: #4CAF50; 
            color: white; 
            padding: 4px 12px; 
            border-radius: 15px; 
            font-size: 0.8em; 
            font-weight: bold;
            margin-left: 10px;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            padding: 20px; 
        }
        .stats { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .stat-card { 
            background: white; 
            padding: 20px; 
            border-radius: 10px; 
            text-align: center; 
            box-shadow: 0 6px 20px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        .stat-card:hover { transform: translateY(-5px); }
        .stat-number { 
            font-size: 3em; 
            font-weight: bold; 
            margin-bottom: 10px; 
        }
        .stat-label { 
            color: #666; 
            text-transform: uppercase; 
            font-weight: 600; 
            letter-spacing: 1px;
        }
        .green { color: #4CAF50; }
        .yellow { color: #FF9800; }
        .orange { color: #FF5722; }
        .red { color: #f44336; }
        .blue { color: #2196F3; }
        .table-container { 
            background: white; 
            border-radius: 10px; 
            overflow: hidden; 
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
        }
        .table-header { 
            background: linear-gradient(45deg, #2c3e50, #34495e); 
            color: white; 
            padding: 15px 20px; 
            font-weight: bold; 
            text-transform: uppercase; 
            letter-spacing: 1px;
        }
        table { 
            width: 100%; 
            border-collapse: collapse; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #eee; 
        }
        th { 
            background: #34495e; 
            color: white; 
            font-weight: 600; 
            text-transform: uppercase; 
            font-size: 0.9em; 
            letter-spacing: 0.5px;
        }
        tr:hover { 
            background-color: #f8f9fa; 
        }
        .status-badge { 
            padding: 4px 12px; 
            border-radius: 20px; 
            color: white; 
            font-weight: bold; 
            font-size: 0.85em; 
            text-transform: uppercase; 
        }
        .status-valid { background-color: #4CAF50; }
        .status-warning { background-color: #FF9800; }
        .status-expiring { background-color: #FF5722; }
        .status-expired { background-color: #f44336; }
        .mono { font-family: 'Courier New', monospace; font-size: 0.9em; }
        .small-text { font-size: 0.85em; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Certificate Surveillance Dashboard <span class="version">v2.6.0</span><span class="ps7-badge">PowerShell 7.x</span></h1>
        <div class="info">
            MedUni Wien | Windows Server Infrastructure | Port: 9080<br>
            Status: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Regelwerk v10.1.0 | UTF-8 Enhanced | $totalCount Certificates
        </div>
    </div>
    
    <div class="container">
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number blue">$totalCount</div>
                <div class="stat-label">Total Certificates</div>
            </div>
            <div class="stat-card">
                <div class="stat-number green">$validCount</div>
                <div class="stat-label">Valid</div>
            </div>
            <div class="stat-card">
                <div class="stat-number yellow">$warningCount</div>
                <div class="stat-label">Warning (≤90d)</div>
            </div>
            <div class="stat-card">
                <div class="stat-number orange">$expiringSoonCount</div>
                <div class="stat-label">Expiring Soon (≤30d)</div>
            </div>
            <div class="stat-card">
                <div class="stat-number red">$expiredCount</div>
                <div class="stat-label">Expired</div>
            </div>
        </div>
        
        <div class="table-container">
            <div class="table-header">Certificate Details - PowerShell 7.x Enhanced</div>
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
"@

    # Add certificate rows
    foreach ($cert in $allCerts | Sort-Object DaysRemaining) {
        $hostname = if ($cert.Subject -match "CN=([^,]+)") { $matches[1] } else { "N/A" }
        $statusClass = switch ($cert.Status) {
            "Valid" { "status-valid" }
            "Warning" { "status-warning" }
            "Expiring Soon" { "status-expiring" }
            "Expired" { "status-expired" }
        }
        
        $html += @"
                    <tr>
                        <td><strong>$hostname</strong></td>
                        <td class="small-text">$($cert.Subject)</td>
                        <td class="small-text">$($cert.Issuer)</td>
                        <td>$($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss'))</td>
                        <td><strong>$($cert.DaysRemaining)</strong></td>
                        <td><span class="status-badge $statusClass">$($cert.Status)</span></td>
                        <td class="mono">$($cert.Store)</td>
                    </tr>
"@
    }
    
    $html += @"
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

# HTTP Listener Setup
Write-ServiceLog "Starting CertWebService v2.6.0 (PowerShell 7.x) on port $Port"

try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$Port/")
    $listener.Start()
    Write-ServiceLog "HTTP Listener started successfully on port $Port (PowerShell 7.x)"
    
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            Write-ServiceLog "Request: $($request.HttpMethod) $($request.Url.PathAndQuery) from $($request.RemoteEndPoint)"
            
            # Set enhanced UTF-8 response headers
            $response.ContentType = "text/html; charset=UTF-8"
            $response.ContentEncoding = [System.Text.Encoding]::UTF8
            $response.Headers.Add("Server", "CertWebService/2.6.0-PS7x")
            $response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
            $response.Headers.Add("X-PowerShell-Version", "7.x")
            $response.Headers.Add("X-UTF8-Enhanced", "true")
            
            try {
                $html = Get-HTMLDashboard
                # Use PowerShell 7.x enhanced UTF-8 encoding
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.StatusCode = 200
                Write-ServiceLog "Response sent successfully (200 OK, $($buffer.Length) bytes, UTF-8 Enhanced)"
            } catch {
                $errorHtml = "<html><head><meta charset='UTF-8'></head><body><h1>Error 500</h1><p>$($_.Exception.Message)</p></body></html>"
                $errorBuffer = [System.Text.Encoding]::UTF8.GetBytes($errorHtml)
                $response.ContentLength64 = $errorBuffer.Length
                $response.OutputStream.Write($errorBuffer, 0, $errorBuffer.Length)
                $response.StatusCode = 500
                Write-ServiceLog "Error generating dashboard: $($_.Exception.Message)" "ERROR"
            }
            
            $response.OutputStream.Close()
            
        } catch {
            Write-ServiceLog "Request processing error: $($_.Exception.Message)" "ERROR"
        }
    }
    
} catch {
    Write-ServiceLog "Critical error: $($_.Exception.Message)" "ERROR"
    throw
} finally {
    if ($listener -and $listener.IsListening) {
        $listener.Stop()
        Write-ServiceLog "HTTP Listener stopped"
    }
}