# PSProfile - PowerShell Profile Management System
*MUW-Regelwerk konformes PowerShell Profilverwaltungssystem | MUW-Regelwerk compliant PowerShell profile management system*

## Multi-Repository Entwicklungsumgebung | Multi-Repository Development Environment

Diese Codebase ist Teil eines größeren Enterprise-Ökosystems:
This codebase is part of a larger enterprise ecosystem:

```
f:\DEV\repositories\
├── CertSurv/           # Zertifikatüberwachungssystem | Certificate surveillance system
├── CertWebService/     # Web Service Komponente | Web service component
├── GitCache/           # Git-Cache System für Template-Sync | Git cache system for template sync
├── PSProfile/          # DIESES Repository | THIS repository
├── ResetProfile/       # Legacy Profile Reset System | Legacy profile reset system
├── Tests/              # Cross-Repository Tests | Cross-repository tests
└── Useranlage/         # Benutzeranlage System | User provisioning system
```

### Production Network Deployment | Produktions-Netzwerk-Deployment
**KRITISCH**: Produktive Scripts werden auf dem Netzwerkpfad bereitgestellt:
**CRITICAL**: Production scripts are deployed to the network path:

```
\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\
├── PSProfile\          # Produktive PowerShell Profile Scripts
├── CertSurv\           # Produktive Zertifikatüberwachung
├── CertWebService\     # Produktive Web Services  
└── Shared\             # Gemeinsame Ressourcen und Templates
```

### Cross-Repository-Workflows | Cross-Repository Workflows
```powershell
# Repository-übergreifende Kommunikation | Cross-repository communication
Send-CrossRepoMessage -SourceRepo "PSProfile" -TargetRepo "CertSurv" -Message "Profile updated"

# Zentrale Git-Synchronisation | Central Git synchronization
.\GitCache\Sync-AllRepositories.ps1 -RepositoryList @("PSProfile", "CertSurv", "CertWebService")

# Übergreifende Tests ausführen | Run cross-repository tests
.\Tests\Run-All-Tests.ps1 -IncludeRepos @("PSProfile", "CertSurv")
```

## Systemarchitektur | System Architecture

Dies ist ein **MUW-Regelwerk v9.6.2 konformes** Enterprise PowerShell Profilverwaltungssystem mit WPF GUI, Netzwerk-Deployment und Enterprise-Features.

This is a **MUW-Regelwerk v9.6.2 compliant** enterprise PowerShell profile management system with WPF GUI, network deployment, and enterprise features.

### Kernkomponenten | Core Components

- **`Reset-PowerShellProfiles.ps1`**: Haupt-Orchestrator Script das Module lädt, Konfiguration verwaltet und PowerShell Profile mit Templates zurücksetzt | Main orchestrator script that loads modules, manages configuration, and resets PowerShell profiles using templates
- **`VERSION.ps1`**: Zentrale Versionsverwaltung mit `$ScriptVersion`, `$RegelwerkVersion` und Cross-Script-Kommunikationsfunktionen | Centralized version management with cross-script communication functions 
- **`Modules/FL-*.psm1`**: Modulare Architektur mit Config, Logging, GUI, Maintenance und Utils Modulen | Modular architecture with Config, Logging, GUI, Maintenance, and Utils modules
- **`Templates/`**: PowerShell Profil-Templates (Profile-template.ps1, Profile-templateX.ps1, Profile-templateMOD.ps1) | PowerShell profile templates
- **`Config/`**: JSON Konfigurationen, Lokalisierungsdateien (de-DE.json, en-US.json) und GUI Assets | JSON configurations, localization files, and GUI assets

## Enterprise Deployment Patterns

