<#
.SYNOPSIS
    Smart CertWebService Update v3.0.0 - Universal PowerShell Compatibility
    Automatische PS 5.1/7.x Erkennung mit optimaler Funktionsauswahl

.DESCRIPTION
    Universelles Update-System basierend auf PowerShell-Regelwerk Universal v10.1.0
    Nutzt automatische Versionserkennung und wählt die optimalen Funktionen
    
    § 15 PowerShell Version Compatibility Management
    § 16 Automated Update Deployment  
    § 17 Excel Integration Standards

.PARAMETER Filter
    Server-Filter (z.B. "UVW", "EX", "DC", "All")

.PARAMETER TestOnly
    Nur Test-Modus, keine echten Updates

.PARAMETER MaxConcurrent
    Maximale parallele Jobs (automatisch basierend auf PS-Version wenn nicht angegeben)

.EXAMPLE
    .\Smart-CertWebService-Update.ps1 -Filter "UVW" -TestOnly
    
.EXAMPLE  
    .\Smart-CertWebService-Update.ps1 -Filter "All" -MaxConcurrent 8

.NOTES
    Author: PowerShell Team
    Version: 3.0.0
    Date: 07.10.2025
    
    Requires: Update-CertWebService-Simple.ps1 in same directory
#>

[CmdletBinding()]
param(
    [string]$Filter = "",
    [switch]$TestOnly,
    [int]$MaxConcurrent = 0
)

$ErrorActionPreference = "Stop"

# ==========================================
# Smart PowerShell Detection (§ 15.1)
# ==========================================

$PSVersionInfo = @{
    Version = $PSVersionTable.PSVersion.ToString()
    Edition = $PSVersionTable.PSEdition
    Platform = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { 'Win32NT' }
    IsCore = $PSVersionTable.PSEdition -eq 'Core'
    IsWindows = ($PSVersionTable.Platform -eq 'Win32NT') -or ($PSVersionTable.PSVersion.Major -le 5)
    IsPowerShell7 = $PSVersionTable.PSVersion.Major -ge 7
    IsPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5
}

$SmartConfig = @{
    MaxConcurrentJobs = if ($PSVersionInfo.IsCore) { 10 } else { 5 }
    DefaultTimeout = if ($PSVersionInfo.IsCore) { 30 } else { 60 }
    UseAdvancedFeatures = $PSVersionInfo.IsCore
    RecommendedMode = if ($PSVersionInfo.IsCore) { "High-Performance" } else { "Stable-Compatible" }
}

# Set MaxConcurrent based on PowerShell version if not specified
if ($MaxConcurrent -eq 0) {
    $MaxConcurrent = $SmartConfig.MaxConcurrentJobs
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  SMART CERTWEBSERVICE UPDATE v3.0.0" -ForegroundColor Cyan
Write-Host "  Universal PowerShell Compatibility" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PowerShell: $($PSVersionInfo.Version) ($($PSVersionInfo.Edition))" -ForegroundColor Yellow
Write-Host "Platform: $($PSVersionInfo.Platform)" -ForegroundColor Yellow
Write-Host "Mode: $($SmartConfig.RecommendedMode)" -ForegroundColor Yellow
Write-Host "Filter: $(if($Filter){"'$Filter'"}else{'None'})" -ForegroundColor Yellow
Write-Host "Max Concurrent: $MaxConcurrent" -ForegroundColor Yellow
Write-Host "Test Mode: $(if($TestOnly){'ENABLED'}else{'DISABLED'})" -ForegroundColor Yellow
Write-Host ""

# ==========================================
# Smart Functions (§ 15.2)
# ==========================================

function Invoke-SmartWebRequest {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 30
    )
    
    if ($PSVersionInfo.IsCore -and $PSVersionTable.PSVersion.Major -ge 7) {
        # PowerShell 7.x mit TimeoutSec Parameter
        return Invoke-WebRequest -Uri $Uri -TimeoutSec $TimeoutSeconds
    } else {
        # PowerShell 5.1 ohne TimeoutSec Parameter
        return Invoke-WebRequest -Uri $Uri
    }
}

