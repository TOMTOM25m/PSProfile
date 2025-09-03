<#
.SYN    Last modified:  2025.09.02
    Version:        v11.2.2
    MUW-Regelwerk:  v8.2.0IS
    [DE] Modul für allgemeine Hilfsfunktionen.
    [EN] Module for general utility functions.
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
# Functions for Utilities

function Get-AllProfilePaths {
    Write-Log -Level DEBUG -Message "Querying all four potential profile paths."
    $profileProperties = 'CurrentUserCurrentHost', 'CurrentUserAllHosts', 'AllUsersCurrentHost', 'AllUsersAllHosts'
    return $profileProperties.ForEach({ try { $PROFILE.$_ } catch {} }) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Select-Object -Unique
}

function Get-SystemwideProfilePath {
    Write-Log -Level DEBUG -Message "Determining system-wide profile path for this PowerShell edition."
    if ($IsCoreCLR) {
        # PowerShell 7+
        return Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\profile.ps1'
    }
    else {
        # Windows PowerShell 5.1
        return Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\profile.ps1'
    }
}

function Set-TemplateVersion {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$FilePath, [string]$NewVersion, [string]$OldVersion)

    if ([string]::IsNullOrEmpty($NewVersion) -or [string]::IsNullOrEmpty($OldVersion)) {
        Write-Log -Level WARNING -Message "Skipping versioning for '$FilePath' due to missing version information."
        return
    }

    if ($PSCmdlet.ShouldProcess($FilePath, "Set Version to $NewVersion")) {
        try {
            $content = Get-Content -Path $FilePath -Raw
            $content = $content -replace "(old Version:\s*v)[\d\.]+", "`$1$OldVersion"
            $content = $content -replace "(Version now:\s*v)[\d\.]+", "`$1$($NewVersion.TrimStart('v'))"
            # This regex is more robust to handle different footer formats
            $content = $content -replace "(old:\s*v)[\d\.]+(\s*;\s*now:\s*v)[\d\.]+", "`$1$OldVersion`$2$($NewVersion.TrimStart('v'))"
            
            $encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'UTF8BOM' } else { 'UTF8' }
            Set-Content -Path $FilePath -Value $content -Encoding $encoding -Force
            Write-Log -Level DEBUG -Message "Version for '$FilePath' was set to '$NewVersion' using encoding '$($encoding)'."
        }
        catch { Write-Log -Level ERROR -Message "Error versioning file '$FilePath': $($_.Exception.Message)" }
    }
}

function Send-MailNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$Body
    )
    $mailSettings = $Global:Config.Mail
    if (-not $mailSettings.Enabled) {
        Write-Log -Level DEBUG -Message "Mail notifications are disabled."
        return
    }
    
    if ([string]::IsNullOrEmpty($mailSettings.SmtpServer)) {
        Write-Log -Level WARNING -Message "SMTP server is not configured. Email could not be sent."
        return
    }

    Write-Log -Level DEBUG -Message "Testing connection to SMTP server $($mailSettings.SmtpServer) on port $($mailSettings.SmtpPort)..."
    # E-Mail-Verbindungstests werden immer ausgeführt, unabhängig vom WhatIf-Modus
    if (-not (Test-NetConnection -ComputerName $mailSettings.SmtpServer -Port $mailSettings.SmtpPort -WarningAction SilentlyContinue)) {
        Write-Log -Level WARNING -Message "SMTP server unreachable. Email could not be sent."
        return
    }
    
    $isDev = $Global:Config.Environment -eq "DEV"
    $recipientString = if ($isDev) { $mailSettings.DevTo } else { $mailSettings.ProdTo }
    $recipients = $recipientString -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) }

    if ([string]::IsNullOrEmpty($mailSettings.Sender) -or $recipients.Count -eq 0) {
        Write-Log -Level WARNING -Message "Sender or recipient(s) are not configured. Email could not be sent."
        return
    }

    $recipientLogString = $recipients -join ', '
    Write-Log -Level INFO -Message "Sending email notification to '$recipientLogString'"
    try {
        # E-Mail-Versand wird immer ausgeführt, unabhängig vom WhatIf-Modus
        $smtpClient = New-Object System.Net.Mail.SmtpClient($mailSettings.SmtpServer, $mailSettings.SmtpPort)
        $smtpClient.EnableSsl = $mailSettings.UseSsl
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = $mailSettings.Sender
        $recipients | ForEach-Object { $mailMessage.To.Add($_) }
        $mailMessage.Subject = $Subject
        $mailMessage.Body = $Body
        
        # E-Mail wird immer gesendet, unabhängig vom WhatIf-Modus
        $smtpClient.Send($mailMessage)
        Write-Log -Level INFO -Message "Email sent successfully."
    }
    catch { Write-Log -Level ERROR -Message "Error sending email: $($_.Exception.Message)" }
    finally {
        if ($smtpClient) { $smtpClient.Dispose() }
        if ($mailMessage) { $mailMessage.Dispose() }
    }
}

