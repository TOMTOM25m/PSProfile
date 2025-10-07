#requires -Version 5.1

<#
.SYNOPSIS
    CertWebService Excel Analysis & SMB Updates v1.0

.DESCRIPTION
    Einfache Excel-Auswertung mit SMB-prioritierten Updates:
    1. Excel-Serverliste einlesen
    2. CertWebService-Status prüfen
    3. SMB-Zugriff testen
    4. Updates durchführen

.VERSION
    1.0 - Working Simple Version
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "F:\DEV\repositories\Data\Serverliste2025.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$FilterDomain = "uvw",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$NewVersion = "v2.5.0"
Write-Host "🚀 CertWebService Excel Analysis & SMB Updates" -ForegroundColor Cyan
Write-Host "Excel: $ExcelPath" -ForegroundColor Gray
Write-Host "Filter: $FilterDomain" -ForegroundColor Gray
Write-Host "Target: $NewVersion" -ForegroundColor Gray
Write-Host ""

# Install ImportExcel
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "📦 Installing ImportExcel..." -ForegroundColor Cyan
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}
Import-Module ImportExcel -Force

# Read Excel
Write-Host "📊 Reading Excel..." -ForegroundColor Yellow
$worksheets = Get-ExcelSheetInfo -Path $ExcelPath
Write-Host "Worksheets: $($worksheets.Name -join ', ')" -ForegroundColor Gray

$allServers = @()

