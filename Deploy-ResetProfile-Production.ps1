#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Bereinigtes Deployment des ResetProfile-Systems zur Produktion
    Clean deployment of ResetProfile system to production
.DESCRIPTION
    Deployed das aktuelle ResetProfile-System v11.2.6 bereinigt und versioniert 
    auf das Produktions-Netzlaufwerk \\itscmgmt03.srv.meduniwien.ac.at\iso\PROD
    
    Deploys the current ResetProfile system v11.2.6 cleaned and versioned 
    to the production network drive \\itscmgmt03.srv.meduniwien.ac.at\iso\PROD
.PARAMETER ValidateOnly
    Nur Validierung durchführen, kein tatsächliches Deployment
    Only perform validation, no actual deployment
.PARAMETER BackupExisting  
    Backup der bestehenden Produktionsversion erstellen
    Create backup of existing production version
.PARAMETER Force
    Deployment auch bei Warnungen durchführen
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

# Zentrale Versionsverwaltung laden | Load central version management
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Production Deployment" -CurrentVersion "v1.0.0"

#region Deployment Configuration | Deployment-Konfiguration
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

Write-Host "`n🎯 Deployment Configuration:" -ForegroundColor Cyan
Write-Host "   Source Version: $($Global:DeploymentConfig.Version)" -ForegroundColor Green  
Write-Host "   Regelwerk: $($Global:DeploymentConfig.RegelwerkVersion)" -ForegroundColor Green
Write-Host "   Target: $($Global:DeploymentConfig.ProductionPath)" -ForegroundColor Yellow
Write-Host "   Backup: $($BackupExisting)" -ForegroundColor $(if($BackupExisting){'Green'}else{'Red'})
#endregion

#region Logging Functions | Logging-Funktionen
function Write-DeploymentLog {
    param(
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level,
        [string]$Message
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Console Output mit Farben | Console output with colors
    $Color = switch ($Level) {
        'INFO' { 'White' }
        'WARNING' { 'Yellow' }  
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
    }
    Write-Host $LogEntry -ForegroundColor $Color
    
    # Log-Datei schreiben | Write to log file
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

#region Validation Functions | Validierungsfunktionen
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
    
    # Server-Ping | Server ping
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
    
    # Produktionspfad-Zugriff | Production path access
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
    
    # Schreibberechtigungen testen | Test write permissions
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
    
    # Backup-Pfad-Zugriff | Backup path access  
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
    
    # Validierungsergebnis | Validation result
    $SuccessPercentage = [math]::Round(($ValidationResults.Score / $ValidationResults.MaxScore) * 100)
    Write-Host "`n📊 Production Access Validation: $($ValidationResults.Score)/$($ValidationResults.MaxScore) ($SuccessPercentage%)" -ForegroundColor Cyan
    
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
        ConfigsCount = 0
        Score = 0
    }
    
    # Erforderliche Hauptdateien | Required main files
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
    
    # Module prüfen | Check modules
    $ModulesPath = Join-Path $Global:DeploymentConfig.SourcePath "Modules"
    if (Test-Path $ModulesPath) {
        $ModuleFiles = Get-ChildItem -Path $ModulesPath -Filter "FL-*.psm1"
        $IntegrityResults.ModulesCount = $ModuleFiles.Count
        $IntegrityResults.Score += [math]::Min($ModuleFiles.Count, 5)  # Max 5 points for modules
        Write-DeploymentLog -Level SUCCESS -Message "Found $($ModuleFiles.Count) FL-modules"
    }
    
    # Templates prüfen | Check templates
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

#region Deployment Functions | Deployment-Funktionen  
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
    
    # Backup-Verzeichnis erstellen | Create backup directory
    $BackupVersionPath = "$($Global:DeploymentConfig.BackupPath)\v$($Global:DeploymentConfig.Version)_$($Global:DeploymentConfig.DeploymentTimestamp)"
    
    try {
        if (-not (Test-Path (Split-Path $BackupVersionPath))) {
            New-Item -Path (Split-Path $BackupVersionPath) -ItemType Directory -Force | Out-Null
        }
        
        # Robocopy für Enterprise-Backup | Robocopy for enterprise backup
        $RobocopyArgs = @(
            $Global:DeploymentConfig.ProductionPath
            $BackupVersionPath
            '/MIR'
            '/R:3'
            '/W:10'
            '/NP'
            '/LOG+:C:\Temp\Deployment-Backup.log'
        )
        
        $RobocopyResult = & robocopy @RobocopyArgs
        $RobocopyExitCode = $LASTEXITCODE
        
        # Robocopy Exit Codes: 0-7 sind erfolgreiche Codes | 0-7 are successful codes
        if ($RobocopyExitCode -le 7) {
            Write-DeploymentLog -Level SUCCESS -Message "Backup created successfully: $BackupVersionPath"
            
            # Backup-Manifest erstellen | Create backup manifest
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
        } else {
            Write-DeploymentLog -Level ERROR -Message "Backup failed with Robocopy exit code: $RobocopyExitCode"
            return $null
        }
    } catch {
        Write-DeploymentLog -Level ERROR -Message "Backup operation failed: $($_.Exception.Message)"
        return $null
    }
}

