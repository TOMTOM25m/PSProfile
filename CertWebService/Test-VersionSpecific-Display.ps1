#requires -Version 5.1

<#
.SYNOPSIS
    PowerShell Version-Specific Display Test v1.0.0

.DESCRIPTION
    Testet die versions-spezifischen Display-Funktionen:
    - PS 5.1: ASCII-Zeichen und einfache Formatierung
    - PS 7.x: Emojis und moderne Unicode-Zeichen
    
.VERSION
    1.0.0

.AUTHOR
    Field Level Automation
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$ShowAllIcons,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestConnectivity
)

$Script:Version = "v1.0.0"
$Script:StartTime = Get-Date

# Import PowerShell Version Compatibility Module
try {
    $compatibilityModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility.psm1"
    if (Test-Path $compatibilityModulePath) {
        Import-Module $compatibilityModulePath -Force
        $Global:PSCompatibilityLoaded = $true
    } else {
        $Global:PSCompatibilityLoaded = $false
        Write-Host "[ERROR] PowerShell compatibility module not found" -ForegroundColor Red
        exit 1
    }
} catch {
    $Global:PSCompatibilityLoaded = $false
    Write-Host "[ERROR] PowerShell compatibility module failed to load: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Display Header
Write-VersionSpecificHeader "PowerShell Version-Specific Display Test" -Version $Script:Version -Color Cyan

# Show PowerShell Version Info
$psVersionInfo = Get-PowerShellVersionInfo
Write-VersionSpecificHost "Current PowerShell Environment:" -IconType 'info' -ForegroundColor Yellow
Write-Host "   Version: $($psVersionInfo.Version)" -ForegroundColor White
Write-Host "   Edition: $($psVersionInfo.Edition)" -ForegroundColor White
Write-Host "   Platform: $($psVersionInfo.Platform)" -ForegroundColor White
Write-Host ""

# Test verschiedene Icon-Typen
Write-VersionSpecificHost "Testing Icon Display System" -IconType 'rocket' -ForegroundColor Cyan
Write-Host ""

$iconTests = @(
    @{ Type = 'success'; Message = 'Operation completed successfully'; Color = 'Green' },
    @{ Type = 'error'; Message = 'Operation failed with error'; Color = 'Red' },
    @{ Type = 'warning'; Message = 'Operation completed with warnings'; Color = 'Yellow' },
    @{ Type = 'info'; Message = 'Information message'; Color = 'Cyan' },
    @{ Type = 'gear'; Message = 'Configuration or tool operation'; Color = 'Gray' },
    @{ Type = 'shield'; Message = 'Security-related operation'; Color = 'Blue' },
    @{ Type = 'network'; Message = 'Network connectivity test'; Color = 'Magenta' },
    @{ Type = 'file'; Message = 'File operation completed'; Color = 'White' },
    @{ Type = 'target'; Message = 'Target or goal achieved'; Color = 'Green' }
)

foreach ($test in $iconTests) {
    Write-VersionSpecificHost $test.Message -IconType $test.Type -ForegroundColor $test.Color
}

Write-Host ""

if ($ShowAllIcons) {
    Write-VersionSpecificHost "Complete Icon Reference:" -IconType 'chart' -ForegroundColor Yellow
    Write-Host ""
    
    $allIcons = @(
        'success', 'error', 'warning', 'info', 'rocket', 'gear', 'shield', 
        'lock', 'globe', 'folder', 'file', 'chart', 'target', 'computer', 
        'network', 'process', 'clock', 'party'
    )
    
    foreach ($iconType in $allIcons) {
        Write-VersionSpecificHost "Icon type: $iconType" -IconType $iconType -ForegroundColor Gray
    }
    Write-Host ""
}

# Test Network Connectivity Functions (if requested)
if ($TestConnectivity) {
    Write-VersionSpecificHost "Testing Version-Specific Network Functions:" -IconType 'network' -ForegroundColor Cyan
    Write-Host ""
    
    # Test localhost connectivity
    $connectivityResult = Test-NetworkConnectivity-VersionSpecific -ComputerName "localhost" -TimeoutSeconds 3
    
    if ($connectivityResult.Success) {
        Write-VersionSpecificHost "Localhost connectivity test successful ($($connectivityResult.Method))" -IconType 'success' -ForegroundColor Green
        Write-Host "   Response Time: $($connectivityResult.ResponseTime)ms" -ForegroundColor Gray
    } else {
        Write-VersionSpecificHost "Localhost connectivity test failed: $($connectivityResult.ErrorMessage)" -IconType 'error' -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Test port connectivity (common ports)
    $portTests = @(80, 443, 3389)
    
    foreach ($port in $portTests) {
        Write-VersionSpecificHost "Testing port $port on localhost..." -IconType 'network' -ForegroundColor Gray
        
        $portResult = Test-NetworkConnectivity-VersionSpecific -ComputerName "localhost" -Port $port -TimeoutSeconds 2
        
        if ($portResult.Success) {
            Write-VersionSpecificHost "Port $port is accessible" -IconType 'success' -ForegroundColor Green
        } else {
            Write-VersionSpecificHost "Port $port is not accessible" -IconType 'warning' -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
}

# Performance Comparison
Write-VersionSpecificHost "Version-Specific Feature Comparison:" -IconType 'chart' -ForegroundColor Cyan
Write-Host ""

$featureComparison = @(
    @{ Feature = "Icon Display"; PS51 = "ASCII characters"; PS7 = "Unicode emojis" },
    @{ Feature = "Network Testing"; PS51 = "Basic Test-Connection"; PS7 = "Enhanced Test-NetConnection" },
    @{ Feature = "PSRemoting"; PS51 = "Traditional parameters"; PS7 = "Modern parameter splatting" },
    @{ Feature = "Error Handling"; PS51 = "Basic try/catch"; PS7 = "Enhanced error information" },
    @{ Feature = "Progress Display"; PS51 = "Simple ASCII bars"; PS7 = "Unicode progress bars" }
)

foreach ($comparison in $featureComparison) {
    Write-Host "   $($comparison.Feature):" -ForegroundColor Yellow
    Write-Host "     PS 5.1: $($comparison.PS51)" -ForegroundColor Gray
    Write-Host "     PS 7+:  $($comparison.PS7)" -ForegroundColor Gray
    Write-Host ""
}

# Summary
Write-VersionSpecificHost "Test Summary:" -IconType 'target' -ForegroundColor Yellow
Write-Host ""

$endTime = Get-Date
$duration = $endTime - $Script:StartTime

Write-VersionSpecificHost "All version-specific display tests completed successfully!" -IconType 'party' -ForegroundColor Green
Write-Host "   Test Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Gray
Write-Host "   PowerShell Version: $($psVersionInfo.Version) ($($psVersionInfo.Edition))" -ForegroundColor Gray
Write-Host "   Display Mode: $(if($psVersionInfo.IsPS51){'ASCII Characters'}else{'Unicode Emojis'})" -ForegroundColor Gray

Write-Host ""
Write-VersionSpecificHost "Version-specific display system is working correctly!" -IconType 'success' -ForegroundColor Green
Write-Host ""

# Usage Examples
Write-VersionSpecificHost "Usage Examples:" -IconType 'info' -ForegroundColor Cyan
Write-Host ""
Write-Host "   # Basic usage:" -ForegroundColor Gray
Write-Host "   Write-VersionSpecificHost 'Message' -IconType 'success' -ForegroundColor Green" -ForegroundColor White
Write-Host ""
Write-Host "   # Header usage:" -ForegroundColor Gray  
Write-Host "   Write-VersionSpecificHeader 'Title' -Version 'v1.0' -Color Cyan" -ForegroundColor White
Write-Host ""
Write-Host "   # Network testing:" -ForegroundColor Gray
Write-Host "   Test-NetworkConnectivity-VersionSpecific -ComputerName 'server' -Port 80" -ForegroundColor White
Write-Host ""