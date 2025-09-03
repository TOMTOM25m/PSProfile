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
    Version:        v11.2.2
    MUW-Regelwerk:  v8.2.0
    Notes:          [DE] Network Profiles-Feature hinzugefügt mit verschlüsselten Credentials.
                    [EN] Added Network Profiles feature with encrypted credentials.
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

function ConvertTo-SecureCredential {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'This function intentionally accepts plain text to convert it to secure format')]
    param(
        [Parameter(Mandatory = $true)][string]$PlainTextPassword
    )
    try {
        $secureString = ConvertTo-SecureString -String $PlainTextPassword -AsPlainText -Force
        return ConvertFrom-SecureString -SecureString $secureString
    }
    catch {
        Write-Log -Level ERROR -Message "Error encrypting credential: $($_.Exception.Message)"
        return ""
    }
}

function ConvertFrom-SecureCredential {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Parameter contains encrypted string, not plain text password')]
    param(
        [Parameter(Mandatory = $true)][string]$EncryptedPassword,
        [Parameter(Mandatory = $true)][string]$Username
    )
    try {
        if ([string]::IsNullOrEmpty($EncryptedPassword) -or [string]::IsNullOrEmpty($Username)) {
            return $null
        }
        $secureString = ConvertTo-SecureString -String $EncryptedPassword
        return New-Object System.Management.Automation.PSCredential($Username, $secureString)
    }
    catch {
        Write-Log -Level ERROR -Message "Error decrypting credential for user '$Username': $($_.Exception.Message)"
        return $null
    }
}

Export-ModuleMember -Function Get-DefaultConfig, Get-Config, Save-Config, Invoke-VersionControl, ConvertTo-SecureCredential, ConvertFrom-SecureCredential

# --- End of module --- v11.2.2 ; Regelwerk: v8.2.0 ---
# SIG # Begin signature block
# MIIb/gYJKoZIhvcNAQcCoIIb7zCCG+sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/xLFHeR4H3KxwTllSZei4vN3
# WO2gghZgMIIDIjCCAgqgAwIBAgIQSrQKC5vlGaZCUpHrJkIsMTANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBQDLwAuZjp5fD+MirUN2gl1ZtpDXjANBgkqhkiG9w0B
# AQEFAASCAQBwpAiX+lVl8+4vAvTRPmB0ZX9BifEHbkSaP923gk2/YbLzdF3Jwxm0
# TUqtGXs7USP5brYh+x3Ds/6KuxT9XVKRN3b1iDSZYpMrRhfrVk/Z6eMvlMPGxEzn
# 0wmEMlv+w1OlB1QqUz9cFXjCv2N5Kttnlo1z485MEA3U2uR1sNqOAUwjIF3BYw+v
# fZaOZkGLObLTH3QW0X1s8v2Qvm/KozFi9hIFXdeSIX4HCwTXIGSKKDRu0D3YekCR
# fNGeOKpbM3yM3dwDNU5qH1h3RhChwm6suDQwT+fdK5fGGaA4nrFWC5VmHYWE50ag
# e6rDFCEOmQQf9VrkkLV2jBSrVLkyM00UoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMw
# ggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0
# MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTI1MDkwMzEwNDYxMVowLwYJKoZIhvcNAQkEMSIEIMZFBnYEjWwIxG0U8PFKGLZh
# uSC3Gpngu3cXmz9QVGgVMA0GCSqGSIb3DQEBAQUABIICAKsZL79o3VGPuEoExgA9
# mjG8VmvUM5Te4fr0Mqd7paYVXPPOJ96/aRJXV7WbsvUpBphsq4kZbxfA4hUJoaSJ
# S4QK2Q1yqTzl7aYR3tJAspKPW+qgkbgnDIDXJgreWHBXxekhrxSCFm9ic5yE9SZh
# /4Xsul7LjTeozM5rrqXVPjxHrx7cR3B3x0S4sRmVsjvtTxonppGzLC/M4xuA/khd
# zgOMNTVyjlfgbBeRmyWaljIUPVPTkBpWsrJ09tfZstDGEXT5/KdizFsVZtZudR83
# zxF3Jw8XF9dQKLZK0PNr0V96SkCBerkcss5stIkUQZK0PR5f3ksynkUBi574hcAt
# uterJFJiNlu0SlyJl2kEHK8oyr/4qHPV3YIiH1trh0sc4DrGkjfr9octURXYBNZa
# lm9HTcWkK0pyNN8m7d3cLiyv4i9kqsUgVD8pxp7iC7C8MfRVbx11vgvEkVqwMbD+
# qMjEPppdGRuOJWONnlYiiC2q4uy2MaHz8YujNXygAc3VpAOaUn7HKI1epPeJWpL8
# 0rnpZer7ytPY3yqdDcDxOHTJMonGHFL0m4knEDBHL4YFU6AclRtGaprYfYlWtNFu
# Ej09m5vY0VojAh8ZU7w1OiHKLCcFbMJCeJBQocyz4moqGvvF2wOXSL/aqJGZ8Vfu
# cCbQRWlfCx3VofNhLlI0yjkh
# SIG # End signature block
