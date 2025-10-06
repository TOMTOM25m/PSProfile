#Requires -Version 5.1

<#
.SYNOPSIS
    Update-REAL-CertWebServices.ps1 - Aktualisiert nur die echten CertWebService-Server
.DESCRIPTION
    Basierend auf Korrektur - nur die 3 bestätigten CertWebService-Server updaten
.NOTES
    ECHTE CertWebService-Server:
    - proman.uvw.meduniwien.ac.at (v10.0.2)
    - evaextest01.srv.meduniwien.ac.at (v10.0.2)
    - wsus.srv.meduniwien.ac.at (v10.0.2)
#>

param(
    [switch]$WhatIf,
    [switch]$ForceUpdate
)

$ErrorActionPreference = "Stop"
$LogFile = "F:\DEV\repositories\LOG\Update-REAL-CertWebServices-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

# Ensure LOG directory exists
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-UpdateLog {
    param([string]$Message, [string]$Level = "INFO")
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStamp] [$Level] $Message"
    Write-Host $logLine -ForegroundColor $(
        switch($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

# Nur die 3 echten CertWebService-Server
$realCertWebServiceServers = @(
    "proman.uvw.meduniwien.ac.at",
    "evaextest01.srv.meduniwien.ac.at", 
    "wsus.srv.meduniwien.ac.at"
)

Write-UpdateLog "=== Update für ECHTE CertWebService-Server ==="
Write-UpdateLog "Server zu aktualisieren: $($realCertWebServiceServers.Count)"
Write-UpdateLog "WhatIf-Modus: $($WhatIf.IsPresent)"
Write-UpdateLog "Force Update: $($ForceUpdate.IsPresent)"

# Step 1: Verify all servers are running
Write-UpdateLog "=== Step 1: Überprüfung der Server-Status ==="

$serverStatus = @{}
foreach ($server in $realCertWebServiceServers) {
    Write-UpdateLog "Checking $server..."
    
    try {
        $url = "http://${server}:9080"
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        
        if ($response.StatusCode -eq 200 -and $response.Content -match "Certificate Surveillance Dashboard") {
            # Extract version
            $versionMatch = [regex]::Match($response.Content, 'Regelwerk v([\d\.]+)')
            $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "Unknown" }
            
            $serverStatus[$server] = @{
                IsRunning = $true
                Version = $version
                Url = $url
                NeedsUpdate = ($version -ne "10.0.2" -or $ForceUpdate)
            }
            
            Write-UpdateLog "  [OK] $server - v$version - Ready for update" -Level "SUCCESS"
            
        } else {
            $serverStatus[$server] = @{
                IsRunning = $false
                Error = "No CertWebService Dashboard found"
            }
            Write-UpdateLog "  [ERROR] $server - No CertWebService Dashboard" -Level "ERROR"
        }
        
    } catch {
        $serverStatus[$server] = @{
            IsRunning = $false
            Error = $_.Exception.Message
        }
        Write-UpdateLog "  [ERROR] $server - $($_.Exception.Message)" -Level "ERROR"
    }
}

# Check if all servers are ready
$readyServers = $serverStatus.Keys | Where-Object { $serverStatus[$_].IsRunning }
$failedServers = $serverStatus.Keys | Where-Object { -not $serverStatus[$_].IsRunning }

Write-UpdateLog "Server bereit: $($readyServers.Count)"
Write-UpdateLog "Server fehlgeschlagen: $($failedServers.Count)"

if ($failedServers.Count -gt 0) {
    Write-UpdateLog "WARNUNG: Einige Server sind nicht bereit:" -Level "WARN"
    foreach ($server in $failedServers) {
        Write-UpdateLog "  - $server`: $($serverStatus[$server].Error)" -Level "WARN"
    }
}

if ($readyServers.Count -eq 0) {
    Write-UpdateLog "Keine Server bereit für Update. Abbruch." -Level "ERROR"
    exit 1
}

# Step 2: Deploy latest version to network share
if (-not $WhatIf) {
    Write-UpdateLog "=== Step 2: Deploy auf Netzlaufwerk ==="
    
    try {
        robocopy "F:\DEV\repositories\CertWebService" "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\CertWebService" /E /Z /R:3 /W:5 /NP /NDL
        if ($LASTEXITCODE -lt 8) {
            Write-UpdateLog "Netzlaufwerk-Deployment erfolgreich" -Level "SUCCESS"
        } else {
            throw "ROBOCOPY failed with exit code: $LASTEXITCODE"
        }
    } catch {
        Write-UpdateLog "Netzlaufwerk-Deployment fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Step 3: Update servers
Write-UpdateLog "=== Step 3: Server-Updates ==="

$updateResults = @{}

foreach ($server in $readyServers) {
    Write-UpdateLog "Updating $server..."
    
    $updateScript = @"
# CertWebService Update Script für $server
`$ErrorActionPreference = "Stop"

try {
    Write-Host "Starting CertWebService update on $server"
    
    # 1. Stop CertWebService
    Get-Process -Name "*CertWebService*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
    Write-Host "CertWebService processes stopped"
    
    # 2. Backup current version
    `$installPath = "C:\CertWebService"
    `$backupPath = "C:\CertWebService_BACKUP_$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    
    if (Test-Path `$installPath) {
        robocopy `$installPath `$backupPath /E /Z /R:3 /W:5 /NP /NDL | Out-Null
        Write-Host "Backup created: `$backupPath"
    }
    
    # 3. Copy new version from network share
    `$networkSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\CertWebService"
    robocopy `$networkSource `$installPath /E /Z /R:3 /W:5 /NP /NDL | Out-Null
    if (`$LASTEXITCODE -lt 8) {
        Write-Host "New version copied successfully"
    } else {
        throw "Copy failed with exit code: `$LASTEXITCODE"
    }
    
    # 4. Start CertWebService
    Start-Process "`$installPath\CertWebService.exe" -WorkingDirectory `$installPath
    Start-Sleep -Seconds 5
    Write-Host "CertWebService started"
    
    # 5. Verify service
    `$testUrl = "http://localhost:9080"
    `$response = Invoke-WebRequest -Uri `$testUrl -TimeoutSec 10 -UseBasicParsing
    if (`$response.StatusCode -eq 200) {
        Write-Host "Service verification successful"
    } else {
        throw "Service verification failed"
    }
    
    Write-Host "Update completed successfully on $server"
    
} catch {
    Write-Host "Update failed on $server`: `$(`$_.Exception.Message)" -ForegroundColor Red
    throw
}
"@

    if ($WhatIf) {
        Write-UpdateLog "  [WHATIF] Würde $server aktualisieren"
        $updateResults[$server] = @{ Success = $true; Message = "WhatIf mode" }
        continue
    }
    
    try {
        # Execute update remotely
        $result = Invoke-Command -ComputerName $server -ScriptBlock ([scriptblock]::Create($updateScript)) -ErrorAction Stop
        
        Write-UpdateLog "  [SUCCESS] $server erfolgreich aktualisiert" -Level "SUCCESS"
        $updateResults[$server] = @{ Success = $true; Message = "Update successful" }
        
    } catch {
        Write-UpdateLog "  [FAILED] $server Update fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        $updateResults[$server] = @{ Success = $false; Message = $_.Exception.Message }
    }
}

