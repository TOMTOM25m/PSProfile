<#
.SYNOPSIS
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

Export-ModuleMember -Function Get-AllProfilePaths, Get-SystemwideProfilePath, Set-TemplateVersion, Send-MailNotification, ConvertTo-Base64, ConvertFrom-Base64

# --- End of module --- v11.2.1 ; Regelwerk: v8.2.0 ---