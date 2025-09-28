#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Clean deployment of ResetProfile system to production
.DESCRIPTION
    Deploys the current ResetProfile system v11.2.6 cleaned and versioned 
    to the production network drive \\itscmgmt03.srv.meduniwien.ac.at\iso\PROD
.PARAMETER ValidateOnly
    Only perform validation, no actual deployment
.PARAMETER BackupExisting  
    Create backup of existing production version
.PARAMETER Force
    Perform deployment even with warnings
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: v1.0.0
    Regelwerk: v9.6.2
    Target: \\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$ValidateOnly,
    [switch]$BackupExisting = $true,
    [switch]$Force
)

# Load central version management
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Production Deployment" -CurrentVersion "v1.0.0"

#region Deployment Configuration
$Global:DeploymentConfig = @{
    SourcePath = $PSScriptRoot
    ProductionServer = "itscmgmt03.srv.meduniwien.ac.at"
    ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile"
    BackupPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Backup\PSProfile"
    LogPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\Deployment"
    Version = $ScriptVersion
    RegelwerkVersion = $RegelwerkVersion
    BuildDate = $BuildDate
    DeploymentTimestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
}

Write-Host "`nDeployment Configuration:" -ForegroundColor Cyan
Write-Host "   Source Version: $($Global:DeploymentConfig.Version)" -ForegroundColor Green  
Write-Host "   Regelwerk: $($Global:DeploymentConfig.RegelwerkVersion)" -ForegroundColor Green
Write-Host "   Target: $($Global:DeploymentConfig.ProductionPath)" -ForegroundColor Yellow
Write-Host "   Backup: $($BackupExisting)" -ForegroundColor $(if($BackupExisting){'Green'}else{'Red'})
#endregion

