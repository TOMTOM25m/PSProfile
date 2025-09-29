# requires -Version 5.1

<#
.SYNOPSIS
    Beispiel für E-Mail-Integration nach Regelwerk v9.6.0

.DESCRIPTION
    Demonstriert die Standard E-Mail-Integration mit MedUni Wien SMTP-Server
    Zeigt Verwendung für DEV und PROD Umgebungen

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        1.0.1
    Regelwerk:      v9.6.2

.EXAMPLE
    .\Email-Integration-Example.ps1 -Environment DEV -TestMessage "Script Test erfolgreich"
    
.EXAMPLE
    .\Email-Integration-Example.ps1 -Environment PROD -TestMessage "Deployment abgeschlossen"
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("DEV", "PROD")]
    [string]$Environment,
    
    [string]$TestMessage = "PowerShell E-Mail Integration Test",
    [switch]$WhatIf
)

#region Initialization
. (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path) "VERSION.ps1")
Show-ScriptInfo
#endregion

#region Logging Function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogEntry -ForegroundColor $(
        switch ($Level) {
            "INFO" { "White" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            default { "Gray" }
        }
    )
}
#endregion

#region E-Mail Configuration - Regelwerk §8
# E-Mail Standard-Konfiguration
$EmailConfig = @{
    SMTPServer = "smtp.meduniwien.ac.at"
    From = "$env:COMPUTERNAME@meduniwien.ac.at"
    Port = 25
    UseSSL = $false
}

# Umgebungsspezifische Empfänger
$Recipients = @{
    DEV = @{
        Primary = "thomas.garnreiter@meduniwien.ac.at"
        Subject = "[DEV] PowerShell Script Notification"
    }
    PROD = @{
        Primary = "win-admin@meduniwien.ac.at"
        Subject = "[PROD] PowerShell Script Notification"
    }
}

function Send-StandardMail {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [ValidateSet("DEV", "PROD")]
        [string]$Environment,
        
        [string]$Subject = $null,
        [string]$Priority = "Normal"
    )
    
    try {
        # Umgebungsspezifische Konfiguration
        $Recipient = $Recipients[$Environment]
        $MailSubject = if ($Subject) { $Subject } else { $Recipient.Subject }
        
        # Mail-Parameter
        $MailParams = @{
            SmtpServer = $EmailConfig.SMTPServer
            From = $EmailConfig.From
            To = $Recipient.Primary
            Subject = $MailSubject
            Body = $Message
            Port = $EmailConfig.Port
        }
        
        if ($WhatIf) {
            Write-Log "WHATIF: Würde Mail senden an: $($Recipient.Primary)" -Level "INFO"
            Write-Log "WHATIF: Subject: $MailSubject" -Level "INFO"
            Write-Log "WHATIF: Message: $Message" -Level "INFO"
            return
        }
        
        # Mail versenden
        Send-MailMessage @MailParams
        Write-Log "Mail erfolgreich gesendet an: $($Recipient.Primary)" -Level "INFO"
        
    } catch {
        Write-Log "Fehler beim Mail-Versand: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}
#endregion

#region Main Logic
Write-Log "Starte E-Mail Integration Test für Umgebung: $Environment" -Level "INFO"

# Status-Message erstellen
$StatusMessage = @"
PowerShell E-Mail Integration Test - Status Report

Script: Email-Integration-Example.ps1
Version: $ScriptVersion
Regelwerk: $RegelwerkVersion
Zeitpunkt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Test-Message: $TestMessage
Umgebung: $Environment
Status: Test erfolgreich durchgeführt

System-Information:
- Computer: $env:COMPUTERNAME
- Benutzer: $env:USERNAME
- PowerShell Version: $($PSVersionTable.PSVersion)

E-Mail Konfiguration:
- SMTP Server: $($EmailConfig.SMTPServer)
- From: $($EmailConfig.From)
- To: $($Recipients[$Environment].Primary)

Dieses E-Mail wurde automatisch von einem PowerShell Script generiert.
Regelwerk Version: v9.6.0 - §8 E-Mail-Integration
"@

# E-Mail senden
try {
    Send-StandardMail -Message $StatusMessage -Environment $Environment -Subject "[$Environment] E-Mail Integration Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "E-Mail Integration Test erfolgreich abgeschlossen" -Level "INFO"
} catch {
    Write-Log "E-Mail Integration Test fehlgeschlagen: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
#endregion

Write-Log "Script beendet" -Level "INFO"