function Deploy-CleanedVersion {
    Write-DeploymentLog -Level INFO -Message "Deploying cleaned ResetProfile version $($Global:DeploymentConfig.Version)..."
    
    # Produktionsverzeichnis vorbereiten | Prepare production directory
    if (Test-Path $Global:DeploymentConfig.ProductionPath) {
        Remove-Item $Global:DeploymentConfig.ProductionPath -Recurse -Force
        Write-DeploymentLog -Level INFO -Message "Cleared existing production directory"
    }
    
    New-Item -Path $Global:DeploymentConfig.ProductionPath -ItemType Directory -Force | Out-Null
    Write-DeploymentLog -Level SUCCESS -Message "Created production directory: $($Global:DeploymentConfig.ProductionPath)"
    
    # Deployment-Struktur definieren | Define deployment structure
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
                # Multiple einzelne Dateien | Multiple individual files
                foreach ($SourceFile in $Item.Source) {
                    $SourcePath = Join-Path $Global:DeploymentConfig.SourcePath $SourceFile
                    $TargetPath = Join-Path $Global:DeploymentConfig.ProductionPath $SourceFile
                    
                    if (Test-Path $SourcePath) {
                        Copy-Item -Path $SourcePath -Destination $TargetPath -Force
                        Write-DeploymentLog -Level SUCCESS -Message "  ✅ Deployed: $SourceFile"
                    } else {
                        if ($Item.Critical) {
                            throw "Critical file not found: $SourceFile"
                        } else {
                            Write-DeploymentLog -Level WARNING -Message "  ⚠️  Optional file not found: $SourceFile"
                        }
                    }
                }
            } else {
                # Verzeichnis | Directory
                $SourcePath = Join-Path $Global:DeploymentConfig.SourcePath $Item.Source
                $TargetPath = Join-Path $Global:DeploymentConfig.ProductionPath $Item.Target
                
                if (Test-Path $SourcePath) {
                    Copy-Item -Path $SourcePath -Destination $TargetPath -Recurse -Force
                    $FileCount = (Get-ChildItem -Path $TargetPath -Recurse -File).Count
                    Write-DeploymentLog -Level SUCCESS -Message "  ✅ Deployed: $($Item.Name) ($FileCount files)"
                } else {
                    if ($Item.Critical) {
                        throw "Critical directory not found: $($Item.Source)"
                    } else {
                        Write-DeploymentLog -Level WARNING -Message "  ⚠️  Optional directory not found: $($Item.Source)"
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

#region Main Deployment Logic | Haupt-Deployment-Logik
try {
    Write-Host "`n🚀 Starting ResetProfile Production Deployment" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Gray
    
    # Phase 1: Validation | Phase 1: Validierung
    Write-Host "`n📋 Phase 1: Pre-Deployment Validation" -ForegroundColor Cyan
    $AccessValidation = Test-ProductionAccess
    $SourceValidation = Test-SourceIntegrity
    
    if ($ValidateOnly) {
        Write-Host "`n✅ Validation completed successfully!" -ForegroundColor Green
        Write-Host "Use -ValidateOnly:`$false to proceed with deployment." -ForegroundColor Yellow
        exit 0
    }
    
    # Phase 2: Backup | Phase 2: Backup
    Write-Host "`n💾 Phase 2: Backup Existing Production" -ForegroundColor Cyan
    $BackupPath = Backup-ExistingProduction
    
    # Phase 3: Deployment | Phase 3: Deployment
    Write-Host "`n📦 Phase 3: Clean Deployment" -ForegroundColor Cyan
    $DeploymentResults = Deploy-CleanedVersion
    
    # Phase 4: Configuration | Phase 4: Konfiguration
    Write-Host "`n⚙️  Phase 4: Production Configuration" -ForegroundColor Cyan
    $ConfigFile = Set-ProductionConfiguration
    
    # Phase 5: Manifest | Phase 5: Manifest
    Write-Host "`n📄 Phase 5: Deployment Manifest" -ForegroundColor Cyan
    $ManifestPath = New-DeploymentManifest -DeploymentResults $DeploymentResults -BackupPath $BackupPath
    
    # Deployment Summary | Deployment-Zusammenfassung
    Write-Host "`n🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Gray
    Write-Host "Version:     $($Global:DeploymentConfig.Version)" -ForegroundColor White
    Write-Host "Regelwerk:   $($Global:DeploymentConfig.RegelwerkVersion)" -ForegroundColor White  
    Write-Host "Target:      $($Global:DeploymentConfig.ProductionPath)" -ForegroundColor White
    Write-Host "Backup:      $BackupPath" -ForegroundColor White
    Write-Host "Manifest:    $ManifestPath" -ForegroundColor White
    Write-Host "Timestamp:   $($Global:DeploymentConfig.DeploymentTimestamp)" -ForegroundColor White
    
    # Erfolgs-Status setzen | Set success status
    Set-ResetProfileStatus -Status "DEPLOYED_TO_PRODUCTION" -Details @{
        Version = $Global:DeploymentConfig.Version
        ProductionPath = $Global:DeploymentConfig.ProductionPath
        DeploymentTimestamp = $Global:DeploymentConfig.DeploymentTimestamp
        BackupCreated = ($BackupPath -ne $null)
    }
    
    Write-DeploymentLog -Level SUCCESS -Message "ResetProfile v$($Global:DeploymentConfig.Version) successfully deployed to production"
    
} catch {
    Write-Host "`n❌ DEPLOYMENT FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-DeploymentLog -Level ERROR -Message "Deployment failed: $($_.Exception.Message)"
    
    # Fehler-Status setzen | Set error status
    Set-ResetProfileStatus -Status "DEPLOYMENT_FAILED" -Details @{
        Error = $_.Exception.Message
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Phase = "Unknown"
    }
    
    exit 1
}
#endregion

# Ende des Deployment-Scripts | End of deployment script
Write-Host "`n✅ Deployment script completed." -ForegroundColor Green