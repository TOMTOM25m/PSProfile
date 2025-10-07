<#
.SYNOPSIS
    PowerShell-Regelwerk Universal v10.0.3 - Implementation Guide
    Smart CertWebService Update Deployment System

.DESCRIPTION
    Regelwerk für universelle PowerShell-Kompatibilität zwischen Version 5.1 und 7.x
    mit automatischer Funktionsauswahl und optimaler Performance.
    
    Implementiert § 15-17 des PowerShell-Regelwerks Universal v10.0.3

.NOTES
    Author: PowerShell Team
    Version: 10.0.3
    Date: 07.10.2025
    
    REGELWERK PARAGRAPHEN:
    § 15 PowerShell Version Compatibility Management
    § 16 Automated Update Deployment
    § 17 Excel Integration Standards
#>

# ==========================================
# § 15 PowerShell Version Compatibility Management
# ==========================================

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  POWERSHELL-REGELWERK UNIVERSAL v10.0.3" -ForegroundColor Cyan
Write-Host "  Smart Version Detection & Compatibility Framework" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# § 15.1 Version Detection
$PSVersionInfo = @{
    Version = $PSVersionTable.PSVersion.ToString()
    Edition = $PSVersionTable.PSEdition
    Platform = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { 'Win32NT' }
    IsCore = $PSVersionTable.PSEdition -eq 'Core'
    IsWindows = ($PSVersionTable.Platform -eq 'Win32NT') -or ($PSVersionTable.PSVersion.Major -le 5)
    IsPowerShell7 = $PSVersionTable.PSVersion.Major -ge 7
    IsPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5
}

Write-Host "§ 15.1 PowerShell Version Detection:" -ForegroundColor Yellow
Write-Host "  Version: $($PSVersionInfo.Version)" -ForegroundColor White
Write-Host "  Edition: $($PSVersionInfo.Edition)" -ForegroundColor White
Write-Host "  Platform: $($PSVersionInfo.Platform)" -ForegroundColor White
Write-Host "  Is Core: $($PSVersionInfo.IsCore)" -ForegroundColor White
Write-Host "  Is Windows: $($PSVersionInfo.IsWindows)" -ForegroundColor White
Write-Host ""

# § 15.2 Capability Detection
$Capabilities = @{
    TimeoutSec = $PSVersionInfo.IsCore
    ExcelCOM = $PSVersionInfo.IsWindows
    CrossPlatform = $PSVersionInfo.IsCore
    ISE = (-not $PSVersionInfo.IsCore)
    Jobs = $true
    Remoting = $true
    CIM = $PSVersionInfo.IsWindows
    ModernSyntax = $PSVersionInfo.IsCore
}

Write-Host "§ 15.2 Capability Matrix:" -ForegroundColor Yellow
foreach ($cap in $Capabilities.GetEnumerator()) {
    $color = if ($cap.Value) { 'Green' } else { 'Red' }
    Write-Host "  $($cap.Key): $($cap.Value)" -ForegroundColor $color
}
Write-Host ""

# § 15.3 Smart Configuration
$SmartConfig = @{
    MaxConcurrentJobs = if ($PSVersionInfo.IsCore) { 10 } else { 5 }
    DefaultTimeout = if ($PSVersionInfo.IsCore) { 30 } else { 60 }
    UseAdvancedFeatures = $PSVersionInfo.IsCore
    ExcelCompatible = $PSVersionInfo.IsWindows
    RecommendedDeployment = if ($PSVersionInfo.IsCore) { "High-Performance" } else { "Stable-Compatible" }
}

Write-Host "§ 15.3 Smart Configuration:" -ForegroundColor Yellow
Write-Host "  Max Concurrent Jobs: $($SmartConfig.MaxConcurrentJobs)" -ForegroundColor White
Write-Host "  Default Timeout: $($SmartConfig.DefaultTimeout)s" -ForegroundColor White
Write-Host "  Advanced Features: $($SmartConfig.UseAdvancedFeatures)" -ForegroundColor White
Write-Host "  Excel Compatible: $($SmartConfig.ExcelCompatible)" -ForegroundColor White
Write-Host "  Recommended Mode: $($SmartConfig.RecommendedDeployment)" -ForegroundColor White
Write-Host ""

