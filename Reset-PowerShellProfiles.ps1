<#
.SYNOPSIS
    [DE] Setzt alle PowerShell-Profile auf einen Standard zurueck und verwaltet die Konfiguration ueber eine GUI.
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
    [DE] Prüft die Konfigurationsdatei gegen die Skript-Version, zeigt Unterschiede an und aktualisiert sie.
    [EN] Checks the configuration file against the script version, displays differences, and updates it.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.11
    Last modified:  2025.09.02
    old Version:    v11.2.1
    Version now:    v11.2.2
    MUW-Regelwerk:  v8.2.0
    Notes:          [DE] Network Profiles-Feature hinzugefuegt: Konfigurierbare Netzwerkpfade mit verschluesselten Credentials fuer Profile-TemplateX.ps1.
                    [EN] Added Network Profiles feature: Configurable network paths with encrypted credentials for Profile-TemplateX.ps1.
    Copyright:      © 2025 Flecki Garnreiter
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
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v11.2.2"
$Global:RulebookVersion = "v8.2.0"
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
        # Initialize-LocalizationFiles  # TODO: Implement if needed
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
            # Initialize-LocalizationFiles  # TODO: Implement if needed
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
    $emailBody = "Script '$($Global:ScriptName)' ($($Global:ScriptVersion)) failed on $($env:COMPUTERNAME) at $(Get-Date).`n`nError:`n$($_.Exception.Message)"
}
finally {
    if ($Global:Config) {
        if ($emailSubject) { Send-MailNotification -Subject $emailSubject -Body $emailBody }
        Invoke-ArchiveMaintenance
        Save-Config -Config $Global:Config -Path $Global:ConfigFile | Out-Null
    }
    Write-Log -Level INFO -Message "--- Script finished: $($Global:ScriptName). Old Version: $oldVersion -> New Version: $($Global:ScriptVersion) ---"
}
#endregion

# --- End of Script --- old: v11.2.1 ; now: v11.2.2 ; Regelwerk: v8.2.0 ---

