#requires -Version 7.0
# Deploy-CertWebService-PS7.ps1 - PowerShell 7.x Enhanced (UTF-8 BOM, Emojis)
# Version: 3.0.0 | Regelwerk: v10.1.0

param(
    [string[]]$Servers = @("itscmgmt03.srv.meduniwien.ac.at", "wsus.srv.meduniwien.ac.at"),
    [switch]$DeployToNetworkShare,
    [switch]$RunInitialScan,
    [switch]$SkipBackup,
    [PSCredential]$Credential
)

$Script:Version = "v3.0.0"
$Script:Regelwerk = "v10.1.0"
$scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$networkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"

# Import Credential Manager
$credMgrPath = Join-Path $scriptRoot "Modules\FL-CredentialManager.psm1"
if (Test-Path $credMgrPath) {
    Import-Module $credMgrPath -Force
}

# Files to deploy
$coreFiles = @("ScanCertificates.ps1", "VERSION.ps1")
$setupFiles = @("Setup-Universal-Compatible.ps1", "Setup-ScheduledTask-CertScan.ps1", "Setup-ACL-Config.ps1")
$installerFiles = @("CertWebService-Installer.ps1", "Install.bat")
$mgmtFiles = @("Remove.ps1", "Update.ps1")
$directories = @("Modules", "Config", "WebFiles")

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $pre = switch ($Level) {
        "SUCCESS" { "" }
        "ERROR" { "" }
        "WARN" { " " }
        "DETAIL" { "  " }
        default { "" }
    }
    $clr = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "DETAIL" { "Gray" }
        default { "White" }
    }
    Write-Host "[$ts] $pre $Msg" -ForegroundColor $clr
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
        [string]$Path, 
        [string]$Name,
        [PSCredential]$Credential
    )
    
    Write-Log "Deployment: $Name" -Level INFO
    Write-Log "Path: $Path" -Level DETAIL
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Verzeichnis erstellt" -Level SUCCESS
        } catch {
            Write-Log "Fehler: $($_.Exception.Message)" -Level ERROR
            return $false
        }
    }
    
    # Backup
    if (-not $SkipBackup) {
        $scanScript = Join-Path $Path "ScanCertificates.ps1"
        if (Test-Path $scanScript) {
            $backup = "ScanCertificates_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
            Copy-Item $scanScript -Destination (Join-Path $Path $backup) -Force
            Write-Log "Backup: $backup" -Level DETAIL
        }
    }
    
    # Build PSDrive if credential provided
    $usePSDrive = $false
    $driveName = "DeployDrive$(Get-Random)"
    if ($Credential -and $Path -like "\\*") {
        try {
            $uncRoot = "\\$($Path.Split('\')[2])\$($Path.Split('\')[3])"
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $uncRoot -Credential $Credential -ErrorAction Stop | Out-Null
            $Path = $Path -replace [regex]::Escape($uncRoot), "${driveName}:"
            $usePSDrive = $true
            Write-Log "PSDrive mounted with credentials" -Level DETAIL
        } catch {
            Write-Log "PSDrive mount failed: $($_.Exception.Message)" -Level WARN
        }
    }
    
    # Deploy Core
    Write-Log "Core Files..." -Level INFO
    foreach ($file in $coreFiles) {
        $src = Join-Path $scriptRoot $file
        if (Test-Path $src) {
            Copy-Item $src -Destination (Join-Path $Path $file) -Force
            Write-Log "$file" -Level DETAIL
        }
    }
    
    # Deploy Setup
    Write-Log "Setup Scripts..." -Level INFO
    foreach ($file in $setupFiles) {
        $src = Join-Path $scriptRoot $file
        if (Test-Path $src) {
            Copy-Item $src -Destination (Join-Path $Path $file) -Force
            Write-Log "$file" -Level DETAIL
        }
    }
    
    # Deploy Installer
    Write-Log "Installer..." -Level INFO
    foreach ($file in $installerFiles) {
        $src = Join-Path $scriptRoot $file
        if (Test-Path $src) {
            Copy-Item $src -Destination (Join-Path $Path $file) -Force
            Write-Log "$file" -Level DETAIL
        }
    }
    
    # Deploy Management
    Write-Log "Management Scripts..." -Level INFO
    foreach ($file in $mgmtFiles) {
        $src = Join-Path $scriptRoot $file
        if (Test-Path $src) {
            Copy-Item $src -Destination (Join-Path $Path $file) -Force
            Write-Log "$file" -Level DETAIL
        }
    }
    
    # Deploy Directories
    Write-Log "Directories..." -Level INFO
    foreach ($dir in $directories) {
        $src = Join-Path $scriptRoot $dir
        if (Test-Path $src) {
            Copy-Item $src -Destination (Join-Path $Path $dir) -Recurse -Force
            $cnt = (Get-ChildItem $src -Recurse -File | Measure-Object).Count
            Write-Log "$dir\ ($cnt files)" -Level DETAIL
        }
    }
    
    # Create Logs
    $logs = Join-Path $Path "Logs"
    if (-not (Test-Path $logs)) {
        New-Item -Path $logs -ItemType Directory -Force | Out-Null
    }
    
    # Deployment Info
    @"
