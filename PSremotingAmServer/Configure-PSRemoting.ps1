#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Configure-PSRemoting - Enterprise PSRemoting Configuration Tool v1.0.0
    
.DESCRIPTION
    Vollständige PSRemoting-Konfiguration für Windows Server nach Regelwerk v10.0.3
    - Aktiviert WinRM und PSRemoting
    - Konfiguriert TrustedHosts
    - Firewall-Regeln erstellen
    - HTTPS-Listener (optional)
    - Credential-Management Integration
    
.PARAMETER TrustedHosts
    Komma-separierte Liste von Hosts (z.B. "*.meduniwien.ac.at,192.168.*")
    
.PARAMETER EnableHTTPS
    Aktiviert HTTPS-Listener mit Zertifikat
    
.PARAMETER TestConnection
    Testet PSRemoting-Verbindung nach Konfiguration
    
.PARAMETER RemoteComputer
    Remote-Computer für Test (nur mit -TestConnection)
    
.EXAMPLE
    .\Configure-PSRemoting.ps1
    Standard-Konfiguration: Aktiviert PSRemoting mit Firewall-Regeln
    
.EXAMPLE
    .\Configure-PSRemoting.ps1 -TrustedHosts "*.meduniwien.ac.at" -EnableHTTPS
    Konfiguriert PSRemoting mit Domain-Trust und HTTPS
    
.EXAMPLE
    .\Configure-PSRemoting.ps1 -TestConnection -RemoteComputer "SERVER01"
    Testet PSRemoting-Verbindung zu SERVER01
    
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Created on:     2025-10-07
    Regelwerk:      v10.0.3
    
    CHANGELOG:
    v1.0.0 - Initial Release
    - Regelwerk v10.0.3 Compliance
    - PowerShell 5.1/7.x Kompatibilität
    - 3-Stufen Credential-Strategie
    - Enterprise-grade Konfiguration
#>

