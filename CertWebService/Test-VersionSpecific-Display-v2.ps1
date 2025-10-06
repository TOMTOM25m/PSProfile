#requires -Version 5.1

<#
.SYNOPSIS
    Test-Script für PowerShell Version-spezifische Funktionen v2.0.0

.DESCRIPTION
    Testet das neue FL-PowerShell-VersionCompatibility-v2.psm1 Modul
    PS 5.1: ASCII-Zeichen
    PS 7.x: Emojis

.VERSION
    2.0.0
#>

# Teste das neue v2 Modul
$ModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility-v2.psm1"

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  TESTING PowerShell Version Compatibility v2.0" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Lade das Modul
try {
    if (Test-Path $ModulePath) {
        Write-Host "Loading Module: $ModulePath" -ForegroundColor Yellow
        Import-Module $ModulePath -Force -Verbose
        Write-Host "Module loaded successfully!" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Module not found at $ModulePath" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR loading module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== PowerShell Version Information ===" -ForegroundColor White

# Teste Version Detection
$versionInfo = Get-PowerShellVersionInfo
Write-Host "PowerShell Version: $($versionInfo.Version)" -ForegroundColor Gray
Write-Host "Edition: $($versionInfo.Edition)" -ForegroundColor Gray
Write-Host "Major Version: $($versionInfo.Major)" -ForegroundColor Gray
Write-Host "Is PS 5.1: $($versionInfo.IsPS51)" -ForegroundColor Gray
Write-Host "Is PS 7+: $($versionInfo.IsPS7Plus)" -ForegroundColor Gray
Write-Host "Platform: $($versionInfo.Platform)" -ForegroundColor Gray

Write-Host ""
Write-Host "=== Testing Version-Specific Display Functions ===" -ForegroundColor White

# Teste Header
Write-VersionSpecificHeader -Title "Test Header" -Version "v2.0.0" -Color Green

# Teste verschiedene Icons
$testIcons = @(
    @{ Type = 'success'; Message = 'Operation successful'; Color = 'Green' }
    @{ Type = 'error'; Message = 'Operation failed'; Color = 'Red' }
    @{ Type = 'warning'; Message = 'Warning message'; Color = 'Yellow' }
    @{ Type = 'info'; Message = 'Information message'; Color = 'Cyan' }
    @{ Type = 'rocket'; Message = 'Starting process'; Color = 'Green' }
    @{ Type = 'gear'; Message = 'Tool operation'; Color = 'Blue' }
    @{ Type = 'shield'; Message = 'Security check'; Color = 'Magenta' }
    @{ Type = 'lock'; Message = 'Secure operation'; Color = 'Red' }
    @{ Type = 'globe'; Message = 'Network operation'; Color = 'Cyan' }
    @{ Type = 'folder'; Message = 'Directory operation'; Color = 'Yellow' }
    @{ Type = 'file'; Message = 'File operation'; Color = 'Gray' }
    @{ Type = 'chart'; Message = 'Report generation'; Color = 'Green' }
    @{ Type = 'target'; Message = 'Target achieved'; Color = 'Green' }
    @{ Type = 'computer'; Message = 'Computer operation'; Color = 'Blue' }
    @{ Type = 'network'; Message = 'Network connection'; Color = 'Cyan' }
    @{ Type = 'process'; Message = 'Process running'; Color = 'Yellow' }
    @{ Type = 'clock'; Message = 'Timing operation'; Color = 'Gray' }
    @{ Type = 'party'; Message = 'Operation completed'; Color = 'Green' }
)

Write-Host ""
Write-Host "Icon Display Test (should show ASCII for PS 5.1, Emojis for PS 7+):" -ForegroundColor White

foreach ($test in $testIcons) {
    Write-VersionSpecificHost -Message $test.Message -IconType $test.Type -ForegroundColor $test.Color
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "=== Testing Compatibility Functions ===" -ForegroundColor White

# Teste Kompatibilität
$compatibility = Test-PowerShellCompatibility
Write-Host "Excel COM Available: $($compatibility.ExcelCOMAvailable)" -ForegroundColor $(if($compatibility.ExcelCOMAvailable){'Green'}else{'Red'})
Write-Host "ImportExcel Available: $($compatibility.ImportExcelAvailable)" -ForegroundColor $(if($compatibility.ImportExcelAvailable){'Green'}else{'Yellow'})
Write-Host "WMI Available: $($compatibility.WMIAvailable)" -ForegroundColor $(if($compatibility.WMIAvailable){'Green'}else{'Red'})
Write-Host "CIM Available: $($compatibility.CIMAvailable)" -ForegroundColor $(if($compatibility.CIMAvailable){'Green'}else{'Red'})
Write-Host "Modern Web Requests: $($compatibility.ModernWebRequests)" -ForegroundColor $(if($compatibility.ModernWebRequests){'Green'}else{'Yellow'})

Write-Host ""
Write-Host "=== Testing Network Connectivity Functions ===" -ForegroundColor White

# Teste Netzwerk-Konnektivität (localhost sollte immer funktionieren)
Write-Host "Testing localhost connectivity..." -ForegroundColor Yellow
$networkTest = Test-NetworkConnectivity-VersionSpecific -ComputerName "localhost"
Write-Host "Result: Success=$($networkTest.Success), Method=$($networkTest.Method), ResponseTime=$($networkTest.ResponseTime)ms" -ForegroundColor $(if($networkTest.Success){'Green'}else{'Red'})

if (-not $networkTest.Success) {
    Write-Host "Error: $($networkTest.ErrorMessage)" -ForegroundColor Red
}

# Teste einen nicht erreichbaren Host
Write-Host ""
Write-Host "Testing unreachable host..." -ForegroundColor Yellow
$failTest = Test-NetworkConnectivity-VersionSpecific -ComputerName "192.168.255.254" -TimeoutSeconds 2
Write-Host "Result: Success=$($failTest.Success), Method=$($failTest.Method)" -ForegroundColor $(if(-not $failTest.Success){'Green'}else{'Red'})

Write-Host ""
Write-Host "=== Testing PSRemoting Functions ===" -ForegroundColor White

# Teste PSRemoting (einfaches lokales Script)
Write-Host "Testing PSRemoting to localhost..." -ForegroundColor Yellow
$psRemoteTest = Invoke-PSRemoting-VersionSpecific -ComputerName "localhost" -ScriptBlock { 
    return @{
        ComputerName = $env:COMPUTERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        DateTime = Get-Date
    }
}

Write-Host "PSRemoting Result:" -ForegroundColor Yellow
Write-Host "  Success: $($psRemoteTest.Success)" -ForegroundColor $(if($psRemoteTest.Success){'Green'}else{'Red'})
Write-Host "  Method: $($psRemoteTest.Method)" -ForegroundColor Gray

if ($psRemoteTest.Success -and $psRemoteTest.Data) {
    Write-Host "  Remote Computer: $($psRemoteTest.Data.ComputerName)" -ForegroundColor Gray
    Write-Host "  Remote PS Version: $($psRemoteTest.Data.PowerShellVersion)" -ForegroundColor Gray
    Write-Host "  Remote DateTime: $($psRemoteTest.Data.DateTime)" -ForegroundColor Gray
} elseif (-not $psRemoteTest.Success) {
    Write-Host "  Error: $($psRemoteTest.ErrorMessage)" -ForegroundColor Red
}

Write-Host ""

# Finale Ausgabe
if ($versionInfo.IsPS51) {
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "  [OK] All PS 5.1 tests completed" -ForegroundColor Green
    Write-Host "  [INFO] ASCII icons displayed" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Green
} elseif ($versionInfo.IsPS7Plus) {
    Write-Host "All PS 7+ tests completed successfully!" -ForegroundColor Green
    Write-Host "Emoji icons displayed" -ForegroundColor Cyan
    Write-Host "Modern features tested" -ForegroundColor Magenta
} else {
    Write-Host "Tests completed for PowerShell $($versionInfo.Version)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray