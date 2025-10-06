#requires -Version 5.1

<#
.SYNOPSIS
    PowerShell Version Compatibility Test Script v1.0.0

.DESCRIPTION
    Testet das FL-PowerShell-VersionCompatibility Modul auf verschiedenen PowerShell Versionen:
    - Versionserkennung
    - Excel Import (COM vs ImportExcel)
    - Web Requests (Parameter-Unterschiede)
    - System Information (WMI vs CIM)
    
.VERSION
    1.0.0

.AUTHOR
    Field Level Automation
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TestExcelPath = "C:\Temp\TestData.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$TestUrl = "https://httpbin.org/get",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateTestExcel,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

$Script:Version = "v1.0.0"
$Script:StartTime = Get-Date

Write-Host "🧪 PowerShell Version Compatibility Test Suite" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Version: $Script:Version" -ForegroundColor Gray
Write-Host "   Start: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host ""

# Test 1: Module Loading
Write-Host "📦 Test 1: Module Loading" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow

try {
    $compatibilityModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility.psm1"
    
    if (-not (Test-Path $compatibilityModulePath)) {
        throw "Compatibility module not found at: $compatibilityModulePath"
    }
    
    Import-Module $compatibilityModulePath -Force
    Write-Host "✅ Module loaded successfully" -ForegroundColor Green
    
    # Test PowerShell version detection
    $psVersionInfo = Get-PowerShellVersionInfo
    Write-Host "   PowerShell Version: $($psVersionInfo.Version)" -ForegroundColor Cyan
    Write-Host "   Edition: $($psVersionInfo.Edition)" -ForegroundColor Cyan
    Write-Host "   Platform: $($psVersionInfo.Platform)" -ForegroundColor Cyan
    Write-Host "   Core Features: $($psVersionInfo.IsCoreOrNewer)" -ForegroundColor Cyan
    Write-Host "   Desktop Features: $($psVersionInfo.IsDesktopOnly)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Module loading failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Compatibility Testing
Write-Host "🔍 Test 2: Compatibility Testing" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow

try {
    $compatResult = Test-PowerShellCompatibility
    
    Write-Host "   Excel COM Support: $($compatResult.ExcelCOMAvailable)" -ForegroundColor $(if($compatResult.ExcelCOMAvailable){"Green"}else{"Red"})
    Write-Host "   ImportExcel Available: $($compatResult.ImportExcelAvailable)" -ForegroundColor $(if($compatResult.ImportExcelAvailable){"Green"}else{"Red"})
    Write-Host "   WMI Available: $($compatResult.WMIAvailable)" -ForegroundColor $(if($compatResult.WMIAvailable){"Green"}else{"Red"})
    Write-Host "   CIM Available: $($compatResult.CIMAvailable)" -ForegroundColor $(if($compatResult.CIMAvailable){"Green"}else{"Red"})
    Write-Host "   Modern Web Requests: $($compatResult.ModernWebRequests)" -ForegroundColor $(if($compatResult.ModernWebRequests){"Green"}else{"Red"})
    
    Write-Host "✅ Compatibility testing completed" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Compatibility testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Excel Test Data Creation (if requested)
if ($CreateTestExcel) {
    Write-Host "📊 Test 3: Excel Test Data Creation" -ForegroundColor Yellow
    Write-Host "===================================" -ForegroundColor Yellow
    
    try {
        # Create test Excel data
        $testData = @(
            [PSCustomObject]@{ ServerName = "server01.test.local"; Domain = "test.local"; Status = "Active" },
            [PSCustomObject]@{ ServerName = "server02.test.local"; Domain = "test.local"; Status = "Active" },
            [PSCustomObject]@{ ServerName = "server03.test.local"; Domain = "test.local"; Status = "Inactive" },
            [PSCustomObject]@{ ServerName = "webserver01.test.local"; Domain = "test.local"; Status = "Active" }
        )
        
        # Ensure directory exists
        $testDir = Split-Path $TestExcelPath -Parent
        if (-not (Test-Path $testDir)) {
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
        }
        
        # Try to export using version-specific method
        if (Get-Command "Export-ExcelData-VersionSpecific" -ErrorAction SilentlyContinue) {
            $exportResult = Export-ExcelData-VersionSpecific -Data $testData -ExcelPath $TestExcelPath -WorksheetName "TestServers"
            if ($exportResult.Success) {
                Write-Host "✅ Test Excel file created: $TestExcelPath ($($exportResult.Method))" -ForegroundColor Green
            } else {
                throw "Excel export failed: $($exportResult.ErrorMessage)"
            }
        } else {
            # Fallback method
            $testData | Export-Csv -Path ($TestExcelPath -replace '\.xlsx$', '.csv') -NoTypeInformation
            Write-Host "✅ Test CSV file created (Excel not available): $($TestExcelPath -replace '\.xlsx$', '.csv')" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "❌ Excel test data creation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Test 4: Excel Import Testing
Write-Host "📈 Test 4: Excel Import Testing" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow

if (Test-Path $TestExcelPath) {
    try {
        $importResult = Import-ExcelData-VersionSpecific -ExcelPath $TestExcelPath -WorksheetName "TestServers" -IncludeStrikethrough
        
        if ($importResult.Success) {
            Write-Host "✅ Excel import successful using: $($importResult.Method)" -ForegroundColor Green
            Write-Host "   Imported rows: $($importResult.Data.Count)" -ForegroundColor Cyan
            Write-Host "   Strikethrough servers: $($importResult.StrikethroughServers.Count)" -ForegroundColor Cyan
            
            if ($Verbose -and $importResult.Data.Count -gt 0) {
                Write-Host "   Sample data:" -ForegroundColor Gray
                $importResult.Data | Select-Object -First 2 | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
            }
        } else {
            throw "Excel import failed: $($importResult.ErrorMessage)"
        }
        
    } catch {
        Write-Host "❌ Excel import testing failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️ Test Excel file not found: $TestExcelPath" -ForegroundColor Yellow
    Write-Host "   Use -CreateTestExcel to generate test data" -ForegroundColor Gray
}

Write-Host ""

# Test 5: Web Request Testing
Write-Host "🌐 Test 5: Web Request Testing" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow

try {
    Write-Host "   Testing URL: $TestUrl" -ForegroundColor Gray
    
    $startTime = Get-Date
    $response = Invoke-WebRequest-VersionSpecific -Uri $TestUrl -TimeoutSec 10 -UseBasicParsing
    $duration = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
    
    Write-Host "✅ Web request successful" -ForegroundColor Green
    Write-Host "   Response time: ${duration}ms" -ForegroundColor Cyan
    Write-Host "   Status code: $($response.StatusCode)" -ForegroundColor Cyan
    Write-Host "   Content length: $($response.Content.Length) bytes" -ForegroundColor Cyan
    
    if ($Verbose) {
        Write-Host "   Response headers:" -ForegroundColor Gray
        $response.Headers.GetEnumerator() | Select-Object -First 5 | ForEach-Object {
            Write-Host "     $($_.Key): $($_.Value)" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "❌ Web request testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: System Information Testing
Write-Host "💻 Test 6: System Information Testing" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

try {
    $systemInfo = Get-SystemInfo-VersionSpecific -ComputerName "localhost"
    
    if ($systemInfo) {
        Write-Host "✅ System information retrieved successfully" -ForegroundColor Green
        Write-Host "   Computer: $($systemInfo.CSName)" -ForegroundColor Cyan
        Write-Host "   OS: $($systemInfo.Caption)" -ForegroundColor Cyan
        Write-Host "   Version: $($systemInfo.Version)" -ForegroundColor Cyan
        Write-Host "   Architecture: $($systemInfo.OSArchitecture)" -ForegroundColor Cyan
    } else {
        throw "No system information returned"
    }
    
} catch {
    Write-Host "❌ System information testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test Summary
Write-Host "📋 Test Summary" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow

$endTime = Get-Date
$duration = $endTime - $Script:StartTime

Write-Host "   Test Duration: $([math]::Round($duration.TotalSeconds, 1)) seconds" -ForegroundColor Gray
Write-Host "   PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "   Module Path: $(Split-Path $compatibilityModulePath -Leaf)" -ForegroundColor Gray

Write-Host ""
Write-Host "🎯 Testing completed! Check results above for any failures." -ForegroundColor Green
Write-Host "   Use -Verbose for detailed output" -ForegroundColor Gray
Write-Host "   Use -CreateTestExcel to generate test Excel file" -ForegroundColor Gray
Write-Host ""