foreach ($ws in $worksheets) {
    Write-Host "Processing: $($ws.Name)" -ForegroundColor Cyan
    
    try {
        $data = Import-Excel -Path $ExcelPath -WorksheetName $ws.Name -NoHeader
        
        $currentDomain = "srv"
        $isDomain = $false
        
        foreach ($row in $data) {
            if (-not $row.P1) { continue }
            $server = $row.P1.ToString().Trim()
            
            # Domain detection
            if ($server -match '^\(Domain(?:-[\w]+)?\)([\w-]+)') {
                $currentDomain = $matches[1].ToLower()
                $isDomain = $true
                continue
            }
            
            if ($server -match '^\(Workgroup\)([\w-]+)') {
                $currentDomain = $matches[1].ToLower()
                $isDomain = $false
                continue
            }
            
            if ($server -match '^SUMME:?\s*$') {
                $currentDomain = "srv"
                $isDomain = $false
                continue
            }
            
            # Skip headers
            if ($server -match "^(Server|Servers|NEUE|DATACENTER|STANDARD|ServerName)") { continue }
            
            # Valid server
            if ($server.Length -gt 2 -and $server -notmatch '^[\s\-_=]+$') {
                $fqdn = if ($isDomain -and $server -notlike "*.*") {
                    "$server.$currentDomain.meduniwien.ac.at"
                } else {
                    $server
                }
                
                $allServers += @{
                    Name = $server
                    Domain = if ($isDomain) { $currentDomain } else { "" }
                    IsDomain = $isDomain
                    FQDN = $fqdn
                    Sheet = $ws.Name
                }
            }
        }
    } catch {
        Write-Host "Skipped $($ws.Name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "Total servers found: $($allServers.Count)" -ForegroundColor Green

# Filter by domain
if ($FilterDomain) {
    $filteredServers = $allServers | Where-Object { 
        $_.Domain -like "*$FilterDomain*" -or $_.Name -like "*$FilterDomain*"
    }
    Write-Host "Filtered servers: $($filteredServers.Count)" -ForegroundColor Green
} else {
    $filteredServers = $allServers
}

Write-Host ""
Write-Host "🔍 ANALYSIS PHASE" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan

$results = @{
    Total = $filteredServers.Count
    HasCertWeb = @()
    NeedsUpdate = @()
    SMBAccess = @()
    Unreachable = @()
    UpdateSuccess = @()
    UpdateFailed = @()
}

foreach ($server in $filteredServers) {
    Write-Host "🖥️ $($server.Name) ($($server.FQDN))" -ForegroundColor White
    
    # Test CertWebService
    $hasCertWeb = $false
    $currentVersion = "Unknown"
    $needsUpdate = $false
    
    foreach ($port in @(9080, 8080)) {
        try {
            $url = "http://$($server.FQDN):$port/health.json"
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                $hasCertWeb = $true
                try {
                    $health = $response.Content | ConvertFrom-Json
                    $currentVersion = $health.version
                    $needsUpdate = ($currentVersion -ne $NewVersion)
                } catch {
                    $currentVersion = "Legacy"
                    $needsUpdate = $true
                }
                Write-Host "   ✅ CertWebService: $currentVersion (Port $port)" -ForegroundColor Green
                break
            }
        } catch {
            continue
        }
    }
    
    if ($hasCertWeb) {
        $results.HasCertWeb += $server
        if ($needsUpdate) {
            $results.NeedsUpdate += $server
            Write-Host "   🔄 Update needed: $currentVersion → $NewVersion" -ForegroundColor Yellow
        } else {
            Write-Host "   ✅ Already current version" -ForegroundColor Green
        }
    } else {
        Write-Host "   ❌ CertWebService not found" -ForegroundColor Red
    }
    
    # Test connectivity
    $ping = $false
    $smb = $false
    
    try {
        $ping = Test-Connection -ComputerName $server.FQDN -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) {
            $adminShare = "\\$($server.FQDN)\C$"
            $smb = Test-Path $adminShare -ErrorAction SilentlyContinue
            if ($smb) {
                $results.SMBAccess += $server
                Write-Host "   🌐 SMB: Accessible" -ForegroundColor Green
            } else {
                Write-Host "   🌐 SMB: No access" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ❌ Unreachable" -ForegroundColor Red
            $results.Unreachable += $server
        }
    } catch {
        Write-Host "   ❌ Connection test failed" -ForegroundColor Red
        $results.Unreachable += $server
    }
    
    # Execute update if needed and not dry run
    if ($hasCertWeb -and $needsUpdate -and $smb -and -not $DryRun) {
        Write-Host "   🚀 Executing SMB update..." -ForegroundColor Cyan
        
        try {
            # Copy new CertWebService
            $localFile = Join-Path $PSScriptRoot "CertWebService.ps1"
            $remotePath = "\\$($server.FQDN)\C$\CertWebService"
            
            if (-not (Test-Path $remotePath)) {
                New-Item -Path $remotePath -ItemType Directory -Force | Out-Null
            }
            
            # Backup existing
            $remoteFile = "$remotePath\CertWebService.ps1"
            if (Test-Path $remoteFile) {
                Copy-Item $remoteFile "$remotePath\CertWebService-backup.ps1" -Force
            }
            
            # Copy new version
            Copy-Item $localFile $remoteFile -Force
            
            # Create simple restart script
            $restartScript = @"
Get-Process powershell | Where-Object { `$_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Set-Location "C:\CertWebService"
Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
"@
            
            $restartFile = "$remotePath\Restart.ps1"
            $restartScript | Out-File -FilePath $restartFile -Encoding UTF8 -Force
            
            # Try to execute restart
            $executed = $false
            
            # Try PsExec
            $psExec = "${env:ProgramFiles}\SysinternalsSuite\PsExec.exe"
            if (Test-Path $psExec) {
                try {
                    Start-Process $psExec -ArgumentList "\\$($server.FQDN)", "-accepteula", "-s", "powershell.exe", "-ExecutionPolicy Bypass", "-File C:\CertWebService\Restart.ps1" -Wait -NoNewWindow
                    $executed = $true
                } catch {
                    # PsExec failed
                }
            }
            
            # Try WMI if PsExec failed
            if (-not $executed) {
                try {
                    $wmi = Invoke-WmiMethod -ComputerName $server.FQDN -Class Win32_Process -Name Create -ArgumentList "powershell.exe -ExecutionPolicy Bypass -File C:\CertWebService\Restart.ps1"
                    $executed = ($wmi.ReturnValue -eq 0)
                } catch {
                    # WMI failed
                }
            }
            
            if ($executed) {
                Start-Sleep 10
                
                # Verify update
                try {
                    $url = "http://$($server.FQDN):9080/health.json"
                    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
                    $health = $response.Content | ConvertFrom-Json
                    
                    if ($health.version -eq $NewVersion) {
                        Write-Host "   ✅ Update successful: $($health.version)" -ForegroundColor Green
                        $results.UpdateSuccess += $server
                    } else {
                        Write-Host "   ⚠️ Update partially successful: $($health.version)" -ForegroundColor Yellow
                        $results.UpdateFailed += $server
                    }
                } catch {
                    Write-Host "   ⚠️ Update completed but verification failed" -ForegroundColor Yellow
                    $results.UpdateFailed += $server
                }
            } else {
                Write-Host "   ❌ Could not execute restart script" -ForegroundColor Red
                $results.UpdateFailed += $server
            }
            
        } catch {
            Write-Host "   ❌ Update failed: $($_.Exception.Message)" -ForegroundColor Red
            $results.UpdateFailed += $server
        }
    } elseif ($hasCertWeb -and $needsUpdate -and -not $smb) {
        Write-Host "   📋 Manual update required (no SMB access)" -ForegroundColor Yellow
    } elseif ($hasCertWeb -and $needsUpdate -and $DryRun) {
        Write-Host "   🧪 DRY RUN: Would update via SMB" -ForegroundColor Cyan
    }
    
    Write-Host ""
}

# Final summary
Write-Host "📊 FINAL SUMMARY" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan
Write-Host "Total Servers: $($results.Total)" -ForegroundColor White
Write-Host "Has CertWebService: $($results.HasCertWeb.Count)" -ForegroundColor Green
Write-Host "Needs Update: $($results.NeedsUpdate.Count)" -ForegroundColor Yellow
Write-Host "SMB Accessible: $($results.SMBAccess.Count)" -ForegroundColor Cyan
Write-Host "Unreachable: $($results.Unreachable.Count)" -ForegroundColor Red

if (-not $DryRun) {
    Write-Host "Update Successful: $($results.UpdateSuccess.Count)" -ForegroundColor Green
    Write-Host "Update Failed: $($results.UpdateFailed.Count)" -ForegroundColor Red
}

Write-Host ""

if ($results.UpdateSuccess.Count -gt 0) {
    Write-Host "✅ Successfully Updated Servers:" -ForegroundColor Green
    foreach ($server in $results.UpdateSuccess) {
        Write-Host "   🖥️ $($server.Name)" -ForegroundColor White
    }
    Write-Host ""
}

if ($results.UpdateFailed.Count -gt 0) {
    Write-Host "❌ Failed Updates:" -ForegroundColor Red
    foreach ($server in $results.UpdateFailed) {
        Write-Host "   🖥️ $($server.Name)" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($results.NeedsUpdate.Count -gt 0 -and $results.UpdateSuccess.Count -eq 0 -and -not $DryRun) {
    Write-Host "💡 RECOMMENDATIONS:" -ForegroundColor Yellow
    Write-Host "• Check SMB access to servers without access" -ForegroundColor White
    Write-Host "• Verify PsExec is installed in SysinternalsSuite" -ForegroundColor White
    Write-Host "• Consider manual updates for unreachable servers" -ForegroundColor White
}

$successRate = if ($results.NeedsUpdate.Count -gt 0) {
    [math]::Round(($results.UpdateSuccess.Count / $results.NeedsUpdate.Count) * 100, 1)
} else { 100 }

Write-Host "📊 Success Rate: $successRate%" -ForegroundColor $(if($successRate -gt 80){'Green'}elseif($successRate -gt 50){'Yellow'}else{'Red'})
Write-Host ""
Write-Host "🏁 Excel analysis completed!" -ForegroundColor Green