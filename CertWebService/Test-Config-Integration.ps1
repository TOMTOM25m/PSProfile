#requires -Version 5.1

<#
.SYNOPSIS
    Test-Config-Integration.ps1 - Testet die Config-Integration für Excel-Pfad

.DESCRIPTION
    Überprüft ob die Config-Datei korrekt gelesen wird und Excel-Pfad/Worksheet 
    korrekt extrahiert werden.
    
.VERSION
    1.0.0
#>

$configPath = "F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"

Write-Host "🧪 Config Integration Test" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Testing config file reading..." -ForegroundColor Yellow
Write-Host "   Config Path: $configPath" -ForegroundColor Gray

# Test 1: Config file exists
if (-not (Test-Path $configPath)) {
    Write-Host "   ❌ Config file not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUTION:" -ForegroundColor Yellow
    Write-Host "1. Check if path is correct" -ForegroundColor White
    Write-Host "2. Ensure CertSurv config exists" -ForegroundColor White
    exit 1
} else {
    Write-Host "   ✅ Config file found" -ForegroundColor Green
}

# Test 2: Config file readable
try {
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "   ✅ Config file readable" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Config file read error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Excel path in config
if ($config.ExcelFilePath) {
    Write-Host "   ✅ ExcelFilePath found in config" -ForegroundColor Green
    Write-Host "     Path: $($config.ExcelFilePath)" -ForegroundColor Cyan
} else {
    Write-Host "   ❌ ExcelFilePath not found in config" -ForegroundColor Red
}

# Test 4: Worksheet name in config
if ($config.ExcelWorksheet) {
    Write-Host "   ✅ ExcelWorksheet found in config" -ForegroundColor Green
    Write-Host "     Worksheet: $($config.ExcelWorksheet)" -ForegroundColor Cyan
} else {
    Write-Host "   ❌ ExcelWorksheet not found in config" -ForegroundColor Red
}

Write-Host ""

# Test 5: Excel file exists at configured path
Write-Host "📊 Testing Excel file access..." -ForegroundColor Yellow
$excelPath = $config.ExcelFilePath

if ($excelPath) {
    if (Test-Path $excelPath) {
        Write-Host "   ✅ Excel file accessible at configured path" -ForegroundColor Green
        
        # Get file info
        $fileInfo = Get-Item $excelPath
        Write-Host "     Size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "     Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
        
    } else {
        Write-Host "   ❌ Excel file not accessible: $excelPath" -ForegroundColor Red
        Write-Host "     This might be a network share - testing network connectivity..." -ForegroundColor Yellow
        
        # Test network path
        if ($excelPath -like "\\*") {
            $serverName = $excelPath.Split('\')[2]
            Write-Host "     Network server: $serverName" -ForegroundColor Gray
            
            $pingResult = Test-Connection -ComputerName $serverName -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($pingResult) {
                Write-Host "     ✅ Network server reachable" -ForegroundColor Green
                Write-Host "     ⚠️ File might need credentials or permissions" -ForegroundColor Yellow
            } else {
                Write-Host "     ❌ Network server not reachable" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "   ❌ No Excel path configured" -ForegroundColor Red
}

Write-Host ""

# Test 6: ImportExcel module
Write-Host "📦 Testing ImportExcel module..." -ForegroundColor Yellow

if (Get-Module -ListAvailable -Name ImportExcel) {
    Write-Host "   ✅ ImportExcel module available" -ForegroundColor Green
    
    $module = Get-Module -ListAvailable -Name ImportExcel | Select-Object -First 1
    Write-Host "     Version: $($module.Version)" -ForegroundColor Gray
    
} else {
    Write-Host "   ⚠️ ImportExcel module not installed" -ForegroundColor Yellow
    Write-Host "     Will be installed automatically when needed" -ForegroundColor Gray
}

Write-Host ""

# Test 7: Test strikethrough detection
Write-Host "⚠️ Testing strikethrough detection..." -ForegroundColor Yellow

if ($config.IgnoreStrikethroughServers) {
    Write-Host "   ✅ IgnoreStrikethroughServers enabled in config" -ForegroundColor Green
    
    if ($excelPath -and (Test-Path $excelPath)) {
        try {
            # Test Excel COM availability for strikethrough detection
            $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
            $excel.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
            
            Write-Host "   ✅ Excel COM available for strikethrough detection" -ForegroundColor Green
            
        } catch {
            Write-Host "   ⚠️ Excel COM not available: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "     Strikethrough detection will use limited fallback" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ⚠️ Cannot test strikethrough - Excel file not accessible" -ForegroundColor Yellow
    }
} else {
    Write-Host "   📝 IgnoreStrikethroughServers disabled in config" -ForegroundColor Gray
    Write-Host "     All servers will be processed (including strikethrough)" -ForegroundColor Gray
}

Write-Host ""

# Test 8: Test basic Excel reading (if file accessible)
if ($excelPath -and (Test-Path $excelPath)) {
    Write-Host "📋 Testing Excel reading..." -ForegroundColor Yellow
    
    try {
        # Try to import ImportExcel
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Host "   📦 Installing ImportExcel module..." -ForegroundColor Cyan
            Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
        }
        
        Import-Module ImportExcel -Force
        
        # Test reading first few rows
        $testData = Import-Excel -Path $excelPath -WorksheetName $config.ExcelWorksheet -NoHeader -ErrorAction Stop | Select-Object -First 5
        
        Write-Host "   ✅ Excel reading successful" -ForegroundColor Green
        Write-Host "     Sample rows read: $($testData.Count)" -ForegroundColor Gray
        
        # Show sample data
        Write-Host "     Sample content from column A (P1):" -ForegroundColor Gray
        foreach ($row in $testData) {
            if ($row.P1) {
                $content = $row.P1.ToString().Trim()
                if ($content.Length -gt 0) {
                    Write-Host "       '$content'" -ForegroundColor White
                }
            }
        }
        
    } catch {
        Write-Host "   ❌ Excel reading failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎯 INTEGRATION TEST SUMMARY" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

$configValid = $config -and $config.ExcelFilePath -and $config.ExcelWorksheet
$excelAccessible = $excelPath -and (Test-Path $excelPath)
$strikethroughSupported = $config -and $config.IgnoreStrikethroughServers

if ($configValid -and $excelAccessible) {
    Write-Host "✅ Config integration ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Configuration Details:" -ForegroundColor Yellow
    Write-Host "   Config File: $configPath" -ForegroundColor White
    Write-Host "   Excel Path: $($config.ExcelFilePath)" -ForegroundColor White
    Write-Host "   Worksheet: $($config.ExcelWorksheet)" -ForegroundColor White
    Write-Host "   Strikethrough Detection: $(if($strikethroughSupported){"✅ Enabled"}else{"❌ Disabled"})" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 Ready to run Excel-based mass update:" -ForegroundColor Green
    Write-Host "   .\Excel-Update-Launcher.ps1 -Mode Analyze" -ForegroundColor Cyan
    Write-Host ""
    if ($strikethroughSupported) {
        Write-Host "⚠️ Note: Strikethrough servers will be automatically ignored" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️ Note: All servers will be processed (strikethrough detection disabled)" -ForegroundColor Yellow
    }
    
} elseif ($configValid) {
    Write-Host "⚠️ Config valid but Excel file access issues" -ForegroundColor Yellow
    Write-Host "   Check network connectivity and permissions" -ForegroundColor White
    
} else {
    Write-Host "❌ Config integration issues detected" -ForegroundColor Red
    Write-Host "   Check config file format and required fields" -ForegroundColor White
}

Write-Host ""
Write-Host "🏁 Test completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan