#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    CertWebService Update Deployment v1.0.0

.DESCRIPTION
    Intelligentes Update-Deployment für alle Server mit bereits installiertem CertWebService.
    
    WORKFLOW:
    1. Excel-Serverliste einlesen (\\itscmgmt03\iso\WindowsServerListe\Serverliste2025.xlsx)
    2. Server-Konnektivität prüfen
    3. CertWebService-Status abfragen (Port 9080)
    4. Nur Server mit laufendem CertWebService updaten
    5. Automatisches Deployment des neuen CertWebService v2.5.0
    
    FEATURES:
    - 3-Stufen-Credential-Strategie (Default → Vault → Prompt)
    - Excel-Integration mit Block-Struktur
    - Intelligente Server-Erkennung
    - Parallel-Deployment für bessere Performance
    - Detaillierte Logging und Reporting

.PARAMETER ExcelPath
    Pfad zur Excel-Serverliste (Standard: \\itscmgmt03\iso\WindowsServerListe\Serverliste2025.xlsx)

.PARAMETER TestOnly
    Nur Analyse, kein tatsächliches Update

.PARAMETER MaxConcurrent
    Maximale Anzahl paralleler Updates (Standard: 5)

.PARAMETER Filter
    Server-Filter (Domain/Workgroup/ServerName)

.PARAMETER Force
    Update auch bei Warnungen durchführen

.EXAMPLE
    .\Update-CertWebService-Deployment.ps1 -TestOnly
    
.EXAMPLE
    .\Update-CertWebService-Deployment.ps1 -Filter "UVW" -MaxConcurrent 3

.VERSION
    1.0.0

.RULEBOOK
    v10.0.3 §14 - 3-Tier Credential Strategy
#>