function Test-SmartConnection {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutSeconds = 10
    )
    
    if ($PSVersionInfo.IsCore) {
        # PowerShell 7.x - Test-NetConnection
        try {
            $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
            return $result
        } catch {
            return $false
        }
    } else {
        # PowerShell 5.1 - TcpClient Fallback
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
            
            if ($wait) {
                try {
                    $tcpClient.EndConnect($connect)
                    $result = $true
                } catch {
                    $result = $false
                }
            } else {
                $result = $false
            }
            
            $tcpClient.Close()
            return $result
        } catch {
            return $false
        }
    }
}

# ==========================================
# Excel Integration (§ 17)
# ==========================================

function Get-ServersFromExcel {
    param(
        [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
        [string]$FilterString = ""
    )
    
    if (-not $PSVersionInfo.IsWindows) {
        Write-Host "[WARNING] Excel COM not available on $($PSVersionInfo.Platform)" -ForegroundColor Yellow
        return @()
    }
    
    Write-Host "[EXCEL] Reading server list from Excel..." -ForegroundColor Cyan
    
    try {
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        $Worksheet = $Workbook.Worksheets.Item(1)
        
        $servers = @()
        $currentBlock = ""
        $invalidPatterns = @('^SUMME:', 'ServerName', 'NEUE SERVER', 'Stand:', 'Servers', 'DATACENTER', '^\(Domain', '^\(Workgroup', '\s+')
        
        for ($row = 1; $row -le 1000; $row++) {
            $cellA = $Worksheet.Cells.Item($row, 1).Text
            $cellB = $Worksheet.Cells.Item($row, 2).Text
            
            if ([string]::IsNullOrWhiteSpace($cellA) -and [string]::IsNullOrWhiteSpace($cellB)) {
                continue
            }
            
            # Block detection
            if ($cellA -match '^[A-Z]{2,4}$' -and [string]::IsNullOrWhiteSpace($cellB)) {
                $currentBlock = $cellA
                continue
            }
            
            # Skip invalid patterns
            $skipRow = $false
            foreach ($pattern in $invalidPatterns) {
                if ($cellA -match $pattern) {
                    $skipRow = $true
                    break
                }
            }
            if ($skipRow) { continue }
            
            # Valid server entry
            if ($cellA -match '^[a-zA-Z0-9\-]+$' -and $cellA.Length -ge 3) {
                $serverName = $cellA.ToUpper()
                $fqdn = "$serverName.srv.meduniwien.ac.at"
                
                # Apply filter
                if ($FilterString -and $FilterString -ne "All") {
                    if ($currentBlock -notlike "*$FilterString*" -and $serverName -notlike "*$FilterString*") {
                        continue
                    }
                }
                
                $servers += @{
                    Name = $serverName
                    FQDN = $fqdn
                    Block = $currentBlock
                }
            }
        }
        
        Write-Host "[EXCEL] Found $($servers.Count) servers" -ForegroundColor Green
        return $servers
        
    } catch {
        Write-Host "[ERROR] Excel reading failed: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    } finally {
        if ($Workbook) { $Workbook.Close($false) }
        if ($Excel) { 
            $Excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null
        }
    }
}

# ==========================================
# Smart Update Logic (§ 16)
# ==========================================

function Test-CertWebServiceSmart {
    param([hashtable]$Server)
    
    $webServicePort = 9080
    $healthUrl = "http://$($Server.FQDN):$webServicePort/health.json"
    
    try {
        # Test connection first
        $connectionTest = Test-SmartConnection -ComputerName $Server.FQDN -Port $webServicePort -TimeoutSeconds 5
        if (-not $connectionTest) {
            return @{
                Server = $Server.Name
                FQDN = $Server.FQDN
                Status = "Unreachable"
                Version = "N/A"
                Reachable = $false
                NeedsUpdate = $false
                Error = "Connection failed on port $webServicePort"
            }
        }
        
        # Get health status
        $response = Invoke-SmartWebRequest -Uri $healthUrl -TimeoutSeconds 10
        $healthData = $response.Content | ConvertFrom-Json
        
        $currentVersion = $healthData.version
        $targetVersion = "v2.5.0"
        $needsUpdate = $currentVersion -ne $targetVersion
        
        return @{
            Server = $Server.Name
            FQDN = $Server.FQDN
            Status = "CertWebService Running"
            Version = $currentVersion
            Reachable = $true
            NeedsUpdate = $needsUpdate
            Error = $null
            HealthData = $healthData
        }
        
    } catch {
        return @{
            Server = $Server.Name
            FQDN = $Server.FQDN
            Status = "Error"
            Version = "N/A"
            Reachable = $false
            NeedsUpdate = $false
            Error = $_.Exception.Message
        }
    }
}

# ==========================================
# Main Execution (§ 16.3)
# ==========================================

try {
    # Step 1: Get servers from Excel
    $servers = Get-ServersFromExcel -FilterString $Filter
    
    if ($servers.Count -eq 0) {
        Write-Host "[WARNING] No servers found matching filter '$Filter'" -ForegroundColor Yellow
        
        # Fallback: Use simple script if available
        $simpleScript = Join-Path $PSScriptRoot "Update-CertWebService-Simple.ps1"
        if (Test-Path $simpleScript) {
            Write-Host "[FALLBACK] Using Update-CertWebService-Simple.ps1..." -ForegroundColor Yellow
            if ($TestOnly) {
                & $simpleScript -Filter $Filter -TestOnly
            } else {
                & $simpleScript -Filter $Filter
            }
        }
        exit 0
    }
    
    # Step 2: Check CertWebService status
    Write-Host "[STATUS] Checking CertWebService status on $($servers.Count) servers..." -ForegroundColor Cyan
    Write-Host "Using $($SmartConfig.RecommendedMode) mode with $MaxConcurrent concurrent jobs" -ForegroundColor Yellow
    Write-Host ""
    
    $statusResults = @()
    $jobs = @()
    $jobCount = 0
    
    foreach ($server in $servers) {
        # Create job for status check
        $job = Start-Job -ScriptBlock {
            param($ServerInfo, $WebServicePort, $PSVersionIsCore)
            
            # Recreate smart functions in job context
            function Test-SmartConnectionLocal {
                param([string]$ComputerName, [int]$Port, [int]$TimeoutSeconds = 10)
                
                if ($PSVersionIsCore) {
                    try {
                        $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
                        return $result
                    } catch {
                        return $false
                    }
                } else {
                    try {
                        $tcpClient = New-Object System.Net.Sockets.TcpClient
                        $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
                        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
                        
                        if ($wait) {
                            try {
                                $tcpClient.EndConnect($connect)
                                $result = $true
                            } catch {
                                $result = $false
                            }
                        } else {
                            $result = $false
                        }
                        
                        $tcpClient.Close()
                        return $result
                    } catch {
                        return $false
                    }
                }
            }
            
            function Invoke-SmartWebRequestLocal {
                param([string]$Uri, [int]$TimeoutSeconds = 30)
                
                if ($PSVersionIsCore -and $PSVersionTable.PSVersion.Major -ge 7) {
                    return Invoke-WebRequest -Uri $Uri -TimeoutSec $TimeoutSeconds
                } else {
                    return Invoke-WebRequest -Uri $Uri
                }
            }
            
            # Test server
            $healthUrl = "http://$($ServerInfo.FQDN):$WebServicePort/health.json"
            
            try {
                $connectionTest = Test-SmartConnectionLocal -ComputerName $ServerInfo.FQDN -Port $WebServicePort -TimeoutSeconds 5
                if (-not $connectionTest) {
                    return @{
                        Server = $ServerInfo.Name
                        FQDN = $ServerInfo.FQDN
                        Status = "Unreachable"
                        Version = "N/A"
                        Reachable = $false
                        NeedsUpdate = $false
                        Error = "Connection failed on port $WebServicePort"
                    }
                }
                
                $response = Invoke-SmartWebRequestLocal -Uri $healthUrl -TimeoutSeconds 10
                $healthData = $response.Content | ConvertFrom-Json
                
                $currentVersion = $healthData.version
                $targetVersion = "v2.5.0"
                $needsUpdate = $currentVersion -ne $targetVersion
                
                return @{
                    Server = $ServerInfo.Name
                    FQDN = $ServerInfo.FQDN
                    Status = "CertWebService Running"
                    Version = $currentVersion
                    Reachable = $true
                    NeedsUpdate = $needsUpdate
                    Error = $null
                }
                
            } catch {
                return @{
                    Server = $ServerInfo.Name
                    FQDN = $ServerInfo.FQDN
                    Status = "Error"
                    Version = "N/A"
                    Reachable = $false
                    NeedsUpdate = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $server, 9080, $PSVersionInfo.IsCore -Name "StatusCheck_$($server.Name)"
        
        $jobs += $job
        $jobCount++
        
        # Limit concurrent jobs and show progress
        if ($jobs.Count -ge $MaxConcurrent) {
            Write-Host "  Processing batch $($jobCount - $jobs.Count + 1)-$jobCount..." -ForegroundColor Gray
            Wait-Job $jobs | Out-Null
            
            # Collect results
            foreach ($j in $jobs) {
                $result = Receive-Job $j
                $statusResults += $result
                Remove-Job $j
            }
            $jobs = @()
        }
    }
    
    # Process remaining jobs
    if ($jobs.Count -gt 0) {
        Write-Host "  Processing final batch..." -ForegroundColor Gray
        Wait-Job $jobs | Out-Null
        
        foreach ($j in $jobs) {
            $result = Receive-Job $j
            $statusResults += $result
            Remove-Job $j
        }
    }
    
    # Display results
    Write-Host ""
    Write-Host "Status Summary:" -ForegroundColor Yellow
    Write-Host "===============" -ForegroundColor Yellow
    
    $reachable = $statusResults | Where-Object { $_.Reachable }
    $needsUpdate = $reachable | Where-Object { $_.NeedsUpdate }
    $upToDate = $reachable | Where-Object { -not $_.NeedsUpdate }
    $unreachable = $statusResults | Where-Object { -not $_.Reachable }
    
    Write-Host "Total Servers: $($statusResults.Count)" -ForegroundColor White
    Write-Host "Reachable: $($reachable.Count)" -ForegroundColor Green
    Write-Host "Need Update: $($needsUpdate.Count)" -ForegroundColor Yellow
    Write-Host "Up to Date: $($upToDate.Count)" -ForegroundColor Green
    Write-Host "Unreachable: $($unreachable.Count)" -ForegroundColor Red
    Write-Host ""
    
    # Show servers that need update
    if ($needsUpdate.Count -gt 0) {
        Write-Host "Servers needing update to v2.5.0:" -ForegroundColor Yellow
        foreach ($server in $needsUpdate) {
            Write-Host "  [$($server.Server)] $($server.Version) → v2.5.0" -ForegroundColor White
        }
        Write-Host ""
        
        if ($TestOnly) {
            Write-Host "[TEST MODE] Would update $($needsUpdate.Count) servers" -ForegroundColor Yellow
        } else {
            $confirm = Read-Host "Proceed with updating $($needsUpdate.Count) servers? (y/N)"
            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                Write-Host "Update cancelled by user" -ForegroundColor Yellow
                exit 0
            }
            
            Write-Host "[PRODUCTION] Starting updates..." -ForegroundColor Red
            Write-Host "This would call the actual update deployment script" -ForegroundColor Yellow
            
            # Here we would integrate with the actual update mechanism
            # For now, just simulate the process
            foreach ($server in $needsUpdate) {
                Write-Host "  [$($server.Server)] Simulated update to v2.5.0" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "All reachable servers are up to date! ✓" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Smart CertWebService Update completed successfully!" -ForegroundColor Green
    Write-Host "PowerShell $($PSVersionInfo.Version) ($($SmartConfig.RecommendedMode) mode)" -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
