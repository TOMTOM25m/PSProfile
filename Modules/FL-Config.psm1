<#
.SYNOPSIS
    [EN] Module for handling script configuration.
    [DE] Modul für die Handhabung der Skriptkonfiguration.
.DESCRIPTION
    [EN] This module contains functions related to loading, saving, and managing the JSON configuration for the Reset-PowerShellProfiles.ps1 script.
    [DE] Dieses Modul enthält Funktionen zum Laden, Speichern und Verwalten der JSON-Konfiguration für das Skript Reset-PowerShellProfiles.ps1.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.08.29
    Version:        v09.04.00
    MUW-Regelwerk:  v7.3.0
    Copyright:      © 2025 Flecki Garnreiter
#>

function Get-DefaultConfig {
    # This function doesn't write logs because $Global:Config might not exist yet.
    return [PSCustomObject]@{ 
        Version           = $Global:ScriptVersion
        RulebookVersion   = "v7.3.0"
        Language          = "de-DE"
        LanguageFileVersions = @{
            "de-DE" = "v1.0.0"
            "en-US" = "v1.0.0"
        }
        Environment       = "DEV"
        WhatIfMode        = $true
        TemplateVersions  = @{
            Profile    = "v23.0.1"
            ProfileX   = "v6.0.0"
            ProfileMOD = "v6.0.0"
        }
        TemplateFilePaths = @(
            (Join-Path $Global:ScriptDirectory 'Profile-template.ps1'),
            (Join-Path $Global:ScriptDirectory 'Profile-templateX.ps1'),
            (Join-Path $Global:ScriptDirectory 'Profile-templateMOD.ps1')
        )
        UNCPaths          = @{
            Logo = '\\itscmgmt03.srv.meduniwien.ac.at\iso\DEV\Images\Logo.ico'
        }
        Logging           = @{
            LogPath              = (Join-Path $Global:ScriptDirectory "LOG")
            ReportPath           = (Join-Path $Global:ScriptDirectory "Reports")
            LogoPath             = (Join-Path $Global:ScriptDirectory "Images\Logo.ico")
            EnableEventLog       = $true
            ArchiveLogs          = $true
            LogRetentionDays     = 30
            ArchiveRetentionDays = 90
            SevenZipPath         = "C:\Program Files\7-Zip\7z.exe"
        }
        Backup            = @{
            Enabled = $false
            Path    = ""
        }
        Mail              = @{
            Enabled    = $false
            SmtpServer = "smtpi.meduniwien.ac.at"
            SmtpPort   = 25
            UseSsl     = $false
            Sender     = "$($env:COMPUTERNAME)@meduniwien.ac.at"
            DevTo      = "Thomas.garnreiter@meduniwien.ac.at"
            ProdTo     = "win-admin@meduniwien.ac.at;another.admin@meduniwien.ac.at"
        }
        GitUpdate         = @{
            Enabled        = $false
            RepositoryUrl  = "https://your-git-server/user/powershell-profiles.git"
            Branch         = "main"
            LocalCachePath = (Join-Path $Global:ScriptDirectory "GitCache")
        }
    }
}

function Save-Config {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([PSCustomObject]$Config, [string]$Path, [switch]$NoHostWrite)

    try {
        Write-Log -Level DEBUG -Message "Saving configuration to '$Path'." -NoHostWrite:$NoHostWrite
        $Config.Version = $Global:ScriptVersion
        $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
        return $true
    }
    catch {
        Write-Log -Level ERROR -Message "Error saving configuration file: $($_.Exception.Message)" -NoHostWrite:$NoHostWrite
        return $false
    }
}

function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    try {
        $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Log -Level WARNING -Message "Configuration file '$Path' is corrupt."
        return $null
    }
}

function Invoke-VersionControl {
    param([PSCustomObject]$LoadedConfig, [string]$ConfigPath)
    Write-Log -Level INFO -Message "Starting version control for configuration file..."
    $defaultConfig = Get-DefaultConfig
    $isUpdated = $false
    function Compare-AndUpdate($Reference, $Target) {
        $updated = $false
        foreach ($key in $Reference.PSObject.Properties.Name) {
            # Robustly check if the target object has a property with the same name as the key from the reference object.
            if (-not $Target.PSObject.Properties[$key]) {
                Write-Log -Level WARNING -Message "Missing property in configuration found. Adding '$key'."
                $Target | Add-Member -MemberType NoteProperty -Name $key -Value $Reference.$key
                $updated = $true
            }
            elseif (($Reference.$key -is [PSCustomObject]) -and ($Target.$key -is [PSCustomObject])) {
                # Recurse into nested objects
                if (Compare-AndUpdate -Reference $Reference.$key -Target $Target.$key) { $updated = $true }
            }
        }
        return $updated
    }
    if (Compare-AndUpdate -Reference $defaultConfig -Target $LoadedConfig) { $isUpdated = $true }
    if ($LoadedConfig.Version -ne $Global:ScriptVersion) {
        Write-Log -Level WARNING -Message "Version conflict! Script is $($Global:ScriptVersion), Config was $($LoadedConfig.Version). Configuration will be updated."
        $LoadedConfig.Version = $Global:ScriptVersion
        $isUpdated = $true
    }
    if ($LoadedConfig.RulebookVersion -ne $Global:RulebookVersion) {
        Write-Log -Level WARNING -Message "Rulebook version conflict! Script requires $($Global:RulebookVersion), Config has $($LoadedConfig.RulebookVersion). Updating."
        $LoadedConfig.RulebookVersion = $Global:RulebookVersion
        $isUpdated = $true
    }
    if ($isUpdated) {
        Write-Log -Level INFO -Message "Configuration file has been updated. Saving changes."
        Save-Config -Config $LoadedConfig -Path $ConfigPath
    }
    else { Write-Log -Level INFO -Message "Configuration is up to date." }
}

Export-ModuleMember -Function Get-DefaultConfig, Save-Config, Get-Config, Invoke-VersionControl

# --- End of module --- v09.04.00 ; Regelwerk: v7.3.0 ---