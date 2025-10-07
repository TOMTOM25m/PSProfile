#requires -Version 5.1

<#
.SYNOPSIS
    Certificate Surveillance Scanner v1.0.0

.DESCRIPTION
    Scannt Server aus ServerList.txt und sammelt Zertifikatsdaten
    von CertWebService APIs (Port 9080 HTTP).

.PARAMETER ServerListPath
    Pfad zur ServerList.txt

.PARAMETER OutputDirectory
    Ausgabe-Verzeichnis für Reports

.PARAMETER Port
    CertWebService Port (Standard: 9080)

.PARAMETER MaxConcurrent
    Maximale parallele Scans (Standard: 5)

.VERSION
    1.0.0

.RULEBOOK
    v10.0.2
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ServerListPath = "C:\CertSurv\Config\ServerList.txt",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "C:\CertSurv\Reports",
    
    [Parameter(Mandatory = $false)]
    [int]$Port = 9080,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxConcurrent = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Script Information
$Script:Version = "v1.0.0"
$Script:RulebookVersion = "v10.0.2"
$Script:StartTime = Get-Date

# ASCII Art Header (PS 5.1 Compatible)
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CERTIFICATE SURVEILLANCE SCANNER" -ForegroundColor Cyan
Write-Host "  Version: $Script:Version" -ForegroundColor Cyan
Write-Host "  Regelwerk: $Script:RulebookVersion" -ForegroundColor Cyan
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

#region Functions

function Read-ServerList {
    param([string]$Path)
    
    Write-Host "[1/5] Reading server list..." -ForegroundColor Yellow
    
    if (-not (Test-Path $Path)) {
        Write-Host "  [ERROR] Server list not found: $Path" -ForegroundColor Red
        return @()
    }
    
    try {
        $content = Get-Content -Path $Path -Encoding UTF8
        $servers = $content | Where-Object { 
            $_ -and 
            $_ -notmatch '^\s*#' -and 
            $_ -notmatch '^\s*$' 
        } | ForEach-Object { $_.Trim() }
        
        Write-Host "  [OK] Found $($servers.Count) servers" -ForegroundColor Green
        
        return $servers
        
    } catch {
        Write-Host "  [ERROR] Failed to read server list: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Get-CertificatesFromServer {
    param(
        [string]$ServerName,
        [int]$Port = 9080
    )
    
    $result = @{
        ServerName = $ServerName
        Success = $false
        CertificateCount = 0
        Certificates = @()
        ResponseTime = 0
        ErrorMessage = $null
    }
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # DevSkim: ignore DS137138 - HTTP used intentionally (no SSL yet)
        $uri = "http://${ServerName}:${Port}/certificates.json"
        
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        $stopwatch.Stop()
        $result.ResponseTime = [int]$stopwatch.ElapsedMilliseconds
        
        if ($response) {
            $result.Success = $true
            $result.Certificates = $response
            $result.CertificateCount = ($response | Measure-Object).Count
        }
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
    }
    
    return $result
}