# ==========================================
# § 16 Automated Update Deployment
# ==========================================

Write-Host "§ 16 Automated Update Deployment Framework:" -ForegroundColor Yellow

# § 16.1 Universal Web Request Function
function Invoke-SmartWebRequest {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 30,
        [hashtable]$Headers = @{},
        [string]$Method = 'GET'
    )
    
    if ($Capabilities.TimeoutSec) {
        # PowerShell 7.x mit TimeoutSec Parameter
        return Invoke-WebRequest -Uri $Uri -TimeoutSec $TimeoutSeconds -Headers $Headers -Method $Method
    } else {
        # PowerShell 5.1 ohne TimeoutSec Parameter  
        return Invoke-WebRequest -Uri $Uri -Headers $Headers -Method $Method
    }
}

# § 16.2 Universal Connection Test
function Test-SmartConnection {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutSeconds = 10
    )
    
    if ($PSVersionInfo.IsCore) {
        # PowerShell 7.x - Test-NetConnection
        try {
            $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
            return $result
        } catch {
            return $false
        }
    } else {
        # PowerShell 5.1 - TcpClient Fallback
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
            
            if ($wait) {
                try {
                    $tcpClient.EndConnect($connect)
                    $result = $true
                } catch {
                    $result = $false
                }
            } else {
                $result = $false
            }
            
            $tcpClient.Close()
            return $result
        } catch {
            return $false
        }
    }
}

# § 16.3 Smart Job Management  
function Start-SmartJob {
    param(
        [scriptblock]$ScriptBlock,
        [array]$ArgumentList = @(),
        [string]$Name = "SmartJob"
    )
    
    if ($PSVersionInfo.IsCore) {
        # PowerShell 7.x - Moderne Job Syntax
        return Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Name $Name
    } else {
        # PowerShell 5.1 - Klassische Job Syntax
        return Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Name $Name
    }
}

Write-Host "  ✓ Invoke-SmartWebRequest (PS $($PSVersionInfo.Version) optimized)" -ForegroundColor Green
Write-Host "  ✓ Test-SmartConnection (Platform: $($PSVersionInfo.Platform))" -ForegroundColor Green  
Write-Host "  ✓ Start-SmartJob (Max concurrent: $($SmartConfig.MaxConcurrentJobs))" -ForegroundColor Green
Write-Host ""

# ==========================================
# § 17 Excel Integration Standards
# ==========================================

Write-Host "§ 17 Excel Integration Standards:" -ForegroundColor Yellow

