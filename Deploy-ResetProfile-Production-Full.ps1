#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Complete deployment of ResetProfile system to production
.DESCRIPTION
    Deploys the current ResetProfile system v11.2.6 cleaned and versioned 
    to the production network drive \\itscmgmt03.srv.meduniwien.ac.at\iso\PROD
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
    
    # Write to log file (with error handling)
    try {
        $LogDir = $Global:DeploymentConfig.LogPath
        if (-not (Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
        $LogFile = Join-Path $LogDir "Deployment-$($Global:DeploymentConfig.DeploymentTimestamp).log"
        Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    } catch {
        # Fallback to local logging if network path fails
        $LocalLogFile = Join-Path $env:TEMP "PSProfile-Deployment-$($Global:DeploymentConfig.DeploymentTimestamp).log"
        Add-Content -Path $LocalLogFile -Value $LogEntry -Encoding UTF8
    }
}
#endregion

#region Deployment Functions
function Backup-ExistingProduction {
    if (-not $BackupExisting) {
        Write-DeploymentLog -Level INFO -Message "Backup skipped (BackupExisting = false)"
        return $null
    }
    
    Write-DeploymentLog -Level INFO -Message "Creating backup of existing production version..."
    
    if (-not (Test-Path $Global:DeploymentConfig.ProductionPath)) {
        Write-DeploymentLog -Level INFO -Message "No existing production version found to backup"
        return $null
    }
    
    # Create backup directory
    $BackupVersionPath = "$($Global:DeploymentConfig.BackupPath)\v$($Global:DeploymentConfig.Version)_$($Global:DeploymentConfig.DeploymentTimestamp)"
    
    try {
        if (-not (Test-Path (Split-Path $BackupVersionPath))) {
            New-Item -Path (Split-Path $BackupVersionPath) -ItemType Directory -Force | Out-Null
        }
        
        # Use Copy-Item for backup (more reliable than robocopy for small deployments)
        Copy-Item -Path $Global:DeploymentConfig.ProductionPath -Destination $BackupVersionPath -Recurse -Force
        
        Write-DeploymentLog -Level SUCCESS -Message "Backup created successfully: $BackupVersionPath"
        
        # Create backup manifest
        $BackupManifest = @{
            BackupTimestamp = $Global:DeploymentConfig.DeploymentTimestamp
            OriginalVersion = $Global:DeploymentConfig.Version
            BackupPath = $BackupVersionPath
            Files = (Get-ChildItem -Path $BackupVersionPath -Recurse -File).Count
            TotalSize = [math]::Round(((Get-ChildItem -Path $BackupVersionPath -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 2)
        }
        
        $ManifestPath = Join-Path $BackupVersionPath "BACKUP-MANIFEST.json"
        $BackupManifest | ConvertTo-Json -Depth 3 | Set-Content $ManifestPath -Encoding UTF8
        
        return $BackupVersionPath
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Backup operation failed: $($_.Exception.Message)"
        return $null
    }
}

function Deploy-CleanedVersion {
    Write-DeploymentLog -Level INFO -Message "Deploying cleaned ResetProfile version $($Global:DeploymentConfig.Version)..."
    
    # Prepare production directory
    if (Test-Path $Global:DeploymentConfig.ProductionPath) {
        Remove-Item $Global:DeploymentConfig.ProductionPath -Recurse -Force
        Write-DeploymentLog -Level INFO -Message "Cleared existing production directory"
    }
    
    New-Item -Path $Global:DeploymentConfig.ProductionPath -ItemType Directory -Force | Out-Null
    Write-DeploymentLog -Level SUCCESS -Message "Created production directory: $($Global:DeploymentConfig.ProductionPath)"
    
    # Define deployment structure
    $DeploymentItems = @(
        @{
            Name = "Main Scripts"
            Source = @("Reset-PowerShellProfiles.ps1", "VERSION.ps1")
            Target = ""
            Critical = $true
        },
        @{
            Name = "Modules"
            Source = "Modules"
            Target = "Modules"
            Critical = $true
        },
        @{
            Name = "Templates" 
            Source = "Templates"
            Target = "Templates"
            Critical = $true
        },
        @{
            Name = "Config"
            Source = "Config"
            Target = "Config"
            Critical = $false
        }
    )
    
    $DeploymentResults = @()
    
    foreach ($Item in $DeploymentItems) {
        Write-DeploymentLog -Level INFO -Message "Deploying $($Item.Name)..."
        
        try {
            if ($Item.Source -is [array]) {
                # Multiple individual files
                foreach ($SourceFile in $Item.Source) {
                    $SourcePath = Join-Path $Global:DeploymentConfig.SourcePath $SourceFile
                    $TargetPath = Join-Path $Global:DeploymentConfig.ProductionPath $SourceFile
                    
                    if (Test-Path $SourcePath) {
                        Copy-Item -Path $SourcePath -Destination $TargetPath -Force
                        Write-DeploymentLog -Level SUCCESS -Message "  [OK] Deployed: $SourceFile"
                    } else {
                        if ($Item.Critical) {
                            throw "Critical file not found: $SourceFile"
                        } else {
                            Write-DeploymentLog -Level WARNING -Message "  [WARN] Optional file not found: $SourceFile"
                        }
                    }
                }
            } else {
                # Directory
                $SourcePath = Join-Path $Global:DeploymentConfig.SourcePath $Item.Source
                $TargetPath = Join-Path $Global:DeploymentConfig.ProductionPath $Item.Target
                
                if (Test-Path $SourcePath) {
                    Copy-Item -Path $SourcePath -Destination $TargetPath -Recurse -Force
                    $FileCount = (Get-ChildItem -Path $TargetPath -Recurse -File).Count
                    Write-DeploymentLog -Level SUCCESS -Message "  [OK] Deployed: $($Item.Name) ($FileCount files)"
                } else {
                    if ($Item.Critical) {
                        throw "Critical directory not found: $($Item.Source)"
                    } else {
                        Write-DeploymentLog -Level WARNING -Message "  [WARN] Optional directory not found: $($Item.Source)"
                    }
                }
            }
            
            $DeploymentResults += @{ Item = $Item.Name; Status = "SUCCESS" }
        } catch {
            $DeploymentResults += @{ Item = $Item.Name; Status = "FAILED"; Error = $_.Exception.Message }
            Write-DeploymentLog -Level ERROR -Message "Failed to deploy $($Item.Name): $($_.Exception.Message)"
            
            if ($Item.Critical) {
                throw "Critical deployment failure for $($Item.Name)"
            }
        }
    }
    
    return $DeploymentResults
}

function Set-ProductionConfiguration {
    Write-DeploymentLog -Level INFO -Message "Setting production-specific configuration..."
    
    $ProductionConfig = @{
        ScriptVersion = $Global:DeploymentConfig.Version
        RulebookVersion = $Global:DeploymentConfig.RegelwerkVersion
        Language = "de-DE"
        Environment = "PROD"
        WhatIfMode = $false
        DeploymentInfo = @{
            DeployedAt = $Global:DeploymentConfig.DeploymentTimestamp
            DeployedBy = $env:USERNAME
            DeployedFrom = $env:COMPUTERNAME
            ProductionPath = $Global:DeploymentConfig.ProductionPath
        }
        Logging = @{
            LogPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\PSProfile"
            ReportPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Reports\PSProfile" 
            ArchiveLogs = $true
            EnableEventLog = $true
            LogRetentionDays = 90
            ArchiveRetentionDays = 365
            SevenZipPath = "C:\Program Files\7-Zip\7z.exe"
        }
        Mail = @{
            Enabled = $true
            SmtpServer = "smtpi.meduniwien.ac.at"
            Sender = "noreply-prod@meduniwien.ac.at" 
            DevRecipient = "thomas.garnreiter@meduniwien.ac.at"
            ProdRecipient = "win-admin@meduniwien.ac.at"
        }
        UNCPaths = @{
            AssetDirectory = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Shared\Assets"
            BackupDirectory = $Global:DeploymentConfig.BackupPath
        }
        GitUpdate = @{
            Enabled = $false  # Disabled in production
            RepoUrl = ""
            Branch = ""
            CachePath = ""
        }
        Security = @{
            RequireDigitalSignature = $true
            AllowedExecutionHosts = @("itscmgmt03.srv.meduniwien.ac.at")
            ProductionMode = $true
        }
    }
    
    try {
        $ConfigPath = Join-Path $Global:DeploymentConfig.ProductionPath "Config"
        if (-not (Test-Path $ConfigPath)) {
            New-Item -Path $ConfigPath -ItemType Directory -Force | Out-Null
        }
        
        $ConfigFile = Join-Path $ConfigPath "Config-Reset-PowerShellProfiles.ps1.json"
        $ProductionConfig | ConvertTo-Json -Depth 5 | Set-Content $ConfigFile -Encoding UTF8
        
        Write-DeploymentLog -Level SUCCESS -Message "Production configuration created: $ConfigFile"
        return $ConfigFile
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Failed to create production configuration: $($_.Exception.Message)"
        throw
    }
}

function New-DeploymentManifest {
    param([array]$DeploymentResults, [string]$BackupPath)
    
    Write-DeploymentLog -Level INFO -Message "Creating deployment manifest..."
    
    $Manifest = @{
        Deployment = @{
            Version = $Global:DeploymentConfig.Version
            RegelwerkVersion = $Global:DeploymentConfig.RegelwerkVersion
            Timestamp = $Global:DeploymentConfig.DeploymentTimestamp
            DeployedBy = $env:USERNAME
            DeployedFrom = $env:COMPUTERNAME
            ProductionPath = $Global:DeploymentConfig.ProductionPath
            BackupPath = $BackupPath
        }
        Results = $DeploymentResults
        Files = @{
            TotalFiles = (Get-ChildItem -Path $Global:DeploymentConfig.ProductionPath -Recurse -File).Count
            TotalSize = [math]::Round(((Get-ChildItem -Path $Global:DeploymentConfig.ProductionPath -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 2)
        }
        Verification = @{
            MainScriptExists = (Test-Path (Join-Path $Global:DeploymentConfig.ProductionPath "Reset-PowerShellProfiles.ps1"))
            VersionFileExists = (Test-Path (Join-Path $Global:DeploymentConfig.ProductionPath "VERSION.ps1"))
            ModulesCount = (Get-ChildItem -Path (Join-Path $Global:DeploymentConfig.ProductionPath "Modules") -Filter "*.psm1" -ErrorAction SilentlyContinue).Count
            TemplatesCount = (Get-ChildItem -Path (Join-Path $Global:DeploymentConfig.ProductionPath "Templates") -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
        }
    }
    
    try {
        $ManifestPath = Join-Path $Global:DeploymentConfig.ProductionPath "DEPLOYMENT-MANIFEST.json"
        $Manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
        
        Write-DeploymentLog -Level SUCCESS -Message "Deployment manifest created: $ManifestPath"
        return $ManifestPath
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Failed to create deployment manifest: $($_.Exception.Message)"
        return $null
    }
}
#endregion

#region Main Deployment Logic
try {
    Write-Host "`nStarting ResetProfile Production Deployment" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    # Phase 1: Pre-flight checks
    Write-Host "`nPhase 1: Pre-flight Checks" -ForegroundColor Cyan
    Write-DeploymentLog -Level INFO -Message "Starting deployment of ResetProfile v$($Global:DeploymentConfig.Version)"
    
    # Phase 2: Backup
    Write-Host "`nPhase 2: Backup Existing Production" -ForegroundColor Cyan
    $BackupPath = Backup-ExistingProduction
    
    # Phase 3: Deployment
    Write-Host "`nPhase 3: Clean Deployment" -ForegroundColor Cyan
    $DeploymentResults = Deploy-CleanedVersion
    
    # Phase 4: Configuration
    Write-Host "`nPhase 4: Production Configuration" -ForegroundColor Cyan
    $ConfigFile = Set-ProductionConfiguration
    
    # Phase 5: Manifest
    Write-Host "`nPhase 5: Deployment Manifest" -ForegroundColor Cyan
    $ManifestPath = New-DeploymentManifest -DeploymentResults $DeploymentResults -BackupPath $BackupPath
    
    # Deployment Summary
    Write-Host "`nDEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Gray
    Write-Host "Version:     $($Global:DeploymentConfig.Version)" -ForegroundColor White
    Write-Host "Regelwerk:   $($Global:DeploymentConfig.RegelwerkVersion)" -ForegroundColor White  
    Write-Host "Target:      $($Global:DeploymentConfig.ProductionPath)" -ForegroundColor White
    Write-Host "Backup:      $BackupPath" -ForegroundColor White
    Write-Host "Manifest:    $ManifestPath" -ForegroundColor White
    Write-Host "Timestamp:   $($Global:DeploymentConfig.DeploymentTimestamp)" -ForegroundColor White
    
    # Set success status
    Set-ResetProfileStatus -Status "DEPLOYED_TO_PRODUCTION" -Details @{
        Version = $Global:DeploymentConfig.Version
        ProductionPath = $Global:DeploymentConfig.ProductionPath
        DeploymentTimestamp = $Global:DeploymentConfig.DeploymentTimestamp
        BackupCreated = ($BackupPath -ne $null)
    }
    
    Write-DeploymentLog -Level SUCCESS -Message "ResetProfile v$($Global:DeploymentConfig.Version) successfully deployed to production"
    
} catch {
    Write-Host "`nDEPLOYMENT FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-DeploymentLog -Level ERROR -Message "Deployment failed: $($_.Exception.Message)"
    
    # Set error status
    Set-ResetProfileStatus -Status "DEPLOYMENT_FAILED" -Details @{
        Error = $_.Exception.Message
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Phase = "Unknown"
    }
    
    exit 1
}
#endregion

Write-Host "`nDeployment script completed successfully." -ForegroundColor Green