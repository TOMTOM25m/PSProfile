#Requires -Version 5.1

<#
.SYNOPSIS
    Update-All-CertWebServices-Simple.ps1 - Einfache Massen-Update-Lösung für CertWebService
.DESCRIPTION
    Scannt Server, findet CertWebService-Installationen und führt Updates durch
.NOTES
    Version: 1.1.0
    Author: GitHub Copilot
    Date: 2025-10-06
    
    FUNKTIONEN:
    1. Server aus Excel scannen
    2. CertWebService-Status prüfen (Port 9080)
    3. Update-Scripts für gefundene Server generieren
    4. Batch-Update mit ROBOCOPY
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$WorksheetName = "Serversliste2025",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPing
)

$ErrorActionPreference = "Continue"
$LogFile = "F:\DEV\repositories\CertSurv\LOG\Update-All-CertWebServices-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

# Ensure LOG directory exists
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-UpdateLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStamp] [$Level] $Message"
    Write-Host $logLine
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

function Test-CertWebServiceRunning {
    param(
        [string]$ServerName
    )
    
    try {
        # Test TCP port 9080
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, 9080, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
        
        if ($wait) {
            $tcpClient.Close()
            return @{
                IsRunning = $true
                Version = "Detected"
                Status = "Port 9080 open"
            }
        } else {
            $tcpClient.Close()
            return @{
                IsRunning = $false
                Version = $null
                Status = "Port 9080 closed"
            }
        }
    } catch {
        return @{
            IsRunning = $false
            Version = $null
            Status = "Connection failed"
        }
    }
}

