#Requires -Version 5.1

<#
.SYNOPSIS
    Test-RemoteConnection - PSRemoting Verbindungstest v1.0.0
    
.DESCRIPTION
    Testet PSRemoting-Verbindungen zu einem oder mehreren Remote-Computern
    mit detaillierten Informationen und Fehlerdiagnose.
    
.PARAMETER ComputerName
    Einzelner Computer oder Array von Computern
    
.PARAMETER UseSSL
    Verwendet HTTPS (Port 5986) statt HTTP (Port 5985)
    
.PARAMETER TestPort
    Testet nur die Netzwerk-Verbindung (Port-Test)
    
.EXAMPLE
    .\Test-RemoteConnection.ps1 -ComputerName "SERVER01"
    
.EXAMPLE
    .\Test-RemoteConnection.ps1 -ComputerName "SERVER01","SERVER02","SERVER03"
    
.EXAMPLE
    .\Test-RemoteConnection.ps1 -ComputerName "SERVER01" -UseSSL
    
.EXAMPLE
    .\Test-RemoteConnection.ps1 -ComputerName "SERVER01" -TestPort
    
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Created on:     2025-10-07
    Regelwerk:      v10.0.3
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$ComputerName,
    
    [switch]$UseSSL = $false,
    
    [switch]$TestPort = $false
)

# ==========================================
# § 19 PowerShell Version Detection (MANDATORY)
# ==========================================
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "PowerShell Version: $($PSVersion.ToString())"
Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){'PS 7.x Enhanced'}elseif($IsPS51){'PS 5.1 Compatible'}else{'PS 5.x Standard'})"

# ==========================================
# Configuration
# ==========================================
$Port = if ($UseSSL) { 5986 } else { 5985 }
$Protocol = if ($UseSSL) { "HTTPS" } else { "HTTP" }

# ==========================================
# Functions
# ==========================================

