#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    CertSurv Quick-Start Deployment Script v1.0.0

.DESCRIPTION
    Schnelles Deployment von CertWebService auf alle Server von ITSC020 aus.
    Automatische Erkennung der Deployment-Methode für jeden Server.

.PARAMETER Phase
    Deployment-Phase: Test, Production, All

.PARAMETER TargetServers
    Liste der Zielserver (optional, verwendet Excel-Liste wenn nicht angegeben)

.VERSION
    1.0.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Test", "ITSCMGMT03", "Critical", "Production", "All")]
    [string]$Phase = "Test",
    
    [Parameter(Mandatory = $false)]
    [string[]]$TargetServers = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipHealthCheck
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "CertSurv Quick-Start Deployment" -Version "v1.0.0 | Regelwerk: v10.1.0" -Color Cyan

# Konfiguration
$Config = @{
    NetworkSharePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
    ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx"
    LogPath = "C:\Temp\CertSurv-Deployment"
    
    # Server-Gruppen
    ServerGroups = @{
        Test = @("testserver01.meduniwien.ac.at")
        ITSCMGMT03 = @("ITSCMGMT03.srv.meduniwien.ac.at")
        Critical = @(
            "ITSCMGMT03.srv.meduniwien.ac.at",
            "itsc049.uvw.meduniwien.ac.at",
            "critical-server01.meduniwien.ac.at"
        )
    }
}

