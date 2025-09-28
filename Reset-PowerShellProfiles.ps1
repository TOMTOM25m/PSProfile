<#
.SYNOPSIS
    [DE] Setzt alle PowerShell-function Show-ScriptInfo {
    param(
        [string]$ScriptName,
        [string]$CurrentVersion
    )
    Write-Host ">> $ScriptName" -ForegroundColor Cyan
    Write-Host "Version: $CurrentVersion" -ForegroundColor Green
    Write-Host "Regelwerk: $RegelwerkVersion" -ForegroundColor Yellow
}uf einen Standard zurueck und verwaltet die Konfiguration ueber eine GUI.
    [EN] Resets all PowerShell profiles to a standard and manages the configuration via a GUI.
.DESCRIPTION
    [DE] Ein vollumfaengliches Verwaltungsskript fuer PowerShell-Profile gemaess MUW-Regeln. Es erzwingt Administratorrechte,
         stellt die UTF-8-Kodierung sicher und bietet eine WPF-basierte GUI (-Setup) zur Konfiguration. Bei fehlender
         oder korrupter Konfiguration startet die GUI automatisch. Das Skript fuehrt eine Versionskontrolle der Konfiguration
         durch, versioniert die Profil-Vorlagen, schreibt in das Windows Event Log und beinhaltet eine voll funktionsfaehige
         Log-Archivierung sowie einen Mail-Versand.
    [EN] A comprehensive management script for PowerShell profiles according to MUW rules. It enforces administrator rights,
         ensures UTF-8 encoding, and provides a WPF-based GUI (-Setup) for configuration. The GUI starts automatically
         if the configuration is missing or corrupt. The script performs version control of the configuration, versions
         the profile templates, writes to the Windows Event Log, and includes fully functional log archiving and mail sending.
.PARAMETER Setup
    [DE] Startet die WPF-Konfigurations-GUI, um die Einstellungen zu bearbeiten.
    [EN] Starts the WPF configuration GUI to edit the settings.
.PARAMETER Versionscontrol
    [DE] Pr??ft die Konfigurationsdatei gegen die Skript-Version, zeigt Unterschiede an und aktualisiert sie.
    [EN] Checks the configuration file against the script version, displays differences, and updates it.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.11
    Last modified:  2025.09.02
    old Version:    v11.2.2
    Version now:    v11.2.6
    MUW-Regelwerk:  v9.6.2
    Notes:          [DE] Initialize-LocalizationFiles implementiert, PowerShell 5.1/7.x Kompatibilität verbessert, Regelwerk v9.6.2 compliance.
                    [EN] Implemented Initialize-LocalizationFiles, improved PowerShell 5.1/7.x compatibility, Regelwerk v9.6.2 compliance.
    Copyright:      ?? 2025 Flecki Garnreiter
    License:        MIT License
#>
#requires -Version 5.1
#requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Switch]$Setup,
    [Switch]$Versionscontrol
)

#region ####################### [1. Initialization] ##############################
# Load VERSION.ps1 for centralized version management (Regelwerk v9.6.0)
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")

# Simple Show-ScriptInfo implementation for PS 5.1 compatibility
function Show-ScriptInfo {
    param(
        [string]$ScriptName,
        [string]$CurrentVersion
    )
    # PowerShell 5.1/7.x compatibility (Regelwerk v9.6.2 §7)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # PowerShell 7.x - Unicode-Emojis erlaubt
        Write-Host "🚀 $ScriptName" -ForegroundColor Cyan
        Write-Host "📦 Version: $CurrentVersion" -ForegroundColor Green
        Write-Host "📋 Regelwerk: $RegelwerkVersion" -ForegroundColor Yellow
    } else {
        # PowerShell 5.1 - ASCII-Alternativen verwenden
        Write-Host ">> $ScriptName" -ForegroundColor Cyan
        Write-Host "[VER] Version: $CurrentVersion" -ForegroundColor Green
        Write-Host "[RW] Regelwerk: $RegelwerkVersion" -ForegroundColor Yellow
    }
}