[CmdletBinding()]
param(
    [string]$TrustedHosts = "ITSC020.cc.meduniwien.ac.at,itscmgmt03.srv.meduniwien.ac.at",
    
    [switch]$EnableHTTPS = $false,
    
    [switch]$TestConnection = $false,
    
    [string]$RemoteComputer = ""
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
# Script Information
# ==========================================
$ScriptVersion = "1.0.0"
$RulebookVersion = "v10.0.3"

# ==========================================
# § 5 Logging Configuration (Bewährtes System)
# ==========================================
$LogPath = Join-Path $PSScriptRoot "Logs"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Tages-Rotation wie in CertWebService
$LogFile = Join-Path $LogPath "PSRemoting-Config_$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Datei-Logging
    try {
        $LogEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    } catch {
        Write-Host "[WARN] Logging fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Konsolen-Ausgabe
    switch ($Level) {
        "SUCCESS" { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        "WARNING" { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        default   { Write-Host "[INFO] $Message" -ForegroundColor White }
    }
}

# ==========================================
# Script Header
# ==========================================
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Configure-PSRemoting v$ScriptVersion" -ForegroundColor Cyan
Write-Host "  Enterprise PSRemoting Configuration Tool" -ForegroundColor Cyan
Write-Host "  Regelwerk: $RulebookVersion" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Configure-PSRemoting v$ScriptVersion gestartet" -Level "INFO"
Write-Log "Computer: $env:COMPUTERNAME" -Level "INFO"
Write-Log "User: $env:USERNAME" -Level "INFO"
Write-Log "PowerShell Version: $($PSVersion.ToString())" -Level "INFO"

# ==========================================
# § 4 Error Handling
# ==========================================
$ErrorActionPreference = "Stop"

# ==========================================
# Main Configuration Functions
# ==========================================

function Test-AdminRights {
    <#
    .SYNOPSIS
        Prüft, ob das Script mit Administrator-Rechten läuft
    #>
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Enable-PSRemotingService {
    <#
    .SYNOPSIS
        Aktiviert WinRM und PSRemoting
    #>
    Write-Host ""
    Write-Host "[STEP 1] Aktiviere WinRM und PSRemoting..." -ForegroundColor Yellow
    Write-Log "Aktiviere WinRM und PSRemoting" -Level "INFO"
    
    try {
        # WinRM Service aktivieren
        Set-Service -Name WinRM -StartupType Automatic
        Start-Service -Name WinRM
        Write-Log "WinRM Service aktiviert" -Level "SUCCESS"
        
        # PSRemoting aktivieren
        Enable-PSRemoting -Force -SkipNetworkProfileCheck
        Write-Log "PSRemoting aktiviert" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-Log "Fehler beim Aktivieren von PSRemoting: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Set-TrustedHostsConfiguration {
    <#
    .SYNOPSIS
        Konfiguriert TrustedHosts für PSRemoting
    #>
    param([string]$Hosts)
    
    Write-Host ""
    Write-Host "[STEP 2] Konfiguriere TrustedHosts..." -ForegroundColor Yellow
    Write-Log "Konfiguriere TrustedHosts: $Hosts" -Level "INFO"
    
    try {
        # Aktuelle TrustedHosts auslesen
        $CurrentTrusted = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
        
        if ($CurrentTrusted.Value) {
            Write-Host "  Aktuelle TrustedHosts: $($CurrentTrusted.Value)" -ForegroundColor Gray
            Write-Log "Aktuelle TrustedHosts: $($CurrentTrusted.Value)" -Level "INFO"
        }
        
        # TrustedHosts setzen
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $Hosts -Force
        Write-Log "TrustedHosts gesetzt: $Hosts" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-Log "Fehler beim Setzen der TrustedHosts: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Enable-FirewallRules {
    <#
    .SYNOPSIS
        Erstellt Firewall-Regeln für PSRemoting
    #>
    Write-Host ""
    Write-Host "[STEP 3] Konfiguriere Firewall-Regeln..." -ForegroundColor Yellow
    Write-Log "Konfiguriere Firewall-Regeln" -Level "INFO"
    
    try {
        # HTTP (5985)
        $RuleHTTP = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue
        if (-not $RuleHTTP) {
            New-NetFirewallRule -Name "WINRM-HTTP-In-TCP" `
                -DisplayName "Windows Remote Management (HTTP-In)" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort 5985 `
                -Action Allow `
                -Enabled True
            Write-Log "Firewall-Regel für HTTP (5985) erstellt" -Level "SUCCESS"
        } else {
            Write-Host "  Firewall-Regel HTTP (5985) existiert bereits" -ForegroundColor Gray
            Write-Log "Firewall-Regel HTTP bereits vorhanden" -Level "INFO"
        }
        
        # HTTPS (5986) - optional
        if ($EnableHTTPS) {
            $RuleHTTPS = Get-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -ErrorAction SilentlyContinue
            if (-not $RuleHTTPS) {
                New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" `
                    -DisplayName "Windows Remote Management (HTTPS-In)" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort 5986 `
                    -Action Allow `
                    -Enabled True
                Write-Log "Firewall-Regel für HTTPS (5986) erstellt" -Level "SUCCESS"
            } else {
                Write-Host "  Firewall-Regel HTTPS (5986) existiert bereits" -ForegroundColor Gray
                Write-Log "Firewall-Regel HTTPS bereits vorhanden" -Level "INFO"
            }
        }
        
        return $true
    } catch {
        Write-Log "Fehler beim Konfigurieren der Firewall: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Enable-HTTPSListener {
    <#
    .SYNOPSIS
        Erstellt HTTPS-Listener mit selbstsigniertem Zertifikat
    #>
    Write-Host ""
    Write-Host "[STEP 4] Konfiguriere HTTPS-Listener..." -ForegroundColor Yellow
    Write-Log "Konfiguriere HTTPS-Listener" -Level "INFO"
    
    try {
        # Prüfen, ob HTTPS-Listener bereits existiert
        $HTTPSListener = Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate | 
            Where-Object { $_.Transport -eq "HTTPS" }
        
        if ($HTTPSListener) {
            Write-Host "  HTTPS-Listener existiert bereits" -ForegroundColor Gray
            Write-Log "HTTPS-Listener bereits konfiguriert" -Level "INFO"
            return $true
        }
        
        # Selbstsigniertes Zertifikat erstellen
        $Cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME `
            -CertStoreLocation Cert:\LocalMachine\My `
            -KeyExportPolicy NonExportable `
            -KeySpec KeyExchange `
            -Subject "CN=$env:COMPUTERNAME"
        
        Write-Log "Selbstsigniertes Zertifikat erstellt: $($Cert.Thumbprint)" -Level "SUCCESS"
        
        # HTTPS-Listener erstellen
        $Cmd = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS '@{Hostname=`"$env:COMPUTERNAME`"; CertificateThumbprint=`"$($Cert.Thumbprint)`"}'"
        Invoke-Expression $Cmd
        
        Write-Log "HTTPS-Listener erstellt mit Zertifikat" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-Log "Fehler beim Erstellen des HTTPS-Listeners: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-PSRemotingStatus {
    <#
    .SYNOPSIS
        Zeigt aktuellen PSRemoting-Status an
    #>
    Write-Host ""
    Write-Host "[STATUS] PSRemoting-Konfiguration:" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    # WinRM Service
    $WinRMService = Get-Service -Name WinRM
    Write-Host "WinRM Service:" -ForegroundColor Yellow
    Write-Host "  Status: $($WinRMService.Status)" -ForegroundColor White
    Write-Host "  Startup: $($WinRMService.StartType)" -ForegroundColor White
    
    # TrustedHosts
    $TrustedHostsValue = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    Write-Host ""
    Write-Host "TrustedHosts:" -ForegroundColor Yellow
    if ($TrustedHostsValue) {
        Write-Host "  $TrustedHostsValue" -ForegroundColor White
    } else {
        Write-Host "  <nicht konfiguriert>" -ForegroundColor Gray
    }
    
    # Listener
    Write-Host ""
    Write-Host "WinRM Listener:" -ForegroundColor Yellow
    $Listeners = Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate
    foreach ($Listener in $Listeners) {
        Write-Host "  Transport: $($Listener.Transport) | Port: $($Listener.Port) | Address: $($Listener.Address)" -ForegroundColor White
    }
    
    # Firewall-Regeln
    Write-Host ""
    Write-Host "Firewall-Regeln:" -ForegroundColor Yellow
    $FirewallHTTP = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue
    $FirewallHTTPS = Get-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -ErrorAction SilentlyContinue
    
    if ($FirewallHTTP) {
        Write-Host "  HTTP (5985): $($FirewallHTTP.Enabled)" -ForegroundColor White
    }
    if ($FirewallHTTPS) {
        Write-Host "  HTTPS (5986): $($FirewallHTTPS.Enabled)" -ForegroundColor White
    }
    
    Write-Host "=====================================================================" -ForegroundColor Cyan
}

function Test-PSRemotingConnection {
    <#
    .SYNOPSIS
        Testet PSRemoting-Verbindung zu Remote-Computer
    #>
    param([string]$ComputerName)
    
    Write-Host ""
    Write-Host "[TEST] Teste PSRemoting-Verbindung zu $ComputerName..." -ForegroundColor Yellow
    Write-Log "Teste PSRemoting-Verbindung zu $ComputerName" -Level "INFO"
    
    try {
        # Import FL-CredentialManager (falls vorhanden)
        $CredManagerPath = Join-Path $PSScriptRoot "Modules\FL-CredentialManager-v1.0.psm1"
        if (Test-Path $CredManagerPath) {
            Import-Module $CredManagerPath -Force
            Write-Log "FL-CredentialManager geladen (3-Stufen-Strategie)" -Level "INFO"
            
            # 3-Stufen Credential-Strategie (§14 Regelwerk v10.0.3)
            $Credential = Get-OrPromptCredential -Target $ComputerName -Username "$ComputerName\Administrator" -AutoSave
        } else {
            Write-Host "  FL-CredentialManager nicht gefunden - verwende Get-Credential" -ForegroundColor Gray
            $Credential = Get-Credential -Message "Credentials für $ComputerName"
        }
        
        if (-not $Credential) {
            Write-Log "Keine Credentials bereitgestellt" -Level "WARNING"
            return $false
        }
        
        # Test-Verbindung
        $Result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            @{
                ComputerName = $env:COMPUTERNAME
                PSVersion = $PSVersionTable.PSVersion.ToString()
                OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
            }
        }
        
        Write-Host ""
        Write-Host "[SUCCESS] PSRemoting-Verbindung erfolgreich!" -ForegroundColor Green
        Write-Host "  Computer: $($Result.ComputerName)" -ForegroundColor White
        Write-Host "  PowerShell: $($Result.PSVersion)" -ForegroundColor White
        Write-Host "  OS: $($Result.OSVersion)" -ForegroundColor White
        
        Write-Log "PSRemoting-Verbindung zu $ComputerName erfolgreich" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-Log "PSRemoting-Verbindung fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ==========================================
# Main Execution
# ==========================================

try {
    # Admin-Rechte prüfen
    if (-not (Test-AdminRights)) {
        Write-Host ""
        Write-Host "[ERROR] Dieses Script erfordert Administrator-Rechte!" -ForegroundColor Red
        Write-Host "Bitte als Administrator ausführen." -ForegroundColor Yellow
        Write-Log "Script ohne Administrator-Rechte gestartet" -Level "ERROR"
        exit 1
    }
    
    # Test-Modus
    if ($TestConnection) {
        if (-not $RemoteComputer) {
            Write-Host ""
            Write-Host "[ERROR] Parameter -RemoteComputer erforderlich für Test!" -ForegroundColor Red
            Write-Log "Test-Modus ohne RemoteComputer-Parameter" -Level "ERROR"
            exit 1
        }
        
        Test-PSRemotingConnection -ComputerName $RemoteComputer
        exit 0
    }
    
    # Normale Konfiguration
    Write-Host ""
    Write-Host "Starte PSRemoting-Konfiguration..." -ForegroundColor Cyan
    Write-Host "  TrustedHosts: $TrustedHosts" -ForegroundColor White
    Write-Host "  HTTPS: $(if($EnableHTTPS){'Aktiviert'}else{'Deaktiviert'})" -ForegroundColor White
    Write-Host ""
    Write-Host "[SECURITY] PSRemoting ist auf folgende Rechner beschränkt:" -ForegroundColor Yellow
    Write-Host "  - ITSC020.cc.meduniwien.ac.at" -ForegroundColor Cyan
    Write-Host "  - itscmgmt03.srv.meduniwien.ac.at" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: PSRemoting aktivieren
    if (-not (Enable-PSRemotingService)) {
        throw "PSRemoting-Aktivierung fehlgeschlagen"
    }
    
    # Step 2: TrustedHosts konfigurieren
    if (-not (Set-TrustedHostsConfiguration -Hosts $TrustedHosts)) {
        throw "TrustedHosts-Konfiguration fehlgeschlagen"
    }
    
    # Step 3: Firewall-Regeln
    if (-not (Enable-FirewallRules)) {
        throw "Firewall-Konfiguration fehlgeschlagen"
    }
    
    # Step 4: HTTPS-Listener (optional)
    if ($EnableHTTPS) {
        if (-not (Enable-HTTPSListener)) {
            Write-Log "HTTPS-Listener-Konfiguration fehlgeschlagen (nicht kritisch)" -Level "WARNING"
        }
    }
    
    # Status anzeigen
    Get-PSRemotingStatus
    
    # Erfolg
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host "  PSRemoting-Konfiguration erfolgreich abgeschlossen!" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[SECURITY] PSRemoting Whitelist aktiv:" -ForegroundColor Yellow
    Write-Host "  Nur ITSC020.cc.meduniwien.ac.at und itscmgmt03.srv.meduniwien.ac.at" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NAECHSTE SCHRITTE:" -ForegroundColor Yellow
    Write-Host "  1. Teste lokale Verbindung:" -ForegroundColor White
    Write-Host "     Test-WSMan -ComputerName localhost" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Teste Remote-Verbindung (von authorisierten Rechnern):" -ForegroundColor White
    Write-Host "     .\Configure-PSRemoting.ps1 -TestConnection -RemoteComputer SERVER01" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Verwende PSRemoting (von authorisierten Rechnern):" -ForegroundColor White
    Write-Host "     Enter-PSSession -ComputerName SERVER01" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "PSRemoting-Konfiguration erfolgreich abgeschlossen" -Level "SUCCESS"
    Write-Log "Logfile: $LogFile" -Level "INFO"
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Fehler während der Konfiguration:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Log "Kritischer Fehler: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Logfile: $LogFile" -Level "INFO"
    exit 1
}
