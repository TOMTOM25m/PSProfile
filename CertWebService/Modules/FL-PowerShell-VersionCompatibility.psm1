#requires -Version 5.1

<#
.SYNOPSIS
    PowerShell Version Detection and Compatibility Module v1.0.0

.DESCRIPTION
    Zentrale Erkennung von PowerShell-Versionen und Bereitstellung
    von versionsspezifischen Funktionen für das CertWebService-System.
    
    Unterstützt:
    - PowerShell 5.1 (Windows PowerShell)
    - PowerShell 7.x (PowerShell Core)
    
.VERSION
    1.0.0

.RULEBOOK
    v10.0.0
#>

# Global PowerShell Version Information
$Global:PSVersionInfo = @{
    Version = $PSVersionTable.PSVersion
    Major = $PSVersionTable.PSVersion.Major
    Minor = $PSVersionTable.PSVersion.Minor
    Edition = $PSVersionTable.PSEdition
    IsPS5 = ($PSVersionTable.PSVersion.Major -eq 5)
    IsPS51 = ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1)
    IsPS7Plus = ($PSVersionTable.PSVersion.Major -ge 7)
    IsWindows = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }
    IsCore = ($PSVersionTable.PSEdition -eq 'Core')
    IsDesktop = ($PSVersionTable.PSEdition -eq 'Desktop')
    Platform = if ($PSVersionTable.PSVersion.Major -ge 6) { $PSVersionTable.Platform } else { 'Win32NT' }
    OS = if ($PSVersionTable.PSVersion.Major -ge 6) { $PSVersionTable.OS } else { 'Windows' }
    IsCoreOrNewer = ($PSVersionTable.PSVersion.Major -ge 6)
    IsDesktopOnly = ($PSVersionTable.PSVersion.Major -eq 5)
    HasModernFeatures = ($PSVersionTable.PSVersion.Major -ge 7)
    SupportsClasses = ($PSVersionTable.PSVersion.Major -ge 5)
    SupportsRestMethod = $true
    SupportsInvokeWebRequest = $true
}

#region Version Detection Functions

function Get-PowerShellVersionInfo {
    <#
    .SYNOPSIS
        Gibt detaillierte PowerShell-Versionsinformationen zurück
    #>
    return $Global:PSVersionInfo
}

function Test-PowerShellCompatibility {
    <#
    .SYNOPSIS
        Prüft Kompatibilität für spezifische Features
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("ExcelCOM", "ImportExcel", "Invoke-WebRequest", "PSRemoting", "WMI", "CIM")]
        [string]$Feature
    )
    
    switch ($Feature) {
        "ExcelCOM" {
            # Excel COM funktioniert nur unter Windows mit Excel installiert
            return ($Global:PSVersionInfo.IsWindows -and (Test-ExcelCOMAvailability))
        }
        "ImportExcel" {
            # ImportExcel Modul funktioniert in allen PS Versionen
            return $true
        }
        "Invoke-WebRequest" {
            # Invoke-WebRequest hat unterschiedliche Parameter in PS5 vs PS7
            return $true
        }
        "PSRemoting" {
            # PSRemoting funktioniert in allen Versionen, aber mit unterschiedlichen Features
            return $true
        }
        "WMI" {
            # WMI/Get-WmiObject vs Get-CimInstance
            return $Global:PSVersionInfo.IsWindows
        }
        "CIM" {
            # CIM funktioniert in PS3+ 
            return ($Global:PSVersionInfo.Major -ge 3)
        }
        default {
            return $false
        }
    }
}

function Test-ExcelCOMAvailability {
    <#
    .SYNOPSIS
        Testet ob Excel COM Objects verfügbar sind
    #>
    try {
        $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
        $excel.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        return $true
    } catch {
        return $false
    }
}

#endregion

#region Version-Specific Excel Functions

function Import-ExcelData-VersionSpecific {
    <#
    .SYNOPSIS
        Importiert Excel-Daten mit der optimalen Methode für die PS-Version
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeStrikethrough,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseHeaders
    )
    
    $result = @{
        Data = @()
        StrikethroughServers = @()
        Method = ""
        Success = $false
        ErrorMessage = ""
    }
    
    try {
        # Strategie 1: Excel COM wenn verfügbar (beste Formatierungs-Unterstützung)
        if (Test-PowerShellCompatibility -Feature "ExcelCOM" -and $IncludeStrikethrough) {
            Write-Host "   📊 Using Excel COM for full formatting support..." -ForegroundColor Cyan
            $result = Import-ExcelData-COM -ExcelPath $ExcelPath -WorksheetName $WorksheetName -IncludeStrikethrough:$IncludeStrikethrough
            $result.Method = "Excel COM"
            return $result
        }
        
        # Strategie 2: ImportExcel Modul (funktioniert überall, begrenzte Formatierung)
        Write-Host "   📦 Using ImportExcel module..." -ForegroundColor Cyan
        $result = Import-ExcelData-ImportExcel -ExcelPath $ExcelPath -WorksheetName $WorksheetName -UseHeaders:$UseHeaders
        $result.Method = "ImportExcel Module"
        return $result
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Host "   ❌ Excel import failed: $($_.Exception.Message)" -ForegroundColor Red
        return $result
    }
}

