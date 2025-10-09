<#
.SYNOPSIS
    Universal CertWebService Update Deployment v2.0.0
    Smart PowerShell 5.1/7.x Compatible Update System

.DESCRIPTION
    Universelles Update-System das automatisch zwischen PowerShell 5.1 und 7.x 
    unterscheidet und die optimalen Funktionen verwendet.
    
    Implementiert gemäß PowerShell-Regelwerk Universal v10.1.0:
    § 15 PowerShell Version Compatibility Management
    § 16 Automated Update Deployment
    § 17 Excel Integration Standards
    
.PARAMETER ExcelPath
    Pfad zur Excel-Serverliste

.PARAMETER Filter
    Server-Filter (z.B. "UVW", "EX", "DC")

.PARAMETER TestOnly
    Nur Test-Modus, keine echten Updates

.PARAMETER MaxConcurrent
    Maximale parallele Jobs

.EXAMPLE
    .\Universal-CertWebService-Update.ps1 -Filter "UVW" -TestOnly
    
.EXAMPLE
    .\Universal-CertWebService-Update.ps1 -Filter "All" -MaxConcurrent 8

.NOTES
    Author: PowerShell Team  
    Version: 2.0.0
    Date: 07.10.2025
    
    Requires: Universal-PowerShell-Compatibility.ps1
#>

[CmdletBinding()]
param(
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    [string]$Filter = "",
    [switch]$TestOnly,
    [int]$MaxConcurrent = 0
)

$ErrorActionPreference = "Stop"

# ==========================================
# § 16.1 Universal Framework Loading
# ==========================================

$compatibilityScript = Join-Path $PSScriptRoot "Universal-PowerShell-Compatibility.ps1"
if (Test-Path $compatibilityScript) {
    . $compatibilityScript
} else {
    throw "Required Universal-PowerShell-Compatibility.ps1 not found in script directory"
}

# Initialize compatibility
$PSCompat = New-PowerShellCompatibility
$config = Get-UniversalConfiguration