# Log-Verzeichnis erstellen
if (-not (Test-Path $Config.LogPath)) {
    New-Item -Path $Config.LogPath -ItemType Directory -Force | Out-Null
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Helper # Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
Functions

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Get-ServerListForPhase {
    param([string]$PhaseName)
    
    switch ($PhaseName) {
        "Test" {
            return $Config.ServerGroups.Test
        }
        "ITSCMGMT03" {
            return $Config.ServerGroups.ITSCMGMT03
        }
        "Critical" {
            return $Config.ServerGroups.Critical
        }
        "Production" {
            Write-VersionSpecificHost "Loading server list from Excel..." -IconType 'file' -ForegroundColor Yellow
            # TODO: Excel-Integration hier implementieren
            return @()
        }
        "All" {
            Write-VersionSpecificHost "Loading ALL servers from Excel..." -IconType 'file' -ForegroundColor Yellow
            # TODO: Excel-Integration hier implementieren
            return @()
        }
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Test-PreDeploymentRequirements {
    Write-VersionSpecificHost "Checking pre-deployment requirements..." -IconType 'shield' -ForegroundColor Yellow
    
    $checks = @{
        NetworkShare = $false
        AdminRights = $false
        PowerShellVersion = $false
    }
    
    # Network Share Check
    try {
        $checks.NetworkShare = Test-Path $Config.NetworkSharePath
        if ($checks.NetworkShare) {
            Write-VersionSpecificHost "Network share accessible: $($Config.NetworkSharePath)" -IconType 'success' -ForegroundColor Green
        } else {
            Write-VersionSpecificHost "Network share NOT accessible: $($Config.NetworkSharePath)" -IconType 'error' -ForegroundColor Red
        }
    } catch {
        Write-VersionSpecificHost "Network share check failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    }
    
    # Admin Rights Check
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $checks.AdminRights = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($checks.AdminRights) {
        Write-VersionSpecificHost "Running with Administrator privileges" -IconType 'success' -ForegroundColor Green
    } else {
        Write-VersionSpecificHost "WARNING: Not running as Administrator" -IconType 'warning' -ForegroundColor Yellow
    }
    
    # PowerShell Version Check
    $versionInfo = Get-PowerShellVersionInfo
    $checks.PowerShellVersion = $versionInfo.IsPS51 -or $versionInfo.IsPS7Plus
    Write-VersionSpecificHost "PowerShell Version: $($versionInfo.Version) - $($versionInfo.CompatibilityMode)" -IconType 'info' -ForegroundColor Cyan
    
    Write-Host ""
    
    # Ergebnis
    $allChecks = $checks.Values | Where-Object { $_ -eq $false }
    if ($allChecks.Count -eq 0) {
        Write-VersionSpecificHost "All pre-deployment checks passed!" -IconType 'success' -ForegroundColor Green
        return $true
    } else {
        Write-VersionSpecificHost "Some pre-deployment checks failed!" -IconType 'error' -ForegroundColor Red
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Invoke-HealthCheck {
    param([string[]]$Servers)
    
    Write-VersionSpecificHost "Running health checks on target servers..." -IconType 'network' -ForegroundColor Yellow
    
    $healthResults = @()
    
    foreach ($server in $Servers) {
        Write-Host "  Checking $server..." -ForegroundColor Gray
        
        $result = @{
            Server = $server
            Ping = $false
            SMB = $false
            CertWebService = $false
            Port8443 = $false
            Timestamp = Get-Date
        }
        
        # Ping Test
        try {
            $result.Ping = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
        } catch { }
        
        # SMB Test
        try {
            $result.SMB = Test-Path "\\$server\C$" -ErrorAction SilentlyContinue
        } catch { }
        
        # Port 8443 Test
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($server, 8443, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(2000, $false)
            
            if ($wait) {
                $tcpClient.EndConnect($connect)
                $result.Port8443 = $true
                $result.CertWebService = $true
            }
            $tcpClient.Close()
        } catch { }
        
        # Ausgabe
        $status = if ($result.CertWebService) { "INSTALLED" } elseif ($result.Ping) { "READY" } else { "OFFLINE" }
        $color = if ($result.CertWebService) { "Green" } elseif ($result.Ping) { "Yellow" } else { "Red" }
        
        Write-Host "    Status: $status (Ping: $($result.Ping), SMB: $($result.SMB), Port 8443: $($result.Port8443))" -ForegroundColor $color
        
        $healthResults += $result
    }
    
    Write-Host ""
    return $healthResults
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Start-DeploymentPhase {
    param(
        [string[]]$Servers,
        [switch]$TestMode
    )
    
    Write-VersionSpecificHost "Starting deployment to $($Servers.Count) server(s)..." -IconType 'rocket' -ForegroundColor Cyan
    
    if ($TestMode) {
        Write-VersionSpecificHost "TEST MODE - No actual deployment will be performed" -IconType 'warning' -ForegroundColor Yellow
    }
    
    # Credentials anfordern (falls nicht im TestMode)
    $creds = $null
    if (-not $TestMode) {
        Write-Host ""
        Write-Host "Using 3-tier credential strategy (Default -> Vault -> Prompt):" -ForegroundColor Yellow
        try {
            $creds = Get-OrPromptCredential -Target "CertSurv-Deployment" -Username "Administrator" -AutoSave
        } catch {
            Write-VersionSpecificHost "Credentials required for deployment. Exiting." -IconType 'error' -ForegroundColor Red
            return
        }
    }
    
    # Deployment durchführen
    .\Update-AllServers-Hybrid-v2.5.ps1 `
        -ServerList $Servers `
        -NetworkSharePath $Config.NetworkSharePath `
        -AdminCredential $creds `
        -TestOnly:$TestMode `
        -GenerateReports `
        -Verbose
}

#endregion

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region Main Execution

try {
    Write-Host ""
    Write-VersionSpecificHost "Phase: $Phase" -IconType 'info' -ForegroundColor Cyan
    Write-Host ""
    
    # Pre-Deployment Checks
    $checksPass = Test-PreDeploymentRequirements
    
    if (-not $checksPass) {
        Write-VersionSpecificHost "Pre-deployment checks failed. Please fix issues before deployment." -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Server-Liste bestimmen
    $serverList = if ($TargetServers.Count -gt 0) {
        $TargetServers
    } else {
        Get-ServerListForPhase -PhaseName $Phase
    }
    
    if ($serverList.Count -eq 0) {
        Write-VersionSpecificHost "No servers found for deployment phase: $Phase" -IconType 'warning' -ForegroundColor Yellow
        exit 1
    }
    
    Write-VersionSpecificHost "Target servers ($($serverList.Count)):" -IconType 'target' -ForegroundColor Cyan
    foreach ($srv in $serverList) {
        Write-Host "  - $srv" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Health Check
    if (-not $SkipHealthCheck) {
        $healthResults = Invoke-HealthCheck -Servers $serverList
        
        # Health Check Zusammenfassung
        $online = ($healthResults | Where-Object { $_.Ping }).Count
        $installed = ($healthResults | Where-Object { $_.CertWebService }).Count
        
        Write-VersionSpecificHost "Health Check Summary:" -IconType 'chart' -ForegroundColor Cyan
        Write-Host "  Online: $online / $($serverList.Count)" -ForegroundColor $(if($online -eq $serverList.Count){'Green'}else{'Yellow'})
        Write-Host "  CertWebService Installed: $installed / $($serverList.Count)" -ForegroundColor $(if($installed -eq $serverList.Count){'Green'}else{'Yellow'})
        Write-Host ""
    }
    
    # Deployment starten
    if ($TestOnly) {
        Write-VersionSpecificHost "TEST MODE - Deployment simulation" -IconType 'warning' -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Bestätigung einholen (außer in TestOnly Mode)
    if (-not $TestOnly) {
        Write-Host "Ready to deploy CertWebService to $($serverList.Count) server(s)." -ForegroundColor Yellow
        $confirm = Read-Host "Continue? (Y/N)"
        
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-VersionSpecificHost "Deployment cancelled by user." -IconType 'warning' -ForegroundColor Yellow
            exit 0
        }
        Write-Host ""
    }
    
    # Deployment ausführen
    Start-DeploymentPhase -Servers $serverList -TestMode:$TestOnly
    
    Write-Host ""
    Write-VersionSpecificHost "Deployment phase completed!" -IconType 'party' -ForegroundColor Green
    
    # Deployment-Log anzeigen
    $logFiles = Get-ChildItem $Config.LogPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($logFiles) {
        Write-Host ""
        Write-VersionSpecificHost "Recent log files:" -IconType 'file' -ForegroundColor Cyan
        foreach ($log in $logFiles) {
            Write-Host "  - $($log.Name) ($($log.LastWriteTime))" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-VersionSpecificHost "Deployment failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}

#endregion