function Test-PortConnection {
    param(
        [string]$ComputerName,
        [int]$Port
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
        
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

function Test-PSRemotingConnection {
    param(
        [string]$ComputerName,
        [switch]$UseSSL
    )
    
    $Result = @{
        ComputerName = $ComputerName
        PortOpen = $false
        WSManTest = $false
        RemoteCommand = $false
        Details = @{}
        Error = $null
    }
    
    # Test 1: Port-Test
    Write-Host "  [1/3] Teste Port $Port..." -ForegroundColor Gray -NoNewline
    $Result.PortOpen = Test-PortConnection -ComputerName $ComputerName -Port $Port
    
    if ($Result.PortOpen) {
        Write-Host " [SUCCESS]" -ForegroundColor Green
    } else {
        Write-Host " [FAILED]" -ForegroundColor Red
        $Result.Error = "Port $Port nicht erreichbar"
        return $Result
    }
    
    # Test 2: WSMan-Test
    Write-Host "  [2/3] Teste WSMan..." -ForegroundColor Gray -NoNewline
    try {
        if ($UseSSL) {
            $null = Test-WSMan -ComputerName $ComputerName -UseSSL -ErrorAction Stop
        } else {
            $null = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
        }
        $Result.WSManTest = $true
        Write-Host " [SUCCESS]" -ForegroundColor Green
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        $Result.Error = "WSMan-Test fehlgeschlagen: $($_.Exception.Message)"
        return $Result
    }
    
    # Test 3: Remote-Command
    Write-Host "  [3/3] Teste Remote-Command..." -ForegroundColor Gray -NoNewline
    try {
        # Import FL-CredentialManager (falls vorhanden)
        $CredManagerPath = Join-Path $PSScriptRoot "Modules\FL-CredentialManager-v1.0.psm1"
        $Credential = $null
        
        if (Test-Path $CredManagerPath) {
            Import-Module $CredManagerPath -Force -ErrorAction SilentlyContinue
            try {
                $Credential = Get-OrPromptCredential -Target $ComputerName -Username "$ComputerName\Administrator" -AutoSave
            } catch {
                # Fallback zu Get-Credential
                $Credential = Get-Credential -Message "Credentials für $ComputerName"
            }
        } else {
            $Credential = Get-Credential -Message "Credentials für $ComputerName"
        }
        
        if (-not $Credential) {
            Write-Host " [SKIPPED]" -ForegroundColor Yellow
            $Result.Error = "Keine Credentials bereitgestellt"
            return $Result
        }
        
        # Remote-Command ausführen
        $RemoteData = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            @{
                ComputerName = $env:COMPUTERNAME
                PSVersion = $PSVersionTable.PSVersion.ToString()
                OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
                UpTime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                TotalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            }
        } -ErrorAction Stop
        
        $Result.RemoteCommand = $true
        $Result.Details = $RemoteData
        Write-Host " [SUCCESS]" -ForegroundColor Green
        
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        $Result.Error = "Remote-Command fehlgeschlagen: $($_.Exception.Message)"
    }
    
    return $Result
}

# ==========================================
# Main Execution
# ==========================================

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  PSRemoting Verbindungstest v1.0.0" -ForegroundColor Cyan
Write-Host "  Regelwerk: v10.0.3" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Protokoll: $Protocol | Port: $Port" -ForegroundColor White
Write-Host "Computer: $($ComputerName -join ', ')" -ForegroundColor White
Write-Host ""

$Results = @()

foreach ($Computer in $ComputerName) {
    Write-Host "[$Computer]" -ForegroundColor Yellow
    
    if ($TestPort) {
        # Nur Port-Test
        Write-Host "  Teste Port $Port..." -ForegroundColor Gray -NoNewline
        $PortOpen = Test-PortConnection -ComputerName $Computer -Port $Port
        
        if ($PortOpen) {
            Write-Host " [SUCCESS]" -ForegroundColor Green
        } else {
            Write-Host " [FAILED]" -ForegroundColor Red
        }
        
        $Results += @{
            ComputerName = $Computer
            PortOpen = $PortOpen
        }
    } else {
        # Vollständiger Test
        $Result = Test-PSRemotingConnection -ComputerName $Computer -UseSSL:$UseSSL
        $Results += $Result
    }
    
    Write-Host ""
}

# ==========================================
# Zusammenfassung
# ==========================================

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  ZUSAMMENFASSUNG" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($Result in $Results) {
    if ($TestPort) {
        $Status = if ($Result.PortOpen) { "[SUCCESS]" } else { "[FAILED]" }
        $Color = if ($Result.PortOpen) { "Green" } else { "Red" }
        
        Write-Host "$($Result.ComputerName): $Status Port $Port" -ForegroundColor $Color
    } else {
        Write-Host "[$($Result.ComputerName)]" -ForegroundColor Yellow
        
        # Port
        $PortStatus = if ($Result.PortOpen) { "[SUCCESS]" } else { "[FAILED]" }
        $PortColor = if ($Result.PortOpen) { "Green" } else { "Red" }
        Write-Host "  Port $Port: $PortStatus" -ForegroundColor $PortColor
        
        # WSMan
        $WSManStatus = if ($Result.WSManTest) { "[SUCCESS]" } else { "[FAILED]" }
        $WSManColor = if ($Result.WSManTest) { "Green" } else { "Red" }
        Write-Host "  WSMan Test: $WSManStatus" -ForegroundColor $WSManColor
        
        # Remote-Command
        $RemoteStatus = if ($Result.RemoteCommand) { "[SUCCESS]" } else { "[FAILED]" }
        $RemoteColor = if ($Result.RemoteCommand) { "Green" } else { "Red" }
        Write-Host "  Remote Command: $RemoteStatus" -ForegroundColor $RemoteColor
        
        # Details
        if ($Result.RemoteCommand -and $Result.Details) {
            Write-Host ""
            Write-Host "  Details:" -ForegroundColor Cyan
            Write-Host "    ComputerName: $($Result.Details.ComputerName)" -ForegroundColor White
            Write-Host "    PowerShell: $($Result.Details.PSVersion)" -ForegroundColor White
            Write-Host "    OS: $($Result.Details.OSVersion)" -ForegroundColor White
            Write-Host "    UpTime: $($Result.Details.UpTime.Days)d $($Result.Details.UpTime.Hours)h $($Result.Details.UpTime.Minutes)m" -ForegroundColor White
            Write-Host "    Memory: $($Result.Details.TotalMemoryGB) GB" -ForegroundColor White
        }
        
        # Fehler
        if ($Result.Error) {
            Write-Host ""
            Write-Host "  [ERROR] $($Result.Error)" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

# Statistik
$TotalTests = $Results.Count
$SuccessfulTests = ($Results | Where-Object { $_.RemoteCommand -eq $true }).Count
$FailedTests = $TotalTests - $SuccessfulTests

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "STATISTIK:" -ForegroundColor Yellow
Write-Host "  Gesamt: $TotalTests" -ForegroundColor White
Write-Host "  Erfolgreich: $SuccessfulTests" -ForegroundColor Green
Write-Host "  Fehlgeschlagen: $FailedTests" -ForegroundColor Red
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