### Produktions-Deployment auf Netzwerkpfad | Production Deployment to Network Path
**Standard-Produktionspfad**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\`

```powershell
# Produktions-Deployment-Pattern | Production deployment pattern
function Deploy-ToProduction {
    param(
        [string]$ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile",
        [switch]$ValidateOnly,
        [switch]$BackupExisting
    )
    
    # Pre-Deployment-Validierung | Pre-deployment validation
    Test-NetworkPath -Path $ProductionPath -RequiredPermissions @('Read','Write','Execute')
    Test-ProductionReadiness -SourcePath $Global:ScriptDirectory
    
    if ($BackupExisting) {
        # Existing production version backup | Backup der bestehenden Produktionsversion
        $BackupPath = "$ProductionPath\.backup\$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        New-Item -Path $BackupPath -ItemType Directory -Force
        Copy-Item "$ProductionPath\*" $BackupPath -Recurse -Force
        Write-Log -Level INFO -Message "Production backup created: $BackupPath"
    }
    
    if ($ValidateOnly) {
        Write-Host "✅ Deployment validation passed. Use -ValidateOnly:$false to deploy." -ForegroundColor Green
        return
    }
    
    # Deployment zur Produktion | Deployment to production
    $DeploymentItems = @(
        @{ Source = "Reset-PowerShellProfiles.ps1"; Target = "$ProductionPath\Reset-PowerShellProfiles.ps1" }
        @{ Source = "VERSION.ps1"; Target = "$ProductionPath\VERSION.ps1" }
        @{ Source = "Modules\"; Target = "$ProductionPath\Modules\" }
        @{ Source = "Templates\"; Target = "$ProductionPath\Templates\" }
        @{ Source = "Config\"; Target = "$ProductionPath\Config\" }
    )
    
    foreach ($Item in $DeploymentItems) {
        $SourcePath = Join-Path $Global:ScriptDirectory $Item.Source
        Copy-Item -Path $SourcePath -Destination $Item.Target -Recurse -Force
        Write-Log -Level INFO -Message "Deployed: $($Item.Source) -> $($Item.Target)"
    }
    
    # Produktions-Konfiguration setzen | Set production configuration
    Set-ProductionConfiguration -ConfigPath "$ProductionPath\Config"
    
    Write-Log -Level INFO -Message "Successfully deployed PSProfile to production: $ProductionPath"
}
```

### Netzwerk-basierte Script-Ausführung | Network-based Script Execution
```powershell
# Scripts vom Produktionspfad ausführen | Execute scripts from production path
function Invoke-ProductionScript {
    param(
        [string]$ScriptName = "Reset-PowerShellProfiles.ps1",
        [hashtable]$Parameters = @{},
        [string]$ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile"
    )
    
    # Netzwerkpfad-Zugriff validieren | Validate network path access
    if (-not (Test-Path $ProductionPath)) {
        throw "Production path not accessible: $ProductionPath"
    }
    
    $ScriptFullPath = Join-Path $ProductionPath $ScriptName
    
    # Execution Policy für Netzwerk-Scripts | Execution policy for network scripts
    $CurrentPolicy = Get-ExecutionPolicy
    if ($CurrentPolicy -eq 'Restricted') {
        Write-Warning "ExecutionPolicy is Restricted. Script execution may fail."
    }
    
    # Script mit Parametern ausführen | Execute script with parameters
    try {
        & $ScriptFullPath @Parameters
        Write-Log -Level INFO -Message "Successfully executed production script: $ScriptName"
    } catch {
        Write-Log -Level ERROR -Message "Failed to execute production script $ScriptName`: $($_.Exception.Message)"
        throw
    }
}
```

### Shared Resources Management | Verwaltung geteilter Ressourcen
```powershell
# Gemeinsame Ressourcen auf Netzwerkpfad verwalten | Manage shared resources on network path
function Sync-SharedResources {
    param(
        [string]$SharedPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Shared",
        [string[]]$ResourceTypes = @("Templates", "Configs", "Assets")
    )
    
    foreach ($ResourceType in $ResourceTypes) {
        $SourcePath = Join-Path $Global:ScriptDirectory $ResourceType
        $TargetPath = Join-Path $SharedPath $ResourceType
        
        if (Test-Path $SourcePath) {
            # Robocopy für Enterprise-Synchronisation | Robocopy for enterprise synchronization
            $RobocopyArgs = @(
                $SourcePath
                $TargetPath
                '/MIR'           # Mirror directory tree
                '/R:3'           # Retry 3 times on failure
                '/W:10'          # Wait 10 seconds between retries
                '/LOG+:C:\Logs\ResourceSync.log'
                '/TEE'           # Output to console and log
            )
            
            & robocopy @RobocopyArgs
            Write-Log -Level INFO -Message "Synchronized $ResourceType to shared path"
        }
    }
}
```

### Production Configuration Management | Produktions-Konfigurationsverwaltung
```powershell
# Produktions-spezifische Konfiguration | Production-specific configuration
function Set-ProductionConfiguration {
    param([string]$ConfigPath)
    
    $ProductionConfig = @{
        Environment = "PROD"
        WhatIfMode = $false
        Logging = @{
            LogPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\PSProfile"
            EnableEventLog = $true
            LogRetentionDays = 90
            ArchiveRetentionDays = 365
        }
        Mail = @{
            Enabled = $true
            SmtpServer = "smtpi.meduniwien.ac.at"
            Sender = "noreply-prod@meduniwien.ac.at"
            ProdRecipient = "win-admin@meduniwien.ac.at"
        }
        UNCPaths = @{
            AssetDirectory = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Shared\Assets"
            BackupDirectory = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Backup"
        }
        Security = @{
            RequireDigitalSignature = $true
            AllowedExecutionHosts = @("itscmgmt03.srv.meduniwien.ac.at")
        }
    }
    
    $ConfigFile = Join-Path $ConfigPath "Config-Production.json"
    $ProductionConfig | ConvertTo-Json -Depth 5 | Set-Content $ConfigFile -Encoding UTF8
    
    Write-Log -Level INFO -Message "Production configuration created: $ConfigFile"
}
```

### Network Path Access Validation | Netzwerkpfad-Zugriff-Validierung
```powershell
# Netzwerkpfad-Zugriff und Berechtigungen prüfen | Validate network path access and permissions
function Test-ProductionNetworkAccess {
    param(
        [string]$ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD",
        [string[]]$RequiredPaths = @("PSProfile", "Shared", "Logs", "Backup")
    )
    
    $ValidationResults = @{
        ServerReachable = $false
        PathAccessible = @{}
        Permissions = @{}
        TotalScore = 0
        MaxScore = 0
    }
    
    # Server-Erreichbarkeit prüfen | Test server reachability
    try {
        $ServerName = "itscmgmt03.srv.meduniwien.ac.at"
        $PingResult = Test-Connection -ComputerName $ServerName -Count 1 -Quiet
        $ValidationResults.ServerReachable = $PingResult
        if ($PingResult) { $ValidationResults.TotalScore++ }
        $ValidationResults.MaxScore++
        
        Write-Log -Level INFO -Message "Server reachability: $PingResult"
    } catch {
        Write-Log -Level ERROR -Message "Server ping failed: $($_.Exception.Message)"
    }
    
    # Pfad-Zugriff prüfen | Test path access
    foreach ($Path in $RequiredPaths) {
        $FullPath = Join-Path $ProductionPath $Path
        $ValidationResults.MaxScore++
        
        try {
            $PathExists = Test-Path $FullPath
            $ValidationResults.PathAccessible[$Path] = $PathExists
            if ($PathExists) { $ValidationResults.TotalScore++ }
            
            # Berechtigungen testen | Test permissions
            if ($PathExists) {
                $ValidationResults.MaxScore += 3  # Read, Write, Execute
                
                # Read-Berechtigung | Read permission
                try {
                    Get-ChildItem $FullPath -ErrorAction Stop | Out-Null
                    $ValidationResults.Permissions["$Path-Read"] = $true
                    $ValidationResults.TotalScore++
                } catch {
                    $ValidationResults.Permissions["$Path-Read"] = $false
                }
                
                # Write-Berechtigung | Write permission
                try {
                    $TestFile = Join-Path $FullPath "test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
                    "test" | Out-File $TestFile -ErrorAction Stop
                    Remove-Item $TestFile -Force -ErrorAction SilentlyContinue
                    $ValidationResults.Permissions["$Path-Write"] = $true
                    $ValidationResults.TotalScore++
                } catch {
                    $ValidationResults.Permissions["$Path-Write"] = $false
                }
                
                # Execute-Berechtigung (für Script-Pfade) | Execute permission (for script paths)
                if ($Path -eq "PSProfile") {
                    try {
                        $TestScript = Join-Path $FullPath "VERSION.ps1"
                        if (Test-Path $TestScript) {
                            # Nur Syntax-Check, nicht ausführen | Syntax check only, don't execute
                            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $TestScript -Raw), [ref]$null)
                            $ValidationResults.Permissions["$Path-Execute"] = $true
                            $ValidationResults.TotalScore++
                        }
                    } catch {
                        $ValidationResults.Permissions["$Path-Execute"] = $false
                    }
                } else {
                    $ValidationResults.TotalScore++  # Non-script paths automatically pass execute test
                }
            }
            
            Write-Log -Level INFO -Message "Path validation for $FullPath`: Accessible=$PathExists"
        } catch {
            $ValidationResults.PathAccessible[$Path] = $false
            Write-Log -Level ERROR -Message "Path access test failed for $FullPath`: $($_.Exception.Message)"
        }
    }
    
    # Validierungsergebnis ausgeben | Output validation result
    $SuccessPercentage = [math]::Round(($ValidationResults.TotalScore / $ValidationResults.MaxScore) * 100)
    Write-Host "`n📊 Production Network Access Validation" -ForegroundColor Cyan
    Write-Host "Score: $($ValidationResults.TotalScore)/$($ValidationResults.MaxScore) ($SuccessPercentage%)" -ForegroundColor $(if ($SuccessPercentage -ge 80) { "Green" } elseif ($SuccessPercentage -ge 60) { "Yellow" } else { "Red" })
    
    return $ValidationResults
}
```

## MUW-Regelwerk v9.6.2 Compliance Patterns

### §1-§6: Basis-Compliance (PFLICHT) | Basic Compliance (MANDATORY)
```powershell
# §1: Versionsverwaltung - Jedes Script MUSS VERSION.ps1 laden | Version management - Every script MUST load VERSION.ps1
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo -ScriptName "Your Script" -CurrentVersion $ScriptVersion

# §2: UTF-8 Encoding erzwingen | Force UTF-8 encoding
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# §3: Admin-Rechte für kritische Operationen | Admin rights for critical operations
#requires -RunAsAdministrator

# §4: Strukturierte Fehlerbehandlung | Structured error handling
try {
    # Kritische Operation | Critical operation
} catch {
    Write-Log -Level ERROR -Message "Operation failed: $($_.Exception.Message)"
    throw
}

# §5: Logging-Standard einhalten | Follow logging standard
Write-Log -Level INFO -Message "Script started: $($MyInvocation.MyCommand.Name)"

# §6: Konfigurationsverwaltung | Configuration management
$Global:Config = Get-Config -Path $Global:ConfigFile
Invoke-VersionControl -LoadedConfig $Global:Config -Path $Global:ConfigFile
```

### §7: PowerShell 5.1/7.x Kompatibilität (KRITISCH) | PowerShell 5.1/7.x Compatibility (CRITICAL)
```powershell
# Unicode-Kompatibilitätsprüfung | Unicode compatibility check
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PowerShell 7.x - Unicode-Emojis erlaubt | Unicode emojis allowed
    Write-Host "🚀 $ScriptName v$CurrentVersion" -ForegroundColor Green
    Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
} else {
    # PowerShell 5.1 - ASCII-Alternativen verwenden | Use ASCII alternatives
    Write-Host ">> $ScriptName v$CurrentVersion" -ForegroundColor Green
    Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
}
```

### §8: E-Mail-Integration mit dynamischer Sender-Adresse | Email Integration with Dynamic Sender Address
```powershell
# Regelwerk v9.6.2 §8: Dynamische Sender-Adresse | Dynamic sender address
function Send-MailNotification {
    param([string]$Subject, [string]$Body)
    
    # Umgebungsbasierte Sender-Adresse | Environment-based sender address
    $SenderAddress = if ($Global:Config.Environment -eq "DEV") {
        "${env:computername}@meduniwien.ac.at"
    } else {
        "noreply-prod@meduniwien.ac.at"
    }
    
    Send-MailMessage -SmtpServer $Global:Config.Mail.SmtpServer `
                     -From $SenderAddress `
                     -To $Recipient `
                     -Subject $Subject `
                     -Body $Body
}
```

### Cross-Script-Kommunikation (§9) | Cross-Script Communication (§9)
```powershell
# Nachricht an andere Scripts senden | Send message to other scripts
Send-ResetProfileMessage -TargetScript "CertSurv" -Message "Profile reset completed" -Type "SUCCESS"

