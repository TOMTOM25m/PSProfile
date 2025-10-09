#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    [DE] Update aller Scripts auf Regelwerk v10.1.0
    [EN] Update all scripts to Rulebook v10.1.0

.DESCRIPTION
    [DE] Aktualisiert systematisch alle PowerShell-Scripts in CertSurv und CertWebService 
         auf die neuesten Standards des Regelwerk v10.1.0 Enterprise Edition.
         Implementiert: MUW Enterprise Standards (§20-§26), Config Version Control,
         Event Log Integration, Enhanced Password Management, etc.
    [EN] Systematically updates all PowerShell scripts in CertSurv and CertWebService
         to the latest standards of Rulebook v10.1.0 Enterprise Edition.
         Implements: MUW Enterprise Standards (§20-§26), Config Version Control,
         Event Log Integration, Enhanced Password Management, etc.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Regelwerk:      v10.1.0
    Copyright:      © 2025 Flecki Garnreiter
    BuildDate:      2025-10-09
#>

param(
    [string[]]$Directories = @("CertSurv", "CertWebService"),
    [switch]$WhatIf,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Regelwerk v10.1.0 Standards Reference

#region Version Information (MANDATORY - Regelwerk v10.1.0)
$ScriptVersion = "v1.0.0"
$RegelwerkVersion = "v10.1.0"
$BuildDate = "2025-10-09"
$Author = "Flecki (Tom) Garnreiter"

function Show-ScriptInfo {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "🚀 Update-Scripts-To-Regelwerk v$ScriptVersion" -ForegroundColor Green
        Write-Host "📅 Build: $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    } else {
        Write-Host ">> Update-Scripts-To-Regelwerk v$ScriptVersion" -ForegroundColor Green
        Write-Host "[BUILD] $BuildDate | Regelwerk: $RegelwerkVersion" -ForegroundColor Cyan
    }
}
#endregion

#region Logging (§5 - Regelwerk v10.1.0)
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "FATAL")][string]$Level = "INFO",
        [string]$LogPath = ".\LOG\Update-Scripts.log"
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    $Color = switch ($Level) {
        "DEBUG"   { "Gray" }
        "INFO"    { "White" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "FATAL"   { "Magenta" }
    }
    Write-Host $LogEntry -ForegroundColor $Color
    
    # File-Logging
    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    $LogEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
}
#endregion

#region Update Functions (Regelwerk v10.1.0 Implementation)

function Update-ScriptHeader {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )
    
    Write-Log "Updating script header: $FilePath" -Level INFO
    
    $content = Get-Content $FilePath -Raw
    
    # Update Regelwerk version references
    $content = $content -replace "v10\.0\.[0-9]", "v10.1.0"
    $content = $content -replace "Regelwerk v10\.0\.[0-9]", "Regelwerk v10.1.0"
    $content = $content -replace "MUW-Regelwerk:\s*v10\.0\.[0-9]", "MUW-Regelwerk: v10.1.0"
    
    # Update build date
    $content = $content -replace "Stand: \d{2}\.\d{2}\.\d{4}", "Stand: 09.10.2025"
    $content = $content -replace "Last modified:\s*\d{4}\.\d{2}\.\d{2}", "Last modified: 2025.10.09"
    
    if (-not $WhatIf) {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8
        Write-Log "Header updated successfully: $FilePath" -Level INFO
    } else {
        Write-Log "[WHATIF] Would update header: $FilePath" -Level INFO
    }
}

function Add-ConfigVersionControl {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )
    
    Write-Log "Adding Config Version Control (§20): $FilePath" -Level INFO
    
    $content = Get-Content $FilePath -Raw
    
    # Check if already has version control
    if ($content -match "Compare-ConfigVersion|Test-MUWVersionFormat") {
        Write-Log "Config Version Control already present: $FilePath" -Level DEBUG
        return
    }
    
    # Add Config Version Control functions after param block
    $versionControlCode = @'