# Final summary
Write-UpdateLog "=== FINAL SUMMARY ==="
$successCount = ($updateResults.Values | Where-Object { $_.Success }).Count
$failureCount = $updateResults.Count - $successCount

Write-UpdateLog "Total servers: $($realCertWebServiceServers.Count)"
Write-UpdateLog "Ready for update: $($readyServers.Count)"
Write-UpdateLog "Update attempts: $($updateResults.Count)"
Write-UpdateLog "Successful updates: $successCount" -Level "SUCCESS"
Write-UpdateLog "Failed updates: $failureCount" -Level $(if ($failureCount -gt 0) { "ERROR" } else { "INFO" })

if ($successCount -gt 0) {
    Write-UpdateLog "Successfully updated:"
    foreach ($server in $updateResults.Keys) {
        if ($updateResults[$server].Success) {
            Write-UpdateLog "  ✅ $server" -Level "SUCCESS"
        }
    }
}

if ($failureCount -gt 0) {
    Write-UpdateLog "Failed updates:"
    foreach ($server in $updateResults.Keys) {
        if (-not $updateResults[$server].Success) {
            Write-UpdateLog "  ❌ $server - $($updateResults[$server].Message)" -Level "ERROR"
        }
    }
}

Write-UpdateLog "Log file: $LogFile"