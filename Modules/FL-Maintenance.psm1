<#
.SYNOPSIS
    [DE] Modul für Wartungsaufgaben wie Archivierung.
    [EN] Module for maintenance tasks like archiving.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.09.02
    Version:        v11.2.1
    MUW-Regelwerk:  v8.2.0
    Notes:          [DE] Versionsnummer für Release-Konsistenz aktualisiert.
                    [EN] Updated version number for release consistency.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Invoke-ArchiveMaintenance {
    [CmdletBinding()]
    param()
    if (-not $Global:Config.Logging.ArchiveLogs) {
        Write-Log -Level INFO -Message "Log archiving is disabled."
        return
    }
    Write-Log -Level INFO -Message "Starting archive maintenance..."
    $logConf = $Global:Config.Logging
    $use7Zip = (Test-Path $logConf.SevenZipPath) -and ($logConf.SevenZipPath.EndsWith("7z.exe"))

    $cutoffDate = (Get-Date).AddDays(-$logConf.LogRetentionDays)
    $logsToArchive = Get-ChildItem -Path $logConf.LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    if ($logsToArchive) {
        $archiveName = "$($Global:ScriptName -replace '\.ps1', '')_$((Get-Date).AddMonths(-1).ToString('yyyy_MM')).zip"
        $archivePath = Join-Path $logConf.LogPath $archiveName
        Write-Log -Level INFO -Message "Archiving $($logsToArchive.Count) log files to '$archivePath'..."
        try {
            # Log-Archivierung wird immer ausgeführt, unabhängig vom WhatIf-Modus
            if ($use7Zip) {
                $filesString = $logsToArchive.FullName -join '" "'
                Start-Process -FilePath $logConf.SevenZipPath -ArgumentList "a -tzip `"$archivePath`" `"$filesString`"" -Wait -NoNewWindow
            }
            else {
                Compress-Archive -Path $logsToArchive.FullName -DestinationPath $archivePath -Update
            }
            $logsToArchive | Remove-Item -Force
        }
        catch { Write-Log -Level ERROR -Message "Archiving failed: $($_.Exception.Message)" }
    }
    $archiveCutoffDate = (Get-Date).AddDays(-$logConf.ArchiveRetentionDays)
    Get-ChildItem -Path $logConf.LogPath -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $archiveCutoffDate } | ForEach-Object {
        Write-Log -Level INFO -Message "Deleting old archive: $($_.FullName)"
        # Alte Archive werden immer gelöscht, unabhängig vom WhatIf-Modus
        $_ | Remove-Item -Force
    }
}

function Initialize-LocalAssets {
    [CmdletBinding()]
    param()
    Write-Log -Level DEBUG -Message "Initializing local assets..."

    if (-not ($Global:Config.GuiAssets -and $Global:Config.UNCPaths)) {
        Write-Log -Level DEBUG -Message "GuiAssets or UNCPaths not defined in config. Skipping asset initialization."
        return
    }

    # Define assets to check and copy
    $assets = @{
        Logo = @{
            Dest = $Global:Config.GuiAssets.LogoPath
            File = "MedUniWien_logo.png"
        }
        Icon = @{
            Dest = $Global:Config.GuiAssets.IconPath
            File = "MedUniWien_logo.ico"
        }
    }

    foreach ($assetName in $assets.Keys) {
        $asset = $assets[$assetName]
        $destPath = $asset.Dest
        
        if ($null -eq $destPath) {
            Write-Log -Level DEBUG -Message "Destination path for asset '$assetName' is null. Skipping."
            continue
        }

        if (-not (Test-Path $destPath)) {
            $uncDir = $Global:Config.UNCPaths.AssetDirectory
            if ($null -eq $uncDir) {
                Write-Log -Level DEBUG -Message "UNC asset directory not configured. Cannot copy '$assetName'."
                continue
            }

            $sourcePath = Join-Path $uncDir $asset.File
            if (Test-Path $sourcePath) {
                Write-Log -Level INFO -Message "Local $assetName not found. Attempting to copy from UNC path: $sourcePath"
                $localDir = Split-Path $destPath -Parent
                if (-not (Test-Path $localDir)) {
                    New-Item -Path $localDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
                try {
                    # Regelwerk v9.5.0 Compliance: Use robocopy for UNC path operations
                    $robocopyArgs = @('/E', '/R:3', '/W:5')
                    $assetFileName = Split-Path $sourcePath -Leaf
                    $assetSourceDir = Split-Path $sourcePath -Parent
                    $assetDestDir = Split-Path $destPath -Parent
                    
                    Write-Log -Level INFO -Message "Using robocopy for UNC path operation (Regelwerk v9.5.0): robocopy `"$assetSourceDir`" `"$assetDestDir`" `"$assetFileName`" /E /R:3 /W:5"
                    & robocopy $assetSourceDir $assetDestDir $assetFileName @robocopyArgs | Out-Null
                    
                    if ($LASTEXITCODE -le 3) {
                        Write-Log -Level INFO -Message "$assetName successfully copied to $destPath via robocopy (exit code: $LASTEXITCODE)"
                    } else {
                        throw "Robocopy failed with exit code: $LASTEXITCODE"
                    }
                }
                catch {
                    Write-Log -Level WARNING -Message "Could not copy $assetName from UNC path: $($_.Exception.Message)"
                }
            } else {
                Write-Log -Level WARNING -Message "Source asset '$sourcePath' not found on UNC path. Cannot copy."
            }
        }
    }
}

function Invoke-GitUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $gitConfig = $Global:Config.GitUpdate
    if (-not $gitConfig.Enabled) {
        Write-Log -Level INFO -Message "Git update feature is disabled."
        return $null
    }

    Write-Log -Level INFO -Message "Starting Git update for profile templates..."

    $gitPath = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $gitPath) {
        throw "Git is not installed or not in the system's PATH. Cannot perform Git update."
    }
    Write-Log -Level DEBUG -Message "Found git.exe at: $($gitPath.Source)"

    $cachePath = $gitConfig.CachePath
    if (-not (Test-Path $cachePath)) {
        if ($PSCmdlet.ShouldProcess($cachePath, "Create Git cache directory")) {
            New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
        }
    }

    $repoDir = Join-Path $cachePath "repository"

    if (-not (Test-Path (Join-Path $repoDir ".git"))) {
        Write-Log -Level INFO -Message "Local repository not found. Cloning from $($gitConfig.RepoUrl)..."
        $cloneArgs = "clone --branch $($gitConfig.Branch) --single-branch `"$($gitConfig.RepoUrl)`" `"$repoDir`""
        if ($PSCmdlet.ShouldProcess($gitConfig.RepoUrl, "Clone Repository")) {
            $process = Start-Process -FilePath $gitPath.Source -ArgumentList $cloneArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($process.ExitCode -ne 0) { throw "Git clone failed with exit code $($process.ExitCode)." }
            Write-Log -Level INFO -Message "Repository cloned successfully."
        }
    }
    else {
        Write-Log -Level INFO -Message "Local repository found. Fetching updates..."
        if ($PSCmdlet.ShouldProcess($repoDir, "Update Repository (git fetch & reset)")) {
            $fetchArgs = "-C `"$repoDir`" fetch origin"
            $resetArgs = "-C `"$repoDir`" reset --hard origin/$($gitConfig.Branch)"
            & $gitPath.Source $fetchArgs.Split(' ') | Out-Null
            & $gitPath.Source $resetArgs.Split(' ') | Out-Null
            Write-Log -Level INFO -Message "Repository updated successfully to latest version from branch '$($gitConfig.Branch)'."
        }
    }
    return $repoDir
}