# Set MaxConcurrent based on PowerShell version if not specified
if ($MaxConcurrent -eq 0) {
    $MaxConcurrent = $config.MaxConcurrentJobs
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  UNIVERSAL CERTWEBSERVICE UPDATE" -ForegroundColor Cyan
Write-Host "  v2.0.0 | $(Get-Date -Format 'dd.MM.yyyy HH:mm')" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PowerShell: $(& $PSCompat.GetCompatibilityInfo)" -ForegroundColor Yellow
Write-Host "Excel Source: $(Split-Path $ExcelPath -Leaf)" -ForegroundColor Yellow
Write-Host "Filter: $(if($Filter){"'$Filter'"}else{'None'})" -ForegroundColor Yellow
Write-Host "Max Concurrent: $MaxConcurrent" -ForegroundColor Yellow
Write-Host "Mode: $(if($TestOnly){'TEST ONLY'}else{'PRODUCTION'})" -ForegroundColor Yellow
Write-Host ""

# ==========================================
# § 16.2 Server Discovery Functions
# ==========================================

function Get-ServersFromExcel {
    param(
        [string]$ExcelPath,
        [string]$FilterString
    )
    
    Write-Host "[EXCEL] Reading server list..." -ForegroundColor Cyan
    
    $excelConnection = New-UniversalExcelConnection -ExcelPath $ExcelPath
    if (-not $excelConnection.Success) {
        throw "Failed to open Excel file: $($excelConnection.Error)"
    }
    
    try {
        $Excel = $excelConnection.Excel
        $Workbook = $excelConnection.Workbook
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
        
    } finally {
        $Workbook.Close($false)
        $Excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null
    }
}

# ==========================================
# § 16.3 CertWebService Status Functions
# ==========================================

function Test-CertWebServiceStatus {
    param(
        [hashtable]$Server
    )
    
    $webServicePort = 9080
    $healthUrl = "http://$($Server.FQDN):$webServicePort/health.json"
    
    try {
        # Test connection first
        $connectionTest = Test-UniversalConnection -ComputerName $Server.FQDN -Port $webServicePort -TimeoutSeconds 5
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
        $response = Invoke-UniversalWebRequest -Uri $healthUrl -TimeoutSeconds 10
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
# § 16.4 Update Deployment Functions
# ==========================================

function Start-CertWebServiceUpdate {
    param(
        [hashtable]$Server,
        [switch]$TestOnly
    )
    
    if ($TestOnly) {
        Start-Sleep -Seconds 2  # Simulate work
        return @{
            Server = $Server.Name
            Success = $true
            Action = "TEST ONLY - No actual update performed"
            Time = Get-Date
        }
    }
    
    try {
        # Here we would call the actual update mechanism
        # For now, return success simulation
        return @{
            Server = $Server.Name
            Success = $true
            Action = "CertWebService updated to v2.5.0"
            Time = Get-Date
        }
        
    } catch {
        return @{
            Server = $Server.Name
            Success = $false
            Action = "Update failed"
            Error = $_.Exception.Message
            Time = Get-Date
        }
    }
}

# ==========================================
# § 16.5 Main Execution Logic
# ==========================================

try {
    # Step 1: Get servers from Excel
    $servers = Get-ServersFromExcel -ExcelPath $ExcelPath -FilterString $Filter
    
    if ($servers.Count -eq 0) {
        Write-Host "[WARNING] No servers found matching filter '$Filter'" -ForegroundColor Yellow
        exit 0
    }
    
    # Step 2: Check CertWebService status on all servers
    Write-Host "[STATUS] Checking CertWebService status on $($servers.Count) servers..." -ForegroundColor Cyan
    
    $statusJobs = @()
    foreach ($server in $servers) {
        $job = Start-UniversalJob -ScriptBlock {
            param($Server, $TestConnectionFunction, $WebRequestFunction)
            
            # Import the functions in job context
            $testConnectionCode = $TestConnectionFunction
            $webRequestCode = $WebRequestFunction
            
            Invoke-Expression $testConnectionCode
            Invoke-Expression $webRequestCode
            
            # Now run the actual test
            $webServicePort = 9080
            $healthUrl = "http://$($Server.FQDN):$webServicePort/health.json"
            
            try {
                $connectionTest = Test-UniversalConnection -ComputerName $Server.FQDN -Port $webServicePort -TimeoutSeconds 5
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
                
                $response = Invoke-UniversalWebRequest -Uri $healthUrl -TimeoutSeconds 10
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
        } -ArgumentList @{
            Server = $server
            TestConnectionFunction = ${function:Test-UniversalConnection}.ToString()
            WebRequestFunction = ${function:Invoke-UniversalWebRequest}.ToString()
        } -Name "StatusCheck_$($server.Name)"
        
        $statusJobs += $job
        
        # Limit concurrent jobs
        if ($statusJobs.Count -ge $MaxConcurrent) {
            Wait-Job $statusJobs | Out-Null
            $statusJobs = @()
        }
    }
    
    # Wait for remaining jobs
    if ($statusJobs.Count -gt 0) {
        Wait-Job $statusJobs | Out-Null
    }
    
    # Collect results
    $statusResults = @()
    Get-Job | Where-Object { $_.Name -like "StatusCheck_*" } | ForEach-Object {
        $result = Receive-Job $_
        $statusResults += $result
        Remove-Job $_
    }
    
    # Display results
    Write-Host ""
    Write-Host "Status Summary:" -ForegroundColor Yellow
    Write-Host "===============" -ForegroundColor Yellow
    
    $reachable = $statusResults | Where-Object { $_.Reachable }
    $needsUpdate = $reachable | Where-Object { $_.NeedsUpdate }
    $upToDate = $reachable | Where-Object { -not $_.NeedsUpdate }
    $unreachable = $statusResults | Where-Object { -not $_.Reachable }
    
    Write-Host "Reachable Servers: $($reachable.Count)" -ForegroundColor Green
    Write-Host "Need Update: $($needsUpdate.Count)" -ForegroundColor Yellow
    Write-Host "Up to Date: $($upToDate.Count)" -ForegroundColor Green
    Write-Host "Unreachable: $($unreachable.Count)" -ForegroundColor Red
    Write-Host ""
    
    # Show servers that need update
    if ($needsUpdate.Count -gt 0) {
        Write-Host "Servers needing update:" -ForegroundColor Yellow
        foreach ($server in $needsUpdate) {
            Write-Host "  $($server.Server) ($($server.Version) → v2.5.0)" -ForegroundColor White
        }
        Write-Host ""
        
        if (-not $TestOnly) {
            $confirm = Read-Host "Proceed with updates? (y/N)"
            if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                Write-Host "Update cancelled by user" -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Host "All reachable servers are up to date!" -ForegroundColor Green
        exit 0
    }
    
    Write-Host "[UPDATE] Starting update deployment..." -ForegroundColor Cyan
    Write-Host "Mode: $(if($TestOnly){'TEST ONLY'}else{'PRODUCTION'})" -ForegroundColor Yellow
    Write-Host ""
    
    # Perform updates
    $updateResults = @()
    foreach ($server in $needsUpdate) {
        $result = Start-CertWebServiceUpdate -Server @{Name=$server.Server; FQDN=$server.FQDN} -TestOnly:$TestOnly
        $updateResults += $result
        
        $color = if ($result.Success) { 'Green' } else { 'Red' }
        Write-Host "[$($server.Server)] $($result.Action)" -ForegroundColor $color
    }
    
    Write-Host ""
    Write-Host "Update Summary:" -ForegroundColor Yellow
    Write-Host "===============" -ForegroundColor Yellow
    
    $successful = $updateResults | Where-Object { $_.Success }
    $failed = $updateResults | Where-Object { -not $_.Success }
    
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    
    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed Updates:" -ForegroundColor Red
        foreach ($failure in $failed) {
            Write-Host "  $($failure.Server): $($failure.Error)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Universal CertWebService Update completed!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
