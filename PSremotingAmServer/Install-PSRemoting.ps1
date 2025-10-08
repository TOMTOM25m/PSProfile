#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    PSRemoting Installation und Konfiguration (Konsolidiert)
    
.DESCRIPTION
    Einheitliches Installations-Script fuer PSRemoting nach Regelwerk v10.0.3
    
    Funktionen:
    - Pre-Installation Tests
    - WinRM Service Aktivierung
    - Firewall-Konfiguration
    - TrustedHosts Whitelist (ITSC020 + itscmgmt03)
    - HTTP/HTTPS Listener Setup
    - Status-Anzeige und Compliance-Check
    
.PARAMETER Mode
    Installation Mode:
    - "Auto"     : Automatische Installation ohne Interaktion
    - "Interactive" : Interaktives Menue (Standard)
    - "Status"   : Nur Status anzeigen
    
.EXAMPLE
    .\Install-PSRemoting.ps1
    Interaktive Installation mit Menue
    
.EXAMPLE
    .\Install-PSRemoting.ps1 -Mode Auto
    Automatische Installation ohne Bestaetigung
    
.EXAMPLE
    .\Install-PSRemoting.ps1 -Mode Status
    Zeigt nur aktuellen PSRemoting-Status
    
.NOTES
    Author:  Flecki (Tom) Garnreiter
    Version: v1.0.0
    Date:    2025-10-07
    Regelwerk: v10.0.3 (§5, §14, §19)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Auto", "Interactive", "Status")]
    [string]$Mode = "Interactive"
)

#region Configuration

# Whitelist: Autorisierte Management-Server
$script:TrustedHostsWhitelist = @(
    "ITSC020.cc.meduniwien.ac.at",
    "itscmgmt03.srv.meduniwien.ac.at"
)

# Firewall Ports
$script:HttpPort = 5985
$script:HttpsPort = 5986

# Logging
$script:LogDirectory = ".\Logs"
$script:LogFile = Join-Path $script:LogDirectory "PSRemoting-Install_$(Get-Date -Format 'yyyy-MM-dd').log"

#endregion

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Ensure Log Directory exists
    if (-not (Test-Path $script:LogDirectory)) {
        New-Item -Path $script:LogDirectory -ItemType Directory -Force | Out-Null
    }
    
    # Write to file
    Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8
    
    # Console output with colors
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        default   { Write-Host $logMessage -ForegroundColor Gray }
    }
}

#endregion

#region Helper Functions

function Test-IsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PowerShellVersion {
    return $PSVersionTable.PSVersion
}

