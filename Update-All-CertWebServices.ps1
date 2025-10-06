#Requires -Version 5.1

<#
.SYNOPSIS
    Update-All-CertWebServices.ps1 - Massen-Update für alle CertWebService-Installationen
.DESCRIPTION
    Liest alle Server aus Excel, erkennt CertWebService-Installationen und führt Updates durch
.NOTES
    Version: 1.0.0
    Author: GitHub Copilot
    Date: 2025-10-06
    
    FUNKTIONEN:
    1. Excel-Datei scannen nach Servern
    2. CertWebService-Status prüfen (Port 9080)
    3. Auf gefundenen Servern Update ausführen
    4. Detailliertes Logging und Reporting
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$WorksheetName = "Serversliste2025",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPing,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxConcurrent = 5
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
        # Test HTTP port 9080
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, 9080, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
        $tcpClient.Close()
        
        if ($wait) {
            # Try to get version info
            try {
                $uri = "http://$ServerName:9080/certificates.json"
                $response = Invoke-RestMethod -Uri $uri -TimeoutSec 5 -ErrorAction Stop
                if ($response.version) {
                    return @{
                        IsRunning = $true
                        Version = $response.version
                        Status = "OK"
                    }
                }
            } catch {
                # Port open but no valid response
                return @{
                    IsRunning = $true
                    Version = "Unknown"
                    Status = "Port open, no API response"
                }
            }
        }
        
        return @{
            IsRunning = $false
            Version = $null
            Status = "Not running"
        }
    } catch {
        return @{
            IsRunning = $false
            Version = $null
            Status = "Connection failed: $($_.Exception.Message)"
        }
    }
}

function Update-CertWebServiceOnServer {
    param(
        [string]$ServerName,
        [bool]$WhatIfMode = $false
    )
    
    Write-UpdateLog "Starting update on server: $ServerName"
    
    try {
        # Prepare update script content
        $updateScript = @"
# CertWebService Update Script for $ServerName
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
    # 1. Stop CertWebService if running
    `$service = Get-Service -Name "CertWebService" -ErrorAction SilentlyContinue
    if (`$service -and `$service.Status -eq "Running") {
        Write-RemoteLog "Stopping CertWebService..."
        Stop-Service -Name "CertWebService" -Force
        Start-Sleep -Seconds 3
        Write-RemoteLog "CertWebService stopped"
    }
    
    # 2. Backup current installation
    `$installPath = "C:\CertSurv\CertWebService"
    `$backupPath = "C:\CertSurv\Backup\CertWebService-BACKUP-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    
    if (Test-Path `$installPath) {
        Write-RemoteLog "Creating backup: `$backupPath"
        robocopy `$installPath `$backupPath /E /Z /R:3 /W:5 /NP /NDL | Out-Null
        if (`$LASTEXITCODE -lt 8) {
            Write-RemoteLog "Backup created successfully"
        } else {
            throw "Backup failed with exit code: `$LASTEXITCODE"
        }
    }
    
    # 3. Copy new version from network share
    `$networkSource = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
    if (Test-Path `$networkSource) {
        Write-RemoteLog "Updating from network share: `$networkSource"
        robocopy `$networkSource `$installPath /E /Z /R:3 /W:5 /NP /NDL | Out-Null
        if (`$LASTEXITCODE -lt 8) {
            Write-RemoteLog "Update files copied successfully"
        } else {
            throw "Update copy failed with exit code: `$LASTEXITCODE"
        }
    } else {
        throw "Network source not accessible: `$networkSource"
    }
    
    # 4. Restart CertWebService
    if (`$service) {
        Write-RemoteLog "Starting CertWebService..."
        Start-Service -Name "CertWebService"
        Start-Sleep -Seconds 5
        
        # 5. Verify service is running
        `$service = Get-Service -Name "CertWebService"
        if (`$service.Status -eq "Running") {
            Write-RemoteLog "CertWebService started successfully"
            
            # Test API endpoint
            try {
                `$response = Invoke-RestMethod -Uri "http://localhost:9080/certificates.json" -TimeoutSec 10
                Write-RemoteLog "API test successful - Version: `$(`$response.version)"
            } catch {
                Write-RemoteLog "API test failed: `$(`$_.Exception.Message)" -Level "WARN"
            }
        } else {
            throw "CertWebService failed to start"
        }
    }
    
    Write-RemoteLog "=== Update completed successfully ==="
    
} catch {
    Write-RemoteLog "Update failed: `$(`$_.Exception.Message)" -Level "ERROR"
    throw
}
"@
        
        if ($WhatIfMode) {
            Write-UpdateLog "  [WHATIF] Would execute update script on $ServerName"
            return @{
                Success = $true
                Message = "WhatIf mode - no changes made"
                Version = "Not checked"
            }
        }
        
        # Create temp script file
        $tempScript = "F:\DEV\repositories\temp-update-$ServerName-$(Get-Date -Format 'HHmmss').ps1"
        Set-Content -Path $tempScript -Value $updateScript -Encoding UTF8
        
        # Execute remotely using Invoke-Command
        try {
            $result = Invoke-Command -ComputerName $ServerName -FilePath $tempScript -ErrorAction Stop
            
            # Cleanup temp file
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            
            Write-UpdateLog "  [OK] Update completed on $ServerName"
            return @{
                Success = $true
                Message = "Update completed successfully"
                Version = "Updated"
            }
            
        } catch {
            # Cleanup temp file
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            
            Write-UpdateLog "  [ERROR] Remote execution failed on $ServerName`: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = "Remote execution failed: $($_.Exception.Message)"
                Version = "Unknown"
            }
        }
        
    } catch {
        Write-UpdateLog "  [ERROR] Update preparation failed for $ServerName`: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Update preparation failed: $($_.Exception.Message)"
            Version = "Unknown"
        }
    }
}