CertWebService Deployment
Version: $Script:Version
Regelwerk: $Script:Regelwerk
Deployed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell: $($PSVersionTable.PSVersion) (PS7.x Enhanced)
By: $env:USERNAME@$env:COMPUTERNAME
Target: $Name
"@ | Out-File -FilePath (Join-Path $Path "DEPLOYMENT-INFO.txt") -Encoding UTF8 -Force
    
    # Cleanup PSDrive (AFTER all operations)
    if ($usePSDrive) {
        Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
    }
    
    Write-Log "Deployment abgeschlossen" -Level SUCCESS
    return $true
}

# Main Deployment
Write-Host "`n" -ForegroundColor Cyan
Write-Host "   CertWebService Deployment $Script:Version (PS7.x)         " -ForegroundColor Cyan
Write-Host "   Regelwerk $Script:Regelwerk                                 " -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host ""

# Network Share
if ($DeployToNetworkShare) {
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Log "NETWORK SHARE DEPLOYMENT" -Level INFO
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    
    $ok = Deploy-ToPath -Path $networkShare -Name "Network Share" -Credential $Credential
    if ($ok) {
        Write-Log "Network Share OK" -Level SUCCESS
    } else {
        Write-Log "Network Share FAILED" -Level ERROR
    }
}

# Servers
if ($Servers.Count -gt 0) {
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Log "SERVER DEPLOYMENT ($($Servers.Count) Servers)" -Level INFO
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    $okCnt = 0
    $failCnt = 0
    
    foreach ($srv in $Servers) {
        Write-Host "`n" + ("-" * 60) -ForegroundColor Gray
        Write-Log "Server: $srv" -Level INFO
        Write-Host ("-" * 60) -ForegroundColor Gray
        Write-Host ""
        
        if (-not (Test-Connection -ComputerName $srv -Count 1 -Quiet)) {
            Write-Log "Not reachable" -Level ERROR
            $failCnt++
            continue
        }
        Write-Log "Reachable" -Level SUCCESS
        
        # Get or prompt for credentials if needed
        $serverCred = $Credential
        if (-not $serverCred) {
            # Try to get stored credential
            if (Get-Command Get-SecureCredential -ErrorAction SilentlyContinue) {
                $serverCred = Get-SecureCredential -TargetName $srv -PromptIfNotFound
            }
            else {
                Write-Log "Credential module not available, prompting..." -Level WARN
                $serverCred = Get-Credential -Message "Credentials for $srv"
            }
        }
        
        $target = "\\$srv\c$\inetpub\wwwroot\CertWebService"
        $ok = Deploy-ToPath -Path $target -Name $srv -Credential $serverCred
        
        if ($ok) {
            $okCnt++
            
            if ($RunInitialScan) {
                Write-Host ""
                Write-Log "Running scan..." -Level INFO
                try {
                    Invoke-Command -ComputerName $srv -ScriptBlock {
                        $paths = @(
                            "C:\inetpub\wwwroot\CertWebService\ScanCertificates.ps1",
                            "C:\inetpub\CertWebService\ScanCertificates.ps1"
                        )
                        foreach ($p in $paths) {
                            if (Test-Path $p) {
                                & powershell.exe -ExecutionPolicy Bypass -File $p
                                return $?
                            }
                        }
                        return $false
                    } | Out-Null
                    Write-Log "Scan completed" -Level SUCCESS
                } catch {
                    Write-Log "Scan failed: $($_.Exception.Message)" -Level WARN
                }
            }
        } else {
            $failCnt++
        }
    }
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Log "SUMMARY" -Level INFO
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    Write-Log "Success: $okCnt" -Level SUCCESS
    if ($failCnt -gt 0) {
        Write-Log "Failed: $failCnt" -Level ERROR
    }
}

Write-Host "`n" -ForegroundColor Green
Write-Host "   DEPLOYMENT COMPLETED                                       " -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host ""
Write-Host " Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Setup Scheduled Task: .\Setup-ScheduledTask-CertScan.ps1" -ForegroundColor White
Write-Host "  2. Test API: Invoke-RestMethod http://SERVER:9080/certificates.json" -ForegroundColor White
Write-Host ""
