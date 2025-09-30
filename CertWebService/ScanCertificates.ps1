#requires -Version 5.1

<#
.SYNOPSIS
    Certificate WebService - Daily Certificate Scan Script

.DESCRIPTION
    Automated certificate scanning and content update for the Certificate WebService.
    Runs daily via scheduled task to keep certificate data current.
    
.VERSION
    2.3.0

.RULEBOOK
    v10.0.0
#>

# Script Information
$Script:Version = "v2.3.0"
$Script:RulebookVersion = "v10.0.0"
$Script:ScanDate = Get-Date

# Logging setup
$logPath = "C:\inetpub\CertWebService\Logs"
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $logPath "CertScan_$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "=== Certificate WebService Daily Scan Started ==="
Write-Log "Version: $Script:Version | Regelwerk: $Script:RulebookVersion"

try {
    # Discover certificates from local machine
    Write-Log "Discovering certificates from local machine..."
    
    $certificates = @()
    $stores = @("My", "Root", "CA", "AuthRoot")
    
    foreach ($storeName in $stores) {
        try {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, "LocalMachine")
            $store.Open("ReadOnly")
            
            foreach ($cert in $store.Certificates) {
                # Filter out system/test certificates for cleaner output
                if ($cert.Subject -notlike "*Microsoft*" -and 
                    $cert.Subject -notlike "*Windows*" -and
                    $cert.Subject -notlike "*Root*" -and
                    $cert.NotAfter -gt (Get-Date)) {
                    
                    $certificates += @{
                        subject = $cert.Subject
                        issuer = $cert.Issuer
                        expiry = $cert.NotAfter.ToString("yyyy-MM-dd")
                        thumbprint = $cert.Thumbprint
                        status = if ($cert.NotAfter -lt (Get-Date).AddDays(30)) { "Expiring Soon" } elseif ($cert.NotAfter -lt (Get-Date)) { "Expired" } else { "Valid" }
                        store = $storeName
                        serial = $cert.SerialNumber
                    }
                }
            }
            
            $store.Close()
            
        } catch {
            Write-Log "Warning: Could not access certificate store $storeName`: $($_.Exception.Message)" "WARN"
        }
    }
    
    Write-Log "Discovered $($certificates.Count) certificates"
    
    # Generate updated certificate data
    $certificateData = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        scan_version = $Script:Version
        certificates = $certificates
        total_count = $certificates.Count
        api_version = "2.3.0"
        last_scan = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        statistics = @{
            valid = ($certificates | Where-Object { $_.status -eq "Valid" }).Count
            expiring_soon = ($certificates | Where-Object { $_.status -eq "Expiring Soon" }).Count
            expired = ($certificates | Where-Object { $_.status -eq "Expired" }).Count
        }
    }
    
    # Update certificates.json
    $sitePath = "C:\inetpub\CertWebService"
    $certificatesFile = Join-Path $sitePath "certificates.json"
    
    $certificateData | ConvertTo-Json -Depth 5 | Set-Content -Path $certificatesFile -Encoding UTF8
    Write-Log "Updated certificates.json with $($certificates.Count) certificates"
    
    # Update summary.json
    $summary = @{
        total_certificates = $certificateData.total_count
        valid_certificates = $certificateData.statistics.valid
        expired_certificates = $certificateData.statistics.expired
        expiring_soon = $certificateData.statistics.expiring_soon
        last_update = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        scan_version = $Script:Version
    }
    
    $summaryFile = Join-Path $sitePath "summary.json"
    $summary | ConvertTo-Json | Set-Content -Path $summaryFile -Encoding UTF8
    Write-Log "Updated summary.json"
    
    # Update health.json with current status
    $health = @{
        status = "healthy"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        version = $Script:Version
        uptime = [math]::Round(((Get-Date) - [System.Diagnostics.Process]::GetCurrentProcess().StartTime).TotalHours, 1)
        last_scan = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        certificate_count = $certificateData.total_count
        scan_status = "completed"
    }
    
    $healthFile = Join-Path $sitePath "health.json"
    $health | ConvertTo-Json | Set-Content -Path $healthFile -Encoding UTF8
    Write-Log "Updated health.json"
    
    # Generate statistics for logging
    Write-Log "=== Certificate Statistics ==="
    Write-Log "Total Certificates: $($certificateData.total_count)"
    Write-Log "Valid: $($certificateData.statistics.valid)"
    Write-Log "Expiring Soon (≤30 days): $($certificateData.statistics.expiring_soon)"
    Write-Log "Expired: $($certificateData.statistics.expired)"
    
    if ($certificateData.statistics.expired -gt 0 -or $certificateData.statistics.expiring_soon -gt 0) {
        Write-Log "WARNING: Certificates requiring attention found!" "WARN"
        
        $expiring = $certificates | Where-Object { $_.status -in @("Expired", "Expiring Soon") }
        foreach ($cert in $expiring) {
            Write-Log "  - $($cert.subject) ($($cert.status)) - Expires: $($cert.expiry)" "WARN"
        }
    }
    
    Write-Log "=== Certificate Scan Completed Successfully ==="
    
} catch {
    Write-Log "FATAL: Certificate scan failed: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack Trace: $($_.Exception.StackTrace)" "ERROR"
    
    # Update health.json with error status
    $errorHealth = @{
        status = "error"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        server = $env:COMPUTERNAME
        version = $Script:Version
        error_message = $_.Exception.Message
        last_scan_attempt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        scan_status = "failed"
    }
    
    $healthFile = "C:\inetpub\CertWebService\health.json"
    if (Test-Path $healthFile) {
        $errorHealth | ConvertTo-Json | Set-Content -Path $healthFile -Encoding UTF8
    }
    
    exit 1
}

# Cleanup old log files (keep last 7 days)
try {
    $oldLogs = Get-ChildItem $logPath -Filter "CertScan_*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
    foreach ($oldLog in $oldLogs) {
        Remove-Item $oldLog.FullName -Force
        Write-Log "Cleaned up old log file: $($oldLog.Name)"
    }
} catch {
    Write-Log "Warning: Could not clean up old log files: $($_.Exception.Message)" "WARN"
}

Write-Log "Certificate scan process completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"