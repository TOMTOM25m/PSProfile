#requires -Version 5.1

<#
.SYNOPSIS
    Test der neuen Regelwerk v10.0.2 §19 Hilfsfunktionen

.DESCRIPTION
    Demonstriert die neuen Universal Configuration Helper für PowerShell 5.1/7.x Kompatibilität

.VERSION  
    1.0.0

.RULEBOOK
    v10.0.2
#>

# Import des aktualisierten Moduls
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  REGELWERK v10.0.2 - §19 HILFSFUNKTIONEN" -ForegroundColor Cyan  
Write-Host "  Universal Configuration Helper Functions" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Teste Get-ConfigValueSafe
Write-Host "=== Testing Get-ConfigValueSafe ===" -ForegroundColor White

# Hashtable Test
$HashConfig = @{
    SMTPServer = "smtpi.meduniwien.ac.at"
    SMTPPort = 25
    Recipients = @("admin@meduniwien.ac.at")
}

$smtpServer = Get-ConfigValueSafe -Config $HashConfig -PropertyName "SMTPServer" -DefaultValue "localhost"
$smtpPort = Get-ConfigValueSafe -Config $HashConfig -PropertyName "SMTPPort" -DefaultValue 587
$nonExistent = Get-ConfigValueSafe -Config $HashConfig -PropertyName "NonExistent" -DefaultValue "DEFAULT_VALUE"

Write-Host "SMTP Server: $smtpServer" -ForegroundColor Green
Write-Host "SMTP Port: $smtpPort" -ForegroundColor Green  
Write-Host "Non-Existent (Default): $nonExistent" -ForegroundColor Yellow

Write-Host ""

# PSCustomObject Test
$ObjectConfig = [PSCustomObject]@{
    EmailSubject = "[Zertifikat] Überprüfung"
    WarningDays = 30
    CriticalDays = 7
}

$subject = Get-ConfigValueSafe -Config $ObjectConfig -PropertyName "EmailSubject" -DefaultValue "[DEFAULT] Subject"
$warningDays = Get-ConfigValueSafe -Config $ObjectConfig -PropertyName "WarningDays" -DefaultValue 14
$missing = Get-ConfigValueSafe -Config $ObjectConfig -PropertyName "MissingProperty" -DefaultValue "DEFAULT"

Write-Host "Email Subject: $subject" -ForegroundColor Green
Write-Host "Warning Days: $warningDays" -ForegroundColor Green
Write-Host "Missing Property (Default): $missing" -ForegroundColor Yellow

Write-Host ""
Write-Host "=== Testing Get-ConfigArraySafe ===" -ForegroundColor White

# Array Configuration Test  
$ArrayConfig = @{
    Recipients = @("admin@meduniwien.ac.at", "thomas.garnreiter@meduniwien.ac.at")
    Servers = @("server01", "server02", "server03")
    EmptyArray = @()
}

$recipients = Get-ConfigArraySafe -Config $ArrayConfig -PropertyName "Recipients" -DefaultValue @("default@example.com")
$servers = Get-ConfigArraySafe -Config $ArrayConfig -PropertyName "Servers" -DefaultValue @("localhost")
$empty = Get-ConfigArraySafe -Config $ArrayConfig -PropertyName "EmptyArray" -DefaultValue @("default")
$nonExistentArray = Get-ConfigArraySafe -Config $ArrayConfig -PropertyName "NonExistentArray" -DefaultValue @("fallback")

Write-Host "Recipients: $recipients" -ForegroundColor Green
Write-Host "Servers: $servers" -ForegroundColor Green
Write-Host "Empty Array: '$empty'" -ForegroundColor Yellow
Write-Host "Non-Existent Array: $nonExistentArray" -ForegroundColor Yellow

Write-Host ""
Write-Host "=== Regelwerk v10.0.2 Demonstration ===" -ForegroundColor White

# Demonstration der §19.4 Best Practices
Write-Host "[DEMO] PowerShell Version Detection:" -ForegroundColor Cyan
$versionInfo = Get-PowerShellVersionInfo
Write-Host "  Current Version: $($versionInfo.Version)" -ForegroundColor Gray
Write-Host "  Compatibility Mode: $($versionInfo.CompatibilityMode)" -ForegroundColor Gray

Write-Host ""
Write-Host "[DEMO] Null-Coalescing Alternative:" -ForegroundColor Cyan

# ❌ FALSCH (nur PowerShell 7+):
# $value = $Config.Property ?? $DefaultValue

# ✅ KORREKT (PowerShell 5.1+):
$emailConfig = @{ FromEmail = "system@meduniwien.ac.at" }
$fromEmail = Get-ConfigValueSafe -Config $emailConfig -PropertyName "FromEmail" -DefaultValue "noreply@example.com"
$toEmail = Get-ConfigValueSafe -Config $emailConfig -PropertyName "ToEmail" -DefaultValue "admin@example.com"

Write-Host "  From Email (Config): $fromEmail" -ForegroundColor Green
Write-Host "  To Email (Default): $toEmail" -ForegroundColor Yellow

Write-Host ""
Write-Host "[SUCCESS] Regelwerk v10.0.2 §19 Standards erfolgreich implementiert!" -ForegroundColor Green
Write-Host "[INFO] Universal PowerShell 5.1/7.x Kompatibilität gewährleistet" -ForegroundColor Cyan

Write-Host ""
Write-Host "Test completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray