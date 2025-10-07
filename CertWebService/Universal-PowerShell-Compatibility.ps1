<#
.SYNOPSIS
    Universal PowerShell Compatibility Framework v1.0.0
    Automatische Erkennung und Kompatibilität zwischen PowerShell 5.1 und 7.x

.DESCRIPTION
    Dieses Framework erkennt automatisch die PowerShell-Version und wählt die
    entsprechenden Funktionen/Parameter für optimale Kompatibilität.
    
    Implementiert gemäß PowerShell-Regelwerk Universal v10.0.3
    
    § 15 PowerShell Version Compatibility Management
    § 15.1 Automatische Versionserkennung
    § 15.2 Version-spezifische Funktionsauswahl
    § 15.3 Parameter-Kompatibilität
    § 15.4 Cross-Version Testing

.PARAMETER TestMode
    Aktiviert Testmodus für Kompatibilitätsprüfung

.EXAMPLE
    .\Universal-PowerShell-Compatibility.ps1 -TestMode
    
.NOTES
    Author: PowerShell Team
    Version: 1.0.0
    Date: 07.10.2025
    
    PowerShell 5.1 Features:
    - .NET Framework 4.x
    - Windows PowerShell ISE
    - COM Objects (Excel, etc.)
    
    PowerShell 7.x Features:
    - .NET Core/5+
    - Cross-Platform
    - Improved Performance
    - New Parameters (TimeoutSec, etc.)
#>

param(
    [switch]$TestMode = $false
)

$ErrorActionPreference = "Stop"

# ==========================================
# § 15.1 PowerShell Version Detection
# ==========================================

function New-PowerShellCompatibility {
    $psCompat = @{
        Version = $PSVersionTable.PSVersion.ToString()
        Edition = $PSVersionTable.PSEdition
        Platform = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { 'Win32NT' }
        IsCore = $PSVersionTable.PSEdition -eq 'Core'
        IsWindows = ($PSVersionTable.Platform -eq 'Win32NT') -or ($PSVersionTable.PSVersion.Major -le 5)
    }
    
    # Detect capabilities based on version
    $psCompat.Capabilities = @{
        'TimeoutSec' = $psCompat.IsCore
        'ExcelCOM' = $psCompat.IsWindows
        'CrossPlatform' = $psCompat.IsCore
        'ISE' = (-not $psCompat.IsCore)
        'Jobs' = $true
        'Remoting' = $true
        'CIM' = $psCompat.IsWindows
    }
    
    # Add method-like function
    $psCompat.GetCompatibilityInfo = {
        return "PowerShell $($psCompat.Version) ($($psCompat.Edition)) on $($psCompat.Platform)"
    }
    
    return $psCompat
}

# ==========================================
# § 15.2 Universal Functions
# ==========================================

function Invoke-UniversalWebRequest {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 30,
        [hashtable]$Headers = @{},
        [string]$Method = 'GET'
    )
    
    $PSCompat = [PowerShellCompatibility]::new()
    
    if ($PSCompat.Capabilities['TimeoutSec']) {
        # PowerShell 7.x mit TimeoutSec Parameter
        return Invoke-WebRequest -Uri $Uri -TimeoutSec $TimeoutSeconds -Headers $Headers -Method $Method
    } else {
        # PowerShell 5.1 ohne TimeoutSec Parameter
        return Invoke-WebRequest -Uri $Uri -Headers $Headers -Method $Method
    }
}