function New-CertificateReport {
    param(
        [array]$Results,
        [string]$OutputPath
    )
    
    Write-Host "[4/5] Generating report..." -ForegroundColor Yellow
    
    try {
        # Timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Statistics
        $totalServers = $Results.Count
        $successfulServers = ($Results | Where-Object { $_.Success }).Count
        $totalCertificates = ($Results | Where-Object { $_.Success } | ForEach-Object { $_.CertificateCount } | Measure-Object -Sum).Sum
        
        # Report Header
        $report = @"
========================================
CERTIFICATE SURVEILLANCE REPORT
========================================
Generated: $timestamp
Version: $Script:Version
Regelwerk: $Script:RulebookVersion

SUMMARY
========================================
Total Servers Scanned: $totalServers
Successful Scans: $successfulServers
Failed Scans: $($totalServers - $successfulServers)
Total Certificates: $totalCertificates

SERVER DETAILS
========================================

"@
        
        # Server Details
        foreach ($result in $Results) {
            $status = if ($result.Success) { "OK" } else { "FAILED" }
            
            $report += "Server: $($result.ServerName)`n"
            $report += "  Status: $status`n"
            
            if ($result.Success) {
                $report += "  Certificates: $($result.CertificateCount)`n"
                $report += "  Response Time: $($result.ResponseTime)ms`n"
                
                # Certificate Details
                if ($result.Certificates.Count -gt 0) {
                    foreach ($cert in $result.Certificates) {
                        $report += "    - $($cert.Subject) (Expires: $($cert.NotAfter))`n"
                    }
                }
            } else {
                $report += "  Error: $($result.ErrorMessage)`n"
            }
            
            $report += "`n"
        }
        
        # Footer
        $duration = (Get-Date) - $Script:StartTime
        $report += "========================================`n"
        $report += "Scan Duration: $([Math]::Round($duration.TotalSeconds, 2)) seconds`n"
        $report += "========================================`n"
        
        # Save Report
        $report | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        Write-Host "  [OK] Report saved: $OutputPath" -ForegroundColor Green
        
        return $OutputPath
        
    } catch {
        Write-Host "  [ERROR] Report generation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function New-CertificateJSON {
    param(
        [array]$Results,
        [string]$OutputPath
    )
    
    try {
        $jsonData = @{
            Generated = (Get-Date).ToString("o")
            Version = $Script:Version
            Rulebook = $Script:RulebookVersion
            Summary = @{
                TotalServers = $Results.Count
                SuccessfulScans = ($Results | Where-Object { $_.Success }).Count
                TotalCertificates = ($Results | Where-Object { $_.Success } | ForEach-Object { $_.CertificateCount } | Measure-Object -Sum).Sum
            }
            Results = $Results
        }
        
        $jsonData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        Write-Host "  [OK] JSON saved: $OutputPath" -ForegroundColor Green
        
        return $OutputPath
        
    } catch {
        Write-Host "  [ERROR] JSON export failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

#endregion

#region Main Execution

try {
    # Validate paths
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        Write-Host "[INFO] Created output directory: $OutputDirectory" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Server List: $ServerListPath" -ForegroundColor Gray
    Write-Host "  Output Directory: $OutputDirectory" -ForegroundColor Gray
    Write-Host "  Port: $Port" -ForegroundColor Gray
    Write-Host "  Max Concurrent: $MaxConcurrent" -ForegroundColor Gray
    Write-Host ""
    
    # Step 1: Read server list
    $servers = Read-ServerList -Path $ServerListPath
    
    if ($servers.Count -eq 0) {
        Write-Host "[ERROR] No servers to scan!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Step 2: Scan servers
    Write-Host "[2/5] Scanning servers..." -ForegroundColor Yellow
    Write-Host "  Starting scan of $($servers.Count) servers with max $MaxConcurrent concurrent..." -ForegroundColor Gray
    Write-Host ""
    
    $results = @()
    $processed = 0
    
    # Process in batches
    for ($i = 0; $i -lt $servers.Count; $i += $MaxConcurrent) {
        $batch = $servers[$i..[Math]::Min($i + $MaxConcurrent - 1, $servers.Count - 1)]
        
        # Process batch in parallel using jobs
        $jobs = @()
        foreach ($server in $batch) {
            $jobs += Start-Job -ScriptBlock {
                param($ServerName, $Port)
                
                $result = @{
                    ServerName = $ServerName
                    Success = $false
                    CertificateCount = 0
                    Certificates = @()
                    ResponseTime = 0
                    ErrorMessage = $null
                }
                
                try {
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    
                    # DevSkim: ignore DS137138 - HTTP used intentionally
                    $uri = "http://${ServerName}:${Port}/certificates.json"
                    
                    $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10 -ErrorAction Stop
                    
                    $stopwatch.Stop()
                    $result.ResponseTime = [int]$stopwatch.ElapsedMilliseconds
                    
                    if ($response) {
                        $result.Success = $true
                        $result.Certificates = $response
                        $result.CertificateCount = ($response | Measure-Object).Count
                    }
                    
                } catch {
                    $result.ErrorMessage = $_.Exception.Message
                }
                
                return $result
                
            } -ArgumentList $server, $Port
        }
        
        # Wait for batch completion
        $batchResults = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        # Display results
        foreach ($result in $batchResults) {
            $results += $result
            $processed++
            
            if ($result.Success) {
                Write-Host "  [OK] $($result.ServerName): $($result.CertificateCount) certificates ($($result.ResponseTime)ms)" -ForegroundColor Green
            } else {
                Write-Host "  [FAIL] $($result.ServerName): $($result.ErrorMessage)" -ForegroundColor Red
            }
        }
        
        # Progress
        $percentComplete = [Math]::Round(($processed / $servers.Count) * 100, 1)
        Write-Host "  Progress: $processed/$($servers.Count) ($percentComplete%)" -ForegroundColor Cyan
    }
    
    Write-Host ""
    
    # Step 3: Statistics
    Write-Host "[3/5] Scan Statistics" -ForegroundColor Yellow
    
    $successCount = ($results | Where-Object { $_.Success }).Count
    $failCount = $results.Count - $successCount
    $totalCerts = ($results | Where-Object { $_.Success } | ForEach-Object { $_.CertificateCount } | Measure-Object -Sum).Sum
    
    Write-Host "  Total Servers: $($results.Count)" -ForegroundColor White
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if($failCount -gt 0){'Red'}else{'Green'})
    Write-Host "  Total Certificates: $totalCerts" -ForegroundColor Cyan
    
    Write-Host ""
    
    # Step 4: Generate reports
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    
    $txtReport = Join-Path $OutputDirectory "CertScan_$timestamp.txt"
    $jsonReport = Join-Path $OutputDirectory "CertScan_$timestamp.json"
    
    New-CertificateReport -Results $results -OutputPath $txtReport
    New-CertificateJSON -Results $results -OutputPath $jsonReport
    
    Write-Host ""
    
    # Step 5: Summary
    Write-Host "[5/5] Scan Complete!" -ForegroundColor Green
    
    $duration = (Get-Date) - $Script:StartTime
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  SCAN SUMMARY" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Duration: $([Math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor White
    Write-Host "  Servers Scanned: $($results.Count)" -ForegroundColor White
    Write-Host "  Certificates Found: $totalCerts" -ForegroundColor White
    Write-Host "  Reports:" -ForegroundColor White
    Write-Host "    - $txtReport" -ForegroundColor Gray
    Write-Host "    - $jsonReport" -ForegroundColor Gray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Scan failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion
