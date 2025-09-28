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

## Enterprise Deployment Patterns

### Netzwerk-Deployment auf itscmgmt03.srv.meduniwien.ac.at
```powershell
# Standard Enterprise-Deployment-Pattern | Standard enterprise deployment pattern
function Deploy-ToProductionServer {
    param([string]$TargetServer = "itscmgmt03.srv.meduniwien.ac.at")
    
    # Deployment-Validierung | Deployment validation
    Test-NetworkConnectivity -Server $TargetServer
    Test-AdminCredentials -Server $TargetServer
    
    # Batch-Installation vorbereiten | Prepare batch installation
    $DeploymentPackage = New-DeploymentPackage -Source $Global:ScriptDirectory
    
    # Remote-Installation | Remote installation
    Invoke-Command -ComputerName $TargetServer -ScriptBlock {
        param($Package)
        & "$Package\Install-PSProfile.bat"
    } -ArgumentList $DeploymentPackage
}
```

### Batch-Installation-Pattern
```powershell
# Install-PSProfile.bat Integration | Batch installation integration
function New-BatchInstaller {
    $BatchContent = @"
@echo off
echo Installing PSProfile System...
powershell.exe -ExecutionPolicy Bypass -File ".\Setup-PSProfile.ps1" -Silent
if %ERRORLEVEL% NEQ 0 (
    echo Installation failed with error %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)
echo PSProfile System installed successfully
"@
    
    $BatchContent | Out-File "Install-PSProfile.bat" -Encoding ASCII
}
```

### Service-Installation-Workflows
```powershell
# Windows Service Integration für Enterprise-Monitoring | Windows service integration for enterprise monitoring
function Install-PSProfileService {
    $ServiceParams = @{
        Name = "PSProfileManager"
        BinaryPathName = "powershell.exe -File `"$Global:ScriptDirectory\PSProfile-Service.ps1`""
        DisplayName = "PowerShell Profile Manager Service"
        Description = "MUW-Regelwerk compliant PowerShell profile management service"
        StartupType = "Automatic"
    }
    
    New-Service @ServiceParams
    Start-Service -Name "PSProfileManager"
}
```

## Zentrale Logging-Architektur | Centralized Logging Architecture

### Cross-System Log-Aggregation
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
    
    # Zentrales Enterprise-Log | Central enterprise log
    $CentralLogPath = "\\itscmgmt03.srv.meduniwien.ac.at\Logs\PowerShell\$System"
    $LogEntry = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Level = $Level
        System = $System
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        Message = $Message
        RegelwerkVersion = $RegelwerkVersion
        ScriptVersion = $ScriptVersion
    }
    
    $LogEntry | ConvertTo-Json -Compress | Add-Content "$CentralLogPath\$((Get-Date).ToString('yyyy-MM-dd')).jsonl"
}
```

### Log-Format-Standards für Enterprise-Monitoring
```powershell
# Standardisiertes Log-Format für SIEM-Integration | Standardized log format for SIEM integration
function Format-EnterpriseLogEntry {
    param($LogData)
    
    return @{
        # ISO 8601 Timestamp für internationale Kompatibilität | ISO 8601 timestamp for international compatibility
        '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        level = $LogData.Level.ToLower()
        message = $LogData.Message
        system = @{
            name = "PSProfile"
            version = $ScriptVersion
            regelwerk = $RegelwerkVersion
            environment = $Global:Config.Environment
        }
        host = @{
            name = $env:COMPUTERNAME
            user = $env:USERNAME
            domain = $env:USERDOMAIN
        }
        # Correlation ID für Request-Tracking | Correlation ID for request tracking
        correlation_id = $Global:CorrelationId
        # Custom Fields für erweiterte Analyse | Custom fields for extended analysis
        custom = $LogData.CustomFields
    }
}
```

### Event Log Integration mit Enterprise-Standards
```powershell
# Windows Event Log mit Source-Registration | Windows Event Log with source registration
function Write-EnterpriseEventLog {
    param($Level, $Message, $EventID = 1000)
    
    # Event Source registrieren falls nicht vorhanden | Register event source if not present
    if (-not [System.Diagnostics.EventLog]::SourceExists("PSProfile")) {
        [System.Diagnostics.EventLog]::CreateEventSource("PSProfile", "Application")
    }
    
    $EventType = switch ($Level) {
        'ERROR' { 'Error' }
        'WARNING' { 'Warning' }
        default { 'Information' }
    }
    
    Write-EventLog -LogName Application -Source "PSProfile" -EntryType $EventType -EventId $EventID -Message $Message
}
```

## Comprehensive Testing Architecture

### Integration zwischen verschiedenen Test-Suites
```powershell
# Master Test Controller für alle Repository-Tests | Master test controller for all repository tests
function Invoke-MasterTestSuite {
    param(
        [string[]]$Repositories = @("PSProfile", "CertSurv", "CertWebService"),
        [switch]$IncludeIntegrationTests,
        [switch]$GenerateReport
    )
    
    $TestResults = @{}
    
    foreach ($Repo in $Repositories) {
        Write-Host "Testing $Repo..." -ForegroundColor Cyan
        
        # Repository-spezifische Tests | Repository-specific tests
        $TestResults[$Repo] = @{
            UnitTests = & ".\$Repo\TEST\Test-$Repo-Functions.ps1"
            ComplianceTests = & ".\Tests\Test-$Repo-Compliance.ps1"
            SecurityTests = & ".\Tests\Test-$Repo-Security.ps1"
        }
        
        # Cross-Repository Integration Tests | Cross-repository integration tests
        if ($IncludeIntegrationTests) {
            $TestResults[$Repo].IntegrationTests = & ".\Tests\Test-$Repo-Integration.ps1"
        }
    }
    
    if ($GenerateReport) {
        New-TestReport -Results $TestResults
    }
    
    return $TestResults
}
```

### Compliance-Testing-Workflows
```powershell
# Regelwerk v9.6.2 Compliance-Tests | Regelwerk v9.6.2 compliance tests
function Test-RegelwerkCompliance {
    param([string]$RepositoryPath)
    
    $ComplianceResults = @{
        Version = "v9.6.2"
        TestDate = Get-Date
        Results = @{}
    }
    
    # §1-§6: Basis-Compliance Tests
    $ComplianceResults.Results['BasicCompliance'] = @{
        VersionManagement = Test-VersionManagement -Path $RepositoryPath
        UTF8Encoding = Test-UTF8Encoding -Path $RepositoryPath  
        AdminRequirements = Test-AdminRequirements -Path $RepositoryPath
        ErrorHandling = Test-ErrorHandling -Path $RepositoryPath
        LoggingStandard = Test-LoggingStandard -Path $RepositoryPath
        ConfigManagement = Test-ConfigManagement -Path $RepositoryPath
    }
    
    # §7: PowerShell-Kompatibilität
    $ComplianceResults.Results['PSCompatibility'] = Test-PowerShellCompatibility -Path $RepositoryPath
    
    # §8: E-Mail-Integration  
    $ComplianceResults.Results['EmailIntegration'] = Test-EmailIntegration -Path $RepositoryPath
    
    # §9: Cross-Script-Kommunikation
    $ComplianceResults.Results['CrossScriptComm'] = Test-CrossScriptCommunication -Path $RepositoryPath
    
    return $ComplianceResults
}
```

### Quick-Compliance-Test Pattern
```powershell
# Schnelle Compliance-Überprüfung für CI/CD | Quick compliance check for CI/CD
function Invoke-QuickComplianceTest {
    Write-Host "🔍 Quick Compliance Test - Regelwerk v9.6.2" -ForegroundColor Yellow
    
    $Tests = @(
        @{ Name = "VERSION.ps1 exists"; Test = { Test-Path "VERSION.ps1" } }
        @{ Name = "FL-* modules present"; Test = { (Get-ChildItem "Modules\FL-*.psm1").Count -gt 0 } }
        @{ Name = "UTF-8 encoding"; Test = { Test-ScriptEncoding } }
        @{ Name = "Admin requirements"; Test = { Test-AdminRequirements } }
        @{ Name = "Cross-script functions"; Test = { Test-CrossScriptFunctions } }
    )
    
    $Results = foreach ($Test in $Tests) {
        $Passed = & $Test.Test
        [PSCustomObject]@{
            Test = $Test.Name
            Status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
            Passed = $Passed
        }
    }
    
    $PassedCount = ($Results | Where-Object Passed).Count
    Write-Host "`n📊 Results: $PassedCount/$($Tests.Count) tests passed" -ForegroundColor $(if ($PassedCount -eq $Tests.Count) { "Green" } else { "Red" })
    
    return $Results
}
```

## Modulares Import-Pattern | Modular Import Pattern
```powershell
# FL-Module mit Dependency-Checking importieren | Import FL-modules with dependency checking
function Import-FLModules {
    param([string]$ModulePath = (Join-Path $Global:ScriptDirectory "Modules"))
    
    $RequiredModules = @(
        'FL-Config.psm1',    # Basis-Konfiguration | Base configuration
        'FL-Logging.psm1',   # Logging-Framework | Logging framework  
        'FL-Utils.psm1',     # Utilities | Utilities
        'FL-Maintenance.psm1', # Wartung | Maintenance
        'FL-Gui.psm1'        # GUI-Framework | GUI framework
    )
    
    foreach ($Module in $RequiredModules) {
        try {
            $ModuleFullPath = Join-Path $ModulePath $Module
            if (-not (Test-Path $ModuleFullPath)) {
                throw "Required module not found: $Module"
            }
            
            Import-Module $ModuleFullPath -ErrorAction Stop -Force
            Write-Log -Level DEBUG -Message "Successfully loaded module: $Module"
        } catch {
            Write-Log -Level ERROR -Message "Failed to load critical module $Module`: $($_.Exception.Message)"
            throw "Critical module loading failure. Cannot continue."
        }
    }
}
```

## Konfigurationssystem | Configuration System

### JSON Konfigurationsverwaltung mit Versionsmigration | JSON Configuration Management with Version Migration
```powershell
# Erweiterte Konfigurationsverwaltung | Extended configuration management
function Get-ConfigWithMigration {
    param([string]$ConfigPath)
    
    $Config = Get-Config -Path $ConfigPath
    
    if ($null -eq $Config) {
        Write-Log -Level WARNING -Message "Configuration not found. Creating default configuration."
        $Config = Get-DefaultConfig
        Save-Config -Config $Config -Path $ConfigPath
        return $Config
    }
    
    # Automatische Migration für veraltete Konfigurationen | Automatic migration for outdated configurations
    if ($Config.RegelwerkVersion -ne $RegelwerkVersion) {
        Write-Log -Level INFO -Message "Migrating configuration from $($Config.RegelwerkVersion) to $RegelwerkVersion"
        $Config = Invoke-ConfigMigration -Config $Config -TargetVersion $RegelwerkVersion
        Save-Config -Config $Config -Path $ConfigPath
    }
    
    return $Config
}
```

### Template-Versionierung mit Git-Integration | Template Versioning with Git Integration
```powershell
# Git-basierte Template-Synchronisation | Git-based template synchronization
function Sync-TemplatesFromGit {
    param([string]$GitRepoUrl, [string]$Branch = "main")
    
    $GitCachePath = $Global:Config.GitUpdate.CachePath
    
    if (Test-Path $GitCachePath) {
        # Git Repository aktualisieren | Update git repository
        Set-Location $GitCachePath
        & git pull origin $Branch
    } else {
        # Git Repository klonen | Clone git repository
        & git clone $GitRepoUrl $GitCachePath --branch $Branch
    }
    
    # Template-Dateien kopieren und versionieren | Copy and version template files
    $TemplateSource = Join-Path $GitCachePath "Templates"
    $TemplateTarget = Join-Path $Global:ScriptDirectory "Templates"
    
    Copy-Item "$TemplateSource\*" $TemplateTarget -Force
    
    # Template-Versionen aktualisieren | Update template versions
    Update-TemplateVersions -TemplateDirectory $TemplateTarget
}
```

### Netzwerk-Profile mit Advanced Authentication | Network Profiles with Advanced Authentication
```powershell
# Erweiterte Netzwerk-Authentifizierung | Extended network authentication
function Connect-NetworkProfileAdvanced {
    param([PSCustomObject]$NetworkProfile)
    
    # Multi-Faktor-Authentifizierung unterstützen | Support multi-factor authentication
    if ($NetworkProfile.AuthMethod -eq "Certificate") {
        $Credential = Get-CertificateCredential -CertificateThumbprint $NetworkProfile.CertThumbprint
    } elseif ($NetworkProfile.AuthMethod -eq "Kerberos") {
        $Credential = Get-KerberosCredential -ServicePrincipal $NetworkProfile.SPN
    } else {
        # Standard verschlüsselte Credentials | Standard encrypted credentials
        $Credential = ConvertFrom-SecureCredential -EncryptedPassword $NetworkProfile.EncryptedPassword -Username $NetworkProfile.Username
    }
    
    # Netzwerk-Drive mit Retry-Logic verbinden | Connect network drive with retry logic
    $Connected = $false
    $RetryCount = 0
    $MaxRetries = 3
    
    do {
        try {
            New-PSDrive -Name $NetworkProfile.DriveLetter -PSProvider FileSystem -Root $NetworkProfile.Path -Credential $Credential -ErrorAction Stop
            $Connected = $true
            Write-Log -Level INFO -Message "Successfully connected to network profile: $($NetworkProfile.Name)"
        } catch {
            $RetryCount++
            Write-Log -Level WARNING -Message "Failed to connect to $($NetworkProfile.Name). Retry $RetryCount/$MaxRetries"
            Start-Sleep -Seconds (2 * $RetryCount)
        }
    } while (-not $Connected -and $RetryCount -lt $MaxRetries)
    
    if (-not $Connected) {
        throw "Failed to connect to network profile $($NetworkProfile.Name) after $MaxRetries attempts"
    }
}
```

## Code-Konventionen | Code Conventions

- **Globale Variablen | Global Variables**: `$Global:ScriptDirectory`, `$Global:Config`, `$Global:ScriptVersion`, `$Global:CorrelationId`
- **Modul-Benennung | Module Naming**: FL-{Function}.psm1 (FL-Config, FL-Logging, FL-Gui, FL-Utils, FL-Maintenance)
- **Cross-Repo-Kommunikation | Cross-Repo Communication**: Standardisierte Message-Formate mit JSON-Schema-Validation
- **Fehlerbehandlung | Error Handling**: Immer try/catch mit Write-CentralLog für Enterprise-Umgebungen | Always use try/catch with Write-CentralLog for enterprise environments
- **Encoding**: UTF-8 erzwingen | Force UTF-8: `$OutputEncoding = [System.Text.UTF8Encoding]::new($false)`
- **Deployment**: Batch-Integration für Enterprise-Rollout | Batch integration for enterprise rollout

## Enterprise-Integration Points

- **Git-Template-Sync**: Automatische Template-Synchronisation vom GitHub Repository via `$Global:Config.GitUpdate`
- **SMTP-Integration**: Enterprise-E-Mail-Benachrichtigungen mit dynamischen Sender-Adressen | Enterprise email notifications with dynamic sender addresses
- **Event Log**: Windows Event Log Integration mit SIEM-kompatiblen Formaten | Windows Event Log integration with SIEM-compatible formats
- **Network Deployment**: Remote-Installation auf `itscmgmt03.srv.meduniwien.ac.at` | Remote installation on production servers
- **Service Integration**: Windows Service-Wrapper für automatisierte Profile-Verwaltung | Windows service wrapper for automated profile management
- **7-Zip Archive**: Automatisierte Log-Kompression mit Enterprise-Retention-Policies | Automated log compression with enterprise retention policies
- **Cross-Repository**: Message-Bus-Pattern für Repository-übergreifende Kommunikation | Message bus pattern for cross-repository communication

**Kritisch | Critical**: Immer `Invoke-VersionControl` vor Operationen ausführen, `Initialize-LocalizationFiles` für GUI-Support verwenden, und Cross-Repository-Tests mit `Invoke-MasterTestSuite` durchführen.
Always run `Invoke-VersionControl` before operations, use `Initialize-LocalizationFiles` for GUI support, and perform cross-repository tests with `Invoke-MasterTestSuite`.