Write-UpdateLog "=== CertWebService Mass Update Started ==="
Write-UpdateLog "Excel Path: $ExcelPath"
Write-UpdateLog "Worksheet: $WorksheetName"
Write-UpdateLog "WhatIf Mode: $($WhatIf.IsPresent)"
Write-UpdateLog "Max Concurrent: $MaxConcurrent"

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

# Step 1: Test connectivity and CertWebService status
Write-UpdateLog "=== Step 1: Testing server connectivity and CertWebService status ==="

$serverStatus = @{}
$webServiceServers = @()

foreach ($server in $servers) {
    Write-UpdateLog "Testing $server..."
    
    # Ping test (unless skipped)
    if (-not $SkipPing) {
        $pingResult = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
        if (-not $pingResult) {
            Write-UpdateLog "  [SKIP] $server - not reachable"
            $serverStatus[$server] = @{
                Reachable = $false
                CertWebService = $null
                Reason = "Not reachable"
            }
            continue
        }
    }
    
    # Test CertWebService
    $certWebStatus = Test-CertWebServiceRunning -ServerName $server
    $serverStatus[$server] = @{
        Reachable = $true
        CertWebService = $certWebStatus
        Reason = $certWebStatus.Status
    }
    
    if ($certWebStatus.IsRunning) {
        Write-UpdateLog "  [FOUND] $server - CertWebService $($certWebStatus.Version) running"
        $webServiceServers += $server
    } else {
        Write-UpdateLog "  [SKIP] $server - $($certWebStatus.Status)"
    }
}

Write-UpdateLog "=== Discovery Results ==="
Write-UpdateLog "Total servers scanned: $($servers.Count)"
Write-UpdateLog "Reachable servers: $(($serverStatus.Values | Where-Object { $_.Reachable }).Count)"
Write-UpdateLog "CertWebService servers found: $($webServiceServers.Count)"

if ($webServiceServers.Count -eq 0) {
    Write-UpdateLog "No CertWebService installations found. Exiting." -Level "WARN"
    exit 0
}