function Generate-UpdateScript {
    param(
        [string]$ServerName
    )
    
    $scriptContent = @"
#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    CertWebService Update Script for $ServerName
.DESCRIPTION
    Updates CertWebService on $ServerName from network share
#>

`$ErrorActionPreference = "Stop"
`$LogFile = "C:\CertSurv\LOG\CertWebService-Update-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

function Write-RemoteLog {
    param([string]`$Message, [string]`$Level = "INFO")
    `$timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logLine = "[`$timeStamp] [`$Level] `$Message"
    Write-Host `$logLine
    if (-not (Test-Path (Split-Path `$LogFile))) { New-Item -ItemType Directory -Path (Split-Path `$LogFile) -Force | Out-Null }
    Add-Content -Path `$LogFile -Value `$logLine -Encoding UTF8
}

Write-RemoteLog "=== CertWebService Update on $ServerName ==="

try {
    # 1. Stop CertWebService if running as service
    Write-RemoteLog "Checking for CertWebService service..."
    `$service = Get-Service -Name "CertWebService" -ErrorAction SilentlyContinue
    if (`$service) {
        if (`$service.Status -eq "Running") {
            Write-RemoteLog "Stopping CertWebService service..."
            Stop-Service -Name "CertWebService" -Force
            Start-Sleep -Seconds 5
            Write-RemoteLog "CertWebService service stopped"
        }
    } else {
        Write-RemoteLog "No CertWebService service found - checking for running processes..."
        
        # Stop any running CertWebService processes
        `$processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
            `$_.CommandLine -like "*CertWebService*"
        }
        
        if (`$processes) {
            Write-RemoteLog "Stopping CertWebService processes..."
            `$processes | Stop-Process -Force
            Start-Sleep -Seconds 3
        }
    }
    
    # 2. Create backup
    `$installPath = "C:\CertSurv\CertWebService"
    `$backupPath = "C:\CertSurv\Backup\CertWebService-BACKUP-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    
    if (Test-Path `$installPath) {
        Write-RemoteLog "Creating backup: `$backupPath"
        if (-not (Test-Path (Split-Path `$backupPath))) {
            New-Item -ItemType Directory -Path (Split-Path `$backupPath) -Force | Out-Null
        }
        robocopy `$installPath `$backupPath /E /Z /R:3 /W:5 /NP /NDL | Out-Null
        if (`$LASTEXITCODE -lt 8) {
            Write-RemoteLog "Backup created successfully"
        } else {
            Write-RemoteLog "Backup completed with warnings (Exit Code: `$LASTEXITCODE)" -Level "WARN"
        }
    } else {
        Write-RemoteLog "No existing installation found - fresh install"
        New-Item -ItemType Directory -Path `$installPath -Force | Out-Null
    }
    
    # 3. Update from network share
    `$networkSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
    Write-RemoteLog "Updating from: `$networkSource"
    
    if (-not (Test-Path `$networkSource)) {
        throw "Network source not accessible: `$networkSource"
    }
    
    robocopy `$networkSource `$installPath /E /Z /R:3 /W:5 /NP /NDL | Out-Null
    `$robocopyExit = `$LASTEXITCODE
    
    if (`$robocopyExit -lt 8) {
        Write-RemoteLog "Update files copied successfully (Exit Code: `$robocopyExit)"
    } else {
        throw "Update copy failed with exit code: `$robocopyExit"
    }
    
    # 4. Restart CertWebService
    if (`$service) {
        Write-RemoteLog "Starting CertWebService service..."
        Start-Service -Name "CertWebService"
        Start-Sleep -Seconds 5
        
        `$service = Get-Service -Name "CertWebService"
        if (`$service.Status -eq "Running") {
            Write-RemoteLog "CertWebService service started successfully"
        } else {
            Write-RemoteLog "CertWebService service failed to start" -Level "WARN"
        }
    } else {
        Write-RemoteLog "Manual start required - no service configured"
        Write-RemoteLog "To start manually: & 'C:\CertSurv\CertWebService\CertWebService.ps1'"
    }
    
    Write-RemoteLog "=== Update completed successfully ==="
    Write-RemoteLog "Log file: `$LogFile"
    
} catch {
    Write-RemoteLog "Update failed: `$(`$_.Exception.Message)" -Level "ERROR"
    Write-RemoteLog "Check log file: `$LogFile" -Level "ERROR"
    throw
}
"@
    
    return $scriptContent
}

Write-UpdateLog "=== CertWebService Mass Update Scanner ==="
Write-UpdateLog "Excel Path: $ExcelPath"
Write-UpdateLog "Worksheet: $WorksheetName"
Write-UpdateLog "WhatIf Mode: $($WhatIf.IsPresent)"

# Load Excel data
try {
    # Check if ImportExcel module is available
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-UpdateLog "Installing ImportExcel module..."
        Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
    }
    
    Import-Module ImportExcel -Force
    Write-UpdateLog "ImportExcel module loaded"
    
    # Read Excel data
    $allData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -NoHeader -ErrorAction Stop
    Write-UpdateLog "Excel data loaded: $($allData.Count) rows"
    
} catch {
    Write-UpdateLog "Failed to load Excel data: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Extract server names
$servers = @()
foreach ($row in $allData) {
    $serverNameCell = $row.P1
    if ([string]::IsNullOrWhiteSpace($serverNameCell)) { continue }
    $serverName = $serverNameCell.ToString().Trim()
    
    # Skip headers and block markers
    if ($serverName -match '^(ServerName|\(Domain|\(Workgroup|SUMME:|Server|Servers|NEUE SERVER|DATACENTER|STANDARD)' -or
        $serverName.Length -lt 3 -or
        $serverName -match '^[\s\-_=]+$') {
        continue
    }
    
    $servers += $serverName
}

Write-UpdateLog "Found $($servers.Count) potential servers in Excel"

# Step 1: Scan for CertWebService installations
Write-UpdateLog ""
Write-UpdateLog "=== Step 1: Scanning for CertWebService installations ==="

$webServiceServers = @()
$scanResults = @{}

foreach ($server in $servers) {
    Write-Progress -Activity "Scanning servers" -Status "Testing $server" -PercentComplete (($servers.IndexOf($server) + 1) / $servers.Count * 100)
    
    # Ping test (unless skipped)
    if (-not $SkipPing) {
        $pingResult = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
        if (-not $pingResult) {
            Write-UpdateLog "  [SKIP] $server - not reachable"
            $scanResults[$server] = @{ Status = "Not reachable"; CertWebService = $false }
            continue
        }
    }
    
    # Test CertWebService
    $certWebStatus = Test-CertWebServiceRunning -ServerName $server
    $scanResults[$server] = @{
        Status = $certWebStatus.Status
        CertWebService = $certWebStatus.IsRunning
        Version = $certWebStatus.Version
    }
    
    if ($certWebStatus.IsRunning) {
        Write-UpdateLog "  [FOUND] $server - CertWebService detected"
        $webServiceServers += $server
    } else {
        Write-UpdateLog "  [SKIP] $server - $($certWebStatus.Status)"
    }
}

Write-Progress -Activity "Scanning servers" -Completed

Write-UpdateLog ""
Write-UpdateLog "=== Scan Results ==="
Write-UpdateLog "Total servers scanned: $($servers.Count)"
Write-UpdateLog "CertWebService installations found: $($webServiceServers.Count)"

if ($webServiceServers.Count -eq 0) {
    Write-UpdateLog "No CertWebService installations found. Exiting." -Level "WARN"
    exit 0
}

Write-UpdateLog ""
Write-UpdateLog "CertWebService servers discovered:"
foreach ($server in $webServiceServers) {
    $result = $scanResults[$server]
    Write-UpdateLog "  ✅ $server ($($result.Status), Version: $($result.Version))"
}

if ($WhatIf) {
    Write-UpdateLog ""
    Write-UpdateLog "=== WHATIF MODE ==="
    Write-UpdateLog "Would generate update scripts for $($webServiceServers.Count) servers"
    Write-UpdateLog "Would deploy current CertWebService version to network share"
    Write-UpdateLog "Manual execution required on each server"
    exit 0
}

# Step 2: Deploy current version to network share
Write-UpdateLog ""
Write-UpdateLog "=== Step 2: Deploying current version to network share ==="

try {
    & "F:\DEV\repositories\Deploy-To-NetworkShare.ps1" -Component CertWebService
    if ($LASTEXITCODE -eq 0) {
        Write-UpdateLog "✅ Network share deployment successful"
    } else {
        Write-UpdateLog "❌ Network share deployment failed" -Level "ERROR"
        throw "Deployment to network share failed"
    }
} catch {
    Write-UpdateLog "Failed to deploy to network share: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Step 3: Generate update scripts
Write-UpdateLog ""
Write-UpdateLog "=== Step 3: Generating individual update scripts ==="

$updateScriptsPath = "F:\DEV\repositories\CertSurv\UpdateScripts"
if (-not (Test-Path $updateScriptsPath)) {
    New-Item -ItemType Directory -Path $updateScriptsPath -Force | Out-Null
}

$generatedScripts = @()

foreach ($server in $webServiceServers) {
    $scriptContent = Generate-UpdateScript -ServerName $server
    $scriptPath = Join-Path $updateScriptsPath "Update-CertWebService-$server.ps1"
    
    Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8
    $generatedScripts += @{
        Server = $server
        ScriptPath = $scriptPath
        NetworkPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\UpdateScripts\Update-CertWebService-$server.ps1"
    }
    
    Write-UpdateLog "  ✅ Generated: Update-CertWebService-$server.ps1"
}

# Step 4: Deploy update scripts to network share
Write-UpdateLog ""
Write-UpdateLog "=== Step 4: Deploying update scripts to network share ==="

$networkScriptsPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\UpdateScripts"
robocopy $updateScriptsPath $networkScriptsPath "*.ps1" /Z /R:3 /W:5 /NP /NDL | Out-Null

if ($LASTEXITCODE -lt 8) {
    Write-UpdateLog "✅ Update scripts deployed to network share"
} else {
    Write-UpdateLog "❌ Failed to deploy update scripts" -Level "ERROR"
}

# Step 5: Generate master batch script
Write-UpdateLog ""
Write-UpdateLog "=== Step 5: Generating master execution scripts ==="

$batchScriptContent = @"
@echo off
echo === CertWebService Mass Update Execution ===
echo Found $($webServiceServers.Count) CertWebService servers
echo.

"@

foreach ($script in $generatedScripts) {
    $batchScriptContent += @"
echo Updating $($script.Server)...
powershell.exe -ExecutionPolicy Bypass -File "$($script.NetworkPath)"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Update failed for $($script.Server)
    pause
) else (
    echo SUCCESS: $($script.Server) updated
)
echo.

"@
}

$batchScriptContent += @"
echo === All updates completed ===
pause
"@

$batchScriptPath = Join-Path $updateScriptsPath "Execute-All-Updates.bat"
Set-Content -Path $batchScriptPath -Value $batchScriptContent -Encoding ASCII

# Deploy batch script
robocopy $updateScriptsPath $networkScriptsPath "Execute-All-Updates.bat" /Z /R:3 /W:5 /NP /NDL | Out-Null

# Generate PowerShell execution script
$psExecutionScript = @"
#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Execute-All-CertWebService-Updates.ps1 - Führt alle CertWebService Updates aus
.DESCRIPTION
    Führt alle generierten Update-Scripts nacheinander aus
#>

`$ErrorActionPreference = "Continue"
`$servers = @(
$($webServiceServers | ForEach-Object { "    `"$_`"" } | Join-String -Separator ",`n")
)

Write-Host "=== CertWebService Mass Update Execution ===" -ForegroundColor Green
Write-Host "Found `$(`$servers.Count) CertWebService servers" -ForegroundColor White
Write-Host ""

`$successCount = 0
`$failureCount = 0

foreach (`$server in `$servers) {
    Write-Host "Updating `$server..." -ForegroundColor Cyan
    
    try {
        `$scriptPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\UpdateScripts\Update-CertWebService-`$server.ps1"
        & `$scriptPath
        
        if (`$LASTEXITCODE -eq 0) {
            Write-Host "  ✅ SUCCESS: `$server updated" -ForegroundColor Green
            `$successCount++
        } else {
            Write-Host "  ❌ ERROR: Update failed for `$server (Exit Code: `$LASTEXITCODE)" -ForegroundColor Red
            `$failureCount++
        }
    } catch {
        Write-Host "  ❌ ERROR: Update failed for `$server`: `$(`$_.Exception.Message)" -ForegroundColor Red
        `$failureCount++
    }
    
    Write-Host ""
}

Write-Host "=== Update Summary ===" -ForegroundColor Cyan
Write-Host "Total servers: `$(`$servers.Count)" -ForegroundColor White
Write-Host "Successful: `$successCount" -ForegroundColor Green
Write-Host "Failed: `$failureCount" -ForegroundColor Red

if (`$failureCount -gt 0) {
    Write-Host "Some updates failed. Check individual server logs." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "All updates completed successfully!" -ForegroundColor Green
    exit 0
}
"@

$psExecutionPath = Join-Path $updateScriptsPath "Execute-All-CertWebService-Updates.ps1"
Set-Content -Path $psExecutionPath -Value $psExecutionScript -Encoding UTF8

# Deploy PowerShell execution script
robocopy $updateScriptsPath $networkScriptsPath "Execute-All-CertWebService-Updates.ps1" /Z /R:3 /W:5 /NP /NDL | Out-Null

Write-UpdateLog "✅ Master execution scripts generated"

# Final summary
Write-UpdateLog ""
Write-UpdateLog "=== MASS UPDATE PREPARATION COMPLETE ==="
Write-UpdateLog "CertWebService servers found: $($webServiceServers.Count)"
Write-UpdateLog "Update scripts generated: $($generatedScripts.Count)"
Write-UpdateLog "Scripts deployed to: $networkScriptsPath"
Write-UpdateLog ""
Write-UpdateLog "EXECUTION OPTIONS:"
Write-UpdateLog "1. Batch execution:"
Write-UpdateLog "   $networkScriptsPath\Execute-All-Updates.bat"
Write-UpdateLog ""
Write-UpdateLog "2. PowerShell execution:"
Write-UpdateLog "   & '$networkScriptsPath\Execute-All-CertWebService-Updates.ps1'"
Write-UpdateLog ""
Write-UpdateLog "3. Individual server updates:"
foreach ($script in $generatedScripts) {
    Write-UpdateLog "   $($script.Server): $($script.NetworkPath)"
}
Write-UpdateLog ""
Write-UpdateLog "Log file: $LogFile"

Write-Host ""
Write-Host "=== READY FOR EXECUTION ===" -ForegroundColor Green
Write-Host "Run this to update all CertWebService installations:" -ForegroundColor Yellow
Write-Host "& '$networkScriptsPath\Execute-All-CertWebService-Updates.ps1'" -ForegroundColor White