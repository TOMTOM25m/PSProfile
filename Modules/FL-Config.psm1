<#
.SYNOPSIS
    [DE] Modul für Konfigurationsmanagement.
    [EN] Module for configuration management.
.DESCRIPTION
    [DE] Enthält Funktionen zum Laden, Speichern und Verwalten der JSON-Konfigurationsdatei.
    [EN] Contains functions for loading, saving, and managing the JSON configuration file.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.09.02
    Version:        v11.2.1
    MUW-Regelwerk:  v8.2.0
    Notes:          [DE] Stabile Version nach Fix der Erst-Initialisierung.
                    [EN] Stable version after initial setup fix.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Get-DefaultConfig {
    Write-Log -Level DEBUG -Message "Creating default configuration object."
    
    $disclaimerDE = @"
Die bereitgestellten Skripte und die zugehörige Dokumentation werden "wie besehen" ("as is")
ohne ausdrückliche oder stillschweigende Gewährleistung jeglicher Art zur Verfügung gestellt.
Insbesondere wird keinerlei Gewähr übernommen für die Marktgängigkeit, die Eignung für einen bestimmten Zweck
oder die Nichtverletzung von Rechten Dritter.
Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder Unterstützung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
Entwicklung oder Verbreitung dieser Skripte für direkte, indirekte, zufällige, besondere oder Folgeschäden - einschließlich,
aber nicht beschränkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
selbst wenn sie auf die Möglichkeit solcher Schäden hingewiesen wurden.
Durch die Nutzung der Skripte erklären Sie sich mit diesen Bedingungen einverstanden.
"@
    $disclaimerEN = @"
The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
fitness for a particular purpose, and non-infringement.
There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
including but not not limited to direct, indirect, incidental, consequential, or special damages
(such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
By using these scripts, you agree to be bound by the above terms.
"@

    return [PSCustomObject]@{ 
        ScriptVersion          = $Global:ScriptVersion
        RulebookVersion        = $Global:RulebookVersion
        Language               = "en-US"
        Environment            = "DEV"
        WhatIfMode             = $false
        Disclaimer             = @{ DE = $disclaimerDE; EN = $disclaimerEN }
        GuiAssets              = @{
            LogoPath = (Join-Path $Global:ScriptDirectory "Config\MedUniWien_logo.png")
            IconPath = (Join-Path $Global:ScriptDirectory "Config\MedUniWien_logo.ico")
        }
        UNCPaths               = @{
            AssetDirectory = "\\\\itscmgmt03.srv.meduniwien.ac.at\iso\MUWLogo"
        }
        Logging                = @{
            LogPath              = (Join-Path $Global:ScriptDirectory "LOG")
            ReportPath           = (Join-Path $Global:ScriptDirectory "Reports")
            ArchiveLogs          = $true
            EnableEventLog       = $true
            LogRetentionDays     = 30
            ArchiveRetentionDays = 90
            SevenZipPath         = "C:\Program Files\7-Zip\7z.exe"
        }
        TemplateFilePaths      = @{}
        TemplateVersions       = @{ Profile = "v0.0.0"; ProfileX = "v0.0.0"; ProfileMOD = "v0.0.0" }
        TargetTemplateVersions = @{ Profile = "v25.0.0"; ProfileX = "v8.0.0"; ProfileMOD = "v7.0.0" }
        LanguageFileVersions   = @{ "de-DE" = "v1.0.0"; "en-US" = "v1.0.0" }
        Backup                 = @{
            Enabled = $false
            Path    = (Join-Path $Global:ScriptDirectory "Backup")
        }
        Mail                   = @{
            Enabled      = $false
            SmtpServer   = "smtpi.meduniwien.ac.at"
            Sender       = "${env:computername}@meduniwien.ac.at"
            DevRecipient = "thomas.garnreiter@meduniwien.ac.at"
            ProdRecipient = "win-admin@meduniwien.ac.at"
        }
        GitUpdate              = @{
            Enabled  = $false
            RepoUrl  = "https://github.com/TOMTOM25m/PSProfile.git"
            Branch   = "main"
            CachePath = (Join-Path $env:TEMP "GitProfileCache")
        }
        NetworkProfiles        = @(
            @{
                Name = "Example Network Share"
                Path = "\\\\server\\share"
                Enabled = $false
                Username = ""
                EncryptedPassword = ""
            }
        )
    }
}

function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return Get-Content -Path $Path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log -Level ERROR -Message "Configuration file '$Path' could not be read or is corrupt. Error: $($_.Exception.Message)"
        return $null
    }
}

