#requires -Version 5.1

<#
.SYNOPSIS
    Universal CertWebService Deployment Script

.DESCRIPTION
    Deploys CertWebService to remote servers and network share with full PS5.1/PS7.x compatibility.
    Includes ScanCertificates.ps1, WebFiles, and configuration.

.PARAMETER Servers
    Target servers for deployment

.PARAMETER DeployToNetworkShare
    Deploy to network share (\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService)

.PARAMETER RunInitialScan
    Execute initial certificate scan after deployment

.PARAMETER SkipBackup
    Skip backup of existing files

.VERSION
    3.0.0

.RULEBOOK
    v10.1.0

.EXAMPLE
    .\Deploy-CertWebService.ps1 -DeployToNetworkShare
    
.EXAMPLE
    .\Deploy-CertWebService.ps1 -Servers "itscmgmt03","wsus" -RunInitialScan
#>

param(
    [string[]]$Servers = @(
        "itscmgmt03.srv.meduniwien.ac.at",
        "wsus.srv.meduniwien.ac.at"
    ),
    [switch]$DeployToNetworkShare,
    [switch]$RunInitialScan,
    [switch]$SkipBackup
)

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
#region PowerShell Version Detection (Regelwerk v10.1.0)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

$EditionInfo = if ($IsPS7Plus) {
    "PowerShell 7.x Enhanced Mode"
} elseif ($IsPS51) {
    "PowerShell 5.1 Compatible Mode"
} else {
    "PowerShell 5.x Standard Mode"
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
#region Configuration
$Script:Version = "v3.0.0"
$Script:RegelwerkVersion = "v10.1.0"
$Script:DeploymentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$networkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"

# Files to deploy
$deploymentFiles = @{
    Core = @(
        "ScanCertificates.ps1",
        "VERSION.ps1"
    )
    Setup = @(
        "Setup-Universal-Compatible.ps1",
        "Setup-ScheduledTask-CertScan.ps1",
        "Setup-ACL-Config.ps1"
    )
    Installer = @(
        "CertWebService-Installer.ps1",
        "Install.bat"
    )
    Management = @(
        "Remove.ps1",
        "Update.ps1"
    )
    Directories = @(
        "Modules",
        "Config",
        "WebFiles"
    )
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
function Write-DeployLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARN','ERROR','DETAIL')][string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        'SUCCESS' { "[OK]" }
        'ERROR'   { "[ERROR]" }
        'WARN'    { "[WARN]" }
        'DETAIL'  { "  -" }
        default   { "[INFO]" }
    }
    
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'ERROR'   { 'Red' }
        'WARN'    { 'Yellow' }
        'DETAIL'  { 'Gray' }
        default   { 'White' }
    }
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Test-RemoteAccess {
    param([string]$Path)
    
    try {
        $null = Test-Path $Path -ErrorAction Stop
        return $true
    } catch {
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
function Backup-ExistingFiles {
    param(
        [string]$TargetPath,
        [string]$BackupSuffix
    )
    
    if ($SkipBackup) {
        Write-DeployLog "Backup übersprungen (SkipBackup)" -Level DETAIL
        return
    }
    
    $scanScript = Join-Path $TargetPath "ScanCertificates.ps1"
    if (Test-Path $scanScript) {
        $backupName = "ScanCertificates_backup_$BackupSuffix.ps1"
        $backupPath = Join-Path $TargetPath $backupName
        Copy-Item $scanScript -Destination $backupPath -Force
        Write-DeployLog "Backup: $backupName" -Level DETAIL
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
function Deploy-ToPath {
    param(
        [string]$TargetPath,
        [string]$TargetName
    )
    
    Write-DeployLog "Deployment zu: $TargetName" -Level INFO
    Write-DeployLog "Pfad: $TargetPath" -Level DETAIL
    
    # Check access
    if (-not (Test-RemoteAccess $TargetPath)) {
        Write-DeployLog "Verzeichnis nicht erreichbar - versuche zu erstellen..." -Level WARN
        try {
            New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
            Write-DeployLog "Verzeichnis erstellt" -Level SUCCESS
        } catch {
            Write-DeployLog "Fehler beim Erstellen: $($_.Exception.Message)" -Level ERROR
            return $false
        }
    }
    
    # Backup
    $backupSuffix = Get-Date -Format "yyyyMMdd_HHmmss"
    Backup-ExistingFiles -TargetPath $TargetPath -BackupSuffix $backupSuffix
    
    # Deploy Core Files
    Write-DeployLog "Deploying Core Files..." -Level INFO
    foreach ($file in $deploymentFiles.Core) {
        $source = Join-Path $scriptRoot $file
        $dest = Join-Path $TargetPath $file
        
        if (Test-Path $source) {
            try {
                Copy-Item $source -Destination $dest -Force
                $fileSize = [Math]::Round((Get-Item $source).Length / 1KB, 2)
                Write-DeployLog "$file ($fileSize KB)" -Level DETAIL
            } catch {
                Write-DeployLog "FEHLER bei $file`: $($_.Exception.Message)" -Level ERROR
                return $false
            }
        } else {
            Write-DeployLog "FEHLT: $file" -Level WARN
        }
    }
    
    # Deploy Setup Scripts
    Write-DeployLog "Deploying Setup Scripts..." -Level INFO
    foreach ($file in $deploymentFiles.Setup) {
        $source = Join-Path $scriptRoot $file
        $dest = Join-Path $TargetPath $file
        
        if (Test-Path $source) {
            Copy-Item $source -Destination $dest -Force
            Write-DeployLog "$file" -Level DETAIL
        }
    }
    
    # Deploy Installer
    Write-DeployLog "Deploying Installer..." -Level INFO
    foreach ($file in $deploymentFiles.Installer) {
        $source = Join-Path $scriptRoot $file
        $dest = Join-Path $TargetPath $file
        
        if (Test-Path $source) {
            Copy-Item $source -Destination $dest -Force
            Write-DeployLog "$file" -Level DETAIL
        }
    }
    
    # Deploy Management Scripts
    Write-DeployLog "Deploying Management Scripts..." -Level INFO
    foreach ($file in $deploymentFiles.Management) {
        $source = Join-Path $scriptRoot $file
        $dest = Join-Path $TargetPath $file
        
        if (Test-Path $source) {
            Copy-Item $source -Destination $dest -Force
            Write-DeployLog "$file" -Level DETAIL
        }
    }
    
    # Deploy Directories
    Write-DeployLog "Deploying Directories..." -Level INFO
    foreach ($dir in $deploymentFiles.Directories) {
        $source = Join-Path $scriptRoot $dir
        $dest = Join-Path $TargetPath $dir
        
        if (Test-Path $source) {
            try {
                Copy-Item $source -Destination $dest -Recurse -Force
                $fileCount = (Get-ChildItem $source -Recurse -File | Measure-Object).Count
                Write-DeployLog "$dir\ ($fileCount files)" -Level DETAIL
            } catch {
                Write-DeployLog "FEHLER bei $dir`: $($_.Exception.Message)" -Level ERROR
            }
        }
    }
    
    # Create Logs directory
    $logsPath = Join-Path $TargetPath "Logs"
    if (-not (Test-Path $logsPath)) {
        New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
        Write-DeployLog "Logs\ erstellt" -Level DETAIL
    }
    
    # Create deployment marker
    $markerFile = Join-Path $TargetPath "DEPLOYMENT-INFO.txt"
    $markerContent = @"
CertWebService Deployment
=========================
Version: $Script:Version
Regelwerk: $Script:RegelwerkVersion
Deployed: $Script:DeploymentDate
PowerShell: $($PSVersion.ToString()) ($EditionInfo)
Deployed By: $env:USERNAME@$env:COMPUTERNAME
Target: $TargetName
"@
    $markerContent | Out-File -FilePath $markerFile -Encoding UTF8 -Force
    
    Write-DeployLog "Deployment abgeschlossen" -Level SUCCESS
    return $true
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Invoke-RemoteScan {
    param([string]$ServerName)
    
    Write-DeployLog "Führe Certificate Scan aus auf $ServerName..." -Level INFO
    
    try {
        $result = Invoke-Command -ComputerName $ServerName -ScriptBlock {
            param($paths)
            
            # Find correct path
            $scriptPath = $null
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    $scriptPath = $path
                    break
                }
            }
            
            if (-not $scriptPath) {
                return @{
                    Success = $false
                    Message = "ScanCertificates.ps1 not found"
                }
            }
            
            # Execute scan
            $output = & powershell.exe -ExecutionPolicy Bypass -File $scriptPath 2>&1
            
            return @{
                Success = $?
                Output = $output
                ScriptPath = $scriptPath
            }
        } -ArgumentList @(
            "C:\inetpub\wwwroot\CertWebService\ScanCertificates.ps1",
            "C:\inetpub\CertWebService\ScanCertificates.ps1"
        ) -ErrorAction Stop
        
        if ($result.Success) {
            Write-DeployLog "Scan erfolgreich: $($result.ScriptPath)" -Level SUCCESS
            return $true
        } else {
            Write-DeployLog "Scan fehlgeschlagen: $($result.Message)" -Level ERROR
            return $false
        }
    } catch {
        Write-DeployLog "Remote-Scan Fehler: $($_.Exception.Message)" -Level ERROR
        return $false
    }
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
#region Main Deployment
# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
$ErrorActionPreference = 'Continue'

# Banner
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  CertWebService Universal Deployment $Script:Version" -ForegroundColor Cyan
Write-Host "  Regelwerk $Script:RegelwerkVersion | $EditionInfo" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Write-Host ""
Write-DeployLog "Regelwerk: $Script:RegelwerkVersion" -Level INFO
Write-DeployLog "PowerShell: $($PSVersion.ToString()) - $EditionInfo" -Level INFO
Write-DeployLog "Deployment-Datum: $Script:DeploymentDate" -Level INFO
Write-Host ""

# Verify source files
Write-DeployLog "Prüfe Source-Dateien..." -Level INFO
$missingFiles = @()
foreach ($category in $deploymentFiles.Keys) {
    if ($category -eq 'Directories') {
        foreach ($dir in $deploymentFiles[$category]) {
            $path = Join-Path $scriptRoot $dir
            if (-not (Test-Path $path)) {
                $missingFiles += $dir
            }
        }
    } else {
        foreach ($file in $deploymentFiles[$category]) {
            $path = Join-Path $scriptRoot $file
            if (-not (Test-Path $path)) {
                $missingFiles += $file
            }
        }
    }
}

if ($missingFiles.Count -gt 0) {
    Write-DeployLog "WARNUNG: $($missingFiles.Count) Dateien fehlen:" -Level WARN
    foreach ($file in $missingFiles) {
        Write-DeployLog "$file" -Level DETAIL
    }
}

# Deploy to Network Share
if ($DeployToNetworkShare) {
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-DeployLog "NETWORK SHARE DEPLOYMENT" -Level INFO
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    
    $success = Deploy-ToPath -TargetPath $networkShare -TargetName "Network Share"
    
    if ($success) {
        Write-DeployLog "Network Share Deployment erfolgreich" -Level SUCCESS
    } else {
        Write-DeployLog "Network Share Deployment fehlgeschlagen" -Level ERROR
    }
}

# Deploy to Servers
if ($Servers.Count -gt 0) {
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-DeployLog "SERVER DEPLOYMENT ($($Servers.Count) Server)" -Level INFO
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    $successCount = 0
    $failCount = 0
    
    foreach ($server in $Servers) {
        Write-Host "`n" + ("-" * 60) -ForegroundColor Gray
        Write-DeployLog "Server: $server" -Level INFO
        Write-Host ("-" * 60) -ForegroundColor Gray
        Write-Host ""
        
        # Test connectivity
        Write-DeployLog "Teste Verbindung..." -Level INFO
        if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
            Write-DeployLog "Server nicht erreichbar" -Level ERROR
            $failCount++
            continue
        }
        Write-DeployLog "Server erreichbar" -Level SUCCESS
        
        # Deploy to wwwroot (standard IIS path)
        $targetPath = "\\$server\c$\inetpub\wwwroot\CertWebService"
        $success = Deploy-ToPath -TargetPath $targetPath -TargetName $server
        
        if ($success) {
            $successCount++
            
            # Run initial scan if requested
            if ($RunInitialScan) {
                Write-Host ""
                Start-Sleep -Seconds 2
                Invoke-RemoteScan -ServerName $server
            }
        } else {
            $failCount++
        }
    }
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-DeployLog "DEPLOYMENT ZUSAMMENFASSUNG" -Level INFO
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    Write-DeployLog "Erfolgreich: $successCount Server" -Level SUCCESS
    Write-DeployLog "Fehlgeschlagen: $failCount Server" -Level $(if($failCount -gt 0){'ERROR'}else{'INFO'})
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Green
Write-DeployLog "DEPLOYMENT ABGESCHLOSSEN" -Level SUCCESS
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host ""
Write-Host "CertWebService erfolgreich deployed!" -ForegroundColor Green

Write-Host ""
Write-Host "Naechste Schritte:" -ForegroundColor Yellow
Write-Host "  1. Scheduled Task einrichten: .\Setup-ScheduledTask-CertScan.ps1" -ForegroundColor White
Write-Host "  2. API testen: Invoke-RestMethod -Uri 'http://SERVER:9080/certificates.json'" -ForegroundColor White
Write-Host "  3. Logs pruefen: \\SERVER\c$\inetpub\wwwroot\CertWebService\Logs" -ForegroundColor White
Write-Host ""
#endregion