#region Logging Functions
function Write-DeploymentLog {
    param(
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level,
        [string]$Message
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Console Output with colors
    $Color = switch ($Level) {
        'INFO' { 'White' }
        'WARNING' { 'Yellow' }  
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
    }
    Write-Host $LogEntry -ForegroundColor $Color
    
    # Write to log file
    try {
        $LogDir = $Global:DeploymentConfig.LogPath
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
        $LogFile = Join-Path $LogDir "Deployment-$($Global:DeploymentConfig.DeploymentTimestamp).log"
        Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    } catch {
        Write-Warning "Failed to write to deployment log: $($_.Exception.Message)"
    }
}
#endregion

#region Validation Functions
function Test-ProductionAccess {
    Write-DeploymentLog -Level INFO -Message "Testing production network access..."
    
    $ValidationResults = @{
        ServerReachable = $false
        ProductionPathAccessible = $false
        WritePermissions = $false
        BackupPathAccessible = $false
        Score = 0
        MaxScore = 4
    }
    
    # Server ping
    try {
        $PingResult = Test-Connection -ComputerName $Global:DeploymentConfig.ProductionServer -Count 2 -Quiet
        $ValidationResults.ServerReachable = $PingResult
        if ($PingResult) { 
            $ValidationResults.Score++
            Write-DeploymentLog -Level SUCCESS -Message "Server $($Global:DeploymentConfig.ProductionServer) is reachable"
        } else {
            Write-DeploymentLog -Level ERROR -Message "Server $($Global:DeploymentConfig.ProductionServer) is not reachable"
        }
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Server ping failed: $($_.Exception.Message)"
    }
    
    # Production path access
    try {
        $ProductionPathExists = Test-Path $Global:DeploymentConfig.ProductionPath
        $ValidationResults.ProductionPathAccessible = $ProductionPathExists
        if ($ProductionPathExists) {
            $ValidationResults.Score++
            Write-DeploymentLog -Level SUCCESS -Message "Production path accessible: $($Global:DeploymentConfig.ProductionPath)"
        } else {
            Write-DeploymentLog -Level WARNING -Message "Production path not found (will be created): $($Global:DeploymentConfig.ProductionPath)"
        }
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Production path test failed: $($_.Exception.Message)"
    }
    
    # Test write permissions
    try {
        $TestDir = Split-Path $Global:DeploymentConfig.ProductionPath
        $TestFile = Join-Path $TestDir "deployment_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        "Deployment test" | Out-File $TestFile -ErrorAction Stop
        Remove-Item $TestFile -Force -ErrorAction SilentlyContinue
        
        $ValidationResults.WritePermissions = $true
        $ValidationResults.Score++
        Write-DeploymentLog -Level SUCCESS -Message "Write permissions confirmed"
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Write permission test failed: $($_.Exception.Message)"
    }
    
    # Backup path access  
    try {
        $BackupDir = Split-Path $Global:DeploymentConfig.BackupPath
        if (-not (Test-Path $BackupDir)) {
            New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
        }
        $ValidationResults.BackupPathAccessible = Test-Path $BackupDir
        if ($ValidationResults.BackupPathAccessible) {
            $ValidationResults.Score++
            Write-DeploymentLog -Level SUCCESS -Message "Backup path accessible: $BackupDir"
        }
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Backup path test failed: $($_.Exception.Message)"
    }
    
    # Validation result
    $SuccessPercentage = [math]::Round(($ValidationResults.Score / $ValidationResults.MaxScore) * 100)
    Write-Host "`nProduction Access Validation: $($ValidationResults.Score)/$($ValidationResults.MaxScore) ($SuccessPercentage%)" -ForegroundColor Cyan
    
    if ($ValidationResults.Score -lt 3 -and -not $Force) {
        throw "Production access validation failed. Use -Force to override."
    }
    
    return $ValidationResults
}

function Test-SourceIntegrity {
    Write-DeploymentLog -Level INFO -Message "Testing source code integrity..."
    
    $IntegrityResults = @{
        RequiredFiles = @()
        MissingFiles = @()
        ModulesCount = 0
        TemplatesCount = 0
        Score = 0
    }
    
    # Required main files
    $RequiredFiles = @(
        "Reset-PowerShellProfiles.ps1",
        "VERSION.ps1"
    )
    
    foreach ($File in $RequiredFiles) {
        $FilePath = Join-Path $Global:DeploymentConfig.SourcePath $File
        if (Test-Path $FilePath) {
            $IntegrityResults.RequiredFiles += $File
            $IntegrityResults.Score++
            Write-DeploymentLog -Level SUCCESS -Message "Required file found: $File"
        } else {
            $IntegrityResults.MissingFiles += $File
            Write-DeploymentLog -Level ERROR -Message "Required file missing: $File"
        }
    }
    
    # Check modules
    $ModulesPath = Join-Path $Global:DeploymentConfig.SourcePath "Modules"
    if (Test-Path $ModulesPath) {
        $ModuleFiles = Get-ChildItem -Path $ModulesPath -Filter "FL-*.psm1"
        $IntegrityResults.ModulesCount = $ModuleFiles.Count
        $IntegrityResults.Score += [math]::Min($ModuleFiles.Count, 5)  # Max 5 points for modules
        Write-DeploymentLog -Level SUCCESS -Message "Found $($ModuleFiles.Count) FL-modules"
    }
    
    # Check templates
    $TemplatesPath = Join-Path $Global:DeploymentConfig.SourcePath "Templates"
    if (Test-Path $TemplatesPath) {
        $TemplateFiles = Get-ChildItem -Path $TemplatesPath -Filter "Profile-template*.ps1"
        $IntegrityResults.TemplatesCount = $TemplateFiles.Count
        $IntegrityResults.Score += [math]::Min($TemplateFiles.Count, 3)  # Max 3 points for templates
        Write-DeploymentLog -Level SUCCESS -Message "Found $($TemplateFiles.Count) profile templates"
    }
    
    Write-DeploymentLog -Level INFO -Message "Source integrity check completed. Score: $($IntegrityResults.Score)"
    
    if ($IntegrityResults.MissingFiles.Count -gt 0 -and -not $Force) {
        throw "Source integrity check failed. Missing files: $($IntegrityResults.MissingFiles -join ', ')"
    }
    
    return $IntegrityResults
}
#endregion

#region Main Deployment Logic
try {
    Write-Host "`nStarting ResetProfile Production Deployment" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    # Phase 1: Validation
    Write-Host "`nPhase 1: Pre-Deployment Validation" -ForegroundColor Cyan
    $AccessValidation = Test-ProductionAccess
    $SourceValidation = Test-SourceIntegrity
    
    if ($ValidateOnly) {
        Write-Host "`nValidation completed successfully!" -ForegroundColor Green
        Write-Host "Use -ValidateOnly:`$false to proceed with deployment." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`nDeployment validation passed. Ready to proceed!" -ForegroundColor Green
    
} catch {
    Write-Host "`nDEPLOYMENT VALIDATION FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-DeploymentLog -Level ERROR -Message "Deployment validation failed: $($_.Exception.Message)"
    exit 1
}
#endregion

Write-Host "`nDeployment script completed validation phase." -ForegroundColor Green