if ($Capabilities.ExcelCOM) {
    Write-Host "  ✓ Excel COM Objects Available" -ForegroundColor Green
    Write-Host "  ✓ Server List Integration Ready" -ForegroundColor Green
    
    # § 17.1 Excel Connection Test
    function New-SmartExcelConnection {
        param([string]$ExcelPath)
        
        try {
            $Excel = New-Object -ComObject Excel.Application
            $Excel.Visible = $false
            $Excel.DisplayAlerts = $false
            
            return @{
                Excel = $Excel
                Success = $true
                Error = $null
            }
        } catch {
            return @{
                Excel = $null
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-Host "  ✓ New-SmartExcelConnection Available" -ForegroundColor Green
} else {
    Write-Host "  ✗ Excel COM Objects Not Available (Platform: $($PSVersionInfo.Platform))" -ForegroundColor Red
    Write-Host "  ⚠ Alternative server discovery methods required" -ForegroundColor Yellow
}

Write-Host ""

# ==========================================
# § 18 Practical Implementation Examples
# ==========================================

Write-Host "§ 18 Practical Implementation Examples:" -ForegroundColor Yellow
Write-Host ""

Write-Host "# PowerShell Version-Specific Script Selection:" -ForegroundColor Cyan
if ($PSVersionInfo.IsCore) {
    Write-Host "  → Use: Update-CertWebService-Modern.ps1 (High Performance)" -ForegroundColor Green
    Write-Host "  → Features: Parallel processing, TimeoutSec, Cross-platform" -ForegroundColor White
} else {
    Write-Host "  → Use: Update-CertWebService-Compatible.ps1 (Stable)" -ForegroundColor Green  
    Write-Host "  → Features: Excel COM, Windows-optimized, Legacy support" -ForegroundColor White
}
Write-Host ""

Write-Host "# Recommended Update Command:" -ForegroundColor Cyan
if ($PSVersionInfo.IsCore) {
    Write-Host "  pwsh .\Update-CertWebService-Modern.ps1 -Filter 'UVW' -MaxConcurrent 10" -ForegroundColor Yellow
} else {
    Write-Host "  powershell .\Update-CertWebService-Compatible.ps1 -Filter 'UVW' -MaxConcurrent 5" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "# Excel Integration Example:" -ForegroundColor Cyan
if ($Capabilities.ExcelCOM) {
    Write-Host "  `$servers = Get-ServersFromExcel -Path '\\server\Serverliste2025.xlsx'" -ForegroundColor Yellow
    Write-Host "  `$servers | Where-Object Block -like '*UVW*'" -ForegroundColor Yellow
} else {
    Write-Host "  # Excel not available - use CSV or manual server list" -ForegroundColor Red
    Write-Host "  `$servers = Get-Content servers.txt" -ForegroundColor Yellow
}
Write-Host ""

# ==========================================
# § 19 Testing Framework
# ==========================================

Write-Host "§ 19 Quick Compatibility Test:" -ForegroundColor Yellow

# Test Web Request
try {
    Write-Host "  Testing Web Request..." -NoNewline
    $testResult = Invoke-SmartWebRequest -Uri "https://www.google.com" -TimeoutSeconds 5
    Write-Host " ✓ PASSED" -ForegroundColor Green
} catch {
    Write-Host " ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Connection  
try {
    Write-Host "  Testing Connection..." -NoNewline
    $testResult = Test-SmartConnection -ComputerName "www.google.com" -Port 443 -TimeoutSeconds 5
    if ($testResult) {
        Write-Host " ✓ PASSED" -ForegroundColor Green
    } else {
        Write-Host " ✗ FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host " ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Excel (if available)
if ($Capabilities.ExcelCOM) {
    try {
        Write-Host "  Testing Excel COM..." -NoNewline
        $excelTest = New-SmartExcelConnection
        if ($excelTest.Success) {
            $excelTest.Excel.Quit()
            Write-Host " ✓ PASSED" -ForegroundColor Green
        } else {
            Write-Host " ✗ FAILED: $($excelTest.Error)" -ForegroundColor Red
        }
    } catch {
        Write-Host " ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# ==========================================
# SUMMARY & RECOMMENDATIONS  
# ==========================================

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  REGELWERK IMPLEMENTATION SUMMARY" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Current Environment:" -ForegroundColor Yellow
Write-Host "  PowerShell $($PSVersionInfo.Version) ($($PSVersionInfo.Edition))" -ForegroundColor White
Write-Host "  Platform: $($PSVersionInfo.Platform)" -ForegroundColor White
Write-Host "  Deployment Mode: $($SmartConfig.RecommendedDeployment)" -ForegroundColor White
Write-Host ""

Write-Host "Smart Recommendations:" -ForegroundColor Yellow
if ($PSVersionInfo.IsCore) {
    Write-Host "  ✓ Use modern PowerShell 7.x features" -ForegroundColor Green
    Write-Host "  ✓ Enable parallel processing (up to $($SmartConfig.MaxConcurrentJobs) jobs)" -ForegroundColor Green
    Write-Host "  ✓ Utilize TimeoutSec parameters" -ForegroundColor Green
} else {
    Write-Host "  ✓ Optimize for PowerShell 5.1 compatibility" -ForegroundColor Green
    Write-Host "  ✓ Use Excel COM integration" -ForegroundColor Green
    Write-Host "  ✓ Limit concurrent jobs to $($SmartConfig.MaxConcurrentJobs)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Choose appropriate update script based on PowerShell version" -ForegroundColor White
Write-Host "  2. Configure server filters and deployment parameters" -ForegroundColor White  
Write-Host "  3. Test deployment with -TestOnly flag first" -ForegroundColor White
Write-Host "  4. Monitor concurrent job performance" -ForegroundColor White
Write-Host ""

Write-Host "PowerShell-Regelwerk Universal v10.0.3 implementation complete!" -ForegroundColor Green
Write-Host "Ready for smart CertWebService deployment across mixed environments." -ForegroundColor Green