<#
.SYNOPSIS
    CertWebService Update Manager for ITSC020 Workstation
    
.DESCRIPTION
    Automated update detection and management for all CertWebService installations.
    Checks versions across all servers and generates update reports.
    
.PARAMETER ExcelPath
    Path to Excel file with server list
    
.PARAMETER LatestVersion
    Latest available CertWebService version (default: auto-detect)
    
.PARAMETER GenerateReport
    Generate detailed update report
    
.PARAMETER MaxThreads
    Maximum parallel threads for version checking (default: 20)
    
.EXAMPLE
    .\Manage-CertWebService-Updates.ps1 -GenerateReport
    
.EXAMPLE
    .\Manage-CertWebService-Updates.ps1 -LatestVersion "1.1.0" -MaxThreads 25
    
.NOTES
    For ITSC020.cc.meduwien.ac.at workstation
    Uses FL-FastServerProcessing.psm1 for parallel processing
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory=$false)]
    [string]$LatestVersion = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxThreads = 20,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerFilter = "*"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "" -ForegroundColor White
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                CERTWEBSERVICE UPDATE MANAGER                 ║" -ForegroundColor Cyan
Write-Host "║                  ITSC020 Workstation Tool                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Import required modules
try {
    # Import FL-FastServerProcessing from CertSurv
    $CertSurvPath = Split-Path -Parent $ScriptDir
    $FastProcessingPath = Join-Path $CertSurvPath "CertSurv\Modules\FL-FastServerProcessing.psm1"
    
    if (Test-Path $FastProcessingPath) {
        Import-Module $FastProcessingPath -Force
        Write-Host "✅ Fast processing module loaded (CrossUse from CertSurv)" -ForegroundColor Green
    } else {
        Write-Error "FL-FastServerProcessing.psm1 not found in CertSurv"
        exit 1
    }
    
    # Import Excel processing (if available)
    try {
        Import-Module ImportExcel -Force -ErrorAction SilentlyContinue
        $useImportExcel = $true
        Write-Host "✅ ImportExcel module loaded" -ForegroundColor Green
    } catch {
        $useImportExcel = $false
        Write-Host "⚠️  ImportExcel module not available - using COM objects" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Failed to load required modules: $($_.Exception.Message)"
    exit 1
}

try {
    Write-Host ""
    Write-Host "🔍 PHASE 1: Loading server data..." -ForegroundColor Cyan
    Write-Host "────────────────────────────────────" -ForegroundColor Gray
    
    # Load Excel data (simplified for demo - would need full Excel processing)
    if (Test-Path $ExcelPath) {
        if ($useImportExcel) {
            $excelData = Import-Excel -Path $ExcelPath -WorksheetName "Sheet1"
            Write-Host "✅ Excel data loaded via ImportExcel" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Using sample data (Excel COM processing would be needed)" -ForegroundColor Yellow
            # Placeholder sample data
            $excelData = @(
                [PSCustomObject]@{ ServerName = "wsus"; 'IP-Adresse' = "192.168.1.10"; OS_Name = "Windows Server 2019" },
                [PSCustomObject]@{ ServerName = "exchange"; 'IP-Adresse' = "192.168.1.20"; OS_Name = "Windows Server 2022" },
                [PSCustomObject]@{ ServerName = "sharepoint"; 'IP-Adresse' = "192.168.1.30"; OS_Name = "Windows Server 2019" },
                [PSCustomObject]@{ ServerName = "dc01"; 'IP-Adresse' = "192.168.1.40"; OS_Name = "Windows Server 2022" },
                [PSCustomObject]@{ ServerName = "file01"; 'IP-Adresse' = "192.168.1.50"; OS_Name = "Windows Server 2019" }
            )
        }
    } else {
        Write-Error "Excel file not found: $ExcelPath"
        exit 1
    }
    
    Write-Host "📊 Loaded $($excelData.Count) servers from Excel" -ForegroundColor White
    
    Write-Host ""
    Write-Host "⚡ PHASE 2: Fast server extraction..." -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    
    # Fast server list extraction
    $metadata = @{}  # Would load from Excel metadata
    $serverListFast = Get-ServerListFast -Data $excelData -Metadata $metadata -Filter $ServerFilter
    
    if ($serverListFast.Count -eq 0) {
        Write-Error "No servers found matching filter: $ServerFilter"
        exit 1
    }
    
    # Add FQDN resolution for each server
    foreach ($server in $serverListFast) {
        $cleanName = $server.ServerName -replace '[^a-zA-Z0-9-]', ''
        if ($server.ServerType -eq "Domain") {
            $server | Add-Member -NotePropertyName "FQDN" -NotePropertyValue "$($cleanName.ToLower()).uvw.meduniwien.ac.at"
        } else {
            $server | Add-Member -NotePropertyName "FQDN" -NotePropertyValue "$($cleanName.ToLower()).srv.meduniwien.ac.at"
        }
    }
    
    Write-Host ""
    Write-Host "🔍 PHASE 3: Version detection..." -ForegroundColor Cyan
    Write-Host "──────────────────────────────────" -ForegroundColor Gray
    
    # Get CertWebService versions from all servers
    $versionResults = Get-CertWebServiceVersions -ServerList $serverListFast -MaxThreads $MaxThreads -TimeoutSeconds 15
    
    Write-Host ""
    Write-Host "📊 PHASE 4: Update analysis..." -ForegroundColor Cyan
    Write-Host "────────────────────────────────" -ForegroundColor Gray
    
    # Analyze update candidates
    $updateSummary = Get-UpdateCandidates -VersionResults $versionResults -LatestVersion $LatestVersion
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                        UPDATE SUMMARY                        ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📈 Total Servers: $($updateSummary.TotalServers)" -ForegroundColor White
    Write-Host "✅ Up to Date: $($updateSummary.UpToDateCount)" -ForegroundColor Green
    Write-Host "🔄 Updates Needed: $($updateSummary.UpdatesNeeded)" -ForegroundColor Yellow
    Write-Host "❌ Not Installed: $($updateSummary.NotInstalledCount)" -ForegroundColor Red
    Write-Host ""
    
    if ($updateSummary.UpdatesNeeded -gt 0) {
        Write-Host "🔄 SERVERS NEEDING UPDATES:" -ForegroundColor Yellow
        foreach ($server in $updateSummary.UpdateCandidates) {
            Write-Host "  • $($server.ServerName) -> $($server.FQDN)" -ForegroundColor Yellow
            Write-Host "    Current: $($server.Version) | Latest: $($updateSummary.LatestVersion)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    if ($updateSummary.NotInstalledCount -gt 0) {
        Write-Host "❌ SERVERS WITHOUT CERTWEBSERVICE:" -ForegroundColor Red
        foreach ($server in $updateSummary.NotInstalled) {
            Write-Host "  • $($server.ServerName) -> $($server.FQDN)" -ForegroundColor Red
            Write-Host "    Error: $($server.ErrorMessage)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Generate report if requested
    if ($GenerateReport) {
        Write-Host "📄 PHASE 5: Generating update report..." -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
        
        $reportPath = New-UpdateReport -UpdateSummary $updateSummary
        if ($reportPath) {
            Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Green
            
            # Also copy to desktop for easy access
            $desktopPath = "$env:USERPROFILE\Desktop\CertWebService_UpdateReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            try {
                Copy-Item -Path $reportPath -Destination $desktopPath
                Write-Host "📋 Report copied to desktop: $desktopPath" -ForegroundColor Green
            } catch {
                Write-Warning "Could not copy report to desktop: $($_.Exception.Message)"
            }
        }
    }
    
    Write-Host ""
    Write-Host "💡 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "──────────────" -ForegroundColor Gray
    
    if ($updateSummary.UpdatesNeeded -gt 0) {
        Write-Host "  1. Run deployment script for servers needing updates:" -ForegroundColor White
        Write-Host "     .\Deploy-CertWebService-FromExcel.ps1 -ServerFilter ""server_name""" -ForegroundColor Gray
    }
    
    if ($updateSummary.NotInstalledCount -gt 0) {
        Write-Host "  2. Run full deployment for servers without CertWebService:" -ForegroundColor White
        Write-Host "     .\Deploy-CertWebService-FromExcel.ps1" -ForegroundColor Gray
    }
    
    if ($updateSummary.UpToDateCount -eq $updateSummary.TotalServers) {
        Write-Host "  🎉 All servers are up to date! No action needed." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "✅ Update management completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}