Export-ModuleMember -Function Invoke-ArchiveMaintenance, Initialize-LocalAssets, Invoke-GitUpdate

# --- End of module --- v11.2.1 ; Regelwerk: v8.2.0 ---
# SIG # Begin signature block
# MIIb/gYJKoZIhvcNAQcCoIIb7zCCG+sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEEJ0vaMRUart86lB3n0JjH7W
# +sigghZgMIIDIjCCAgqgAwIBAgIQSrQKC5vlGaZCUpHrJkIsMTANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBS+6deH4qRXBj9NgBnAfOc5+lO7MTANBgkqhkiG9w0B
# AQEFAASCAQBInmiTPGoqMzD2NoHRz1kcFZtHRDE8WnO63IEwwUdtQA8F3aBjpJGY
# Xs4H0hK2/BUGONtlq0qD5L52zx30U1sSmT3DdB2YZ3QymoXSQHRp0NVw4xjYoMPt
# mGqzO/I3fhPmAbgcIw4PKI6NYjrViZLQkNoP1X0iIaeQsB08mFJiCGokpbYZ3MT8
# O3HRGTAOIHEqoMiePM0BLd9m5UhLnZcSfzSy/uDaCrvuJ+EtywardsU6CboRDPtw
# dBn6qCwjUVSF6vkoqcwE/uh8TkpatQBEVCkb2r5sH1l1nU4XCLpMeCExEFOK6Gfk
# NMyEJK0MkOjf40S/4I9jb5hByU7slOJ+oYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMw
# ggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0
# MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTI1MDkwMzEwNDYxMlowLwYJKoZIhvcNAQkEMSIEIFdACna8nnuw2Jlk+smlgwuk
# Azlq3A2Y36A44H5WJis0MA0GCSqGSIb3DQEBAQUABIICABgy8NE8/GSepIE4dzFX
# QWvqGKJVTIWdS45BfsLc7MRYvV6nZ5X+X/YkEauGKDLKoX8KfvypPzIDvabNxFpF
# +8S+eBmuQFLGAK/ZY8bxMyFwtzUAhs9hmjSci7toA8fR83z47CIcxYcMfemsrcFi
# dNoicKKm07DuxF03GSipfPLvkQI+46yikkqVg/ZB3CX9plcmh4E+nrZGciRacPab
# JAJOkxtTREmryhJFyEwuggd8X0Lj82g02ruj+osfElksVD54jQ+VjDosT7mVXTbe
# mIleLn3JDeifX4WXAQ+Qpn7nv19OMP/4PE9/H9Y47hY49gWYe99vjUbtq64hKjBs
# 2w6fB0VLjcSq5wAHNTX5NhNNFnpKfhOIuUYG28OjyWqMcCKgffeoxTxo17S0Mm24
# 32Vp828xKdWbV2E2KTPfVoXlLC0s4/PnpDKP8NnNputgLFHPBUB41HtvW+7Ul5ik
# DqJ5rRle0eG6B8OiKgBCwB6rCe0llnSGWrUJfO2wXGzr3iT2KD1NL4meXlnNDfAl
# aCwxbH+snzjdYKYK9RnuJhl15W9dS5DN6eTpjn6WAwtyGR4Ax284lMr0zZZQSPEy
# a8WcRPe7IxfswnJ76uHDLFSo8c9ruMdquYcZ82V7q7uQ3mUOtsCTy+9uRWJbShcD
# w5+4uY/n5Euzb7aKJNunURNp
# SIG # End signature block