Show-ScriptInfo -ScriptName "PowerShell Profile Reset System" -CurrentVersion $ScriptVersion

$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = $ScriptVersion
$Global:RulebookVersion = $RegelwerkVersion
$Global:ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path

$configDir = Join-Path $Global:ScriptDirectory 'Config'
if (-not (Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory | Out-Null
}
$Global:ConfigFile = Join-Path -Path $configDir -ChildPath "Config-$($MyInvocation.MyCommand.Name).json"

$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
#endregion

#region ####################### [2. Module Import] #################################################
try {
    $modulePath = Join-Path $Global:ScriptDirectory "Modules"
    Import-Module (Join-Path $modulePath "FL-Config.psm1") -ErrorAction Stop -Force
    Import-Module (Join-Path $modulePath "FL-Logging.psm1") -ErrorAction Stop -Force
    Import-Module (Join-Path $modulePath "FL-Gui.psm1") -ErrorAction Stop -Force
    Import-Module (Join-Path $modulePath "FL-Maintenance.psm1") -ErrorAction Stop -Force
    Import-Module (Join-Path $modulePath "FL-Utils.psm1") -ErrorAction Stop -Force
}
catch {
    Write-Error "A critical error occurred while loading essential modules: $($_.ToString())"
    return
}
#endregion

#region ####################### [3. Script Main Body] ##############################
$oldVersion = try {
    $content = Get-Content -Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    # Look for pattern: old: vX.Y.Z
    $pattern = 'old:\s*(v\d+\.\d+\.\d+)'
    $match = $content | Select-String $pattern
    if ($match) {
        $match.Matches[0].Groups[1].Value
    } else {
        "v0.0.0"
    }
} catch { 
    "v0.0.0" 
}

# --- Handle dedicated operational modes first ---
if ($Setup.IsPresent) {
    $Global:Config = Get-Config -Path $Global:ConfigFile
    if ($null -eq $Global:Config) {
        Write-Host "[WARNING] Configuration file not found. Creating a default and starting setup GUI." -ForegroundColor Yellow
        $Global:Config = Get-DefaultConfig
        # FIX: Force writing the initial config file, ignoring the script's WhatIf preference.
        Save-Config -Config $Global:Config -Path $Global:ConfigFile -WhatIf:$false
    }
    
    do {
        $restartGui = $false
        Invoke-VersionControl -LoadedConfig $Global:Config -Path $Global:ConfigFile
        Initialize-LocalizationFiles
        $guiResult = Show-SetupGUI -InitialConfig $Global:Config
        if ($guiResult -eq 'Restart') {
            $restartGui = $true
            # Reload config if GUI saved changes and requested a restart.
            $Global:Config = Get-Config -Path $Global:ConfigFile
        } elseif ($null -ne $guiResult -and $guiResult -is [PSCustomObject]) {
            # Save the updated configuration
            Write-Log -Level INFO -Message "Saving updated configuration from Setup GUI..."
            Save-Config -Config $guiResult -Path $Global:ConfigFile
            $Global:Config = $guiResult
            Write-Log -Level INFO -Message "Configuration saved successfully."
            
            # Update network paths in template if profiles exist
            if ($guiResult.NetworkProfiles -and $guiResult.NetworkProfiles.Count -gt 0) {
                Update-NetworkPathsInTemplate -Config $guiResult
            }
        }
    } while ($restartGui)
    Write-Log -Level INFO -Message "Configuration finished. Script will exit."
    return
}

if ($Versionscontrol.IsPresent) {
    $Global:Config = Get-Config -Path $Global:ConfigFile
    if ($null -ne $Global:Config) {
        Invoke-VersionControl -LoadedConfig $Global:Config -Path $Global:ConfigFile
        Write-Log -Level INFO -Message "Version control check finished. Script will exit."
    } else {
        Write-Log -Level WARNING -Message "Configuration file not found. Cannot perform version control."
    }
    return
}

# --- Main execution logic ---
$emailSubject, $emailBody = $null, $null
try {
    $Global:Config = Get-Config -Path $Global:ConfigFile
    if ($null -eq $Global:Config) {
        # Auto-Setup logic as per rules
        Write-Host "[WARNING] Configuration file not found. Starting initial setup GUI automatically." -ForegroundColor Yellow
        $Global:Config = Get-DefaultConfig
        # FIX: Force writing the initial config file, ignoring the script's WhatIf preference.
        Save-Config -Config $Global:Config -Path $Global:ConfigFile -WhatIf:$false
        
        # The $Global:Config object is now valid and backed by a file. Proceed to GUI.
        do {
            $restartGui = $false
            Invoke-VersionControl -LoadedConfig $Global:Config -Path $Global:ConfigFile
            Initialize-LocalizationFiles
            $guiResult = Show-SetupGUI -InitialConfig $Global:Config
            if ($guiResult -eq 'Restart') { 
                $restartGui = $true
                $Global:Config = Get-Config -Path $Global:ConfigFile
            }
        } while ($restartGui)
        
        Write-Log -Level INFO -Message "Initial configuration finished. Please run the script again to apply settings."
        return
    }

    # Always run version control to ensure config object is complete
    Invoke-VersionControl -LoadedConfig $Global:Config -Path $Global:ConfigFile

    if ($Global:Config.Environment -eq "DEV") {
        $VerbosePreference = 'Continue'
        $DebugPreference = 'Continue'
        if ($Global:Config.WhatIfMode) {
            $WhatIfPreference = $true
            Write-Log -Level WARNING -Message "SCRIPT IS RUNNING IN SIMULATION (WhatIf) MODE. NO CHANGES WILL BE MADE."
        } else {
            $WhatIfPreference = $false
        }
    } else {
        $VerbosePreference = 'SilentlyContinue'
        $DebugPreference = 'SilentlyContinue'
        $WhatIfPreference = $false
    }
    Write-Log -Level INFO -Message "--- Script started: $Global:ScriptName $Global:ScriptVersion ---"
    Initialize-LocalAssets

    $templateSourcePath = $null
    if ($Global:Config.GitUpdate.Enabled) {
        $templateSourcePath = Invoke-GitUpdate
    }
    if ($null -eq $templateSourcePath) {
        $templateSourcePath = Join-Path $Global:ScriptDirectory 'Templates'
        Write-Log -Level INFO -Message "Using local template files from: $templateSourcePath"
    }
    $Global:Config.TemplateFilePaths = @{
        Profile    = Join-Path $templateSourcePath 'Profile-template.ps1';
        ProfileX   = Join-Path $templateSourcePath 'Profile-templateX.ps1';
        ProfileMOD = Join-Path $templateSourcePath 'Profile-templateMOD.ps1';
    }

    @($Global:Config.Logging.LogPath, $Global:Config.Logging.ReportPath, $Global:Config.Backup.Path) | ForEach-Object {
        if ($_ -and -not (Test-Path -Path $_ -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($_, "Create Directory")) {
                New-Item -ItemType Directory -Path $_ -Force -ErrorAction Stop | Out-Null
            }
        }
    }
    $Global:Config.TemplateFilePaths.Values | ForEach-Object {
        if (-not (Test-Path $_)) { throw "Template file '$_' not found. Please check configuration or repository." }
    }
    Write-Log -Level DEBUG -Message 'All template files found.'

    # Update network paths in ProfileX template if network profiles are configured
    if ($Global:Config.NetworkProfiles -and $Global:Config.NetworkProfiles.Count -gt 0) {
        Write-Log -Level INFO -Message 'Updating network paths in ProfileX template...'
        Update-NetworkPathsInTemplate -TemplateFilePath $Global:Config.TemplateFilePaths.ProfileX -NetworkProfiles $Global:Config.NetworkProfiles
    }

    Write-Log -Level INFO -Message 'Deleting existing PowerShell profiles...'
    Get-AllProfilePaths | ForEach-Object {
        if (Test-Path $_) {
            if ($PSCmdlet.ShouldProcess($_, "Delete Profile")) {
                try { Remove-Item $_ -Force -ErrorAction Stop; Write-Log -Level INFO -Message "  - Deleted: $_" }
                catch { Write-Log -Level WARNING -Message "Error deleting '$_': $($_.Exception.Message)" }
            }
        }
    }

    Write-Log -Level INFO -Message 'Creating new profiles from templates...'
    $systemwideProfilePath = Get-SystemwideProfilePath
    $systemwideProfileDir = Split-Path $systemwideProfilePath -Parent
    if (-not (Test-Path $systemwideProfileDir)) {
        if ($PSCmdlet.ShouldProcess($systemwideProfileDir, "Create Directory")) {
            New-Item -ItemType Directory -Path $systemwideProfileDir -Force | Out-Null
        }
    }
    $templateMapping = @{
        Profile    = $systemwideProfilePath;
        ProfileX   = Join-Path $systemwideProfileDir 'profileX.ps1';
        ProfileMOD = Join-Path $systemwideProfileDir 'ProfileMOD.ps1';
    }

    foreach ($templateKey in $templateMapping.Keys) {
        $templatePath = $Global:Config.TemplateFilePaths[$templateKey]
        $destinationPath = $templateMapping[$templateKey]
        if ($null -eq $Global:Config.TemplateVersions) { $Global:Config.TemplateVersions = @{} }
        if ($null -eq $Global:Config.TargetTemplateVersions) { $Global:Config.TargetTemplateVersions = @{} }
        
        # Correctly access properties on the PSCustomObject from JSON
        $oldTemplateVersion = $Global:Config.TemplateVersions.PSObject.Properties[$templateKey].Value
        $versionToSet = $Global:Config.TargetTemplateVersions.PSObject.Properties[$templateKey].Value

        if ($PSCmdlet.ShouldProcess($destinationPath, "Create Profile from $($templatePath | Split-Path -Leaf)")) {
            try {
                Copy-Item -Path $templatePath -Destination $destinationPath -Force -ErrorAction Stop
                Write-Log -Level INFO -Message "  - Created: $destinationPath"
                Set-TemplateVersion -FilePath $destinationPath -NewVersion $versionToSet -OldVersion $oldTemplateVersion
                
                # Correctly assign the new version back to the PSCustomObject
                $Global:Config.TemplateVersions.PSObject.Properties[$templateKey].Value = $versionToSet
            }
            catch { Write-Log -Level ERROR -Message "Error creating '$destinationPath': $($_.Exception.Message)" }
        }
    }

    Write-Log -Level INFO -Message 'PowerShell profiles have been reset successfully.'
    $emailSubject = "SUCCESS: Profile-Reset on $($env:COMPUTERNAME)"
    $emailBody = "Script '$($Global:ScriptName)' ($($Global:ScriptVersion)) finished successfully on $($env:COMPUTERNAME) at $(Get-Date)."
}
catch {
    $errorMessage = "Critical Error: $($_.Exception.Message)"
    Write-Log -Level ERROR -Message $errorMessage
    $emailSubject = "FAILURE: Profile-Reset on $($env:COMPUTERNAME)"
    $dateStr = Get-Date
    $emailBody = "Script '$($Global:ScriptName)' ($($Global:ScriptVersion)) failed on $($env:COMPUTERNAME) at $dateStr. Error: $($_.Exception.Message)"
}
finally {
    if ($Global:Config) {
        if ($emailSubject) { Send-MailNotification -Subject $emailSubject -Body $emailBody }
        Invoke-ArchiveMaintenance
        Save-Config -Config $Global:Config -Path $Global:ConfigFile | Out-Null
    }
    Write-Log -Level INFO -Message "Script finished successfully"
}
#endregion

# --- End of Script --- old: v11.2.2 ; now: v11.2.6 ; Regelwerk: v9.6.2 ---
