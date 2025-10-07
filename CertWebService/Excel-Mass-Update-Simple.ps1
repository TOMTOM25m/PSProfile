#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService Excel Mass Update - SMB Priority v3.1.0

.DESCRIPTION
    Vereinfachte Excel-basierte Mass-Update-Lösung mit SMB-Priorität:
    
    1. Excel-Serverliste vollständig auswerten
    2. CertWebService-Status prüfen (v2.4.0 → v2.5.0 Updates)
    3. SMB-Verbindungen nutzen für File-Deployment
    4. PSRemoting aktivieren wo möglich
    5. Bulk-Update mit Fortschrittsanzeige

.PARAMETER FilterDomain
    Domain-Filter (z.B. "uvw", "srv")

.PARAMETER DryRun
    Testlauf ohne Änderungen

.VERSION
    3.1.0 - Simplified
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$FilterDomain = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$EnablePSRemoting,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 15
)

$Script:Version = "v3.1.0"
$Script:StartTime = Get-Date
$Script:NewVersion = "v2.5.0"

Write-Host "🚀 CertWebService Excel Mass Update - SMB Priority" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version: $Script:Version | Target: $Script:NewVersion" -ForegroundColor Gray
Write-Host "Started: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "Excel: $(Split-Path $ExcelPath -Leaf)" -ForegroundColor Gray
Write-Host ""

