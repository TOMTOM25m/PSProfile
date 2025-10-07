#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    CertWebService Production Update Deployment v1.0.0

.DESCRIPTION
    Production-ready Update-Deployment für alle Server mit CertWebService.
    Kombiniert Excel-Integration mit dem bewährten Update-AllServers-Hybrid-v2.5.ps1
    
    WORKFLOW:
    1. Excel-Serverliste einlesen (mit Block-Struktur)
    2. Server-Konnektivität und CertWebService-Status prüfen
    3. Server mit Updates sammeln
    4. Existierendes Update-AllServers-Hybrid-v2.5.ps1 aufrufen

.PARAMETER ExcelPath
    Pfad zur Excel-Serverliste

.PARAMETER Filter
    Server-Filter (Domain/Workgroup/ServerName)

.PARAMETER TestOnly
    Nur Analyse, kein Update

.PARAMETER MaxConcurrent
    Maximale parallele Updates

.EXAMPLE
    .\Update-CertWebService-Production.ps1 -Filter "UVW" -TestOnly
    
.EXAMPLE
    .\Update-CertWebService-Production.ps1 -Filter "EX" -MaxConcurrent 3
#>

param(
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    [string]$Filter = "",
    [switch]$TestOnly,
    [int]$MaxConcurrent = 5
)

$ErrorActionPreference = "Stop"

# Konfiguration
$webServicePort = 9080
$targetVersion = "v2.5.0"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CERTWEBSERVICE PRODUCTION UPDATE" -ForegroundColor Cyan
Write-Host "  v1.0.0 | $(Get-Date -Format 'dd.MM.yyyy HH:mm')" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Excel Source: $(Split-Path $ExcelPath -Leaf)" -ForegroundColor Yellow
Write-Host "Filter: $(if($Filter){"'$Filter'"}else{'None'})" -ForegroundColor Yellow
Write-Host "Target Version: $targetVersion" -ForegroundColor Yellow
Write-Host "Mode: $(if($TestOnly){'TEST ONLY'}else{'PRODUCTION'})" -ForegroundColor Yellow
Write-Host ""

# Step 1: Excel Server List mit Update-CertSurv-ServerList.ps1 Funktionen
Write-Host "[STEP 1] Reading Excel server list..." -ForegroundColor Cyan

# Nutze die Excel-Reading-Funktion von Update-CertSurv-ServerList.ps1
$scriptBlock = {
    param($ExcelPath, $FilterString)
    
    if (-not (Test-Path $ExcelPath)) {
        throw "Excel file not found: $ExcelPath"
    }
    
    try {
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        $Worksheet = $Workbook.Worksheets.Item(1)
        
        $servers = @()
        $currentBlock = ""
        $invalidPatterns = @('^SUMME:', 'ServerName', 'NEUE SERVER', 'Stand:', 'Servers', 'DATACENTER', '^\(Domain', '^\(Workgroup', '\s+')
        
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
            
            if ($col1Value -match '^\((Domain|WORKGROUP)\)(.+)') {
                $currentBlock = $matches[2].Trim()
                continue
            }
            
            if ($col1Value -match '^SUMME:') { continue }
            
            $isInvalid = $false
            foreach ($pattern in $invalidPatterns) {
                if ($col1Value -match $pattern) { $isInvalid = $true; break }
            }
            if ($isInvalid) { continue }
            
            $isStrikethrough = $cell.Font.Strikethrough
            if ($isStrikethrough) { continue }
            
            $fqdn = $col1Value
            if ($currentBlock -and $domainMap.ContainsKey($currentBlock)) {
                $fqdn = "$col1Value.$($domainMap[$currentBlock])"
            } elseif ($currentBlock -eq "SRV") {
                $fqdn = "$col1Value.srv.meduniwien.ac.at"
            } else {
                $fqdn = "$col1Value.meduniwien.ac.at"
            }
            
            if ($FilterString -and $col1Value -notmatch $FilterString -and $currentBlock -notmatch $FilterString) {
                continue
            }
            
            $servers += @{
                ServerName = $col1Value
                FQDN = $fqdn
                Block = $currentBlock
            }
        }
        
        $Workbook.Close()
        $Excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
        [GC]::Collect()
        
        return $servers
        
    } catch {
        throw "Excel reading failed: $($_.Exception.Message)"
    }
}

