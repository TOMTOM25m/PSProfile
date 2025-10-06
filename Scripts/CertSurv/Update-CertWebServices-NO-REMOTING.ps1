#Requires -Version 5.1

<#
.SYNOPSIS
    Update-CertWebServices-NO-REMOTING.ps1 - Updates ohne PowerShell Remoting
.DESCRIPTION
    Alternative Update-Methode ohne Invoke-Command - verwendet lokale Scripts auf Netzlaufwerk
.NOTES
    Lösung für WinRM/TrustedHosts Probleme in Unternehmensumgebungen
.PARAMETER ManualMode
    Erstellt nur die Update-Scripts auf dem Netzlaufwerk für manuelle Ausführung
#>

param(
    [switch]$WhatIf,
    [switch]$ManualMode,
    [switch]$ForceUpdate
)

$ErrorActionPreference = "Stop"
$LogFile = "F:\DEV\repositories\LOG\Update-CertWebServices-NO-REMOTING-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

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

# Die 3 echten CertWebService-Server
$realCertWebServiceServers = @(
    @{ Name = "proman"; FQDN = "proman.uvw.meduniwien.ac.at"; Domain = "uvw" },
    @{ Name = "evaextest01"; FQDN = "evaextest01.srv.meduniwien.ac.at"; Domain = "srv" },
    @{ Name = "wsus"; FQDN = "wsus.srv.meduniwien.ac.at"; Domain = "srv" }
)

Write-UpdateLog "=== CertWebService Update OHNE PowerShell Remoting ==="
Write-UpdateLog "Server zu aktualisieren: $($realCertWebServiceServers.Count)"
Write-UpdateLog "WhatIf-Modus: $($WhatIf.IsPresent)"
Write-UpdateLog "Manual-Modus: $($ManualMode.IsPresent)"

# Step 1: Verify server status (HTTP only)
Write-UpdateLog "=== Step 1: Server-Status Verification (HTTP) ==="

$serverStatus = @{}
foreach ($serverInfo in $realCertWebServiceServers) {
    $server = $serverInfo.FQDN
    Write-UpdateLog "Checking $server..."
    
    try {
        $url = "http://${server}:9080"
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        
        if ($response.StatusCode -eq 200 -and $response.Content -match "Certificate Surveillance Dashboard") {
            $versionMatch = [regex]::Match($response.Content, 'Regelwerk v([\d\.]+)')
            $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "Unknown" }
            
            $serverStatus[$server] = @{
                IsRunning = $true
                Version = $version
                Url = $url
                ServerInfo = $serverInfo
            }
            
            Write-UpdateLog "  [OK] $server - v$version - CertWebService running" -Level "SUCCESS"
            
        } else {
            Write-UpdateLog "  [ERROR] $server - No CertWebService Dashboard found" -Level "ERROR"
            $serverStatus[$server] = @{ IsRunning = $false; Error = "No Dashboard" }
        }
        
    } catch {
        Write-UpdateLog "  [ERROR] $server - $($_.Exception.Message)" -Level "ERROR"
        $serverStatus[$server] = @{ IsRunning = $false; Error = $_.Exception.Message }
    }
}

$readyServers = $serverStatus.Keys | Where-Object { $serverStatus[$_].IsRunning }
Write-UpdateLog "Server ready for update: $($readyServers.Count)"

if ($readyServers.Count -eq 0) {
    Write-UpdateLog "Keine Server bereit für Update. Abbruch." -Level "ERROR"
    exit 1
}

# Step 2: Deploy current version to network share
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

# Step 3: Create individual update scripts for each server
Write-UpdateLog "=== Step 3: Erstelle Update-Scripts für jeden Server ==="

$networkScriptsPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates"

# Create scripts directory
try {
    if (-not (Test-Path $networkScriptsPath)) {
        New-Item -ItemType Directory -Path $networkScriptsPath -Force | Out-Null
    }
} catch {
    Write-UpdateLog "Could not create scripts directory: $($_.Exception.Message)" -Level "ERROR"
    throw
}

$createdScripts = @()