function New-UniversalExcelConnection {
    param(
        [string]$ExcelPath
    )
    
    $PSCompat = [PowerShellCompatibility]::new()
    
    if (-not $PSCompat.Capabilities['ExcelCOM']) {
        throw "Excel COM Objects are not available on this platform ($($PSCompat.Platform))"
    }
    
    try {
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        
        return @{
            Excel = $Excel
            Workbook = $Workbook
            Success = $true
        }
    } catch {
        return @{
            Excel = $null
            Workbook = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Start-UniversalJob {
    param(
        [scriptblock]$ScriptBlock,
        [hashtable]$ArgumentList = @{},
        [string]$Name = "UniversalJob"
    )
    
    $PSCompat = [PowerShellCompatibility]::new()
    
    if ($PSCompat.IsCore) {
        # PowerShell 7.x - Moderne Job Syntax
        return Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList.Values -Name $Name
    } else {
        # PowerShell 5.1 - Klassische Job Syntax
        return Start-Job -ScriptBlock $ScriptBlock -ArgumentList @($ArgumentList.Values) -Name $Name
    }
}

function Test-UniversalConnection {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutSeconds = 10
    )
    
    $PSCompat = [PowerShellCompatibility]::new()
    
    if ($PSCompat.IsCore) {
        # PowerShell 7.x - Test-NetConnection mit besserer Performance
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

# ==========================================
# § 15.3 Configuration Management
# ==========================================

function Get-UniversalConfiguration {
    $PSCompat = [PowerShellCompatibility]::new()
    
    $config = @{
        'MaxConcurrentJobs' = if ($PSCompat.IsCore) { 10 } else { 5 }
        'DefaultTimeout' = if ($PSCompat.IsCore) { 30 } else { 60 }
        'UseModernSyntax' = $PSCompat.IsCore
        'PlatformSpecific' = @{
            'Excel' = $PSCompat.Capabilities['ExcelCOM']
            'CrossPlatform' = $PSCompat.Capabilities['CrossPlatform']
            'ISE' = $PSCompat.Capabilities['ISE']
        }
    }
    
    return $config
}

# ==========================================
# § 15.4 Testing Functions
# ==========================================

function Test-PowerShellCompatibility {
    param(
        [switch]$Detailed = $false
    )
    
    $PSCompat = [PowerShellCompatibility]::new()
    $config = Get-UniversalConfiguration
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  POWERSHELL COMPATIBILITY CHECK" -ForegroundColor Cyan
    Write-Host "  v1.0.0 | $(Get-Date -Format 'dd.MM.yyyy HH:mm')" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Version Information:" -ForegroundColor Yellow
    Write-Host "  PowerShell: $($PSCompat.Version)" -ForegroundColor White
    Write-Host "  Edition: $($PSCompat.Edition)" -ForegroundColor White
    Write-Host "  Platform: $($PSCompat.Platform)" -ForegroundColor White
    Write-Host "  Is Core: $($PSCompat.IsCore)" -ForegroundColor White
    Write-Host "  Is Windows: $($PSCompat.IsWindows)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Capabilities:" -ForegroundColor Yellow
    foreach ($cap in $PSCompat.Capabilities.GetEnumerator()) {
        $color = if ($cap.Value) { 'Green' } else { 'Red' }
        Write-Host "  $($cap.Key): $($cap.Value)" -ForegroundColor $color
    }
    Write-Host ""
    
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Max Concurrent Jobs: $($config.MaxConcurrentJobs)" -ForegroundColor White
    Write-Host "  Default Timeout: $($config.DefaultTimeout)s" -ForegroundColor White
    Write-Host "  Modern Syntax: $($config.UseModernSyntax)" -ForegroundColor White
    Write-Host ""
    
    if ($Detailed) {
        Write-Host "Detailed Tests:" -ForegroundColor Yellow
        
        # Test Web Request
        try {
            $testResult = Invoke-UniversalWebRequest -Uri "http://www.google.com" -TimeoutSeconds 5
            Write-Host "  Web Request Test: PASSED" -ForegroundColor Green
        } catch {
            Write-Host "  Web Request Test: FAILED - $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test Connection
        try {
            $testResult = Test-UniversalConnection -ComputerName "www.google.com" -Port 80 -TimeoutSeconds 5
            Write-Host "  Connection Test: $(if($testResult){'PASSED'}else{'FAILED'})" -ForegroundColor $(if($testResult){'Green'}else{'Red'})
        } catch {
            Write-Host "  Connection Test: FAILED - $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
    }
    
    return $PSCompat
}

# ==========================================
# § 15.5 Main Execution
# ==========================================

if ($TestMode) {
    Test-PowerShellCompatibility -Detailed
} else {
    # Export functions for use in other scripts
    Write-Host "Universal PowerShell Compatibility Framework loaded" -ForegroundColor Green
    Write-Host "Available Functions:" -ForegroundColor Yellow
    Write-Host "  - Invoke-UniversalWebRequest" -ForegroundColor White
    Write-Host "  - New-UniversalExcelConnection" -ForegroundColor White
    Write-Host "  - Start-UniversalJob" -ForegroundColor White
    Write-Host "  - Test-UniversalConnection" -ForegroundColor White
    Write-Host "  - Get-UniversalConfiguration" -ForegroundColor White
    Write-Host "  - Test-PowerShellCompatibility" -ForegroundColor White
}