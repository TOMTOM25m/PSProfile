<#
.SYNOPSIS
    Prüft die Integrität aller TOC-Links im Regelwerk

.DESCRIPTION
    Extrahiert alle TOC-Links aus dem Inhaltsverzeichnis und validiert, ob die
    entsprechenden Paragraph-Überschriften im Dokument existieren.
    Meldet broken links.

.PARAMETER RegelwerkPath
    Pfad zum zu prüfenden Regelwerk (z.B. PowerShell-Regelwerk-Universal-v10.0.4.md)

.EXAMPLE
    .\Test-Regelwerk-TOC-Links.ps1 -RegelwerkPath ".\PowerShell-Regelwerk-Universal-v10.0.4.md"

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

Write-Host "`n=== TOC Link Integrity Check ===" -ForegroundColor Cyan
Write-Host "File: $RegelwerkPath" -ForegroundColor White
Write-Host ""

# Extrahiere alle tatsächlich vorhandenen Paragraph-Überschriften
# Format: "## §1: Title" (nutze Completeness-Check Regex für Konsistenz)
$existingHeaders = [regex]::Matches($content, '## §(\d+)[:\s]')
$existingParagraphNumbers = $existingHeaders | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique

# Extrahiere TOC-Links (Format: [§1: Title](#anchor))
$tocLinks = [regex]::Matches($content, '\[§(\d+):.*?\]\(#([^)]+)\)')

$brokenLinks = 0
$testedLinks = 0

foreach ($link in $tocLinks) {
    $paragraphNumber = [int]$link.Groups[1].Value
    $anchorText = $link.Groups[2].Value
    $testedLinks++
    
    # Prüfe ob Paragraph in Liste der existierenden Headers
    $anchorExists = $paragraphNumber -in $existingParagraphNumbers
    
    if (-not $anchorExists) {
        Write-Host "  [X] Paragraph $paragraphNumber -> #$anchorText (BROKEN)" -ForegroundColor Red
        $brokenLinks++
    } else {
        Write-Host "  [OK] Paragraph $paragraphNumber" -ForegroundColor Green
    }
}

Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Tested Links: $testedLinks" -ForegroundColor White
Write-Host "  Valid Links:  $($testedLinks - $brokenLinks)" -ForegroundColor Green
Write-Host "  Broken Links: $brokenLinks" -ForegroundColor $(if ($brokenLinks -eq 0) { 'Green' } else { 'Red' })

if ($brokenLinks -eq 0) {
    Write-Host "`n[OK] All TOC links are valid!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERROR] $brokenLinks broken TOC link(s) found!" -ForegroundColor Red
    Write-Host "Fix: Ensure paragraph headers match TOC entries" -ForegroundColor Yellow
    exit 1
}
