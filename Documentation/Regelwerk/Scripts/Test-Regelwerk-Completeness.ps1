<#
.SYNOPSIS
    Prüft die Vollständigkeit aller Paragraphen im Regelwerk

.DESCRIPTION
    Extrahiert alle Paragraph-Nummern aus dem Regelwerk und prüft, ob alle erwartet
    Paragraphen (§1-§19) vorhanden sind. Meldet fehlende oder zusätzliche Paragraphen.

.PARAMETER RegelwerkPath
    Pfad zum zu prüfenden Regelwerk (z.B. PowerShell-Regelwerk-Universal-v10.0.4.md)

.EXAMPLE
    .\Test-Regelwerk-Completeness.ps1 -RegelwerkPath ".\PowerShell-Regelwerk-Universal-v10.0.4.md"

.NOTES
    Version: 1.0
    Autor: Flecki (Tom) Garnreiter
    Datum: 2025-10-09
#>

param(
    [Parameter(Mandatory)]
    [string]$RegelwerkPath
)

# Validierung
if (-not (Test-Path $RegelwerkPath)) {
    Write-Error "Regelwerk not found: $RegelwerkPath"
    exit 1
}

$content = Get-Content $RegelwerkPath -Raw

# Extrahiere alle Paragraphen
$paragraphs = [regex]::Matches($content, '## §(\d+)[:\s]')
$foundNumbers = $paragraphs | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique

Write-Host "`n=== Regelwerk Completeness Check ===" -ForegroundColor Cyan
Write-Host "File: $RegelwerkPath" -ForegroundColor White
Write-Host "`nFound Paragraphs: $($foundNumbers -join ', ')" -ForegroundColor Yellow

# Prüfe Vollständigkeit
$expectedCount = 19  # Aktuell (kann angepasst werden)
$expected = 1..$expectedCount

$missing = $expected | Where-Object { $_ -notin $foundNumbers }
$extra = $foundNumbers | Where-Object { $_ -notin $expected }

if ($missing.Count -gt 0) {
    Write-Host "`n[ERROR] MISSING Paragraphs: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Expected: 1-$expectedCount" -ForegroundColor Yellow
    exit 1
}

if ($extra.Count -gt 0) {
    Write-Host "`n[WARNING] EXTRA Paragraphs: $($extra -join ', ')" -ForegroundColor Yellow
    Write-Host "This may be intentional (new paragraphs added)" -ForegroundColor White
}

if ($foundNumbers.Count -eq $expectedCount -and $missing.Count -eq 0) {
    Write-Host "`n[OK] All $expectedCount paragraphs present!" -ForegroundColor Green
    Write-Host "Paragraphs: Paragraph 1-Paragraph $expectedCount" -ForegroundColor White
    exit 0
} else {
    Write-Host "`n[ERROR] Completeness check FAILED!" -ForegroundColor Red
    Write-Host "Found: $($foundNumbers.Count)/$expectedCount" -ForegroundColor Yellow
    exit 1
}
