#requires -Version 5.1
#Requires -RunAsAdministrator

<#if ($Global:PSCompatibilityLoaded) {
    Write-VersionSpecificHeader "Excel-Based CertWebService Update Launcher" -Version $Script:Version -Color Cyan
    Write-VersionSpecificHost "Mode: $Mode" -IconType 'gear' -ForegroundColor Gray
    Write-VersionSpecificHost "Filter: $Filter $(if($FilterValue){"($FilterValue)"})" -IconType 'target' -ForegroundColor Gray
} else {
    Write-Host "[START] Excel-Based CertWebService Update Launcher" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   Version: $Script:Version" -ForegroundColor Gray
    Write-Host "   Mode: $Mode" -ForegroundColor Gray
    Write-Host "   Filter: $Filter $(if($FilterValue){"($FilterValue)"})" -ForegroundColor Gray
    Write-Host "   Start: $($Script:LauncherStart.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host ""
}PSIS
    Excel-Based CertWebService Update Launcher v2.5.0

.DESCRIPTION
    Intelligenter Launcher für Excel-basierte Mass Updates:
    1. Liest automatisch Serverliste2025.xlsx
    2. Erkennt CertWebService Status auf allen Servern
    3. Führt bulk Installation/Updates durch
    
.VERSION
    2.5.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Analyze", "TestConnectivity", "DryRun", "Deploy")]
    [string]$Mode = "Analyze",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Domain", "Workgroup", "TestOnly")]
    [string]$Filter = "All",
    
    [Parameter(Mandatory = $false)]
    [string]$FilterValue = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$Script:Version = "v2.5.0"
$Script:LauncherStart = Get-Date

# Import PowerShell Version Compatibility Module
try {
    $compatibilityModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility.psm1"
    if (Test-Path $compatibilityModulePath) {
        Import-Module $compatibilityModulePath -Force
        $Global:PSCompatibilityLoaded = $true
        Write-Host "🔧 PowerShell version compatibility module loaded" -ForegroundColor Green
        
        # Display PowerShell version information
        $psVersionInfo = Get-PowerShellVersionInfo
        Write-Host "   PS Version: $($psVersionInfo.Version) ($($psVersionInfo.Edition)) - $($psVersionInfo.Platform)" -ForegroundColor Gray
    } else {
        $Global:PSCompatibilityLoaded = $false
        Write-Host "⚠️ PowerShell compatibility module not found - using fallback methods" -ForegroundColor Yellow
    }
} catch {
    $Global:PSCompatibilityLoaded = $false
    Write-Host "⚠️ PowerShell compatibility module failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "🚀 Excel-Based CertWebService Update Launcher" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Version: $Script:Version" -ForegroundColor Gray
Write-Host "   Mode: $Mode" -ForegroundColor Gray
Write-Host "   Filter: $Filter $(if($FilterValue){"($FilterValue)"})" -ForegroundColor Gray
Write-Host "   Start: $($Script:LauncherStart.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host ""

# Load configuration and paths
$configPath = "F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$massUpdateScript = Join-Path $PSScriptRoot "Update-FromExcel-MassUpdate.ps1"

# Read Excel path from config
try {
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        $excelPath = $config.ExcelFilePath
        $worksheetName = $config.ExcelWorksheet
        Write-Host "   📋 Config loaded: Excel from config file" -ForegroundColor Green
    } else {
        # Fallback to default path
        $excelPath = "F:\DEV\repositories\Data\Serverliste2025.xlsx"
        $worksheetName = "Servers"
        Write-Host "   ⚠️ Config not found, using default Excel path" -ForegroundColor Yellow
    }
} catch {
    # Fallback to default path
    $excelPath = "F:\DEV\repositories\Data\Serverliste2025.xlsx"
    $worksheetName = "Servers"
    Write-Host "   ⚠️ Config read error, using default Excel path" -ForegroundColor Yellow
}

# Verify prerequisites
Write-Host "🔍 Verifying prerequisites..." -ForegroundColor Yellow

if (-not (Test-Path $excelPath)) {
    Write-Host "❌ Excel file not found: $excelPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUTION:" -ForegroundColor Yellow
    Write-Host "1. Check config file: $configPath" -ForegroundColor White
    Write-Host "2. Ensure ExcelFilePath in config points to correct file" -ForegroundColor White
    Write-Host "3. Or ensure default file exists: F:\DEV\repositories\Data\Serverliste2025.xlsx" -ForegroundColor White
    exit 1
}
Write-Host "   ✅ Excel file found: $excelPath" -ForegroundColor Green

if (-not (Test-Path $massUpdateScript)) {
    Write-Host "❌ Mass update script not found: $massUpdateScript" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ Mass update script found" -ForegroundColor Green

# Check ImportExcel module
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "   📦 ImportExcel module not found - will be installed automatically" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ ImportExcel module available" -ForegroundColor Green
}

Write-Host ""