try {
    $servers = & $scriptBlock -ExcelPath $ExcelPath -FilterString $Filter
    Write-Host "[OK] Found $($servers.Count) servers in Excel" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Excel reading failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($servers.Count -eq 0) {
    Write-Host "[WARNING] No servers found with filter '$Filter'" -ForegroundColor Yellow
    exit 0
}

# Step 2: CertWebService Status Check
Write-Host ""
Write-Host "[STEP 2] Checking CertWebService status..." -ForegroundColor Cyan

$certweb_servers = @()
$total = $servers.Count
$checked = 0

foreach ($server in $servers) {
    $checked++
    Write-Progress -Activity "Checking CertWebService Status" -Status "$($server.ServerName)" -PercentComplete (($checked / $total) * 100)
    
    try {
        # Quick ping test
        $ping = Test-Connection -ComputerName $server.FQDN -Count 1 -Quiet
        if (-not $ping) { continue }
        
        # CertWebService health check
        $uri = "http://$($server.FQDN):$webServicePort/health.json"
        $response = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        
        $needsUpdate = $response.version -ne $targetVersion
        
        if ($needsUpdate) {
            $certweb_servers += @{
                ServerName = $server.ServerName
                FQDN = $server.FQDN
                Block = $server.Block
                CurrentVersion = $response.version
                TargetVersion = $targetVersion
            }
            
            Write-Host "  [+] $($server.ServerName) | $($response.version) → $targetVersion" -ForegroundColor Yellow
        } else {
            Write-Host "  [=] $($server.ServerName) | $($response.version) (up-to-date)" -ForegroundColor Cyan
        }
        
    } catch {
        # Server läuft, aber kein CertWebService - das ist OK
        continue
    }
}

Write-Progress -Activity "Checking CertWebService Status" -Completed

Write-Host ""
Write-Host "[OK] Found $($certweb_servers.Count) servers needing CertWebService update" -ForegroundColor Green

if ($certweb_servers.Count -eq 0) {
    Write-Host ""
    Write-Host "[INFO] All servers with CertWebService are up-to-date!" -ForegroundColor Green
    exit 0
}

# Step 3: Show Update Plan
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  UPDATE PLAN" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$grouped = $certweb_servers | Group-Object Block
foreach ($group in $grouped) {
    Write-Host "[$($group.Name)]" -ForegroundColor Yellow
    $group.Group | ForEach-Object {
        Write-Host "  • $($_.ServerName) ($($_.FQDN))" -ForegroundColor White
        Write-Host "    $($_.CurrentVersion) → $($_.TargetVersion)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Step 4: Execute Update or Show Command
if ($TestOnly) {
    Write-Host "[INFO] TEST MODE - No updates performed" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To execute the update, run:" -ForegroundColor Green
    $serverNames = $certweb_servers | ForEach-Object { $_.ServerName }
    Write-Host ".\Update-AllServers-Hybrid-v2.5.ps1 -ServerList @('$($serverNames -join "','")') -MaxConcurrent $MaxConcurrent" -ForegroundColor White
    
} else {
    Write-Host "[STEP 4] Executing update deployment..." -ForegroundColor Cyan
    Write-Host ""
    
    # Get credentials using 3-tier strategy
    Write-Host "[*] Getting deployment credentials..." -ForegroundColor Yellow
    $credential = Get-OrPromptCredential -Target "CertWebService-Production-Update" -Username "Administrator" -AutoSave
    
    if (-not $credential) {
        Write-Host "[ERROR] Credentials required for deployment" -ForegroundColor Red
        exit 1
    }
    
    # Prepare server list for Update-AllServers-Hybrid-v2.5.ps1
    $serverNames = $certweb_servers | ForEach-Object { $_.ServerName }
    
    Write-Host "[*] Starting deployment to $($serverNames.Count) servers..." -ForegroundColor Yellow
    Write-Host "    Using Update-AllServers-Hybrid-v2.5.ps1" -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Call existing deployment script
        & "$PSScriptRoot\Update-AllServers-Hybrid-v2.5.ps1" -ServerList $serverNames -AdminCredential $credential -MaxConcurrent $MaxConcurrent -GenerateReports
        
        Write-Host ""
        Write-Host "[SUCCESS] Deployment completed!" -ForegroundColor Green
        
    } catch {
        Write-Host ""
        Write-Host "[ERROR] Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Excel Servers: $($servers.Count)" -ForegroundColor White
Write-Host "Servers with CertWebService: $($certweb_servers.Count)" -ForegroundColor Yellow
Write-Host "Target Version: $targetVersion" -ForegroundColor White
Write-Host "Status: $(if($TestOnly){'Analysis Complete'}else{'Deployment Complete'})" -ForegroundColor Green
Write-Host ""