#region Config Version Control (§20 - Regelwerk v10.1.0)
function Compare-ConfigVersion {
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$ScriptVersion,
        [Parameter(Mandatory)][string]$RegelwerkVersion
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Warning "Config file not found: $ConfigPath"
            return $false
        }
        
        $Config = Get-Content $ConfigPath | ConvertFrom-Json
        $ConfigScriptVersion = $Config.ProjectInfo.Version
        $ConfigRegelwerkVersion = $Config.ProjectInfo.RegelwerkVersion
        
        if ($ScriptVersion -ne $ConfigScriptVersion) {
            Write-Warning "VERSION MISMATCH: Script $ScriptVersion vs Config $ConfigScriptVersion"
            Write-Host "Consider updating config with -Versionscontrol parameter" -ForegroundColor Yellow
        }
        
        if ($RegelwerkVersion -ne $ConfigRegelwerkVersion) {
            Write-Warning "REGELWERK MISMATCH: Current $RegelwerkVersion vs Config $ConfigRegelwerkVersion"
        }
        
        return @{
            ScriptVersionMatch = ($ScriptVersion -eq $ConfigScriptVersion)
            RegelwerkVersionMatch = ($RegelwerkVersion -eq $ConfigRegelwerkVersion)
        }
    } catch {
        Write-Error "Failed to compare config versions: $($_.Exception.Message)"
        return $false
    }
}
#endregion

'@
    
    # Insert after param block
    $paramEndPattern = '\)\s*\n'
    if ($content -match $paramEndPattern) {
        $content = $content -replace $paramEndPattern, ")`n$versionControlCode"
    }
    
    if (-not $WhatIf) {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8
        Write-Log "Config Version Control added: $FilePath" -Level INFO
    } else {
        Write-Log "[WHATIF] Would add Config Version Control: $FilePath" -Level INFO
    }
}

function Add-EventLogIntegration {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )
    
    Write-Log "Adding Event Log Integration (§22): $FilePath" -Level INFO
    
    $content = Get-Content $FilePath -Raw
    
    # Check if already has Event Log integration
    if ($content -match "Write-EventLog|Initialize-EventLogSource") {
        Write-Log "Event Log Integration already present: $FilePath" -Level DEBUG
        return
    }
    
    $eventLogCode = @'

#region Windows Event Log Integration (§22 - Regelwerk v10.1.0)
function Initialize-EventLogSource {
    param(
        [Parameter(Mandatory)][string]$SourceName,
        [string]$LogName = "Application"
    )
    
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($SourceName)) {
            [System.Diagnostics.EventLog]::CreateEventSource($SourceName, $LogName)
            Write-Verbose "Event Log source '$SourceName' created"
        }
        return $true
    } catch {
        Write-Warning "Failed to initialize Event Log source: $($_.Exception.Message)"
        return $false
    }
}

function Write-EventLogEntry {
    param(
        [Parameter(Mandatory)][string]$SourceName,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][ValidateSet("Information", "Warning", "Error")][string]$EntryType,
        [int]$EventId = 1000
    )
    
    try {
        $EventIdMap = @{ "Information" = 1000; "Warning" = 2000; "Error" = 3000 }
        $FinalEventId = $EventIdMap[$EntryType] + $EventId
        
        Write-EventLog -LogName "Application" -Source $SourceName -EntryType $EntryType -EventId $FinalEventId -Message $Message
        Write-Verbose "Event logged: [$EntryType] ID:$FinalEventId - $Message"
    } catch {
        Write-Warning "Failed to write Event Log entry: $($_.Exception.Message)"
    }
}
#endregion

'@
    
    # Add after existing regions
    if ($content -match '#endregion') {
        $insertPos = $content.LastIndexOf('#endregion') + '#endregion'.Length
        $content = $content.Insert($insertPos, $eventLogCode)
    }
    
    if (-not $WhatIf) {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8
        Write-Log "Event Log Integration added: $FilePath" -Level INFO
    } else {
        Write-Log "[WHATIF] Would add Event Log Integration: $FilePath" -Level INFO
    }
}