# Show mode information
switch ($Mode) {
    "Analyze" {
        Write-Host "📊 ANALYSIS MODE" -ForegroundColor Cyan
        Write-Host "===============" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "This will:" -ForegroundColor Yellow
        Write-Host "✅ Read all servers from Excel" -ForegroundColor White
        Write-Host "✅ Check which servers have CertWebService running" -ForegroundColor White
        Write-Host "✅ Test connectivity capabilities (ping, SMB, PSRemoting)" -ForegroundColor White
        Write-Host "✅ Categorize servers by installation needs" -ForegroundColor White
        Write-Host "✅ Provide deployment recommendations" -ForegroundColor White
        Write-Host ""
        Write-Host "No changes will be made to any server." -ForegroundColor Green
    }
    
    "TestConnectivity" {
        Write-Host "🔍 CONNECTIVITY TEST MODE" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "This will:" -ForegroundColor Yellow
        Write-Host "✅ Test basic connectivity to all servers" -ForegroundColor White
        Write-Host "✅ Check SMB access (C$ share)" -ForegroundColor White
        Write-Host "✅ Test WMI capabilities" -ForegroundColor White
        Write-Host "✅ Verify PSRemoting availability" -ForegroundColor White
        Write-Host ""
        Write-Host "No changes will be made to any server." -ForegroundColor Green
    }
    
    "DryRun" {
        Write-Host "🧪 DRY RUN MODE" -ForegroundColor Cyan
        Write-Host "==============" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "This will:" -ForegroundColor Yellow
        Write-Host "✅ Perform complete analysis" -ForegroundColor White
        Write-Host "✅ Show exactly what would be deployed where" -ForegroundColor White
        Write-Host "✅ Identify deployment methods for each server" -ForegroundColor White
        Write-Host "✅ Generate deployment plan" -ForegroundColor White
        Write-Host ""
        Write-Host "No actual deployments will be executed." -ForegroundColor Green
    }
    
    "Deploy" {
        Write-Host "🚀 DEPLOYMENT MODE" -ForegroundColor Red
        Write-Host "=================" -ForegroundColor Red
        Write-Host ""
        Write-Host "⚠️ WARNING: This will make changes to servers!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This will:" -ForegroundColor Yellow
        Write-Host "🔄 Install CertWebService on servers that don't have it" -ForegroundColor White
        Write-Host "🔄 Update CertWebService on servers that have old versions" -ForegroundColor White
        Write-Host "🔄 Use optimal deployment method for each server" -ForegroundColor White
        Write-Host "🔄 Generate comprehensive deployment reports" -ForegroundColor White
        Write-Host ""
        
        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to proceed with deployment? (yes/no)"
            if ($confirmation -notlike "y*" -and $confirmation -notlike "yes") {
                Write-Host "🛑 Deployment cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
    }
}

Write-Host ""

# Prepare parameters for mass update script
$massUpdateParams = @{
    ExcelPath = $excelPath
    WorksheetName = $worksheetName
}

# Add mode-specific parameters
switch ($Mode) {
    "Analyze" {
        $massUpdateParams.AnalyzeOnly = $true
    }
    "TestConnectivity" {
        $massUpdateParams.TestConnectivityOnly = $true
    }
    "DryRun" {
        $massUpdateParams.DryRun = $true
    }
    "Deploy" {
        # No special parameters for full deployment
    }
}

# Add filter parameters
$massUpdateParams.FilterType = $Filter
if ($FilterValue) {
    $massUpdateParams.FilterValue = $FilterValue
}

# Execute mass update script
Write-Host "▶️ Executing Excel-based mass update..." -ForegroundColor Green
Write-Host ""

try {
    & $massUpdateScript @massUpdateParams
    
    $endTime = Get-Date
    $duration = $endTime - $Script:LauncherStart
    
    Write-Host ""
    Write-Host "🎉 Launcher completed successfully!" -ForegroundColor Green
    Write-Host "   Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host ""
    
    # Show next steps based on mode
    switch ($Mode) {
        "Analyze" {
            Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
            Write-Host "1. Review the analysis results above" -ForegroundColor White
            Write-Host "2. Test connectivity if needed:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode TestConnectivity" -ForegroundColor Gray
            Write-Host "3. Run dry run to see deployment plan:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode DryRun" -ForegroundColor Gray
            Write-Host "4. Execute deployment when ready:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode Deploy" -ForegroundColor Gray
        }
        
        "TestConnectivity" {
            Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
            Write-Host "1. Review connectivity results above" -ForegroundColor White
            Write-Host "2. Run full analysis:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode Analyze" -ForegroundColor Gray
            Write-Host "3. Or proceed with dry run:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode DryRun" -ForegroundColor Gray
        }
        
        "DryRun" {
            Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
            Write-Host "1. Review the deployment plan above" -ForegroundColor White
            Write-Host "2. Execute deployment when ready:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode Deploy" -ForegroundColor Gray
            Write-Host "3. Or filter to specific server groups first:" -ForegroundColor White
            Write-Host "   .\Excel-Update-Launcher.ps1 -Mode Deploy -Filter TestOnly" -ForegroundColor Gray
        }
        
        "Deploy" {
            Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
            Write-Host "1. Review deployment results above" -ForegroundColor White
            Write-Host "2. Complete any manual installations identified" -ForegroundColor White
            Write-Host "3. Test WebService endpoints:" -ForegroundColor White
            Write-Host "   Check http://[SERVER]:9080/health.json on updated servers" -ForegroundColor Gray # DevSkim: ignore DS137138 - Internal network HTTP endpoint
            Write-Host "4. Update Certificate Surveillance (CertSurv) configuration" -ForegroundColor White
            Write-Host "5. Run integration tests" -ForegroundColor White
        }
    }
    
    Write-Host ""
    
} catch {
    Write-Host "❌ Launcher execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. Ensure you have Administrator privileges" -ForegroundColor White
    Write-Host "2. Check Excel file format and worksheet name" -ForegroundColor White  
    Write-Host "3. Verify network connectivity to servers" -ForegroundColor White
    Write-Host "4. Review PowerShell execution policy" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "🏁 Excel-based launcher completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
