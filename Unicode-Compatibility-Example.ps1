#requires -Version 5.1
<#
.SYNOPSIS
    Beispiel für Unicode-Emoji Kompatibilität nach Regelwerk v9.6.0 §7

.DESCRIPTION
    Demonstriert die korrekte Implementierung von Unicode-Emoji Kompatibilität
    zwischen PowerShell 5.1 und PowerShell 7.x gemäß Regelwerk v9.6.0 §7.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        1.0.0
    Regelwerk:      v9.6.0 §7
    Created:        2025-09-27
#>

#region Unicode-Emoji Kompatibilität (Regelwerk v9.6.0 §7)

# ✅ KORREKTE Implementierung mit automatischer Versionserkennung
function Show-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    # ASCII-Version für PowerShell 5.1 Kompatibilität
    switch ($Type) {
        "Info"    { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
        "Success" { Write-Host "[OK] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
    }
}

# ✅ OPTIMALE Implementierung mit separaten Funktionen
function Show-ProcessStartPS7 {
    param([string]$ProcessName)
    Write-Host "[START] Starting $ProcessName..." -ForegroundColor Green
    Write-Host "[CFG] Loading configuration..." -ForegroundColor Yellow
    Write-Host "[DIR] Creating directories..." -ForegroundColor Cyan
}

function Show-ProcessStartPS5 {
    param([string]$ProcessName)
    Write-Host ">> Starting $ProcessName..." -ForegroundColor Green
    Write-Host "[CFG] Loading configuration..." -ForegroundColor Yellow
    Write-Host "[DIR] Creating directories..." -ForegroundColor Cyan
}

# Automatische Funktionsauswahl basierend auf PowerShell-Version
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Set-Alias Show-ProcessStart Show-ProcessStartPS7
    Write-Host "[PS7.x] PowerShell 7.x detected - Unicode emojis would be available" -ForegroundColor Green
} else {
    Set-Alias Show-ProcessStart Show-ProcessStartPS5
    Write-Host "[PS5.1] PowerShell 5.1 detected - ASCII alternatives enabled" -ForegroundColor Green
}

#endregion

#region Demonstration

Write-Host "`n=== Unicode-Emoji Kompatibilitaets-Demo (Regelwerk v9.6.0 Paragraph 7) ===" -ForegroundColor Magenta
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White

# Test verschiedener Nachrichtentypen
Show-StatusMessage -Message "System wird initialisiert" -Type "Info"
Show-StatusMessage -Message "Konfiguration erfolgreich geladen" -Type "Success"  
Show-StatusMessage -Message "Warnung: Temporäre Dateien gefunden" -Type "Warning"
Show-StatusMessage -Message "Fehler: Datei nicht gefunden" -Type "Error"

Write-Host "`n--- Prozess-Start Demo ---" -ForegroundColor Yellow
Show-ProcessStart -ProcessName "Test-Prozess"

Write-Host "`n--- ASCII-Alternativen Referenz ---" -ForegroundColor Yellow
Write-Host "Rocket Emoji → >> oder [START]" -ForegroundColor Gray
Write-Host "Clipboard Emoji → [INFO] oder Status:" -ForegroundColor Gray  
Write-Host "Gear Emoji → [CFG] oder Config:" -ForegroundColor Gray
Write-Host "Checkmark Emoji → [OK] oder SUCCESS:" -ForegroundColor Gray
Write-Host "X Mark Emoji → [ERROR] oder FAILED:" -ForegroundColor Gray
Write-Host "Warning Emoji → [WARN] oder WARNING:" -ForegroundColor Gray

Write-Host "`n=== Demo beendet ===" -ForegroundColor Magenta

#endregion