# SIG # Begin signature block
# MIIb/gYJKoZIhvcNAQcCoIIb7zCCG+sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUKBuJ/KGTViWpeTvAPVLkYmgs
# Wf+gghZgMIIDIjCCAgqgAwIBAgIQSrQKC5vlGaZCUpHrJkIsMTANBgkqhkiG9w0B
# AQsFADApMRQwEgYDVQQKDAtZb3VyQ29tcGFueTERMA8GA1UEAwwIWW91ck5hbWUw
# HhcNMjUwOTAzMTAyOTA0WhcNMzAwOTAzMTAzOTA0WjApMRQwEgYDVQQKDAtZb3Vy
# Q29tcGFueTERMA8GA1UEAwwIWW91ck5hbWUwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCnipm3cYerBn8htsu7JHe+iONzVLuTaocSedCEGTSFfaLeVEUE
# SO3I8nElPYdaj18doUNoo1jHtuPsIjvDTF9BjuiGhL3AvAVopL+JJgVbQuL6sR0H
# mycTzwJliVGN407OZ1F1tC5O2sUWvDcFe6KpqcOHKBpuErB0aUkdR44tdlOYCIL1
# xyMDe6pIzkrttPKgxLWh0ZXd3pukYRaVX+3PsAIWFbz3iJ1kS3qTq65/bvIMR3jt
# ZHQQBRulw6viscaGgYE+cR+WMNz5brsVoebZHiqdZv6m03QNidj/oL2w3KpZcCX1
# abwwtJ4vEAElgzjZG6I3A2N1CGQCQ3R0vuqtAgMBAAGjRjBEMA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU7Saz/ceN2QTiqREx
# Oxv3P2Ij13UwDQYJKoZIhvcNAQELBQADggEBAIJV6u7yU7Cp0LgIqBV4c6bwgHta
# hnFN2/68DYSJoDE2rXgOk7SVg98hUtBqJVpf1l+d0+cmEqQDhK+4cZ8XaYi7mxI8
# sq9juiuR+T+XD5LTQaEF3SNRjnLMLAaRH1t+wcSphfVDrDL1ibTO5BQce9zsqBoI
# v1/GqTftZ/T5WDhqb0XsUR1biTWFC+mkUTqz7w9W9azdCS9vdEfmn3vhPvpYjt9T
# I5Ubp3tRNai8qzwRYEgaUwyIAaa4CZlyp9n23fmpv6qGVMcPJQZtwLOWR5Zf/ds2
# T6iTA2QJgSAwjEiVHqTKRFq1niCL4WjmazcvTuQX2bVIQoEwTWbBjoGaLb4wggWN
# MIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK
# 2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/G
# nhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJ
# IB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4M
# K7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN
# 2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I
# 11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KIS
# G2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9
# HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4
# pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpy
# FiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS31
# 2amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs
# 1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd
# 823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzAB
# hhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9j
# YWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQw
# RQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZI
# hvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4
# hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3
# rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs
# 9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K
# 2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0n
# ftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwgga0MIIEnKADAgECAhANx6xX
# Bf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAf
# BgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBa
# Fw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2Vy
# dCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBp
# bmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1D
# ahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn
# 5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLux
# BG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3I
# fDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cV
# FBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQ
# T/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gby
# lsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rK
# WDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6
# z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9Vne
# Ps6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQAB
# o4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6
# yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYD
# VR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGsw
# aTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUF
# BzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeB
# DAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2
# cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe3
# 6zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMD
# PjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2
# AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410
# ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47O
# vgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39
# OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9v
# ODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3
# s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5
# TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXK
# UjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC0cR2
# p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0
# YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAwMFoX
# DTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1lc3Rh
# bXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA69HF
# TBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6wW2R6
# kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00Cll8
# pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOMA3Co
# B/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmotuQhc
# g9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1Opbyb
# pMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeHVZlc
# 4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1roSrg
# HjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSUROwnu7
# zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+giAwW00aHz
# rDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGVMIIB
# kTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM6DAf
# BgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMCB4Aw
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKGUWh0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVT
# dGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSgUqBQ
# hk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1l
# U3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAIBgZn
# gQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcEua5g
# QezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/YmRDfx
# T7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8AQ/U
# dKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/EABgf
# ZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQVTeL
# ni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gVutDo
# jBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85EE8L
# UkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hggt8l
# 2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJgKf4
# 7CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLvUxxV
# ZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7POGT7
# 5qaL6vdCvHlshtjdNXOCIUjsarfNZzGCBQgwggUEAgEBMD0wKTEUMBIGA1UECgwL
# WW91ckNvbXBhbnkxETAPBgNVBAMMCFlvdXJOYW1lAhBKtAoLm+UZpkJSkesmQiwx
# MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3
# DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEV
# MCMGCSqGSIb3DQEJBDEWBBSzvmCMXREFRuuDEa13dJJQiFlZSjANBgkqhkiG9w0B
# AQEFAASCAQCXNeZpMFSBzfd2avuiOQpzlnHcYF6L3qzfu7oHwXFzh/iO8jL9+FNk
# gP3ax/iwqPQYbUkRYIO6dMbqNN6+k+t52Q3jGk/SD/NDPtbdHzMSSiB6x/XHErtN
# jiA/JwAsH42mvgrazTdnwo2+EAMwQxWBzluX2qpKP7j4dWUo0Eyblam/Dbw9JFcZ
# 2wGIyFIgc3GNa+DBIgCpL86U9d0YWc1kgN7v6W6pyO49jAT8QmuTm6yTH00LPOcv
# pVmulTiUv1xv3WmOriAJC6c+xm1ZExsN7FsiAs3WB1qSRYJgeov4hywwnsrEY8xB
# C1NxgvsLa8KviwK39oTmeiwSnrUVphmMoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMw
# ggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0
# MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTI1MDkwMzEwNDYxMVowLwYJKoZIhvcNAQkEMSIEIPXAHyxqjd3ZnGckbt8Ak/ap
# /yqS6LdDLFVhmFvubo7iMA0GCSqGSIb3DQEBAQUABIICAL4bYRNzRDAdPtumS/3d
# FIKzsvTerpaVVJsPAZI0XOXd1cQc3wOwXNLF9p13SXNkcJGWWfM+wwjyjVqo7SEv
# z1k2xVml/NzR+VIHQK//q2RamGN9fp1hciya8aGDux3QZYygxc3FndAcSkidTNHt
# x/iwW7hTrzG1AhdoOJtg2LPUwS/Pr33vef1GDeLylX5yIfX5naSDHWZhHNj0qnLN
# +FHgTzuYmSy4BW22lD41IqunV5VpMHkMXPG/adThqufY39qF+jVfY3TpjcRqihBL
# VVJVxjqa76mACBvr4qEN+dXU+YevrGr/mppLVLwRU48lpDrmWqZbYG3ITDg2qsB8
# r4u+gbP4l0A5XxlIEK7mknXJ7Da/8KKs1xglfdl94N+cuSxa6dPJa60O0a7MgrrW
# g5W+fumP9BtgiS8mKYgwrNN+yPIf+/HzSfhv/w8krZ7Oz6GdwWipTfd9jfWt0ey3
# fHWWQkyT4wQJKSpzltVyPvUZi0sN9Mcrl6X/iLdbyO6wjSkdcaq3H3ZIXv/ECTnA
# 9XUisqNj0357i4k6xLq8GYusiokqP3xs5GgdDwZlmJYPdR9Jp+EgUtVKWtbjivat
# wLc5wEZ7e7MM7m+tOKfqqac1jbSO7sM565Ht9pzVXqvo8nHM23Pvf9EoIpZpy1aq
# +p1mO+QmpMlN/z+iMeDbxIYn
# SIG # End signature block