# Show discovered CertWebService servers
Write-UpdateLog "CertWebService servers to update:"
foreach ($server in $webServiceServers) {
    $status = $serverStatus[$server].CertWebService
    Write-UpdateLog "  - $server (Version: $($status.Version))"
}

if ($WhatIf) {
    Write-UpdateLog ""
    Write-UpdateLog "=== WHATIF MODE - No updates will be performed ==="
    Write-UpdateLog "Would update $($webServiceServers.Count) CertWebService installations"
    exit 0
}

# Step 2: Deploy current version to network share first
Write-UpdateLog ""
Write-UpdateLog "=== Step 2: Deploying current version to network share ==="

try {
    & "F:\DEV\repositories\Deploy-To-NetworkShare.ps1" -Component CertWebService
    if ($LASTEXITCODE -eq 0) {
        Write-UpdateLog "Network share deployment successful"
    } else {
        Write-UpdateLog "Network share deployment failed" -Level "ERROR"
        throw "Deployment to network share failed"
    }
} catch {
    Write-UpdateLog "Failed to deploy to network share: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Step 3: Update servers
Write-UpdateLog ""
Write-UpdateLog "=== Step 3: Updating CertWebService on servers ==="

$updateResults = @{}
$successCount = 0
$failureCount = 0

# Process servers (with concurrency limit)
$processedServers = @()
foreach ($server in $webServiceServers) {
    # Wait for running jobs to complete if we hit the limit
    while ((Get-Job -State Running).Count -ge $MaxConcurrent) {
        Start-Sleep -Seconds 2
    }
    
    # Start update job
    $job = Start-Job -Name "Update-$server" -ScriptBlock {
        param($ServerName, $WhatIfMode, $UpdateFunction)
        & $UpdateFunction -ServerName $ServerName -WhatIfMode $WhatIfMode
    } -ArgumentList $server, $WhatIf.IsPresent, ${function:Update-CertWebServiceOnServer}
    
    $processedServers += $server
    Write-UpdateLog "Started update job for $server"
}

# Wait for all jobs to complete and collect results
Write-UpdateLog "Waiting for all update jobs to complete..."

while ((Get-Job -State Running).Count -gt 0) {
    Start-Sleep -Seconds 5
    $runningJobs = (Get-Job -State Running).Count
    Write-UpdateLog "  $runningJobs jobs still running..."
}

# Collect results
foreach ($server in $processedServers) {
    $job = Get-Job -Name "Update-$server"
    $result = Receive-Job $job
    Remove-Job $job
    
    $updateResults[$server] = $result
    
    if ($result.Success) {
        $successCount++
        Write-UpdateLog "[SUCCESS] $server - $($result.Message)"
    } else {
        $failureCount++
        Write-UpdateLog "[FAILURE] $server - $($result.Message)" -Level "ERROR"
    }
}

# Final summary
Write-UpdateLog ""
Write-UpdateLog "=== UPDATE SUMMARY ==="
Write-UpdateLog "Total CertWebService servers: $($webServiceServers.Count)"
Write-UpdateLog "Successful updates: $successCount"
Write-UpdateLog "Failed updates: $failureCount"
Write-UpdateLog ""

if ($successCount -gt 0) {
    Write-UpdateLog "Successfully updated servers:"
    foreach ($server in $webServiceServers) {
        if ($updateResults[$server].Success) {
            $version = $updateResults[$server].Version
            Write-UpdateLog "  ✅ $server ($version)"
        }
    }
}

if ($failureCount -gt 0) {
    Write-UpdateLog "Failed updates:"
    foreach ($server in $webServiceServers) {
        if (-not $updateResults[$server].Success) {
            Write-UpdateLog "  ❌ $server - $($updateResults[$server].Message)" -Level "ERROR"
        }
    }
}

Write-UpdateLog ""
Write-UpdateLog "=== Mass update completed ==="
Write-UpdateLog "Log file: $LogFile"

# Exit with appropriate code
if ($failureCount -gt 0) {
    exit 1
} else {
    exit 0
}