# Import ImportExcel module
try {
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "📦 Installing ImportExcel module..." -ForegroundColor Cyan
        Install-Module -Name ImportExcel -Force -Scope CurrentUser
    }
    Import-Module ImportExcel -Force
    Write-Host "✅ ImportExcel module loaded" -ForegroundColor Green
} catch {
    Write-Host "❌ ImportExcel module failed to load: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Global tracking
$Global:Results = @{
    ServersTotal = 0
    ServersProcessed = 0
    HasCertWebService = @()
    NeedsUpdate = @()
    UpdateSuccessful = @()
    UpdateFailed = @()
    Unreachable = @()
    SMBAccessible = @()
}

#region Excel Functions

function Import-ServersFromExcel {
    param([string]$ExcelPath)
    
    Write-Host "📊 Reading Excel server list..." -ForegroundColor Yellow
    
    if (-not (Test-Path $ExcelPath)) {
        throw "Excel file not found: $ExcelPath"
    }
    
    try {
        $workbook = Get-ExcelSheetInfo -Path $ExcelPath
        Write-Host "   📋 Worksheets: $($workbook.Name -join ', ')" -ForegroundColor Gray
        
        $allServers = @()
        
        foreach ($sheet in $workbook) {
            Write-Host "   📄 Processing: $($sheet.Name)" -ForegroundColor Cyan
            
            try {
                $data = Import-Excel -Path $ExcelPath -WorksheetName $sheet.Name -NoHeader
                $servers = Parse-ServerData -Data $data -SheetName $sheet.Name
                $allServers += $servers
                Write-Host "     ✅ Found $($servers.Count) servers" -ForegroundColor Green
            } catch {
                Write-Host "     ⚠️ Skipped $($sheet.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        $uniqueServers = $allServers | Sort-Object ServerName | Get-Unique -AsString
        Write-Host "   ✅ Total unique servers: $($uniqueServers.Count)" -ForegroundColor Green
        
        return $uniqueServers
        
    } catch {
        Write-Host "   ❌ Excel import failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Parse-ServerData {
    param(
        [array]$Data,
        [string]$SheetName
    )
    
    $servers = @()
    $currentDomain = "srv"
    $isDomainBlock = $false
    
    foreach ($row in $Data) {
        $cellValue = $row.P1
        if ([string]::IsNullOrWhiteSpace($cellValue)) { continue }
        
        $serverName = $cellValue.ToString().Trim()
        
        # Domain detection
        if ($serverName -match '^\(Domain(?:-[\w]+)?\)([\w-]+)') {
            $currentDomain = $matches[1].ToLower()
            $isDomainBlock = $true
            continue
        }
        
        # Workgroup detection
        if ($serverName -match '^\(Workgroup\)([\w-]+)') {
            $currentDomain = $matches[1].ToLower()
            $isDomainBlock = $false
            continue
        }
        
        # Block end
        if ($serverName -match '^SUMME:?\s*$') {
            $currentDomain = "srv"
            $isDomainBlock = $false
            continue
        }
        
        # Skip headers
        if ($serverName -match "^(Server|Servers|NEUE SERVER|DATACENTER|STANDARD|ServerName)") {
            continue
        }
        
        # Valid server
        if ($serverName.Length -gt 2 -and $serverName -notmatch '^[\s\-_=]+$') {
            $serverInfo = @{
                ServerName = $serverName
                Domain = if ($isDomainBlock) { $currentDomain } else { "" }
                IsDomain = $isDomainBlock
                Sheet = $SheetName
                FQDN = if ($isDomainBlock) {
                    if ($serverName -notlike "*.*") {
                        "$serverName.$currentDomain.meduniwien.ac.at"
                    } else {
                        $serverName
                    }
                } else {
                    $serverName
                }
            }
            
            $servers += $serverInfo
        }
    }
    
    return $servers
}

function Apply-Filter {
    param(
        [array]$Servers,
        [string]$FilterDomain
    )
    
    if ([string]::IsNullOrEmpty($FilterDomain)) {
        return $Servers
    }
    
    Write-Host "🔍 Applying domain filter: '$FilterDomain'" -ForegroundColor Yellow
    
    $filtered = $Servers | Where-Object {
        $_.Domain -like "*$FilterDomain*" -or 
        $_.ServerName -like "*$FilterDomain*"
    }
    
    Write-Host "   ✅ Filtered to $($filtered.Count) servers" -ForegroundColor Green
    return $filtered
}

#endregion

#region Server Testing Functions

function Test-CertWebService {
    param([object]$Server)
    
    $result = @{
        HasService = $false
        Version = "Unknown"
        NeedsUpdate = $false
        Port = 0
        ResponseTime = 0
        Error = ""
    }
    
    $ports = @(9080, 8080, 80)
    
    foreach ($port in $ports) {
        try {
            $url = "http://$($Server.FQDN):$port/health.json"
            $startTime = Get-Date
            
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            $result.ResponseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
            
            if ($response.StatusCode -eq 200) {
                $result.HasService = $true
                $result.Port = $port
                
                try {
                    $health = $response.Content | ConvertFrom-Json
                    $result.Version = if ($health.version) { $health.version } else { "Legacy" }
                    $result.NeedsUpdate = ($result.Version -ne $Script:NewVersion)
                } catch {
                    $result.Version = "Legacy"
                    $result.NeedsUpdate = $true
                }
                
                break
            }
        } catch {
            $result.Error = $_.Exception.Message
            continue
        }
    }
    
    return $result
}

function Test-Connectivity {
    param([object]$Server)
    
    $result = @{
        Ping = $false
        SMB = $false
        PSRemoting = $false
        AdminShare = ""
        Method = "Unknown"
    }
    
    # Test ping
    try {
        $result.Ping = Test-Connection -ComputerName $Server.FQDN -Count 1 -Quiet -ErrorAction SilentlyContinue
    } catch {
        # Ignore ping errors
    }
    
    if (-not $result.Ping) {
        $result.Method = "UNREACHABLE"
        return $result
    }
    
    # Test SMB
    try {
        $adminShare = "\\$($Server.FQDN)\C$"
        $result.SMB = Test-Path $adminShare -ErrorAction SilentlyContinue
        if ($result.SMB) {
            $result.AdminShare = $adminShare
        }
    } catch {
        # Ignore SMB errors
    }
    
    # Test PSRemoting
    try {
        $psTest = Invoke-Command -ComputerName $Server.FQDN -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        $result.PSRemoting = ($psTest -ne $null)
    } catch {
        # PSRemoting not available
    }
    
    # Determine method
    if ($result.PSRemoting) {
        $result.Method = "PSRemoting"
    } elseif ($result.SMB) {
        $result.Method = "SMB"
    } else {
        $result.Method = "Manual"
    }
    
    return $result
}

#endregion

#region Update Functions

function Update-ViaPSRemoting {
    param([object]$Server)
    
    try {
        $localFile = Join-Path $PSScriptRoot "CertWebService.ps1"
        if (-not (Test-Path $localFile)) {
            throw "Local CertWebService.ps1 not found"
        }
        
        $newContent = Get-Content $localFile -Raw
        
        $updateResult = Invoke-Command -ComputerName $Server.FQDN -ScriptBlock {
            param($Content)
            
            try {
                # Stop existing service
                Get-Process powershell | Where-Object { $_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep 2
                
                # Backup existing
                if (Test-Path "C:\CertWebService\CertWebService.ps1") {
                    $backup = "CertWebService-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
                    Copy-Item "C:\CertWebService\CertWebService.ps1" "C:\CertWebService\$backup" -Force
                }
                
                # Create directory
                if (-not (Test-Path "C:\CertWebService")) {
                    New-Item -Path "C:\CertWebService" -ItemType Directory -Force | Out-Null
                }
                
                # Write new file
                $Content | Out-File "C:\CertWebService\CertWebService.ps1" -Encoding UTF8 -Force
                
                # Start service
                Set-Location "C:\CertWebService"
                Start-Job -ScriptBlock { .\CertWebService.ps1 } | Out-Null
                Start-Sleep 5
                
                # Verify
                $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10
                $health = $response.Content | ConvertFrom-Json
                
                return @{
                    Success = $true
                    Version = $health.version
                    Method = "PSRemoting"
                }
                
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    Method = "PSRemoting"
                }
            }
        } -ArgumentList $newContent
        
        return $updateResult
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Method = "PSRemoting"
        }
    }
}

function Update-ViaSMB {
    param(
        [object]$Server,
        [string]$AdminShare
    )
    
    try {
        $localFile = Join-Path $PSScriptRoot "CertWebService.ps1"
        if (-not (Test-Path $localFile)) {
            throw "Local CertWebService.ps1 not found"
        }
        
        # Setup remote paths
        $remotePath = "$AdminShare\CertWebService"
        if (-not (Test-Path $remotePath)) {
            New-Item -Path $remotePath -ItemType Directory -Force | Out-Null
        }
        
        # Backup existing
        $remoteFile = "$remotePath\CertWebService.ps1"
        if (Test-Path $remoteFile) {
            $backup = "CertWebService-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
            Copy-Item $remoteFile "$remotePath\$backup" -Force
        }
        
        # Copy new file
        Copy-Item $localFile $remoteFile -Force
        
        # Create restart script
        $restartContent = @"
Get-Process powershell | Where-Object { `$_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Set-Location "C:\CertWebService"
Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
"@
        
        $restartScript = "$remotePath\Restart.ps1"
        $restartContent | Out-File -FilePath $restartScript -Encoding UTF8 -Force
        
        # Execute restart (try multiple methods)
        $success = $false
        
        # Try PsExec
        $psExec = "${env:ProgramFiles}\SysinternalsSuite\PsExec.exe"
        if (Test-Path $psExec) {
            try {
                & $psExec "\\$($Server.FQDN)" -accepteula -s powershell.exe -ExecutionPolicy Bypass -File "C:\CertWebService\Restart.ps1"
                $success = $true
            } catch {
                # Try WMI fallback
            }
        }
        
        # Try WMI
        if (-not $success) {
            try {
                $wmi = Invoke-WmiMethod -ComputerName $Server.FQDN -Class Win32_Process -Name Create -ArgumentList "powershell.exe -ExecutionPolicy Bypass -File C:\CertWebService\Restart.ps1"
                $success = ($wmi.ReturnValue -eq 0)
            } catch {
                # WMI failed
            }
        }
        
        # Wait and verify
        if ($success) {
            Start-Sleep 10
            try {
                $url = "http://$($Server.FQDN):9080/health.json"
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
                $health = $response.Content | ConvertFrom-Json
                
                return @{
                    Success = $true
                    Version = $health.version
                    Method = "SMB"
                }
            } catch {
                return @{
                    Success = $false
                    Error = "Service restart verification failed"
                    Method = "SMB"
                }
            }
        } else {
            return @{
                Success = $false
                Error = "Could not execute restart script"
                Method = "SMB"
            }
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Method = "SMB"
        }
    }
}

#endregion

#region Main Processing

function Process-Server {
    param([object]$Server)
    
    Write-Host "🖥️ Processing: $($Server.ServerName)" -ForegroundColor White
    Write-Host "   FQDN: $($Server.FQDN)" -ForegroundColor Gray
    
    $result = @{
        Server = $Server
        CertWebService = $null
        Connectivity = $null
        Update = $null
        Success = $false
    }
    
    # Test CertWebService
    Write-Host "   🔍 Checking CertWebService..." -ForegroundColor Yellow
    $certWeb = Test-CertWebService -Server $Server
    $result.CertWebService = $certWeb
    
    if ($certWeb.HasService) {
        Write-Host "     ✅ Found v$($certWeb.Version) on port $($certWeb.Port)" -ForegroundColor Green
        $Global:Results.HasCertWebService += $Server
        
        if (-not $certWeb.NeedsUpdate) {
            Write-Host "     ℹ️ Already v$Script:NewVersion - skipping" -ForegroundColor Cyan
            $result.Success = $true
            return $result
        }
        
        Write-Host "     🔄 Update needed: v$($certWeb.Version) → v$Script:NewVersion" -ForegroundColor Yellow
        $Global:Results.NeedsUpdate += $Server
    } else {
        Write-Host "     ❌ CertWebService not found" -ForegroundColor Red
        return $result
    }
    
    # Test connectivity
    Write-Host "   🌐 Testing connectivity..." -ForegroundColor Yellow
    $conn = Test-Connectivity -Server $Server
    $result.Connectivity = $conn
    
    if ($conn.Method -eq "UNREACHABLE") {
        Write-Host "     ❌ Server unreachable" -ForegroundColor Red
        $Global:Results.Unreachable += $Server
        return $result
    }
    
    Write-Host "     ✅ Method: $($conn.Method)" -ForegroundColor Green
    if ($conn.SMB) { $Global:Results.SMBAccessible += $Server }
    
    # Execute update
    if ($DryRun) {
        Write-Host "     🧪 DRY RUN: Would update via $($conn.Method)" -ForegroundColor Cyan
        $result.Success = $true
        return $result
    }
    
    Write-Host "   🚀 Executing update..." -ForegroundColor Yellow
    
    if ($conn.Method -eq "PSRemoting") {
        $updateResult = Update-ViaPSRemoting -Server $Server
    } elseif ($conn.Method -eq "SMB") {
        $updateResult = Update-ViaSMB -Server $Server -AdminShare $conn.AdminShare
    } else {
        Write-Host "     ⚠️ Manual update required" -ForegroundColor Yellow
        $updateResult = @{
            Success = $false
            Error = "Manual update required"
            Method = $conn.Method
        }
    }
    
    $result.Update = $updateResult
    $result.Success = $updateResult.Success
    
    if ($updateResult.Success) {
        Write-Host "     ✅ Update successful: v$($updateResult.Version)" -ForegroundColor Green
        $Global:Results.UpdateSuccessful += $Server
    } else {
        Write-Host "     ❌ Update failed: $($updateResult.Error)" -ForegroundColor Red
        $Global:Results.UpdateFailed += $Server
    }
    
    Write-Host ""
    return $result
}

function Process-AllServers {
    param([array]$Servers)
    
    Write-Host "🚀 MASS PROCESSING" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host "Servers: $($Servers.Count)" -ForegroundColor White
    Write-Host "Target: $Script:NewVersion" -ForegroundColor White
    Write-Host "Dry Run: $(if($DryRun){'YES'}else{'NO'})" -ForegroundColor White
    Write-Host ""
    
    $Global:Results.ServersTotal = $Servers.Count
    $allResults = @()
    
    for ($i = 0; $i -lt $Servers.Count; $i++) {
        $server = $Servers[$i]
        Write-Host "[$($i+1)/$($Servers.Count)] " -ForegroundColor Gray -NoNewline
        
        $result = Process-Server -Server $server
        $allResults += $result
        $Global:Results.ServersProcessed++
    }
    
    return $allResults
}

#endregion

#region Results

function Show-Results {
    $endTime = Get-Date
    $duration = $endTime - $Script:StartTime
    
    Write-Host "📊 FINAL RESULTS" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "⏱️ Execution:" -ForegroundColor Yellow
    Write-Host "   Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host "   Average: $([math]::Round($duration.TotalSeconds / $Global:Results.ServersTotal, 1))s per server" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "📈 Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Servers: $($Global:Results.ServersTotal)" -ForegroundColor White
    Write-Host "   Processed: $($Global:Results.ServersProcessed)" -ForegroundColor White
    Write-Host "   Had CertWebService: $($Global:Results.HasCertWebService.Count)" -ForegroundColor Green
    Write-Host "   Needed Update: $($Global:Results.NeedsUpdate.Count)" -ForegroundColor Yellow
    Write-Host "   SMB Accessible: $($Global:Results.SMBAccessible.Count)" -ForegroundColor Cyan
    Write-Host "   Unreachable: $($Global:Results.Unreachable.Count)" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "✅ Update Results:" -ForegroundColor Yellow
    Write-Host "   Successful: $($Global:Results.UpdateSuccessful.Count)" -ForegroundColor Green
    Write-Host "   Failed: $($Global:Results.UpdateFailed.Count)" -ForegroundColor Red
    Write-Host ""
    
    if ($Global:Results.UpdateSuccessful.Count -gt 0) {
        Write-Host "✅ Successfully Updated:" -ForegroundColor Green
        foreach ($server in $Global:Results.UpdateSuccessful) {
            Write-Host "   🖥️ $($server.ServerName)" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($Global:Results.UpdateFailed.Count -gt 0) {
        Write-Host "❌ Failed Updates:" -ForegroundColor Red
        foreach ($server in $Global:Results.UpdateFailed) {
            Write-Host "   🖥️ $($server.ServerName)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Success rate
    $successRate = if ($Global:Results.NeedsUpdate.Count -gt 0) {
        [math]::Round(($Global:Results.UpdateSuccessful.Count / $Global:Results.NeedsUpdate.Count) * 100, 1)
    } else { 100 }
    
    Write-Host "📊 Success Rate: $successRate%" -ForegroundColor $(if($successRate -gt 80){'Green'}elseif($successRate -gt 50){'Yellow'}else{'Red'})
    Write-Host ""
}

#endregion

#region Main Execution

try {
    # Import servers
    Write-Host "📊 PHASE 1: EXCEL IMPORT" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    $allServers = Import-ServersFromExcel -ExcelPath $ExcelPath
    
    if ($allServers.Count -eq 0) {
        throw "No servers found in Excel"
    }
    
    # Apply filter
    $filteredServers = Apply-Filter -Servers $allServers -FilterDomain $FilterDomain
    
    if ($filteredServers.Count -eq 0) {
        throw "No servers match filter"
    }
    
    Write-Host ""
    Write-Host "📋 Processing Plan:" -ForegroundColor Yellow
    Write-Host "   Total in Excel: $($allServers.Count)" -ForegroundColor Gray
    Write-Host "   After filter: $($filteredServers.Count)" -ForegroundColor Gray
    Write-Host "   Target version: $Script:NewVersion" -ForegroundColor Gray
    Write-Host ""
    
    # Process servers
    Write-Host "🚀 PHASE 2: MASS PROCESSING" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    $results = Process-AllServers -Servers $filteredServers
    
    # Show results
    Write-Host "📊 PHASE 3: RESULTS" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Show-Results
    
    Write-Host "🏁 Excel mass update completed!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Mass update failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#endregion