param(
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    [switch]$TestOnly,
    [int]$MaxConcurrent = 5,
    [string]$Filter = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Versionsinformationen
$scriptVersion = "1.0.0"
$targetCertWebServiceVersion = "v2.5.0"
$webServicePort = 9080

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CERTWEBSERVICE UPDATE DEPLOYMENT" -ForegroundColor Cyan  
Write-Host "  v$scriptVersion | $(Get-Date -Format 'dd.MM.yyyy HH:mm')" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Version: $targetCertWebServiceVersion" -ForegroundColor Yellow
Write-Host "Excel Source: $(Split-Path $ExcelPath -Leaf)" -ForegroundColor Yellow
Write-Host "Max Concurrent: $MaxConcurrent" -ForegroundColor Yellow
Write-Host "Test Mode: $(if($TestOnly){'YES'}else{'NO'})" -ForegroundColor Yellow
Write-Host ""

# Import existierender Funktionen aus Update-CertSurv-ServerList.ps1
function Get-ServersFromExcel {
    param(
        [string]$ExcelPath,
        [string]$FilterString = ""
    )
    
    Write-Host "[*] Reading Excel server list..." -ForegroundColor Yellow
    Write-Host "    Excel: $ExcelPath" -ForegroundColor Gray
    
    if (-not (Test-Path $ExcelPath)) {
        throw "Excel file not found: $ExcelPath"
    }
    
    try {
        # Excel COM öffnen
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        $Worksheet = $Workbook.Worksheets.Item(1)
        
        $servers = @()
        $currentBlock = ""
        $invalidPatterns = @(
            '^SUMME:',
            'ServerName',
            'NEUE SERVER',
            'Stand:',
            'Servers',
            'DATACENTER',
            '^\(Domain',
            '^\(Workgroup',
            '\s+'
        )
        
        # Domain-Mapping für FQDN-Konstruktion
        $domainMap = @{
            'UVW' = 'uvw.meduniwien.ac.at'
            'EX' = 'ex.meduniwien.ac.at'
            'NEURO' = 'neuro.meduniwien.ac.at'
            'CC' = 'cc.meduniwien.ac.at'
        }
        
        for ($row = 1; $row -le $Worksheet.UsedRange.Rows.Count; $row++) {
            $cell = $Worksheet.Cells.Item($row, 1)
            $col1Value = if ($cell.Value2) { $cell.Value2.ToString().Trim() } else { "" }
            
            if (-not $col1Value) { continue }
            
            # Block-Header erkennen
            if ($col1Value -match '^\((Domain|WORKGROUP)\)(.+)') {
                $currentBlock = $matches[2].Trim()
                Write-Verbose "Found block: $currentBlock"
                continue
            }
            
            # Block-Ende erkennen
            if ($col1Value -match '^SUMME:') {
                Write-Verbose "Block end found"
                continue
            }
            
            # Ungültige Einträge filtern
            $isInvalid = $false
            foreach ($pattern in $invalidPatterns) {
                if ($col1Value -match $pattern) {
                    $isInvalid = $true
                    break
                }
            }
            if ($isInvalid) { continue }
            
            # Strikethrough-Check
            $isStrikethrough = $cell.Font.Strikethrough
            if ($isStrikethrough) {
                Write-Verbose "Skipping strikethrough server: $col1Value"
                continue
            }
            
            # FQDN konstruieren
            $fqdn = $col1Value
            if ($currentBlock -and $domainMap.ContainsKey($currentBlock)) {
                $fqdn = "$col1Value.$($domainMap[$currentBlock])"
            } elseif ($currentBlock -eq "SRV") {
                $fqdn = "$col1Value.srv.meduniwien.ac.at"
            } else {
                $fqdn = "$col1Value.meduniwien.ac.at"
            }
            
            # Filter anwenden
            if ($FilterString -and $col1Value -notmatch $FilterString -and $currentBlock -notmatch $FilterString) {
                continue
            }
            
            $servers += @{
                ServerName = $col1Value
                FQDN = $fqdn
                Block = $currentBlock
                Row = $row
            }
        }
        
        # Cleanup
        $Workbook.Close()
        $Excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
        [GC]::Collect()
        
        Write-Host "[OK] Found $($servers.Count) servers in Excel" -ForegroundColor Green
        return $servers
        
    } catch {
        Write-Error "Excel reading failed: $($_.Exception.Message)"
        throw
    }
}

function Test-CertWebServiceStatus {
    param(
        [string]$ServerName,
        [int]$Port = 9080,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $uri = "http://${ServerName}:${Port}/health.json"
        $response = Invoke-RestMethod -Uri $uri -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        
        return @{
            IsRunning = $true
            Version = $response.version
            Status = $response.status
            Timestamp = $response.timestamp
            Error = $null
        }
    } catch {
        return @{
            IsRunning = $false
            Version = $null
            Status = "Not Available"
            Timestamp = $null
            Error = $_.Exception.Message
        }
    }
}

function Test-ServerConnectivity {
    param(
        [string]$ServerName,
        [int]$TimeoutMs = 2000
    )
    
    try {
        $ping = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -TimeoutSec ($TimeoutMs/1000)
        return $ping
    } catch {
        return $false
    }
}

function Update-SingleServer {
    param(
        [hashtable]$ServerInfo,
        [PSCredential]$Credential
    )
    
    $serverName = $ServerInfo.FQDN
    $shortName = $ServerInfo.ServerName
    
    Write-Host "  [*] Updating $shortName..." -ForegroundColor Yellow
    
    try {
        # 1. Connectivity Test
        if (-not (Test-ServerConnectivity -ServerName $serverName)) {
            return @{
                Server = $shortName
                Status = "FAILED"
                Error = "Server not reachable"
                Duration = 0
            }
        }
        
        # 2. CertWebService Status prüfen
        $serviceStatus = Test-CertWebServiceStatus -ServerName $serverName -Port $webServicePort
        if (-not $serviceStatus.IsRunning) {
            return @{
                Server = $shortName
                Status = "SKIPPED"
                Error = "CertWebService not running: $($serviceStatus.Error)"
                Duration = 0
            }
        }
        
        Write-Host "    Current version: $($serviceStatus.Version)" -ForegroundColor Gray
        
        # 3. Version Check
        if ($serviceStatus.Version -eq $targetCertWebServiceVersion) {
            return @{
                Server = $shortName
                Status = "UP-TO-DATE"
                Error = $null
                Duration = 0
                CurrentVersion = $serviceStatus.Version
            }
        }
        
        # 4. Actual Update via PSRemoting
        if (-not $TestOnly) {
            $startTime = Get-Date
            
            $updateResult = Invoke-Command -ComputerName $serverName -Credential $Credential -ScriptBlock {
                param($SourcePath, $TargetPath, $ServiceName)
                
                try {
                    # Stop service
                    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                    if ($service -and $service.Status -eq 'Running') {
                        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                        Start-Sleep -Seconds 2
                    }
                    
                    # Backup old version
                    $backupPath = "$TargetPath\Backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                    if (-not (Test-Path $backupPath)) {
                        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item "$TargetPath\CertWebService.ps1" -Destination $backupPath -ErrorAction SilentlyContinue
                    
                    # Copy new version
                    Copy-Item $SourcePath -Destination "$TargetPath\CertWebService.ps1" -Force
                    
                    # Start service
                    if ($service) {
                        Start-Service -Name $ServiceName -ErrorAction Stop
                        Start-Sleep -Seconds 3
                    }
                    
                    return @{
                        Success = $true
                        BackupPath = $backupPath
                        Error = $null
                    }
                    
                } catch {
                    return @{
                        Success = $false
                        BackupPath = $null
                        Error = $_.Exception.Message
                    }
                }
            } -ArgumentList "$PSScriptRoot\CertWebService.ps1", "C:\CertWebService", "CertWebService"
            
            $duration = ((Get-Date) - $startTime).TotalSeconds
            
            if ($updateResult.Success) {
                # Verify update
                Start-Sleep -Seconds 5
                $newStatus = Test-CertWebServiceStatus -ServerName $serverName -Port $webServicePort
                
                return @{
                    Server = $shortName
                    Status = "UPDATED"
                    Error = $null
                    Duration = [Math]::Round($duration, 1)
                    OldVersion = $serviceStatus.Version
                    NewVersion = $newStatus.Version
                    BackupPath = $updateResult.BackupPath
                }
            } else {
                return @{
                    Server = $shortName
                    Status = "FAILED"
                    Error = $updateResult.Error
                    Duration = [Math]::Round($duration, 1)
                }
            }
        } else {
            # Test-Only Mode
            return @{
                Server = $shortName
                Status = "READY-FOR-UPDATE"
                Error = $null
                Duration = 0
                CurrentVersion = $serviceStatus.Version
                TargetVersion = $targetCertWebServiceVersion
            }
        }
        
    } catch {
        return @{
            Server = $shortName
            Status = "FAILED"
            Error = $_.Exception.Message
            Duration = 0
        }
    }
}

#
# MAIN EXECUTION
#

try {
    # 1. Excel-Server einlesen
    $servers = Get-ServersFromExcel -ExcelPath $ExcelPath -FilterString $Filter
    
    if ($servers.Count -eq 0) {
        Write-Host "[ERROR] No servers found in Excel" -ForegroundColor Red
        exit 1
    }
    
    # 2. Credentials für Server-Zugriff
    Write-Host "[*] Getting credentials using 3-tier strategy..." -ForegroundColor Yellow
    $credential = Get-OrPromptCredential -Target "CertWebService-Update-Deployment" -Username "Administrator" -AutoSave
    
    if (-not $credential) {
        Write-Host "[ERROR] Credentials required for deployment" -ForegroundColor Red
        exit 1
    }
    
    # 3. Server-Analyse und Update
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  SERVER ANALYSIS & UPDATE" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $results = @()
    $totalServers = $servers.Count
    $processedServers = 0
    
    # Parallel Processing mit Job-Management
    $jobs = @()
    $maxJobs = $MaxConcurrent
    
    foreach ($server in $servers) {
        # Wait if too many jobs running
        while ($jobs.Count -ge $maxJobs) {
            $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
            foreach ($job in $completed) {
                $result = Receive-Job -Job $job
                $results += $result
                Remove-Job -Job $job
                $processedServers++
                
                # Status Display
                $statusColor = switch ($result.Status) {
                    "UPDATED" { "Green" }
                    "UP-TO-DATE" { "Cyan" }
                    "READY-FOR-UPDATE" { "Yellow" }
                    "SKIPPED" { "Gray" }
                    "FAILED" { "Red" }
                    default { "White" }
                }
                
                Write-Host "[$processedServers/$totalServers] $($result.Server): $($result.Status)" -ForegroundColor $statusColor
                if ($result.Error) {
                    Write-Host "    Error: $($result.Error)" -ForegroundColor Red
                }
                if ($result.Duration -gt 0) {
                    Write-Host "    Duration: $($result.Duration)s" -ForegroundColor Gray
                }
            }
            $jobs = $jobs | Where-Object { $_.State -ne 'Completed' }
            Start-Sleep -Milliseconds 500
        }
        
        # Start new job
        $job = Start-Job -ScriptBlock {
            param($ServerInfo, $Credential, $FunctionDef1, $FunctionDef2, $FunctionDef3, $WebServicePort, $TargetVersion, $TestOnly, $PSScriptRoot)
            
            # Re-define functions in job context
            . ([ScriptBlock]::Create($FunctionDef1))
            . ([ScriptBlock]::Create($FunctionDef2))
            . ([ScriptBlock]::Create($FunctionDef3))
            
            # Call update function
            Update-SingleServer -ServerInfo $ServerInfo -Credential $Credential
            
        } -ArgumentList $server, $credential, ${function:Test-CertWebServiceStatus}, ${function:Test-ServerConnectivity}, ${function:Update-SingleServer}, $webServicePort, $targetCertWebServiceVersion, $TestOnly, $PSScriptRoot
        
        $jobs += $job
    }
    
    # Wait for remaining jobs
    while ($jobs.Count -gt 0) {
        $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
        foreach ($job in $completed) {
            $result = Receive-Job -Job $job
            $results += $result
            Remove-Job -Job $job
            $processedServers++
            
            $statusColor = switch ($result.Status) {
                "UPDATED" { "Green" }
                "UP-TO-DATE" { "Cyan" }
                "READY-FOR-UPDATE" { "Yellow" }
                "SKIPPED" { "Gray" }
                "FAILED" { "Red" }
                default { "White" }
            }
            
            Write-Host "[$processedServers/$totalServers] $($result.Server): $($result.Status)" -ForegroundColor $statusColor
            if ($result.Error) {
                Write-Host "    Error: $($result.Error)" -ForegroundColor Red
            }
            if ($result.Duration -gt 0) {
                Write-Host "    Duration: $($result.Duration)s" -ForegroundColor Gray
            }
        }
        $jobs = $jobs | Where-Object { $_.State -ne 'Completed' }
        if ($jobs.Count -gt 0) {
            Start-Sleep -Seconds 1
        }
    }
    
    # 4. Results Summary
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $summary = @{
        Updated = ($results | Where-Object { $_.Status -eq "UPDATED" }).Count
        UpToDate = ($results | Where-Object { $_.Status -eq "UP-TO-DATE" }).Count
        ReadyForUpdate = ($results | Where-Object { $_.Status -eq "READY-FOR-UPDATE" }).Count
        Skipped = ($results | Where-Object { $_.Status -eq "SKIPPED" }).Count
        Failed = ($results | Where-Object { $_.Status -eq "FAILED" }).Count
        Total = $results.Count
    }
    
    Write-Host "Total Servers: $($summary.Total)" -ForegroundColor White
    Write-Host "Updated: $($summary.Updated)" -ForegroundColor Green
    Write-Host "Up-to-Date: $($summary.UpToDate)" -ForegroundColor Cyan
    Write-Host "Ready for Update: $($summary.ReadyForUpdate)" -ForegroundColor Yellow
    Write-Host "Skipped: $($summary.Skipped)" -ForegroundColor Gray
    Write-Host "Failed: $($summary.Failed)" -ForegroundColor Red
    
    # 5. Detailed Results
    if ($results.Count -gt 0) {
        Write-Host ""
        Write-Host "DETAILED RESULTS:" -ForegroundColor Yellow
        
        $results | Sort-Object Server | ForEach-Object {
            $statusIcon = switch ($_.Status) {
                "UPDATED" { "[+]" }
                "UP-TO-DATE" { "[=]" }
                "READY-FOR-UPDATE" { "[?]" }
                "SKIPPED" { "[-]" }
                "FAILED" { "[X]" }
                default { "[?]" }
            }
            
            Write-Host "  $statusIcon $($_.Server) - $($_.Status)" -ForegroundColor White
            
            if ($_.OldVersion -and $_.NewVersion) {
                Write-Host "      $($_.OldVersion) → $($_.NewVersion)" -ForegroundColor Gray
            } elseif ($_.CurrentVersion) {
                Write-Host "      Current: $($_.CurrentVersion)" -ForegroundColor Gray
            }
            
            if ($_.Duration -gt 0) {
                Write-Host "      Duration: $($_.Duration)s" -ForegroundColor Gray
            }
            
            if ($_.Error) {
                Write-Host "      Error: $($_.Error)" -ForegroundColor Red
            }
        }
    }
    
    # 6. Generate Report
    $reportPath = Join-Path $PSScriptRoot "Reports"
    if (-not (Test-Path $reportPath)) {
        New-Item -Path $reportPath -ItemType Directory -Force | Out-Null
    }
    
    $reportFile = Join-Path $reportPath "CertWebService-Update-Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    
    $reportData = @{
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ScriptVersion = $scriptVersion
        TargetVersion = $targetCertWebServiceVersion
        TestMode = $TestOnly
        Filter = $Filter
        MaxConcurrent = $MaxConcurrent
        Summary = $summary
        Results = $results
    }
    
    $reportData | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host ""
    Write-Host "Report saved: $(Split-Path $reportFile -Leaf)" -ForegroundColor Green
    
    # 7. Exit Code
    if ($summary.Failed -gt 0 -and -not $Force) {
        Write-Host ""
        Write-Host "[WARNING] Some updates failed. Use -Force to ignore failures." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host ""
        Write-Host "[SUCCESS] Deployment completed!" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host ""
    Write-Host "[FATAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}