function Show-Banner {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Pre-Installation Tests

function Test-Prerequisites {
    Show-Banner "PRE-INSTALLATION TESTS"
    Write-Log "Starte Pre-Installation Tests..." -Level INFO
    
    $allTestsPassed = $true
    
    # Test 1: PowerShell Version
    Write-Host "[TEST 1] PowerShell Version..." -ForegroundColor Yellow
    $psVersion = Get-PowerShellVersion
    Write-Host "  Version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Gray
    
    if ($psVersion.Major -ge 5) {
        Write-Log "PowerShell Version OK: $psVersion" -Level SUCCESS
    } else {
        Write-Log "PowerShell Version zu alt: $psVersion (mindestens 5.1 erforderlich)" -Level ERROR
        $allTestsPassed = $false
    }
    
    # Test 2: Administrator Rights
    Write-Host ""
    Write-Host "[TEST 2] Administrator-Rechte..." -ForegroundColor Yellow
    if (Test-IsAdmin) {
        Write-Log "Administrator-Rechte: OK" -Level SUCCESS
    } else {
        Write-Log "Keine Administrator-Rechte!" -Level ERROR
        $allTestsPassed = $false
    }
    
    # Test 3: WinRM Service
    Write-Host ""
    Write-Host "[TEST 3] WinRM Service..." -ForegroundColor Yellow
    try {
        $winrmService = Get-Service -Name WinRM -ErrorAction Stop
        Write-Host "  Status: $($winrmService.Status)" -ForegroundColor Gray
        Write-Host "  StartType: $($winrmService.StartType)" -ForegroundColor Gray
        Write-Log "WinRM Service gefunden: $($winrmService.Status)" -Level INFO
    } catch {
        Write-Log "WinRM Service nicht gefunden!" -Level ERROR
        $allTestsPassed = $false
    }
    
    # Test 4: Network Connectivity
    Write-Host ""
    Write-Host "[TEST 4] Netzwerk-Konnektivitaet..." -ForegroundColor Yellow
    foreach ($hostItem in $script:TrustedHostsWhitelist) {
        try {
            $result = Test-Connection -ComputerName $hostItem -Count 1 -Quiet -ErrorAction Stop
            if ($result) {
                Write-Log "Ping erfolgreich: $hostItem" -Level SUCCESS
            } else {
                Write-Log "Ping fehlgeschlagen: $hostItem" -Level WARNING
            }
        } catch {
            Write-Log "Netzwerk-Test fehlgeschlagen fuer $hostItem - $($_.Exception.Message)" -Level WARNING
        }
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    if ($allTestsPassed) {
        Write-Log "Alle kritischen Tests bestanden" -Level SUCCESS
        return $true
    } else {
        Write-Log "Einige Tests fehlgeschlagen!" -Level ERROR
        return $false
    }
}

#endregion

#region PSRemoting Configuration

function Enable-PSRemotingService {
    Show-Banner "PSREMOTING KONFIGURATION"
    Write-Log "Starte PSRemoting-Konfiguration..." -Level INFO
    
    try {
        # Enable PSRemoting
        Write-Host "[SCHRITT 1] Enable-PSRemoting..." -ForegroundColor Yellow
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
        Write-Log "Enable-PSRemoting erfolgreich" -Level SUCCESS
        
        # WinRM Service auf Automatic setzen
        Write-Host ""
        Write-Host "[SCHRITT 2] WinRM Service Autostart..." -ForegroundColor Yellow
        Set-Service -Name WinRM -StartupType Automatic -ErrorAction Stop
        Start-Service -Name WinRM -ErrorAction Stop
        Write-Log "WinRM Service konfiguriert (Automatic/Running)" -Level SUCCESS
        
        return $true
    } catch {
        Write-Log "Fehler bei PSRemoting-Aktivierung: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Set-TrustedHostsConfiguration {
    Write-Host ""
    Write-Host "[SCHRITT 3] TrustedHosts Whitelist..." -ForegroundColor Yellow
    Write-Log "Konfiguriere TrustedHosts Whitelist..." -Level INFO
    
    try {
        $trustedHostsPath = "WSMan:\localhost\Client\TrustedHosts"
        
        # Aktuelle TrustedHosts auslesen
        $currentTrustedHosts = (Get-Item $trustedHostsPath -ErrorAction SilentlyContinue).Value
        
        if ([string]::IsNullOrWhiteSpace($currentTrustedHosts)) {
            Write-Host "  Aktuell: (leer)" -ForegroundColor Gray
        } else {
            Write-Host "  Aktuell: $currentTrustedHosts" -ForegroundColor Gray
        }
        
        # Neue TrustedHosts zusammenstellen
        $newTrustedHosts = $script:TrustedHostsWhitelist -join ","
        
        Write-Host "  Neu: $newTrustedHosts" -ForegroundColor Cyan
        
        # TrustedHosts setzen
        Set-Item $trustedHostsPath -Value $newTrustedHosts -Force -ErrorAction Stop
        
        Write-Log "TrustedHosts Whitelist gesetzt: $newTrustedHosts" -Level SUCCESS
        
        foreach ($hostItem in $script:TrustedHostsWhitelist) {
            Write-Log "  - $hostItem" -Level INFO
        }
        
        return $true
    } catch {
        Write-Log "Fehler bei TrustedHosts-Konfiguration: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Enable-FirewallRules {
    Write-Host ""
    Write-Host "[SCHRITT 4] Firewall-Regeln..." -ForegroundColor Yellow
    Write-Log "Konfiguriere Firewall-Regeln..." -Level INFO
    
    try {
        # HTTP Port (5985)
        $httpRule = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue
        
        if ($httpRule) {
            Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction Stop
            Write-Log "Firewall-Regel aktiviert: HTTP (Port $script:HttpPort)" -Level SUCCESS
        } else {
            New-NetFirewallRule -Name "WINRM-HTTP-In-TCP" `
                -DisplayName "Windows Remote Management (HTTP-In)" `
                -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP $script:HttpPort]" `
                -Protocol TCP `
                -LocalPort $script:HttpPort `
                -Direction Inbound `
                -Action Allow `
                -ErrorAction Stop | Out-Null
            Write-Log "Firewall-Regel erstellt: HTTP (Port $script:HttpPort)" -Level SUCCESS
        }
        
        # HTTPS Port (5986) - Optional
        Write-Host "  HTTPS (Port $script:HttpsPort): Optional" -ForegroundColor Gray
        
        return $true
    } catch {
        Write-Log "Fehler bei Firewall-Konfiguration: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Enable-HTTPListener {
    Write-Host ""
    Write-Host "[SCHRITT 5] HTTP Listener..." -ForegroundColor Yellow
    Write-Log "Konfiguriere HTTP Listener..." -Level INFO
    
    try {
        # Pruefen ob HTTP Listener existiert
        $httpListener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"} -ErrorAction SilentlyContinue
        
        if ($httpListener) {
            Write-Log "HTTP Listener bereits vorhanden" -Level INFO
        } else {
            # HTTP Listener erstellen
            New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"} -ErrorAction Stop
            Write-Log "HTTP Listener erstellt" -Level SUCCESS
        }
        
        return $true
    } catch {
        Write-Log "Fehler bei HTTP Listener-Konfiguration: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

#endregion

#region Status Display

function Get-PSRemotingStatus {
    Show-Banner "PSREMOTING STATUS"
    Write-Log "Zeige PSRemoting-Status..." -Level INFO
    
    # WinRM Service
    Write-Host "[1] WinRM SERVICE" -ForegroundColor Yellow
    try {
        $winrm = Get-Service -Name WinRM -ErrorAction Stop
        Write-Host "  Status: " -NoNewline
        if ($winrm.Status -eq "Running") {
            Write-Host "$($winrm.Status)" -ForegroundColor Green
        } else {
            Write-Host "$($winrm.Status)" -ForegroundColor Red
        }
        Write-Host "  StartType: $($winrm.StartType)" -ForegroundColor Gray
    } catch {
        Write-Host "  [ERROR] WinRM Service nicht gefunden" -ForegroundColor Red
    }
    
    # TrustedHosts
    Write-Host ""
    Write-Host "[2] TRUSTEDHOSTS" -ForegroundColor Yellow
    try {
        $trustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction Stop).Value
        if ([string]::IsNullOrWhiteSpace($trustedHosts)) {
            Write-Host "  (leer)" -ForegroundColor Gray
        } else {
            $hosts = $trustedHosts -split ","
            foreach ($hostItem in $hosts) {
                if ($script:TrustedHostsWhitelist -contains $hostItem.Trim()) {
                    Write-Host "  [OK] $($hostItem.Trim())" -ForegroundColor Green
                } else {
                    Write-Host "  [?]  $($hostItem.Trim())" -ForegroundColor Yellow
                }
            }
        }
    } catch {
        Write-Host "  [ERROR] Konnte TrustedHosts nicht auslesen" -ForegroundColor Red
    }
    
    # Firewall Rules
    Write-Host ""
    Write-Host "[3] FIREWALL RULES" -ForegroundColor Yellow
    try {
        $httpRule = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue
        if ($httpRule) {
            Write-Host "  HTTP (Port $script:HttpPort): " -NoNewline
            if ($httpRule.Enabled -eq "True") {
                Write-Host "ENABLED" -ForegroundColor Green
            } else {
                Write-Host "DISABLED" -ForegroundColor Red
            }
        } else {
            Write-Host "  HTTP (Port $script:HttpPort): NOT FOUND" -ForegroundColor Red
        }
        
        $httpsRule = Get-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -ErrorAction SilentlyContinue
        if ($httpsRule) {
            Write-Host "  HTTPS (Port $script:HttpsPort): " -NoNewline
            if ($httpsRule.Enabled -eq "True") {
                Write-Host "ENABLED" -ForegroundColor Green
            } else {
                Write-Host "DISABLED" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  HTTPS (Port $script:HttpsPort): NOT CONFIGURED" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  [ERROR] Konnte Firewall-Regeln nicht pruefen" -ForegroundColor Red
    }
    
    # Listeners
    Write-Host ""
    Write-Host "[4] LISTENERS" -ForegroundColor Yellow
    try {
        $listeners = Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate -ErrorAction Stop
        if ($listeners) {
            foreach ($listener in $listeners) {
                Write-Host "  Transport: $($listener.Transport) | Port: $($listener.Port) | Address: $($listener.Address)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  Keine Listener konfiguriert" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [ERROR] Konnte Listeners nicht auslesen" -ForegroundColor Red
    }
    
    # Compliance Check
    Write-Host ""
    Write-Host "[5] COMPLIANCE CHECK" -ForegroundColor Yellow
    
    $compliance = @{
        WinRM = $false
        TrustedHosts = $false
        Firewall = $false
        Listener = $false
    }
    
    # Check WinRM
    try {
        $winrm = Get-Service -Name WinRM -ErrorAction Stop
        if ($winrm.Status -eq "Running" -and $winrm.StartType -eq "Automatic") {
            $compliance.WinRM = $true
        }
    } catch {}
    
    # Check TrustedHosts
    try {
        $trustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction Stop).Value
        if (-not [string]::IsNullOrWhiteSpace($trustedHosts)) {
            $hosts = $trustedHosts -split ","
            $whitelistMatch = $true
            foreach ($required in $script:TrustedHostsWhitelist) {
                if ($hosts -notcontains $required) {
                    $whitelistMatch = $false
                    break
                }
            }
            $compliance.TrustedHosts = $whitelistMatch
        }
    } catch {}
    
    # Check Firewall
    try {
        $httpRule = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue
        if ($httpRule -and $httpRule.Enabled -eq "True") {
            $compliance.Firewall = $true
        }
    } catch {}
    
    # Check Listener
    try {
        $listeners = Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate -ErrorAction Stop
        if ($listeners) {
            $compliance.Listener = $true
        }
    } catch {}
    
    # Display Compliance
    foreach ($key in $compliance.Keys) {
        Write-Host "  $key : " -NoNewline
        if ($compliance[$key]) {
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host "FEHLT" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    $allCompliant = ($compliance.Values | Where-Object { $_ -eq $false }).Count -eq 0
    
    if ($allCompliant) {
        Write-Host "[SUCCESS] PSRemoting vollstaendig konfiguriert!" -ForegroundColor Green
        Write-Log "Compliance-Check: PASSED" -Level SUCCESS
    } else {
        Write-Host "[WARNING] PSRemoting nicht vollstaendig konfiguriert" -ForegroundColor Yellow
        Write-Log "Compliance-Check: FAILED" -Level WARNING
    }
    
    Write-Host ""
}

#endregion

#region Main Installation

function Start-Installation {
    param([bool]$Interactive = $true)
    
    Write-Log "=== INSTALLATION GESTARTET ===" -Level INFO
    Write-Log "Hostname: $env:COMPUTERNAME" -Level INFO
    Write-Log "User: $env:USERNAME" -Level INFO
    Write-Log "PowerShell Version: $(Get-PowerShellVersion)" -Level INFO
    Write-Log "Mode: $(if($Interactive){'Interactive'}else{'Auto'})" -Level INFO
    
    # Pre-Installation Tests
    $testsOk = Test-Prerequisites
    
    if (-not $testsOk) {
        Write-Host ""
        Write-Host "[ERROR] Pre-Installation Tests fehlgeschlagen!" -ForegroundColor Red
        Write-Host "Installation kann nicht fortgesetzt werden." -ForegroundColor Red
        Write-Log "Installation abgebrochen: Pre-Tests fehlgeschlagen" -Level ERROR
        return $false
    }
    
    if ($Interactive) {
        Write-Host ""
        Write-Host "Moechten Sie mit der Installation fortfahren? [J/N]: " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        
        if ($response -ne "J" -and $response -ne "j") {
            Write-Log "Installation vom Benutzer abgebrochen" -Level INFO
            return $false
        }
    }
    
    # PSRemoting konfigurieren
    $step1 = Enable-PSRemotingService
    if (-not $step1) { return $false }
    
    $step2 = Set-TrustedHostsConfiguration
    if (-not $step2) { return $false }
    
    $step3 = Enable-FirewallRules
    if (-not $step3) { return $false }
    
    $step4 = Enable-HTTPListener
    if (-not $step4) { return $false }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Log "=== INSTALLATION ABGESCHLOSSEN ===" -Level SUCCESS
    Write-Host ""
    
    # Status anzeigen
    Start-Sleep -Seconds 2
    Get-PSRemotingStatus
    
    return $true
}

#endregion

#region Interactive Menu

function Show-Menu {
    while ($true) {
        Show-Banner "PSREMOTING INSTALLATION - HAUPTMENU"
        
        Write-Host "Optionen:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  [1] PRE-INSTALLATION TESTS" -ForegroundColor Cyan
        Write-Host "      Prueft alle Voraussetzungen vor Installation" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [2] PSREMOTING INSTALLIEREN" -ForegroundColor Cyan
        Write-Host "      Fuehrt vollstaendige PSRemoting-Konfiguration durch" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [3] STATUS ANZEIGEN" -ForegroundColor Cyan
        Write-Host "      Zeigt aktuellen PSRemoting-Status und Compliance" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [4] LOG-DATEI OEFFNEN" -ForegroundColor Cyan
        Write-Host "      Oeffnet Log-Datei: $script:LogFile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [0] BEENDEN" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Ihre Wahl [0-4]: " -ForegroundColor Yellow -NoNewline
        
        $choice = Read-Host
        
        switch ($choice) {
            "1" {
                Test-Prerequisites
                Write-Host ""
                Write-Host "Druecken Sie eine Taste um fortzufahren..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                $success = Start-Installation -Interactive $true
                Write-Host ""
                Write-Host "Druecken Sie eine Taste um fortzufahren..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Get-PSRemotingStatus
                Write-Host ""
                Write-Host "Druecken Sie eine Taste um fortzufahren..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                if (Test-Path $script:LogFile) {
                    Start-Process notepad.exe -ArgumentList $script:LogFile
                } else {
                    Write-Host ""
                    Write-Host "[INFO] Log-Datei existiert noch nicht: $script:LogFile" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Druecken Sie eine Taste um fortzufahren..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            "0" {
                Write-Host ""
                Write-Host "Auf Wiedersehen!" -ForegroundColor Green
                Write-Host ""
                return
            }
            default {
                Write-Host ""
                Write-Host "[ERROR] Ungueltige Eingabe: $choice" -ForegroundColor Red
                Write-Host ""
                Start-Sleep -Seconds 1
            }
        }
    }
}

#endregion

#region Main Entry Point

# Script Start
Show-Banner "PSREMOTING INSTALLATION v1.0.0"

Write-Host "Hostname: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "User: $env:USERNAME" -ForegroundColor Gray
Write-Host "PowerShell: $(Get-PowerShellVersion)" -ForegroundColor Gray
Write-Host "Log-Datei: $script:LogFile" -ForegroundColor Gray
Write-Host ""

# Mode Selection
switch ($Mode) {
    "Auto" {
        Write-Host "[MODE] Automatische Installation" -ForegroundColor Cyan
        Write-Host ""
        Start-Installation -Interactive $false
    }
    "Status" {
        Write-Host "[MODE] Status-Anzeige" -ForegroundColor Cyan
        Write-Host ""
        Get-PSRemotingStatus
    }
    "Interactive" {
        Write-Host "[MODE] Interaktives Menu" -ForegroundColor Cyan
        Write-Host ""
        Show-Menu
    }
}

#endregion
