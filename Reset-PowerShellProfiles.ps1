<#
.SYNOPSIS
    [DE] Setzt alle PowerShell-Profile auf einen Standard zurück, versioniert Vorlagen und verwaltet die Konfiguration über eine GUI.
    [EN] Resets all PowerShell profiles to a standard, versions templates, and manages the configuration via a GUI.
.DESCRIPTION
    [DE] Ein vollumfängliches Verwaltungsskript für PowerShell-Profile gemäss MUW-Regeln. Es erzwingt Administratorrechte,
         stellt die UTF-8-Kodierung sicher und bietet eine WPF-basierte GUI (-Setup) zur Konfiguration. Bei fehlender
         oder korrupter Konfiguration startet die GUI automatisch. Das Skript führt eine Versionskontrolle der Konfiguration
         durch, versioniert die Profil-Vorlagen, schreibt in das Windows Event Log und beinhaltet eine voll funktionsfähige
         Log-Archivierung sowie einen Mail-Versand.
    [EN] A comprehensive management script for PowerShell profiles according to MUW rules. It enforces administrator rights,
         ensures UTF-8 encoding, and provides a WPF-based GUI (-Setup) for configuration. The GUI starts automatically
         if the configuration is missing or corrupt. The script performs version control of the configuration, versions
         the profile templates, writes to the Windows Event Log, and includes fully functional log archiving and mail sending.
.PARAMETER Setup
    [DE] Startet die WPF-Konfigurations-GUI, um die Einstellungen zu bearbeiten.
    [EN] Starts the WPF configuration GUI to edit the settings.
.PARAMETER Versionscontrol
    [DE] Prüft die Konfigurationsdatei gegen die Skript-Version, zeigt Unterschiede an und aktualisiert sie.
    [EN] Checks the configuration file against the script version, displays differences, and updates it.
.PARAMETER ConfigFile
    [DE] Pfad zur JSON-Konfigurationsdatei. Standard: 'Config\Config-Reset-PowerShellProfiles.ps1.json' im Skriptverzeichnis.
    [EN] Path to the JSON configuration file. Default: 'Config\Config-Reset-PowerShellProfiles.ps1.json' in the script directory.
.EXAMPLE
    .\Reset-PowerShellProfiles.ps1
    [DE] Führt das Skript aus. Setzt die Profile zurück und fordert bei Bedarf Admin-Rechte an. Startet die GUI bei Erstkonfiguration.
    [EN] Executes the script. Resets the profiles and requests admin rights if necessary. Starts the GUI on first configuration.
.EXAMPLE
    .\Reset-PowerShellProfiles.ps1 -Setup
    [DE] Öffnet die Konfigurations-GUI, um die aktuellen Einstellungen zu ändern.
    [EN] Opens the configuration GUI to change the current settings.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.11
    Last modified:  2025.09.01
    old Version:    v10.2.0
    Version now:    v10.3.0
    MUW-Regelwerk:  v7.7.0
    Notes:          [DE] GUI-Modul-Fehler durch Umstellung auf .default-Sprachvorlagen behoben. Git-Fallback implementiert.
                    [EN] Fixed GUI module error by switching to .default language templates. Implemented Git fallback.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>
#requires -Version 5.1
#requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Switch]$Setup,
    [Switch]$Versionscontrol,
    [string]$ConfigFile
)

#region ####################### [1. Initialization] ##############################
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v10.3.0"
$Global:RulebookVersion = "v7.7.0"
$Global:ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path

