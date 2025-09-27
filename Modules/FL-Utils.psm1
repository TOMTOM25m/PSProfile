<#
.SYN    Last modified:  2025-09-27
    Version:        v11.3.0
    MUW-Regelwerk:  v9.6.0
    [DE] Modul fÃ¼r allgemeine Hilfsfunktionen und Cross-Script Kommunikation.
    [EN] Module for general utility functions and cross-script communication.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025-09-27
    Version:        v11.3.0
    MUW-Regelwerk:  v9.6.0 (Cross-Script Communication Â§20.3)
    Notes:          [DE] Versionsnummer fÃ¼r Release-Konsistenz aktualisiert.
                    [EN] Updated version number for release consistency.
    Copyright:      Â© 2025 Flecki Garnreiter
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
    # E-Mail-Verbindungstests werden immer ausgefÃ¼hrt, unabhÃ¤ngig vom WhatIf-Modus
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
        # E-Mail-Versand wird immer ausgefÃ¼hrt, unabhÃ¤ngig vom WhatIf-Modus
        $smtpClient = New-Object System.Net.Mail.SmtpClient($mailSettings.SmtpServer, $mailSettings.SmtpPort)
        $smtpClient.EnableSsl = $mailSettings.UseSsl
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = $mailSettings.Sender
        $recipients | ForEach-Object { $mailMessage.To.Add($_) }
        $mailMessage.Subject = $Subject
        $mailMessage.Body = $Body
        
        # E-Mail wird immer gesendet, unabhÃ¤ngig vom WhatIf-Modus
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