function ConvertTo-Base64 {
    param([Parameter(Mandatory=$true)][string]$String)
    return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($String))
}

function ConvertFrom-Base64 {
    param([Parameter(Mandatory=$true)][string]$Base64String)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64String))
}

function Update-NetworkPathsInTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TemplateFilePath,
        [Parameter(Mandatory = $true)][array]$NetworkProfiles
    )
    
    try {
        if (-not (Test-Path $TemplateFilePath)) {
            Write-Log -Level ERROR -Message "Template file not found: $TemplateFilePath"
            return
        }
        
        $content = Get-Content -Path $TemplateFilePath -Raw
        
        # Generate the network paths array as simple strings for the existing logic
        $networkPathsList = @()
        $enabledProfiles = $NetworkProfiles | Where-Object { $_.Enabled -eq $true }
        
        foreach ($netProfile in $enabledProfiles) {
            $networkPathsList += "'$($netProfile.Path)'"
        }
        
        $networkPathsCode = if ($networkPathsList.Count -gt 0) {
            "`$networkPaths = @(`n    $($networkPathsList -join ",`n    ")`n)"
        } else {
            "`$networkPaths = @()"
        }
        
        # Replace the placeholder with the generated code
        $content = $content -replace '\$networkPaths = #NETWORK_PATHS_PLACEHOLDER#', $networkPathsCode
        
        $encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'UTF8BOM' } else { 'UTF8' }
        Set-Content -Path $TemplateFilePath -Value $content -Encoding $encoding -Force
        Write-Log -Level DEBUG -Message "Network paths updated in template: $TemplateFilePath (Total: $($networkPathsList.Count) paths)"
    }
    catch {
        Write-Log -Level ERROR -Message "Error updating network paths in template '$TemplateFilePath': $($_.Exception.Message)"
    }
}