$configDir = Join-Path $Global:ScriptDirectory 'Config'
if (-not (Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory | Out-Null
}

if ([string]::IsNullOrEmpty($ConfigFile)) {
    $ConfigFile = Join-Path -Path $configDir -ChildPath "Config-$($MyInvocation.MyCommand.Name).json"
}

$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
#endregion

#region ####################### [2. Module Import] #################################################
try {
    $modulePath = Join-Path $Global:ScriptDirectory "Modules"
    Import-Module (Join-Path $modulePath "FL-Config.psm1") -ErrorAction Stop
    Import-Module (Join-Path $modulePath "FL-Logging.psm1") -ErrorAction Stop
    Import-Module (Join-Path $modulePath "FL-Gui.psm1") -ErrorAction Stop
    Import-Module (Join-Path $modulePath "FL-Maintenance.psm1") -ErrorAction Stop
    Import-Module (Join-Path $modulePath "FL-Utils.psm1") -ErrorAction Stop
}
catch {
    Write-Error "A critical error occurred while loading essential modules: $($_.ToString())"
    # Exit the script immediately if modules can't be loaded, as it cannot function.
    return
}
#endregion

#region ####################### [5. Script Main Body] ##############################
$oldVersion = try {
    (Get-Content -Path $MyInvocation.MyCommand.Path -TotalCount 30 -ErrorAction SilentlyContinue | Select-String 'Version now:\s*(v[\d\.]+)' | ForEach-Object { $_.Matches.Groups[1].Value })[0]
} catch { "v0.0.0" }

if ($Setup.IsPresent) {
    do {
        $restartGui = $false
        $Global:Config = Get-Config -Path $ConfigFile
        if ($null -eq $Global:Config) {
            Write-Log -Level WARNING -Message "Configuration file not found or corrupt. Using default values for GUI."
            $Global:Config = Get-DefaultConfig
        }
        Invoke-VersionControl -LoadedConfig $Global:Config -Path $ConfigFile
        Initialize-LocalizationFiles -ConfigDirectory $configDir
        $guiResult = Show-MuwSetupGui -InitialConfig $Global:Config
        if ($guiResult -eq 'Restart') {
            $restartGui = $true
        }
    } while ($restartGui)
    Write-Log -Level INFO -Message "Configuration finished. Script will exit."
    return
}

if ($Versionscontrol.IsPresent) {
    $Global:Config = Get-Config -Path $ConfigFile
    if ($null -ne $Global:Config) {
        Invoke-VersionControl -LoadedConfig $Global:Config -Path $ConfigFile
        Write-Log -Level INFO -Message "Version control check finished. Script will exit."
    }
    else {
        Write-Log -Level WARNING -Message "Configuration file not found. Cannot perform version control."
    }
    return
}

$emailSubject, $emailBody = $null, $null
try {
    $Global:Config = Get-Config -Path $ConfigFile
    if ($null -eq $Global:Config) {
        throw "Configuration file `"$ConfigFile`" not found or corrupt. Please run the script with the -Setup parameter first."
    }
    if ($Global:Config.Environment -eq "DEV") {
        $VerbosePreference = 'Continue'
        $DebugPreference = 'Continue'
        if ($Global:Config.WhatIfMode) {
            $WhatIfPreference = $true
            Write-Log -Level WARNING -Message "SCRIPT IS RUNNING IN SIMULATION (WhatIf) MODE. NO CHANGES WILL BE MADE."
        }
    }
    else {
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
    
    # Fallback to local templates if Git update fails or is disabled
    if ($null -eq $templateSourcePath) {
        $templateSourcePath = $Global:ScriptDirectory
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
        $oldTemplateVersion = $Global:Config.TemplateVersions[$templateKey]
        $versionToSet = $Global:Config.TargetTemplateVersions[$templateKey]

        if ($PSCmdlet.ShouldProcess($destinationPath, "Create Profile from $($templatePath | Split-Path -Leaf)")) {
            try {
                Copy-Item -Path $templatePath -Destination $destinationPath -Force -ErrorAction Stop
                Write-Log -Level INFO -Message "  - Created: $destinationPath"
                Set-TemplateVersion -FilePath $destinationPath -NewVersion $versionToSet -OldVersion $oldTemplateVersion
                $Global:Config.TemplateVersions[$templateKey] = $versionToSet
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
    $emailBody = "Script '$($Global:ScriptName)' ($($Global:ScriptVersion)) failed on $($env:COMPUTERNAME) at $(Get-Date).`n`nError:`n$($_.Exception.Message)"
}
finally {
    if ($Global:Config) {
        if ($emailSubject) { Send-MailNotification -Subject $emailSubject -Body $emailBody }
        Invoke-ArchiveMaintenance
        Save-Config -Config $Global:Config -Path $ConfigFile | Out-Null
    }
    Write-Log -Level INFO -Message "--- Script finished: $Global:ScriptName. ---"
}
#endregion

# --- End of Script --- old: v10.2.0 ; now: v10.3.0 ; Regelwerk: v7.7.0 ---