function Save-Config {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Config,
        [Parameter(Mandatory = $true)][string]$Path
    )
    if ([string]::IsNullOrEmpty($Path)) {
        Write-Log -Level ERROR -Message "Save-Config was called with an empty path. Configuration cannot be saved."
        return
    }
    
    try {
        if ($PSCmdlet.ShouldProcess($Path, "Save Configuration")) {
            Write-Log -Level DEBUG -Message "Saving configuration to '$Path'."
            $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Error saving configuration file: $($_.Exception.Message)"
    }
}

function Invoke-VersionControl {
    param(
        [Parameter(Mandatory=$true)][PSCustomObject]$LoadedConfig,
        [Parameter(Mandatory=$true)][string]$Path
    )
    Write-Log -Level INFO -Message "Starting version control for configuration file..."
    $defaultConfig = Get-DefaultConfig
    $isUpdated = $false

    function Compare-AndUpdate($Reference, $Target) {
        $updated = $false
        foreach ($key in $Reference.PSObject.Properties.Name) {
            $refValue = $Reference.$key
            $targetHasProperty = $Target.PSObject.Properties.Name -contains $key
            
            if (-not $targetHasProperty) {
                Write-Log -Level WARNING -Message "Missing property in configuration. Adding '$key'."
                $Target | Add-Member -MemberType NoteProperty -Name $key -Value $refValue
                $updated = $true
            }
            else {
                $targetValue = $Target.$key
                if (($refValue -is [PSCustomObject]) -and ($targetValue -is [PSCustomObject])) {
                    if (Compare-AndUpdate -Reference $refValue -Target $targetValue) {
                        $updated = true
                    }
                }
                elseif (($refValue -is [PSCustomObject]) -and -not ($targetValue -is [PSCustomObject])) {
                    Write-Log -Level WARNING -Message "Property '$key' has an incorrect type or is null. Overwriting with default structure."
                    $Target.$key = $refValue
                    $updated = true
                }
            }
        }
        return $updated
    }

    if (Compare-AndUpdate -Reference $defaultConfig -Target $LoadedConfig) {
        $isUpdated = $true
    }
    if ($LoadedConfig.RulebookVersion -ne $Global:RulebookVersion) {
        Write-Log -Level WARNING -Message "Rulebook version conflict! Script requires $($Global:RulebookVersion), Config has $($LoadedConfig.RulebookVersion). Updating."
        $LoadedConfig.RulebookVersion = $Global:RulebookVersion
        $isUpdated = $true
    }
     if ($LoadedConfig.ScriptVersion -ne $Global:ScriptVersion) {
        Write-Log -Level WARNING -Message "Version conflict! Script is $($Global:ScriptVersion), Config was $($LoadedConfig.ScriptVersion). Configuration will be updated."
        $LoadedConfig.ScriptVersion = $Global:ScriptVersion
        $isUpdated = $true
    }
    if ($isUpdated) {
        Write-Log -Level INFO -Message "Configuration file has been updated. Saving changes."
        Save-Config -Config $LoadedConfig -Path $Path
    } else {
        Write-Log -Level INFO -Message "Configuration is up to date."
    }
}

# --- End of module --- v11.2.1 ; Regelwerk: v8.2.0 ---