function Test-NetworkConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$UncPath,
        [Parameter(Mandatory = $false)][string]$Username = "",
        [Parameter(Mandatory = $false)][System.Security.SecureString]$SecurePassword = $null
    )
    
    try {
        Write-Log -Level DEBUG -Message "Starting network connection test for path: $UncPath"
        
        # Parse the UNC path to get server name
        if (-not $UncPath.StartsWith("\\")) {
            return @{ Success = $false; Message = "Invalid UNC path format. Path must start with '\\'." }
        }
        
        $pathParts = $UncPath.TrimStart('\').Split('\')
        if ($pathParts.Length -lt 2) {
            return @{ Success = $false; Message = "Invalid UNC path format. Expected format: \\server\share\path" }
        }
        
        $serverName = $pathParts[0]
        $shareName = $pathParts[1]
        $testPath = "\\$serverName\$shareName"
        
        Write-Log -Level DEBUG -Message "Testing connection to server: $serverName, share: $shareName"
        
        # Step 1: Basic network connectivity test (ping)
        Write-Log -Level DEBUG -Message "Step 1: Testing basic connectivity to server '$serverName'"
        if (-not (Test-NetConnection -ComputerName $serverName -Port 445 -InformationLevel Quiet -WarningAction SilentlyContinue)) {
            return @{ Success = $false; Message = "Server '$serverName' is not reachable on SMB port 445. Check network connectivity." }
        }
        
        # Step 2: Credential preparation
        $credential = $null
        if (-not [string]::IsNullOrEmpty($Username) -and $SecurePassword -ne $null) {
            try {
                $credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
                Write-Log -Level DEBUG -Message "Using provided credentials for user: $Username"
            } catch {
                return @{ Success = $false; Message = "Invalid credentials provided: $($_.Exception.Message)" }
            }
        } else {
            Write-Log -Level DEBUG -Message "No credentials provided, using current user context"
        }
        
        # Step 3: Test SMB connection with authentication
        Write-Log -Level DEBUG -Message "Step 2: Testing SMB share access to '$testPath'"
        
        # Remove any existing connections to avoid conflicts
        try {
            $existingConnections = Get-SmbConnection -ServerName $serverName -ErrorAction SilentlyContinue
            if ($existingConnections) {
                Write-Log -Level DEBUG -Message "Found existing SMB connections to '$serverName', removing them for clean test"
                $existingConnections | Remove-SmbConnection -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignore errors when cleaning up existing connections
        }
        
        # Test actual SMB connection
        try {
            if ($null -ne $credential) {
                # Test with specific credentials
                Write-Log -Level DEBUG -Message "Testing SMB connection with provided credentials"
                
                # Simple approach: try to access the share with Get-ChildItem using RunAs
                $testScriptBlock = {
                    param($TestPath)
                    try {
                        Get-ChildItem -Path $TestPath -ErrorAction Stop | Select-Object -First 1 | Out-Null
                        return $true
                    } catch {
                        throw $_.Exception.Message
                    }
                }
                
                $job = Start-Job -ScriptBlock $testScriptBlock -ArgumentList $testPath -Credential $credential
                $jobResult = Wait-Job -Job $job -Timeout 30
                
                if ($jobResult.State -eq "Completed") {
                    try {
                        Receive-Job -Job $job -ErrorAction Stop | Out-Null
                        Remove-Job -Job $job -Force
                        Write-Log -Level DEBUG -Message "SMB connection verified successfully with credentials"
                    } catch {
                        Remove-Job -Job $job -Force
                        return @{ Success = $false; Message = "Credential authentication failed: $($_.Exception.Message)" }
                    }
                } elseif ($jobResult.State -eq "Failed") {
                    $jobError = Receive-Job -Job $job -ErrorAction SilentlyContinue
                    Remove-Job -Job $job -Force
                    return @{ Success = $false; Message = "Connection test with credentials failed: $jobError" }
                } else {
                    Remove-Job -Job $job -Force
                    return @{ Success = $false; Message = "Connection test with credentials timed out after 30 seconds" }
                }
            } else {
                # Test with current user context
                Write-Log -Level DEBUG -Message "Testing SMB connection with current user context"
                if (-not (Test-Path -Path $testPath -PathType Container -ErrorAction SilentlyContinue)) {
                    return @{ Success = $false; Message = "Share '$testPath' is not accessible with current user context." }
                }
            }
            
            # Step 4: Test file system access
            Write-Log -Level DEBUG -Message "Step 3: Testing file system access to '$UncPath'"
            $fullPathAccessible = $false
            
            if ($null -ne $credential) {
                # For credential-based access, use a job to test the full path
                try {
                    $fullPathTestScript = {
                        param($FullPath)
                        try {
                            return Test-Path -Path $FullPath -ErrorAction Stop
                        } catch {
                            return $false
                        }
                    }
                    
                    $pathJob = Start-Job -ScriptBlock $fullPathTestScript -ArgumentList $UncPath -Credential $credential
                    $pathJobResult = Wait-Job -Job $pathJob -Timeout 15
                    
                    if ($pathJobResult.State -eq "Completed") {
                        $fullPathAccessible = Receive-Job -Job $pathJob
                        Remove-Job -Job $pathJob -Force
                    } else {
                        Remove-Job -Job $pathJob -Force
                        Write-Log -Level DEBUG -Message "Full path test with credentials timed out"
                        $fullPathAccessible = $true  # Assume accessible if test times out
                    }
                } catch {
                    Write-Log -Level DEBUG -Message "Full path test with credentials failed: $($_.Exception.Message)"
                    $fullPathAccessible = $true  # Assume accessible if we can't test properly
                }
            } else {
                # Test direct access without credentials
                $fullPathAccessible = Test-Path -Path $UncPath -ErrorAction SilentlyContinue
            }
            
            if (-not $fullPathAccessible) {
                return @{ Success = $false; Message = "Share '$testPath' is accessible, but the full path '$UncPath' is not accessible. Check path and permissions." }
            }
            
            $successMessage = "Connection successful! Server '$serverName' is reachable, share '$shareName' is accessible"
            if ($null -ne $credential) {
                $successMessage += " with provided credentials"
            } else {
                $successMessage += " with current user context"
            }
            $successMessage += ", and the full path '$UncPath' is accessible."
            
            Write-Log -Level INFO -Message "Network connection test completed successfully: $UncPath"
            return @{ Success = $true; Message = $successMessage }
            
        } catch {
            $errorMessage = "SMB connection failed: $($_.Exception.Message)"
            Write-Log -Level WARNING -Message $errorMessage
            return @{ Success = $false; Message = $errorMessage }
        }
        
    } catch {
        $errorMessage = "Network connection test failed: $($_.Exception.Message)"
        Write-Log -Level ERROR -Message $errorMessage
        return @{ Success = $false; Message = $errorMessage }
    }
}

Export-ModuleMember -Function Get-AllProfilePaths, Get-SystemwideProfilePath, Set-TemplateVersion, Send-MailNotification, ConvertTo-Base64, ConvertFrom-Base64, Update-NetworkPathsInTemplate, Test-NetworkConnection

# --- End of module --- v11.2.2 ; Regelwerk: v8.2.0 ---
# SIG # Begin signature block
# MIIb/gYJKoZIhvcNAQcCoIIb7zCCG+sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUHyI23ljik2M8BlnH/S9ZpRdD
# VPigghZgMIIDIjCCAgqgAwIBAgIQSrQKC5vlGaZCUpHrJkIsMTANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBQAWxtmvTGiMyMvd5DKd/ooQT5/4TANBgkqhkiG9w0B
# AQEFAASCAQBLIN2qOOD50kWiMDKi3+B+f3uUCesoW22nytwznPYqHtBT2wyPmxjT
# JALmIHii02BktN3P34PHkU8J74vMepWPMZ6fWDKsZBgNaY6d9KLbo6zSCmAnF26j
# 5ysiFgD9UvRgW/pPOBu2DgNc+akUw6TkoP0fuiCCdvySCQVEnKuspsd4abkl3HzC
# 9jtjzu2SgOEZLDbrs8XZN61MF4PLFloH5mPtmyAzK3IjjarydauP2uPj0aNVJvsQ
# DXX9ZIyuhYtYcizPZmT4K4oUaO1adRgKoxXr+OOAM3r7mXjv2i3mFRxb3C0nbVKv
# /VlUW7tLRGWqEyHEEpUurA9xUsyYypCSoYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMw
# ggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0
# MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTI1MDkwMzEwNDExN1owLwYJKoZIhvcNAQkEMSIEIDf1A3wA8f7Sr/YnlWq23yQw
# X9pRuYJcnYkV1/qfTLkMMA0GCSqGSIb3DQEBAQUABIICAEQ+2AET5EEdlsFrtI9+
# 0RRYGyxgzjURhmaPUupkE+ghisP7mx/YUh7WX0ha0jPyAAM9RfEVyK3j4xjRhvCW
# xSc+4ct7VO/A8Y+W4MW1HyfWOY2IYq0YAl/NIGuVtYsx9MpbSKdDR0ht396vwTGK
# 81o/pKlw2NyJkxQX67bdXyG3Jk+9rLTsqF4qiW460kZBusvV2ysHa/Dcgclpckme
# ycruFC5loq6nxGKDFHhEYnTCzwbNnhOg7ZWR19fcmZTPfNm3I3i2BNyE+i8KoWkU
# n8dk+Nqah95+pStVVlnByZ70fUKRbfcBgydXHzAIk6zMm4FjsA2IB+Bdh4qbXD76
# JduRRnskyFmKLo2HgdPqCK+N6cKsVqqoh88ey/hQx5HGnkPVb0BLHor+im9nJbyk
# uO9QhDo7XgP85Ffkwu9+5+HLm9T1mvq+c7CuFmeUcs1/r98LFmMHVWvMHsGM0rAg
# 7t0MoGR5dwDdrv0n3cBUEG4J88ADUZ43nQGACxhKIW6GLwKjUWjrs6NYsM3sMYPF
# RakbOn1VSPijRj8aY2rIhVUFqcvB4h1jbhM+SwLQNCEw/T2ZJdyqy/SPM4e7oVyy
# 7boUU8PjHEiNTxgW33V73mmYHQxoKY1I7mCheQa6+gJdFoCXldZxMIclQvbHVVRP
# sw8W8Qjs0GcxdfELBJeGryIG
# SIG # End signature block
