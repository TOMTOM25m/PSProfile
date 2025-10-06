#requires -Version 5.1

<#
.SYNOPSIS
    PowerShell Version Compatibility Module v3.0.0 - Pure ASCII
    
.DESCRIPTION
    Zentrale Erkennung von PowerShell-Versionen und Bereitstellung
    von versionsspezifischen Funktionen für das CertWebService-System.
    
    PS 5.1: ASCII-Zeichen nur
    PS 7.x: Kann Emojis verwenden, aber auch ASCII fallback
    
.VERSION
    3.0.0 - Pure ASCII for PS 5.1 compatibility
    
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
}

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
    $result = @{
        ExcelCOMAvailable = $false
        ImportExcelAvailable = $false
        WMIAvailable = $false
        CIMAvailable = $false
        ModernWebRequests = $false
    }
    
    # Test Excel COM (nur Windows Desktop)
    if ($Global:PSVersionInfo.IsWindows -and $Global:PSVersionInfo.IsDesktop) {
        try {
            # DevSkim: ignore DS104456 - Required for Excel COM compatibility testing
            $excel = New-Object -ComObject Excel.Application
            $excel.Quit()
            # DevSkim: ignore DS104456 - Required for proper COM cleanup
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
            $result.ExcelCOMAvailable = $true
        } catch {
            $result.ExcelCOMAvailable = $false
        }
    }
    
    # Test ImportExcel Modul
    $result.ImportExcelAvailable = ($null -ne (Get-Module -ListAvailable -Name ImportExcel))
    
    # Test WMI/CIM
    $result.WMIAvailable = ($null -ne (Get-Command Get-WmiObject -ErrorAction SilentlyContinue))
    $result.CIMAvailable = ($null -ne (Get-Command Get-CimInstance -ErrorAction SilentlyContinue))
    
    # Test moderne Web Request Features
    $result.ModernWebRequests = $Global:PSVersionInfo.IsPS7Plus
    
    return $result
}

function Write-VersionSpecificHost {
    <#
    .SYNOPSIS
        Versions-spezifische Ausgabe - PS 5.1 mit ASCII, PS 7.x mit besseren Zeichen
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ForegroundColor = 'White',
        
        [Parameter(Mandatory = $false)]
        [string]$IconType = 'info'
    )
    
    # Icon-Mapping - nur ASCII für PS 5.1 Kompatibilität
    $iconMap = @{
        'success' = '[OK]'
        'error' = '[ERROR]'
        'warning' = '[WARN]'
        'info' = '[INFO]'
        'rocket' = '[START]'
        'gear' = '[TOOL]'
        'shield' = '[SECURITY]'
        'lock' = '[LOCK]'
        'globe' = '[NET]'
        'folder' = '[DIR]'
        'file' = '[FILE]'
        'chart' = '[CHART]'
        'target' = '[TARGET]'
        'computer' = '[PC]'
        'network' = '[NETWORK]'
        'process' = '[PROC]'
        'clock' = '[TIME]'
        'party' = '[DONE]'
    }
    
    $icon = if ($iconMap.ContainsKey($IconType)) { $iconMap[$IconType] } else { '[?]' }
    $fullMessage = "$icon $Message"
    
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
        # PS 7+ - Erweiterte ASCII Header
        Write-Host ">>> $Title <<<" -ForegroundColor $Color
        Write-Host "===============================================================================" -ForegroundColor $Color
        if ($Version) {
            Write-Host "   [*] Version: $Version" -ForegroundColor Gray
        }
        Write-Host "   [*] PowerShell: $($Global:PSVersionInfo.Version) (Core)" -ForegroundColor Gray
        Write-Host "   [*] Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
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
            # PowerShell 7+ - Moderne Parameter
            Write-Verbose "Using PS 7+ PSRemoting approach with modern features"
            
            $invokeParams = @{
                ComputerName = $ComputerName
                ScriptBlock = $ScriptBlock
                ErrorAction = 'Stop'
            }
            
            if ($Credential) { $invokeParams.Credential = $Credential }
            if ($ArgumentList) { $invokeParams.ArgumentList = $ArgumentList }
            
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
                    if ($null -ne (Get-Command Test-NetConnection -ErrorAction SilentlyContinue)) {
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

# Export functions
Export-ModuleMember -Function @(
    'Get-PowerShellVersionInfo',
    'Test-PowerShellCompatibility',
    'Write-VersionSpecificHost',
    'Write-VersionSpecificHeader',
    'Invoke-PSRemoting-VersionSpecific',
    'Test-NetworkConnectivity-VersionSpecific'
)