function Import-ExcelData-COM {
    <#
    .SYNOPSIS
        Excel-Import via COM Objects (nur Windows + Excel)
    #>
    param(
        [string]$ExcelPath,
        [string]$WorksheetName,
        [switch]$IncludeStrikethrough
    )
    
    $result = @{
        Data = @()
        StrikethroughServers = @()
        Success = $false
    }
    
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        $workbook = $excel.Workbooks.Open($ExcelPath)
        $worksheet = $workbook.Worksheets.Item($WorksheetName)
        $usedRange = $worksheet.UsedRange
        
        $data = @()
        $strikethroughServers = @()
        
        for ($row = 1; $row -le $usedRange.Rows.Count; $row++) {
            $cell = $worksheet.Cells.Item($row, 1)
            $cellValue = if ($cell.Value2) { $cell.Value2.ToString().Trim() } else { "" }
            
            if ([string]::IsNullOrWhiteSpace($cellValue)) { continue }
            
            # Strikethrough-Erkennung
            if ($IncludeStrikethrough -and $cell.Font.Strikethrough) {
                $strikethroughServers += $cellValue
                continue  # Skip strikethrough entries
            }
            
            $data += @{
                P1 = $cellValue
                Row = $row
                IsStrikethrough = [bool]$cell.Font.Strikethrough
            }
        }
        
        $workbook.Close($false)
        $excel.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        
        $result.Data = $data
        $result.StrikethroughServers = $strikethroughServers
        $result.Success = $true
        
    } catch {
        throw $_
    }
    
    return $result
}

function Import-ExcelData-ImportExcel {
    <#
    .SYNOPSIS
        Excel-Import via ImportExcel Modul (plattformunabhängig)
    #>
    param(
        [string]$ExcelPath,
        [string]$WorksheetName,
        [switch]$UseHeaders
    )
    
    $result = @{
        Data = @()
        StrikethroughServers = @()
        Success = $false
    }
    
    try {
        # ImportExcel Modul installieren/importieren
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Host "   📦 Installing ImportExcel module..." -ForegroundColor Yellow
            Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
        }
        
        Import-Module ImportExcel -Force
        
        # Daten importieren
        if ($UseHeaders) {
            $data = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName
        } else {
            $data = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -NoHeader
        }
        
        $result.Data = $data
        $result.StrikethroughServers = @()  # ImportExcel kann keine Strikethrough erkennen
        $result.Success = $true
        
    } catch {
        throw $_
    }
    
    return $result
}

#endregion

#region Version-Specific Web Request Functions

function Invoke-WebRequest-VersionSpecific {
    <#
    .SYNOPSIS
        Führt Web-Requests mit versionsspezifischen Parametern aus
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSec = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseBasicParsing
    )
    
    try {
        if ($Global:PSVersionInfo.IsPS7Plus) {
            # PowerShell 7+ unterstützt erweiterte Parameter
            $params = @{
                Uri = $Uri
                TimeoutSec = $TimeoutSec
                ErrorAction = 'Stop'
            }
            
            if ($UseBasicParsing) {
                # In PS7+ ist UseBasicParsing standardmäßig aktiviert
                # Aber wir können es explizit setzen für Kompatibilität
            }
            
            return Invoke-WebRequest @params
            
        } else {
            # PowerShell 5.1 benötigt UseBasicParsing für Server Core
            $params = @{
                Uri = $Uri
                TimeoutSec = $TimeoutSec
                UseBasicParsing = $true
                ErrorAction = 'Stop'
            }
            
            return Invoke-WebRequest @params
        }
        
    } catch {
        throw $_
    }
}

#endregion

#region Version-Specific System Management Functions