# Script-Status für Monitoring setzen | Set script status for monitoring
Set-ResetProfileStatus -Status "RUNNING" -Details @{
    Phase = "TemplateProcessing"
    Timestamp = Get-Date
    RegelwerkVersion = $RegelwerkVersion
}

# Status von anderen Scripts abfragen | Query status from other scripts
$CertSurvStatus = Get-ScriptStatus -ScriptName "Cert-Surveillance-Main.ps1"
```

## Zentrale Logging-Architektur | Centralized Logging Architecture

### Cross-System Log-Aggregation mit Production Path Integration
```powershell
# Zentrale Log-Sammlung für Enterprise-Monitoring | Central log collection for enterprise monitoring
function Write-CentralLog {
    param(
        [ValidateSet('DEBUG','INFO','WARNING','ERROR','CRITICAL')]
        [string]$Level,
        [string]$Message,
        [string]$System = "PSProfile"
    )
    
    # Lokales Log | Local log
    Write-Log -Level $Level -Message $Message
    
    # Zentrales Production Log | Central production log
    $CentralLogPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\$System"
    if (-not (Test-Path $CentralLogPath)) {
        New-Item -Path $CentralLogPath -ItemType Directory -Force
    }
    
    $LogEntry = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Level = $Level
        System = $System
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        Message = $Message
        RegelwerkVersion = $RegelwerkVersion
        ScriptVersion = $ScriptVersion
        ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD"
    }
    
    try {
        $LogEntry | ConvertTo-Json -Compress | Add-Content "$CentralLogPath\$((Get-Date).ToString('yyyy-MM-dd')).jsonl"
    } catch {
        # Fallback auf lokales Logging | Fallback to local logging
        Write-EventLog -LogName Application -Source $System -EntryType Warning -EventId 2001 -Message "Failed to write to central log: $($_.Exception.Message)"
    }
}
```

### Production Log Monitoring | Produktions-Log-Monitoring
```powershell
# Production Log-Überwachung | Production log monitoring
function Monitor-ProductionLogs {
    param(
        [string]$LogPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs",
        [int]$TailLines = 100,
        [string[]]$Systems = @("PSProfile", "CertSurv", "CertWebService")
    )
    
    foreach ($System in $Systems) {
        $SystemLogPath = Join-Path $LogPath $System
        $TodayLog = Join-Path $SystemLogPath "$((Get-Date).ToString('yyyy-MM-dd')).jsonl"
        
        if (Test-Path $TodayLog) {
            Write-Host "`n📊 $System - Last $TailLines entries:" -ForegroundColor Cyan
            
            $LogEntries = Get-Content $TodayLog -Tail $TailLines | ForEach-Object {
                try {
                    $_ | ConvertFrom-Json
                } catch {
                    # Skip invalid JSON lines
                    $null
                }
            } | Where-Object { $_ -ne $null }
            
            # Fehler und Warnungen hervorheben | Highlight errors and warnings
            foreach ($Entry in $LogEntries) {
                $Color = switch ($Entry.Level.ToUpper()) {
                    'ERROR' { 'Red' }
                    'WARNING' { 'Yellow' }
                    'CRITICAL' { 'Magenta' }
                    default { 'White' }
                }
                
                Write-Host "$($Entry.Timestamp) [$($Entry.Level)] $($Entry.Message)" -ForegroundColor $Color
            }
        } else {
            Write-Host "📝 $System - No log file for today" -ForegroundColor Gray
        }
    }
}
```

## Comprehensive Testing Architecture

### Production Deployment Testing | Produktions-Deployment-Tests
```powershell
# Production-Readiness Tests | Produktions-Bereitschafts-Tests
function Test-ProductionReadiness {
    param([string]$SourcePath = $Global:ScriptDirectory)
    
    $TestResults = @{
        TestName = "Production Readiness Test"
        Timestamp = Get-Date
        Results = @{}
        OverallStatus = "UNKNOWN"
    }
    
    # Network Path Accessibility | Netzwerkpfad-Zugriff
    $TestResults.Results['NetworkAccess'] = Test-ProductionNetworkAccess
    
    # Script Integrity | Script-Integrität  
    $TestResults.Results['ScriptIntegrity'] = Test-ScriptIntegrity -Path $SourcePath
    
    # Dependencies | Abhängigkeiten
    $TestResults.Results['Dependencies'] = Test-ProductionDependencies -Path $SourcePath
    
    # Configuration | Konfiguration
    $TestResults.Results['Configuration'] = Test-ProductionConfiguration -Path $SourcePath
    
    # Security | Sicherheit
    $TestResults.Results['Security'] = Test-ProductionSecurity -Path $SourcePath
    
    # Regelwerk Compliance | Regelwerk-Konformität
    $TestResults.Results['RegelwerkCompliance'] = Test-RegelwerkCompliance -Path $SourcePath
    
    # Overall Status berechnen | Calculate overall status
    $FailedTests = $TestResults.Results.Values | Where-Object { $_.Status -eq 'FAIL' }
    $TestResults.OverallStatus = if ($FailedTests.Count -eq 0) { "READY" } else { "NOT_READY" }
    
    # Ergebnis-Report | Results report
    Write-Host "`n🎯 Production Readiness Summary" -ForegroundColor Cyan
    foreach ($TestCategory in $TestResults.Results.Keys) {
        $Result = $TestResults.Results[$TestCategory]
        $StatusColor = if ($Result.Status -eq 'PASS') { 'Green' } else { 'Red' }
        $StatusIcon = if ($Result.Status -eq 'PASS') { '✅' } else { '❌' }
        
        Write-Host "$StatusIcon $TestCategory`: $($Result.Status)" -ForegroundColor $StatusColor
    }
    
    Write-Host "`n🚀 Overall Status: $($TestResults.OverallStatus)" -ForegroundColor $(if ($TestResults.OverallStatus -eq 'READY') { 'Green' } else { 'Red' })
    
    return $TestResults
}
```

### Integration zwischen verschiedenen Test-Suites
```powershell
# Master Test Controller mit Production Path Integration | Master test controller with production path integration
function Invoke-MasterTestSuite {
    param(
        [string[]]$Repositories = @("PSProfile", "CertSurv", "CertWebService"),
        [switch]$IncludeProductionTests,
        [switch]$ValidateNetworkPaths,
        [switch]$GenerateReport
    )
    
    $TestResults = @{
        ExecutionDate = Get-Date
        ProductionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD"
        RepositoryResults = @{}
        ProductionValidation = $null
        OverallStatus = "UNKNOWN"
    }
    
    # Network Path Validation falls angefordert | Network path validation if requested
    if ($ValidateNetworkPaths) {
        Write-Host "🌐 Validating production network paths..." -ForegroundColor Cyan
        $TestResults.ProductionValidation = Test-ProductionNetworkAccess
    }
    
    # Repository-spezifische Tests | Repository-specific tests
    foreach ($Repo in $Repositories) {
        Write-Host "`n📂 Testing $Repo..." -ForegroundColor Cyan
        
        $RepoResults = @{
            UnitTests = $null
            ComplianceTests = $null
            SecurityTests = $null
            ProductionReadiness = $null
        }
        
        try {
            # Standard Tests | Standard tests
            if (Test-Path ".\$Repo\TEST\Test-$Repo-Functions.ps1") {
                $RepoResults.UnitTests = & ".\$Repo\TEST\Test-$Repo-Functions.ps1"
            }
            
            if (Test-Path ".\Tests\Test-$Repo-Compliance.ps1") {
                $RepoResults.ComplianceTests = & ".\Tests\Test-$Repo-Compliance.ps1"
            }
            
            # Production Tests falls angefordert | Production tests if requested
            if ($IncludeProductionTests -and ($Repo -eq "PSProfile")) {
                $RepoResults.ProductionReadiness = Test-ProductionReadiness -SourcePath ".\$Repo"
            }
            
        } catch {
            Write-Host "❌ Error testing $Repo`: $($_.Exception.Message)" -ForegroundColor Red
            $RepoResults.Error = $_.Exception.Message
        }
        
        $TestResults.RepositoryResults[$Repo] = $RepoResults
    }
    
    # Gesamtstatus berechnen | Calculate overall status
    $FailedRepos = $TestResults.RepositoryResults.Keys | Where-Object {
        $TestResults.RepositoryResults[$_].Error -or 
        ($TestResults.RepositoryResults[$_].ProductionReadiness.OverallStatus -eq "NOT_READY")
    }
    
    $TestResults.OverallStatus = if ($FailedRepos.Count -eq 0) { "ALL_SYSTEMS_GO" } else { "ISSUES_DETECTED" }
    
    # Report generieren falls angefordert | Generate report if requested
    if ($GenerateReport) {
        $ReportPath = ".\Reports\Master-Test-Report-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').json"
        New-Item -Path (Split-Path $ReportPath) -ItemType Directory -Force | Out-Null
        $TestResults | ConvertTo-Json -Depth 10 | Set-Content $ReportPath
        Write-Host "📊 Test report saved: $ReportPath" -ForegroundColor Green
    }
    
    return $TestResults
}
```

## Code-Konventionen | Code Conventions

- **Globale Variablen | Global Variables**: `$Global:ScriptDirectory`, `$Global:Config`, `$Global:ScriptVersion`, `$Global:CorrelationId`
- **Produktionspfad | Production Path**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\`
- **Modul-Benennung | Module Naming**: FL-{Function}.psm1 (FL-Config, FL-Logging, FL-Gui, FL-Utils, FL-Maintenance)
- **Network Deployment**: Robocopy-basierte Synchronisation für Enterprise-Stabilität | Robocopy-based synchronization for enterprise stability
- **Cross-Repo-Kommunikation | Cross-Repo Communication**: Standardisierte Message-Formate mit JSON-Schema-Validation
- **Fehlerbehandlung | Error Handling**: Immer try/catch mit Write-CentralLog für Production-Monitoring | Always use try/catch with Write-CentralLog for production monitoring
- **Encoding**: UTF-8 erzwingen | Force UTF-8: `$OutputEncoding = [System.Text.UTF8Encoding]::new($false)`

## Enterprise-Integration Points

- **Production Network Path**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\PSProfile\` für Script-Bereitstellung | for script deployment
- **Shared Resources**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Shared\` für gemeinsame Templates und Assets | for shared templates and assets
- **Central Logging**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Logs\` für Enterprise-Log-Aggregation | for enterprise log aggregation
- **Backup Location**: `\\itscmgmt03.srv.meduniwien.ac.at\iso\PROD\Backup\` für Produktions-Backups | for production backups
- **SMTP-Integration**: `smtpi.meduniwien.ac.at` mit produktions-spezifischen Sender-Adressen | with production-specific sender addresses
- **Event Log**: Windows Event Log Integration mit SIEM-kompatiblen Formaten | Windows Event Log integration with SIEM-compatible formats
- **Service Integration**: Windows Service-Wrapper für automatisierte Profile-Verwaltung | Windows service wrapper for automated profile management
- **Cross-Repository**: Message-Bus-Pattern für Repository-übergreifende Kommunikation | Message bus pattern for cross-repository communication

**KRITISCH | CRITICAL**: 
- **Immer** `Test-ProductionNetworkAccess` vor Deployment ausführen | **Always** run before deployment
- **Immer** `Test-ProductionReadiness` vor Produktions-Release | **Always** run before production release  
- **Immer** Backup erstellen mit `Deploy-ToProduction -BackupExisting` | **Always** create backup with deployment
- **Niemals** direkt in Produktion entwickeln - nur über validierte Deployment-Pipeline | **Never** develop directly in production - only through validated deployment pipeline