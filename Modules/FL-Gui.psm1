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
    Last modified:  2025.09.01
    Version:        v11.0.0
    MUW-Regelwerk:  v8.0.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Get-DefaultConfig {
    Write-Log -Level DEBUG -Message "Creating default configuration object."
    return [PSCustomObject]@{
        ScriptVersion          = $Global:ScriptVersion
        RulebookVersion        = $Global:RulebookVersion
        Language               = "en-US"
        Environment            = "DEV"
        WhatIfMode             = $true
        Logging                = @{
            LogPath              = (Join-Path $Global:ScriptDirectory "LOG")
            ReportPath           = (Join-Path $Global:ScriptDirectory "Reports")
            ArchiveLogs          = $true
            EnableEventLog       = $true
            LogRetentionDays     = 30
            ArchiveRetentionDays = 90
            SevenZipPath         = "C:\Program Files\7-Zip\7z.exe"
        }
        TemplateFilePaths      = @{
            Profile    = Join-Path $Global:ScriptDirectory 'Profile-template.ps1';
            ProfileX   = Join-Path $Global:ScriptDirectory 'Profile-templateX.ps1';
            ProfileMOD = Join-Path $Global:ScriptDirectory 'Profile-templateMOD.ps1';
        }
        TemplateVersions       = @{ Profile = "v0.0.0"; ProfileX = "v0.0.0"; ProfileMOD = "v0.0.0" }
        TargetTemplateVersions = @{ Profile = "v25.0.0"; ProfileX = "v8.0.0"; ProfileMOD = "v7.0.0" }
        LanguageFileVersions   = @{ "de-DE" = "v1.0.0"; "en-US" = "v1.0.0" }
        Backup                 = @{
            Enabled = $false
            Path    = (Join-Path $Global:ScriptDirectory "Backup")
        }
        Mail                   = @{
            Enabled      = $false
            SmtpServer   = "smtp.example.com"
            Sender       = "powershell@example.com"
            DevRecipient = "dev@example.com"
            ProdRecipient = "prod@example.com"
        }
        GitUpdate              = @{
            Enabled  = $false
            RepoUrl  = "https://github.com/user/repo.git"
            Branch   = "main"
            CachePath = (Join-Path $env:TEMP "GitProfileCache")
        }
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
    if ($PSCmdlet.ShouldProcess($Path, "Save Configuration")) {
        try {
            Write-Log -Level DEBUG -Message "Saving configuration to '$Path'."
            $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
        }
        catch {
            Write-Log -Level ERROR -Message "Error saving configuration file: $($_.Exception.Message)"
        }
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
            if (-not $Target.PSObject.Properties.Contains($key)) {
                Write-Log -Level WARNING -Message "Missing property in configuration. Adding '$key'."
                $Target | Add-Member -MemberType NoteProperty -Name $key -Value $Reference.$key
                $updated = $true
            }
            elseif (($Reference.$key -is [PSCustomObject]) -and ($Target.$key -is [PSCustomObject])) {
                if (Compare-AndUpdate -Reference $Reference.$key -Target $Target.$key) {
                    $updated = $true
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
    if ($isUpdated) {
        Write-Log -Level INFO -Message "Configuration file has been updated. Saving changes."
        Save-Config -Config $LoadedConfig -Path $Path
    } else {
        Write-Log -Level INFO -Message "Configuration is up to date."
    }
}

# --- End of module --- v11.0.0 ; Regelwerk: v8.0.0 ---