function Get-SystemInfo-VersionSpecific {
    <#
    .SYNOPSIS
        Holt Systeminformationen mit der optimalen Methode
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    try {
        if (Test-PowerShellCompatibility -Feature "CIM") {
            # Verwende CIM (moderne Methode)
            $params = @{
                ClassName = 'Win32_OperatingSystem'
                ComputerName = $ComputerName
                ErrorAction = 'Stop'
            }
            
            if ($Credential) {
                $params.Credential = $Credential
            }
            
            return Get-CimInstance @params
            
        } else {
            # Fallback zu WMI (PowerShell 5.1)
            $params = @{
                Class = 'Win32_OperatingSystem'
                ComputerName = $ComputerName
                ErrorAction = 'Stop'
            }
            
            if ($Credential) {
                $params.Credential = $Credential
            }
            
            return Get-WmiObject @params
        }
        
    } catch {
        throw $_
    }
}

#endregion

#region Version Information Display

function Show-PowerShellVersionInfo {
    <#
    .SYNOPSIS
        Zeigt detaillierte PowerShell-Versionsinformationen an
    #>
    $info = $Global:PSVersionInfo
    
    Write-Host "🔧 PowerShell Version Information" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version: $($info.Version)" -ForegroundColor White
    Write-Host "Edition: $($info.Edition)" -ForegroundColor White
    Write-Host "Platform: $(if($info.IsWindows){'Windows'}else{'Non-Windows'})" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📋 Compatibility Matrix:" -ForegroundColor Yellow
    Write-Host "   Excel COM: $(if(Test-PowerShellCompatibility -Feature 'ExcelCOM'){'✅ Available'}else{'❌ Not Available'})" -ForegroundColor White
    Write-Host "   ImportExcel: $(if(Test-PowerShellCompatibility -Feature 'ImportExcel'){'✅ Available'}else{'❌ Not Available'})" -ForegroundColor White
    Write-Host "   PSRemoting: $(if(Test-PowerShellCompatibility -Feature 'PSRemoting'){'✅ Available'}else{'❌ Not Available'})" -ForegroundColor White
    Write-Host "   WMI/CIM: $(if(Test-PowerShellCompatibility -Feature 'WMI'){'✅ Available'}else{'❌ Not Available'})" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🎯 Recommended Strategy:" -ForegroundColor Yellow
    if ($info.IsPS51) {
        Write-Host "   PowerShell 5.1 detected - Using Windows-optimized methods" -ForegroundColor Green
        Write-Host "   - Excel COM for full formatting support" -ForegroundColor Gray
        Write-Host "   - WMI for system management" -ForegroundColor Gray
        Write-Host "   - UseBasicParsing for web requests" -ForegroundColor Gray
    } elseif ($info.IsPS7Plus) {
        Write-Host "   PowerShell 7+ detected - Using cross-platform methods" -ForegroundColor Green
        Write-Host "   - ImportExcel for cross-platform compatibility" -ForegroundColor Gray
        Write-Host "   - CIM for system management" -ForegroundColor Gray
        Write-Host "   - Enhanced web request features" -ForegroundColor Gray
    } else {
        Write-Host "   Unsupported PowerShell version - Using fallback methods" -ForegroundColor Yellow
    }
    Write-Host ""
}

#region Version-Specific Display Functions

function Write-VersionSpecificHost {
    <#
    .SYNOPSIS
        Versions-spezifische Ausgabe - PS 5.1 mit ASCII, PS 7.x mit Emojis
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ForegroundColor = 'White',
        
        [Parameter(Mandatory = $false)]
        [string]$IconType = 'info'
    )
    
    # Icon-Mapping für verschiedene Versionen (PS 5.1 = ASCII, PS 7+ = Emojis)
    $iconMap = @{
        'success' = @{ PS51 = '[OK]'; PS7 = 'v' }
        'error' = @{ PS51 = '[ERROR]'; PS7 = 'X' }
        'warning' = @{ PS51 = '[WARN]'; PS7 = '!' }
        'info' = @{ PS51 = '[INFO]'; PS7 = 'i' }
        'rocket' = @{ PS51 = '[START]'; PS7 = '^' }
        'gear' = @{ PS51 = '[TOOL]'; PS7 = '*' }
        'shield' = @{ PS51 = '[SECURITY]'; PS7 = '#' }
        'lock' = @{ PS51 = '[LOCK]'; PS7 = '@' }
        'globe' = @{ PS51 = '[NET]'; PS7 = 'O' }
        'folder' = @{ PS51 = '[DIR]'; PS7 = '[]' }
        'file' = @{ PS51 = '[FILE]'; PS7 = '=' }
        'chart' = @{ PS51 = '[CHART]'; PS7 = '|' }
        'target' = @{ PS51 = '[TARGET]'; PS7 = '+' }
        'computer' = @{ PS51 = '[PC]'; PS7 = '&' }
        'network' = @{ PS51 = '[NETWORK]'; PS7 = '~' }
        'process' = @{ PS51 = '[PROC]'; PS7 = '%' }
        'clock' = @{ PS51 = '[TIME]'; PS7 = 'T' }
        'party' = @{ PS51 = '[DONE]'; PS7 = '!' }
    }
    
    $icon = ""
    if ($iconMap.ContainsKey($IconType)) {
        if ($Global:PSVersionInfo.IsPS51) {
            $icon = $iconMap[$IconType].PS51
        } elseif ($Global:PSVersionInfo.IsPS7Plus) {
            $icon = $iconMap[$IconType].PS7
        } else {
            $icon = "[?]"
        }
    }
    
    $fullMessage = if ($icon) { "$icon $Message" } else { $Message }
    Write-Host $fullMessage -ForegroundColor $ForegroundColor
}