foreach ($server in $readyServers) {
    $serverInfo = $serverStatus[$server].ServerInfo
    $serverName = $serverInfo.Name
    
    Write-UpdateLog "Creating update script for $server..."
    
    $updateScript = @"
#Requires -Version 5.1
# CertWebService Update Script für $server
# Generiert: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Server: $($serverInfo.Name) ($($serverInfo.FQDN))
# Domain: $($serverInfo.Domain)

`$ErrorActionPreference = "Stop"
`$LogFile = "C:\Temp\CertWebService-Update-$serverName-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

function Write-UpdateLog {
    param([string]`$Message, [string]`$Level = "INFO")
    `$timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logLine = "[`$timeStamp] [`$Level] `$Message"
    Write-Host `$logLine -ForegroundColor `$(if (`$Level -eq "ERROR") { "Red" } else { "Green" })
    
    # Ensure log directory exists
    `$logDir = Split-Path `$LogFile -Parent
    if (-not (Test-Path `$logDir)) { New-Item -ItemType Directory -Path `$logDir -Force | Out-Null }
    Add-Content -Path `$LogFile -Value `$logLine -Encoding UTF8
}

Write-UpdateLog "=== CertWebService Update für $server ==="
Write-UpdateLog "Hostname: $serverName"
Write-UpdateLog "FQDN: $($serverInfo.FQDN)"
Write-UpdateLog "Domain: $($serverInfo.Domain)"

try {
    # 1. Stop CertWebService processes
    Write-UpdateLog "Stopping CertWebService processes..."
    Get-Process -Name "*CertWebService*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-UpdateLog "Stopping process: `$(`$_.Name) (PID: `$(`$_.Id))"
        Stop-Process -Id `$_.Id -Force
    }
    Start-Sleep -Seconds 5
    Write-UpdateLog "CertWebService processes stopped"
    
    # 2. Create backup
    `$installPath = "C:\CertWebService"
    `$backupPath = "C:\CertWebService_BACKUP_$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    
    if (Test-Path `$installPath) {
        Write-UpdateLog "Creating backup: `$backupPath"
        robocopy `$installPath `$backupPath /E /Z /R:3 /W:5 /NP /NDL /LOG:NUL
        if (`$LASTEXITCODE -lt 8) {
            Write-UpdateLog "Backup created successfully"
        } else {
            Write-UpdateLog "Backup warning - exit code: `$LASTEXITCODE" -Level "WARN"
        }
    } else {
        Write-UpdateLog "No existing installation found at `$installPath" -Level "WARN"
    }
    
    # 3. Copy new version from network share
    `$networkSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\CertWebService"
    Write-UpdateLog "Copying from: `$networkSource"
    Write-UpdateLog "Copying to: `$installPath"
    
    robocopy `$networkSource `$installPath /E /Z /R:3 /W:5 /NP /NDL /LOG:NUL
    if (`$LASTEXITCODE -lt 8) {
        Write-UpdateLog "New version copied successfully"
    } else {
        Write-UpdateLog "Copy completed with exit code: `$LASTEXITCODE" -Level "WARN"
    }
    
    # 4. Start CertWebService
    `$exePath = "`$installPath\CertWebService.ps1"
    if (Test-Path `$exePath) {
        Write-UpdateLog "Starting CertWebService: `$exePath"
        Start-Process powershell.exe -ArgumentList "-File `"`$exePath`"" -WorkingDirectory `$installPath
        Start-Sleep -Seconds 10
        Write-UpdateLog "CertWebService started"
    } else {
        Write-UpdateLog "CertWebService executable not found: `$exePath" -Level "ERROR"
        throw "Executable not found"
    }
    
    # 5. Verify service
    Start-Sleep -Seconds 5
    Write-UpdateLog "Verifying service..."
    
    `$testUrl = "http://localhost:9080"
    try {
        `$response = Invoke-WebRequest -Uri `$testUrl -TimeoutSec 15 -UseBasicParsing
        if (`$response.StatusCode -eq 200 -and `$response.Content -match "Certificate Surveillance Dashboard") {
            `$versionMatch = [regex]::Match(`$response.Content, 'Regelwerk v([\d\.]+)')
            `$newVersion = if (`$versionMatch.Success) { `$versionMatch.Groups[1].Value } else { "Unknown" }
            Write-UpdateLog "✅ Service verification successful - Version: `$newVersion" -Level "SUCCESS"
        } else {
            Write-UpdateLog "⚠️ Service responding but dashboard not found" -Level "WARN"
        }
    } catch {
        Write-UpdateLog "❌ Service verification failed: `$(`$_.Exception.Message)" -Level "ERROR"
        throw "Service verification failed"
    }
    
    Write-UpdateLog "=== Update completed successfully for $server ==="
    Write-UpdateLog "Log file: `$LogFile"
    
    # Success indicator file
    Set-Content -Path "C:\Temp\CertWebService-Update-SUCCESS-$serverName.txt" -Value "Update completed successfully at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
} catch {
    Write-UpdateLog "❌ Update failed for $server`: `$(`$_.Exception.Message)" -Level "ERROR"
    Write-UpdateLog "Stack trace: `$(`$_.ScriptStackTrace)" -Level "ERROR"
    
    # Error indicator file
    Set-Content -Path "C:\Temp\CertWebService-Update-ERROR-$serverName.txt" -Value "Update failed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): `$(`$_.Exception.Message)"
    
    throw
}
"@

    $scriptPath = "$networkScriptsPath\Update-$serverName.ps1"
    
    if ($WhatIf) {
        Write-UpdateLog "  [WHATIF] Would create: $scriptPath"
    } else {
        try {
            Set-Content -Path $scriptPath -Value $updateScript -Encoding UTF8
            Write-UpdateLog "  [OK] Created: $scriptPath" -Level "SUCCESS"
            $createdScripts += @{
                Server = $server
                ServerName = $serverName
                ScriptPath = $scriptPath
                FQDN = $serverInfo.FQDN
            }
        } catch {
            Write-UpdateLog "  [ERROR] Failed to create script for $server`: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

# Step 4: Create master execution script
Write-UpdateLog "=== Step 4: Erstelle Master-Execution-Script ==="

$masterScript = @"
#Requires -Version 5.1
# Master CertWebService Update Execution Script
# Generiert: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# 
# ANLEITUNG:
# 1. Dieses Script auf einem Admin-Computer ausführen
# 2. Es verwendet PsExec oder ähnliche Tools für Remote-Ausführung
# 3. Alternativ: Die einzelnen Scripts manuell auf jedem Server ausführen

Write-Host "=== CertWebService Mass Update (NO REMOTING) ===" -ForegroundColor Green
Write-Host "Verfügbare Server-Update-Scripts:" -ForegroundColor Yellow

"@

foreach ($script in $createdScripts) {
    $masterScript += @"
Write-Host "  - $($script.ServerName) ($($script.FQDN))" -ForegroundColor White
Write-Host "    Script: $($script.ScriptPath)" -ForegroundColor Gray

"@
}

$masterScript += @"

Write-Host ""
Write-Host "OPTION 1 - Manuelle Ausführung:" -ForegroundColor Cyan
"@

foreach ($script in $createdScripts) {
    $masterScript += @"
Write-Host "  RDP/SSH zu $($script.FQDN) und ausführen:" -ForegroundColor White
Write-Host "  PowerShell -ExecutionPolicy Bypass -File `"$($script.ScriptPath)`"" -ForegroundColor Yellow
Write-Host ""
"@
}

$masterScript += @"

Write-Host "OPTION 2 - PsExec (falls verfügbar):" -ForegroundColor Cyan
"@

foreach ($script in $createdScripts) {
    $masterScript += @"
Write-Host "  psexec \\$($script.FQDN) -u Administrator powershell.exe -ExecutionPolicy Bypass -File `"$($script.ScriptPath)`"" -ForegroundColor Yellow
"@
}

$masterScript += @"

Write-Host ""
Write-Host "Die Update-Scripts sind bereit auf dem Netzlaufwerk!" -ForegroundColor Green
Write-Host "Pfad: $networkScriptsPath" -ForegroundColor White
"@

$masterScriptPath = "$networkScriptsPath\MASTER-Execute-All-Updates.ps1"

if ($WhatIf) {
    Write-UpdateLog "[WHATIF] Would create master script: $masterScriptPath"
} else {
    Set-Content -Path $masterScriptPath -Value $masterScript -Encoding UTF8
    Write-UpdateLog "Master script created: $masterScriptPath" -Level "SUCCESS"
}

# Final summary
Write-UpdateLog "=== FINAL SUMMARY ==="
Write-UpdateLog "Ready servers: $($readyServers.Count)"
Write-UpdateLog "Scripts created: $($createdScripts.Count)"
Write-UpdateLog "Scripts location: $networkScriptsPath"

if (-not $WhatIf) {
    Write-UpdateLog ""
    Write-UpdateLog "🎯 NÄCHSTE SCHRITTE:" -Level "SUCCESS"
    Write-UpdateLog "1. Führe Master-Script aus: $masterScriptPath" -Level "SUCCESS"
    Write-UpdateLog "2. ODER führe Scripts manuell auf jedem Server aus" -Level "SUCCESS"
    
    Write-UpdateLog ""
    Write-UpdateLog "📁 Erstellte Update-Scripts:" -Level "SUCCESS"
    foreach ($script in $createdScripts) {
        Write-UpdateLog "  ✅ $($script.ServerName): $($script.ScriptPath)" -Level "SUCCESS"
    }
}

Write-UpdateLog "Log file: $LogFile"