function Add-EnhancedPasswordManagement {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )
    
    Write-Log "Adding Enhanced Password Management (§24): $FilePath" -Level INFO
    
    $content = Get-Content $FilePath -Raw
    
    # Check if already has enhanced password management
    if ($content -match "Get-SecureConfigPassword|Set-SecureConfigPassword") {
        Write-Log "Enhanced Password Management already present: $FilePath" -Level DEBUG
        return
    }
    
    $passwordMgmtCode = @'

#region Enhanced Password Management (§24 - Regelwerk v10.1.0)
function Get-SecureConfigPassword {
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$PasswordKey
    )
    
    try {
        $PasswordValue = $Config[$PasswordKey]
        
        if ($PasswordValue -like "CREDENTIAL_MANAGER:*") {
            # Retrieve from Credential Manager (preferred)
            $CredentialTarget = $PasswordValue -replace "CREDENTIAL_MANAGER:", ""
            # Implementation depends on FL-CredentialManager module
            Write-Verbose "Retrieving password from Credential Manager: $CredentialTarget"
            return $null  # Placeholder - requires FL-CredentialManager
        }
        elseif ($PasswordValue) {
            # Base64 encoded (SMTP compatibility only)
            Write-Verbose "Decoding Base64 password (SMTP compatibility mode)"
            $DecodedPassword = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($PasswordValue))
            return ConvertTo-SecureString -String $DecodedPassword -AsPlainText -Force
        }
        else {
            Write-Warning "No password found for key: $PasswordKey"
            return $null
        }
    } catch {
        Write-Error "Failed to retrieve secure password: $($_.Exception.Message)"
        return $null
    }
}
#endregion

'@
    
    # Add before the main execution block
    if ($content -match '#region Main Execution|#region Initialization') {
        $content = $content -replace '(#region (?:Main Execution|Initialization))', "$passwordMgmtCode`$1"
    }
    
    if (-not $WhatIf) {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8
        Write-Log "Enhanced Password Management added: $FilePath" -Level INFO
    } else {
        Write-Log "[WHATIF] Would add Enhanced Password Management: $FilePath" -Level INFO
    }
}

#endregion

#region Main Execution
function Start-ScriptUpdate {
    Show-ScriptInfo
    
    Write-Log "Starting script update to Regelwerk v10.1.0" -Level INFO
    Write-Log "Directories to process: $($Directories -join ', ')" -Level INFO
    
    $totalScripts = 0
    $updatedScripts = 0
    
    foreach ($Directory in $Directories) {
        if (-not (Test-Path $Directory)) {
            Write-Log "Directory not found: $Directory" -Level WARNING
            continue
        }
        
        Write-Log "Processing directory: $Directory" -Level INFO
        
        # Get all PowerShell scripts
        $scripts = Get-ChildItem -Path $Directory -Filter "*.ps1" -Recurse
        $totalScripts += $scripts.Count
        
        foreach ($script in $scripts) {
            try {
                Write-Log "Processing: $($script.FullName)" -Level DEBUG
                
                # Apply Regelwerk v10.1.0 updates
                Update-ScriptHeader -FilePath $script.FullName
                
                # Only add new features to main scripts (not utilities)
                if ($script.Name -match "(Main|Deploy|Setup|Install)") {
                    Add-ConfigVersionControl -FilePath $script.FullName
                    Add-EventLogIntegration -FilePath $script.FullName
                    Add-EnhancedPasswordManagement -FilePath $script.FullName
                }
                
                $updatedScripts++
            }
            catch {
                Write-Log "Failed to update $($script.FullName): $($_.Exception.Message)" -Level ERROR
            }
        }
    }
    
    Write-Log "Update completed: $updatedScripts/$totalScripts scripts processed" -Level INFO
    
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "✅ Regelwerk v10.1.0 implementation completed!" -ForegroundColor Green
        Write-Host "📊 Updated $updatedScripts of $totalScripts scripts" -ForegroundColor Cyan
    } else {
        Write-Host "[SUCCESS] Regelwerk v10.1.0 implementation completed!" -ForegroundColor Green
        Write-Host "[STATS] Updated $updatedScripts of $totalScripts scripts" -ForegroundColor Cyan
    }
}

# Execute the update
Start-ScriptUpdate
#endregion