function Write-VersionSpecificHeader {
    <#
    .SYNOPSIS
        Versions-spezifische Header-Ausgabe
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Version = "",
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = 'Cyan'
    )
    
    if ($Global:PSVersionInfo.IsPS51) {
        # PS 5.1 - ASCII Header
        Write-Host "=================================" -ForegroundColor $Color
        Write-Host "  $Title" -ForegroundColor $Color
        if ($Version) {
            Write-Host "  Version: $Version" -ForegroundColor Gray
        }
        Write-Host "  PowerShell: $($Global:PSVersionInfo.Version) (Desktop)" -ForegroundColor Gray
        Write-Host "=================================" -ForegroundColor $Color
    } elseif ($Global:PSVersionInfo.IsPS7Plus) {
        # PS 7+ - Emoji Header
        Write-Host "🚀 $Title" -ForegroundColor $Color
        Write-Host "===============================================================================" -ForegroundColor $Color
        if ($Version) {
            Write-Host "   📋 Version: $Version" -ForegroundColor Gray
        }
        Write-Host "   💻 PowerShell: $($Global:PSVersionInfo.Version) (Core)" -ForegroundColor Gray
        Write-Host "   📅 Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""
    }
}

function Invoke-PSRemoting-VersionSpecific {
    <#
    .SYNOPSIS
        Versions-spezifische PSRemoting-Ausführung
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [object[]]$ArgumentList,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )
    
    $result = @{
        Success = $false
        Data = $null
        Method = "Unknown"
        ErrorMessage = ""
    }
    
    try {
        Write-VersionSpecificHost "Testing PSRemoting to $ComputerName" -IconType 'network' -ForegroundColor Gray
        
        if ($Global:PSVersionInfo.IsPS51) {
            # PowerShell 5.1 - Traditionelle Parameter
            Write-Verbose "Using PS 5.1 PSRemoting approach"
            
            if ($Credential) {
                if ($ArgumentList) {
                    # DevSkim: ignore DS104456 - Required for PS 5.1 PSRemoting
                    $remoteResult = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ErrorAction Stop
                } else {
                    # DevSkim: ignore DS104456 - Required for PS 5.1 PSRemoting
                    $remoteResult = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock -ErrorAction Stop
                }
            } else {
                if ($ArgumentList) {
                    # DevSkim: ignore DS104456 - Required for PS 5.1 PSRemoting
                    $remoteResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ErrorAction Stop
                } else {
                    # DevSkim: ignore DS104456 - Required for PS 5.1 PSRemoting
                    $remoteResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ErrorAction Stop
                }
            }
            
            $result.Method = "PS51-InvokeCommand"
            Write-VersionSpecificHost "PSRemoting successful via PS 5.1" -IconType 'success' -ForegroundColor Green
            
        } elseif ($Global:PSVersionInfo.IsPS7Plus) {
            # PowerShell 7+ - Moderne Parameter mit erweiterten Features
            Write-Verbose "Using PS 7+ PSRemoting approach with modern features"
            
            $invokeParams = @{
                ComputerName = $ComputerName
                ScriptBlock = $ScriptBlock
                ErrorAction = 'Stop'
            }
            
            if ($Credential) { $invokeParams.Credential = $Credential }
            if ($ArgumentList) { $invokeParams.ArgumentList = $ArgumentList }
            
            # PS 7+ unterstützt bessere Timeout-Behandlung
            # DevSkim: ignore DS104456 - Required for PS 7+ PSRemoting
            $remoteResult = Invoke-Command @invokeParams
            
            $result.Method = "PS7-InvokeCommand-Modern"
            Write-VersionSpecificHost "PSRemoting successful via PS 7+" -IconType 'success' -ForegroundColor Green
        } else {
            throw "Unsupported PowerShell version: $($Global:PSVersionInfo.Version)"
        }
        
        $result.Success = $true
        $result.Data = $remoteResult
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-VersionSpecificHost "PSRemoting failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
        Write-Verbose "PSRemoting failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Test-NetworkConnectivity-VersionSpecific {
    <#
    .SYNOPSIS
        Versions-spezifische Netzwerk-Konnektivitätstests
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 0,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 5
    )
    
    $result = @{
        Success = $false
        ResponseTime = 0
        Method = "Unknown"
        ErrorMessage = ""
        Details = @{}
    }
    
    try {
        Write-VersionSpecificHost "Testing connectivity to $ComputerName$(if($Port -gt 0){":$Port"})" -IconType 'network' -ForegroundColor Gray
        
        $startTime = Get-Date
        
        if ($Global:PSVersionInfo.IsPS51) {
            # PowerShell 5.1 - Traditionelle Methoden
            Write-Verbose "Using PS 5.1 network testing"
            
            if ($Port -gt 0) {
                # Port-spezifischer Test für PS 5.1
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
                $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
                
                if ($wait) {
                    $tcpClient.EndConnect($connect)
                    $result.Success = $true
                    $result.Details.PortOpen = $true
                    Write-VersionSpecificHost "Port $Port is open" -IconType 'success' -ForegroundColor Green
                } else {
                    $result.Details.PortOpen = $false
                    throw "Port $Port not reachable"
                }
                $tcpClient.Close()
                $result.Method = "PS51-TcpClient"
            } else {
                # Einfacher Ping-Test
                $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
                $result.Success = $pingResult
                $result.Method = "PS51-TestConnection"
                
                if ($pingResult) {
                    Write-VersionSpecificHost "Ping successful" -IconType 'success' -ForegroundColor Green
                } else {
                    Write-VersionSpecificHost "Ping failed" -IconType 'error' -ForegroundColor Red
                }
            }
            
        } elseif ($Global:PSVersionInfo.IsPS7Plus) {
            # PowerShell 7+ - Moderne Methoden
            Write-Verbose "Using PS 7+ network testing with modern features"
            
            if ($Port -gt 0) {
                # Test-NetConnection ist in PS 7+ verfügbar
                try {
                    if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
                        $testResult = Test-NetConnection -ComputerName $ComputerName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
                        $result.Success = $testResult
                        $result.Details.PortOpen = $testResult
                        $result.Method = "PS7-TestNetConnection"
                        
                        if ($testResult) {
                            Write-VersionSpecificHost "Port $Port is accessible" -IconType 'success' -ForegroundColor Green
                        } else {
                            Write-VersionSpecificHost "Port $Port is not accessible" -IconType 'error' -ForegroundColor Red
                        }
                    } else {
                        # Fallback zu TcpClient
                        $tcpClient = New-Object System.Net.Sockets.TcpClient
                        $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
                        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
                        
                        if ($wait) {
                            $tcpClient.EndConnect($connect)
                            $result.Success = $true
                            $result.Details.PortOpen = $true
                            Write-VersionSpecificHost "Port $Port is open (fallback method)" -IconType 'success' -ForegroundColor Green
                        } else {
                            $result.Details.PortOpen = $false
                            throw "Port $Port not reachable"
                        }
                        $tcpClient.Close()
                        $result.Method = "PS7-TcpClient-Fallback"
                    }
                } catch {
                    Write-VersionSpecificHost "Port test failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
                    throw
                }
            } else {
                # Ping mit Timeout (PS 7+ Feature)
                $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -TimeoutSeconds $TimeoutSeconds -Quiet
                $result.Success = $pingResult
                $result.Method = "PS7-TestConnection-Timeout"
                
                if ($pingResult) {
                    Write-VersionSpecificHost "Network connectivity confirmed" -IconType 'success' -ForegroundColor Green
                } else {
                    Write-VersionSpecificHost "Network connectivity failed" -IconType 'error' -ForegroundColor Red
                }
            }
        }
        
        $result.ResponseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-VersionSpecificHost "Network test failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
        Write-Verbose "Network connectivity test failed: $($_.Exception.Message)"
    }
    
    return $result
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Get-PowerShellVersionInfo',
    'Test-PowerShellCompatibility',
    'Import-ExcelData-VersionSpecific',
    'Invoke-WebRequest-VersionSpecific', 
    'Get-SystemInfo-VersionSpecific',
    'Show-PowerShellVersionInfo',
    'Write-VersionSpecificHost',
    'Write-VersionSpecificHeader',
    'Invoke-PSRemoting-VersionSpecific',
    'Test-NetworkConnectivity-VersionSpecific'
)