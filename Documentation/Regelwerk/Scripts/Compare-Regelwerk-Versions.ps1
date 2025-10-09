<#
.SYNOPSIS
    Vergleicht zwei Regelwerk-Versionen auf Unterschiede

.DESCRIPTION
    Analysiert Unterschiede zwischen zwei Regelwerk-Versionen:
    - Paragraphen: Hinzugefügt, entfernt, beibehalten
    - Dateigröße: Absolut und prozentual
    - Warnt bei Paragraphen-Verlust oder signifikantem Größenverlust

.PARAMETER OldVersion
    Alte Version (z.B. "v10.0.3")

.PARAMETER NewVersion
    Neue Version (z.B. "v10.0.4")

.EXAMPLE
    .\Compare-Regelwerk-Versions.ps1 -OldVersion "v10.0.3" -NewVersion "v10.0.4"

.NOTES
    Version: 1.0
    Autor: Flecki (Tom) Garnreiter
    Datum: 2025-10-09
#>

param(
    [Parameter(Mandatory)]
    [string]$OldVersion,  # z.B. "v10.0.3"
    
    [Parameter(Mandatory)]
    [string]$NewVersion   # z.B. "v10.0.4"
)

# Pfade bestimmen
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

$oldPath = Join-Path $repoRoot "PowerShell-Regelwerk-Universal-$OldVersion.md"
$newPath = Join-Path $repoRoot "PowerShell-Regelwerk-Universal-$NewVersion.md"

# Validierung
if (-not (Test-Path $oldPath)) {
    Write-Error "Old version not found: $oldPath"
    exit 1
}

if (-not (Test-Path $newPath)) {
    Write-Error "New version not found: $newPath"
    exit 1
}

Write-Host "`n=== Regelwerk Version Diff ===" -ForegroundColor Cyan
Write-Host "OLD: $OldVersion ($oldPath)" -ForegroundColor Yellow
Write-Host "NEW: $NewVersion ($newPath)" -ForegroundColor Green
Write-Host ""

# Extrahiere Paragraphen aus beiden Versionen
$oldContent = Get-Content $oldPath -Raw
$newContent = Get-Content $newPath -Raw

$oldParagraphs = [regex]::Matches($oldContent, '## §(\d+)[:\s]') | 
    ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique

$newParagraphs = [regex]::Matches($newContent, '## §(\d+)[:\s]') | 
    ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique

# Vergleiche
$removed = $oldParagraphs | Where-Object { $_ -notin $newParagraphs }
$added = $newParagraphs | Where-Object { $_ -notin $oldParagraphs }
$kept = $oldParagraphs | Where-Object { $_ -in $newParagraphs }

Write-Host "Paragraph Changes:" -ForegroundColor White
Write-Host "  Kept:    $($kept.Count) " -ForegroundColor Green -NoNewline
if ($kept.Count -gt 0) {
    Write-Host "($(($kept | Sort-Object) -join ', '))" -ForegroundColor Gray
} else {
    Write-Host ""
}

Write-Host "  Added:   $($added.Count) " -ForegroundColor Cyan -NoNewline
if ($added.Count -gt 0) {
    Write-Host "($(($added | Sort-Object) -join ', '))" -ForegroundColor Gray
} else {
    Write-Host ""
}

Write-Host "  Removed: $($removed.Count) " -ForegroundColor $(if ($removed.Count -gt 0) { 'Red' } else { 'Green' }) -NoNewline
if ($removed.Count -gt 0) {
    Write-Host "($(($removed | Sort-Object) -join ', '))" -ForegroundColor Gray
} else {
    Write-Host ""
}

# Größenvergleich
$oldSize = (Get-Item $oldPath).Length
$newSize = (Get-Item $newPath).Length
$sizeDiff = $newSize - $oldSize
$sizePercent = if ($oldSize -gt 0) { [math]::Round(($sizeDiff / $oldSize) * 100, 2) } else { 0 }

Write-Host "`nFile Size:" -ForegroundColor White
Write-Host "  OLD: $([math]::Round($oldSize/1KB, 2)) KB" -ForegroundColor Yellow
Write-Host "  NEW: $([math]::Round($newSize/1KB, 2)) KB" -ForegroundColor Green
Write-Host "  DIFF: $([math]::Round($sizeDiff/1KB, 2)) KB (" -NoNewline -ForegroundColor $(if ($sizeDiff -gt 0) { 'Cyan' } elseif ($sizeDiff -lt -5KB) { 'Red' } else { 'Yellow' })
Write-Host "$sizePercent%" -NoNewline -ForegroundColor $(if ($sizeDiff -gt 0) { 'Cyan' } elseif ($sizeDiff -lt -5KB) { 'Red' } else { 'Yellow' })
Write-Host ")" -ForegroundColor $(if ($sizeDiff -gt 0) { 'Cyan' } elseif ($sizeDiff -lt -5KB) { 'Red' } else { 'Yellow' })

# Warnungen
$hasErrors = $false

if ($removed.Count -gt 0) {
    Write-Host "`n[CRITICAL WARNING] Paragraphs were REMOVED!" -ForegroundColor Red
    Write-Host "This is unusual and requires manual review!" -ForegroundColor Red
    Write-Host "Removed: $($removed -join ', ')" -ForegroundColor Red
    $hasErrors = $true
}

if ($sizeDiff -lt -5KB) {
    Write-Host "`n[WARNING] Significant size decrease detected!" -ForegroundColor Yellow
    Write-Host "Content may have been lost. Manual review recommended!" -ForegroundColor Yellow
}

if ($added.Count -gt 0) {
    Write-Host "`n[INFO] New paragraphs added:" -ForegroundColor Cyan
    Write-Host "$($added -join ', ')" -ForegroundColor White
}

# Exit
if ($hasErrors) {
    Write-Host "`n[ERROR] Version comparison FAILED!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[OK] Version comparison complete." -ForegroundColor Green
    exit 0
}
