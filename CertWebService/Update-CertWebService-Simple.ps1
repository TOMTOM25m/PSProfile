#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService Update Deployment - Simplified v1.0.0

.DESCRIPTION
    Vereinfachtes Update-Deployment für Server mit CertWebService v2.4.0 → v2.5.0
    
    WORKFLOW:
    1. Excel-Serverliste einlesen
    2. Server mit laufendem CertWebService finden (Port 9080 Check)
    3. Update durchführen (nur Server mit aktuellem CertWebService)
    
.PARAMETER TestOnly
    Nur Analyse, kein Update

.PARAMETER Filter
    Server-Filter für Excel-Auswahl

.EXAMPLE
    .\Update-CertWebService-Simple.ps1 -TestOnly -Filter "UVW"
#>

param(
    [switch]$TestOnly,
    [string]$Filter = "UVW"
)

$ErrorActionPreference = "Stop"

# Konfiguration
$excelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx"
$webServicePort = 9080
$targetVersion = "v2.5.0"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CERTWEBSERVICE UPDATE DEPLOYMENT" -ForegroundColor Cyan
Write-Host "  Simplified Version" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mode: $(if($TestOnly){'TEST ONLY'}else{'PRODUCTION'})" -ForegroundColor Yellow
Write-Host "Filter: $Filter" -ForegroundColor Yellow
Write-Host "Target Version: $targetVersion" -ForegroundColor Yellow
Write-Host ""

# Vereinfachte Server-Liste (hardcoded für Test)
$testServers = @(
    @{ Name = "wsus"; FQDN = "wsus.srv.meduniwien.ac.at" }
    @{ Name = "ITSCMGMT03"; FQDN = "ITSCMGMT03.srv.meduniwien.ac.at" }
    @{ Name = "UVWmgmt01"; FQDN = "UVWmgmt01.uvw.meduniwien.ac.at" }
    @{ Name = "UVW-FINANZ01"; FQDN = "UVW-FINANZ01.uvw.meduniwien.ac.at" }
    @{ Name = "EX01"; FQDN = "EX01.ex.meduniwien.ac.at" }
    @{ Name = "UVWDC001"; FQDN = "UVWDC001.uvw.meduniwien.ac.at" }
)

# Filter anwenden
if ($Filter) {
    $testServers = $testServers | Where-Object { $_.Name -match $Filter -or $_.FQDN -match $Filter }
}

Write-Host "[*] Checking $($testServers.Count) servers for CertWebService..." -ForegroundColor Yellow
Write-Host ""

$results = @()

foreach ($server in $testServers) {
    Write-Host "[$($server.Name)]" -ForegroundColor Cyan -NoNewline
    
    try {
        # 1. Ping Test
        $ping = Test-Connection -ComputerName $server.FQDN -Count 1 -Quiet
        if (-not $ping) {
            Write-Host " OFFLINE" -ForegroundColor Red
            $results += @{ Server = $server.Name; Status = "OFFLINE"; Version = $null }
            continue
        }
        
        # 2. CertWebService Check
        try {
            $uri = "http://$($server.FQDN):$webServicePort/health.json"
            $response = Invoke-RestMethod -Uri $uri -ErrorAction Stop
            
            Write-Host " ONLINE" -ForegroundColor Green -NoNewline
            Write-Host " | CertWebService: $($response.version)" -ForegroundColor Gray
            
            $needsUpdate = $response.version -ne $targetVersion
            
            $results += @{
                Server = $server.Name
                FQDN = $server.FQDN
                Status = "RUNNING"
                CurrentVersion = $response.version
                NeedsUpdate = $needsUpdate
                TargetVersion = $targetVersion
            }
            
        } catch {
            Write-Host " ONLINE" -ForegroundColor Green -NoNewline
            Write-Host " | No CertWebService" -ForegroundColor Gray
            
            $results += @{
                Server = $server.Name
                FQDN = $server.FQDN
                Status = "NO_CERTWEBSERVICE"
                CurrentVersion = $null
                NeedsUpdate = $false
            }
        }
        
    } catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $results += @{ Server = $server.Name; Status = "ERROR"; Version = $null; Error = $_.Exception.Message }
    }
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ANALYSIS RESULTS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$serversWithCertWebService = $results | Where-Object { $_.Status -eq "RUNNING" }
$serversNeedingUpdate = $serversWithCertWebService | Where-Object { $_.NeedsUpdate -eq $true }
$serversUpToDate = $serversWithCertWebService | Where-Object { $_.NeedsUpdate -eq $false }

Write-Host "Total Servers Checked: $($results.Count)" -ForegroundColor White
Write-Host "Servers with CertWebService: $($serversWithCertWebService.Count)" -ForegroundColor Green
Write-Host "Servers needing update: $($serversNeedingUpdate.Count)" -ForegroundColor Yellow
Write-Host "Servers up-to-date: $($serversUpToDate.Count)" -ForegroundColor Cyan
Write-Host ""

if ($serversNeedingUpdate.Count -gt 0) {
    Write-Host "SERVERS NEEDING UPDATE:" -ForegroundColor Yellow
    $serversNeedingUpdate | ForEach-Object {
        Write-Host "  [+] $($_.Server) ($($_.FQDN))" -ForegroundColor White
        Write-Host "      Current: $($_.CurrentVersion) → Target: $($_.TargetVersion)" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($serversUpToDate.Count -gt 0) {
    Write-Host "SERVERS UP-TO-DATE:" -ForegroundColor Cyan
    $serversUpToDate | ForEach-Object {
        Write-Host "  [=] $($_.Server) ($($_.CurrentVersion))" -ForegroundColor Gray
    }
    Write-Host ""
}

# Update Execution
if (-not $TestOnly -and $serversNeedingUpdate.Count -gt 0) {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  UPDATE EXECUTION" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[!] This would update $($serversNeedingUpdate.Count) servers" -ForegroundColor Yellow
    Write-Host "[!] Use existing Update-AllServers-Hybrid-v2.5.ps1 for actual deployment" -ForegroundColor Yellow
    
    # Erstelle Server-Liste für existierendes Script
    $serverNames = $serversNeedingUpdate | ForEach-Object { $_.Server }
    Write-Host ""
    Write-Host "COMMAND TO RUN:" -ForegroundColor Green
    Write-Host ".\Update-AllServers-Hybrid-v2.5.ps1 -ServerList @('$($serverNames -join "','")') -AdminCredential `$cred" -ForegroundColor White
    
} elseif ($TestOnly) {
    Write-Host "[INFO] Test mode - no updates performed" -ForegroundColor Cyan
    Write-Host "[INFO] Use -TestOnly:`$false for actual deployment" -ForegroundColor Cyan
} else {
    Write-Host "[INFO] All servers are up-to-date!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Analysis completed!" -ForegroundColor Green