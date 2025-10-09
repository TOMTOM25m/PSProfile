# Regelwerk Maintenance Process v1.0

**Datum:** 2025-10-09  
**Status:** AKTIV  
**Gültigkeit:** Ab sofort für alle Regelwerk-Updates  
**Autor:** Flecki (Tom) Garnreiter

---

## 🎯 ZIEL

Sicherstellen, dass bei jedem Regelwerk-Update ALLE Paragraphen erhalten bleiben und keine Inhalte versehentlich verloren gehen.

---

## 📋 PRE-RELEASE CHECKLIST

Vor jedem neuen Regelwerk-Release **MUSS** folgende Checkliste abgearbeitet werden:

### ✅ 1. Struktur-Vollständigkeit prüfen

```powershell
# Script: Test-Regelwerk-Completeness.ps1
param(
    [Parameter(Mandatory)]
    [string]$RegelwerkPath
)

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
    exit 1
}

if ($extra.Count -gt 0) {
    Write-Host "`n[WARNING] EXTRA Paragraphs: $($extra -join ', ')" -ForegroundColor Yellow
}

if ($foundNumbers.Count -eq $expectedCount -and $missing.Count -eq 0) {
    Write-Host "`n[OK] All $expectedCount paragraphs present!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERROR] Completeness check FAILED!" -ForegroundColor Red
    exit 1
}
```

**Verwendung:**

```powershell
.\Test-Regelwerk-Completeness.ps1 -RegelwerkPath ".\PowerShell-Regelwerk-Universal-v10.0.4.md"
```

---

### ✅ 2. TOC-Link-Integrität prüfen

```powershell
# Script: Test-Regelwerk-TOC-Links.ps1
param(
    [Parameter(Mandatory)]
    [string]$RegelwerkPath
)

$content = Get-Content $RegelwerkPath -Raw

Write-Host "`n=== TOC Link Integrity Check ===" -ForegroundColor Cyan
Write-Host "File: $RegelwerkPath" -ForegroundColor White

# Extrahiere TOC-Links
$tocLinks = [regex]::Matches($content, '\[§(\d+):.*?\]\(#([^)]+)\)')

$brokenLinks = 0
$testedLinks = 0

foreach ($link in $tocLinks) {
    $paragraphNumber = $link.Groups[1].Value
    $anchorText = $link.Groups[2].Value
    $testedLinks++
    
    # Suche nach Paragraph-Überschrift
    $anchorPattern = "^## §$paragraphNumber[:\s]"
    $anchorExists = $content -match $anchorPattern
    
    if (-not $anchorExists) {
        Write-Host "  [X] §$paragraphNumber -> #$anchorText (BROKEN)" -ForegroundColor Red
        $brokenLinks++
    } else {
        Write-Host "  [✓] §$paragraphNumber" -ForegroundColor Green
    }
}

Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Tested Links: $testedLinks" -ForegroundColor White
Write-Host "  Broken Links: $brokenLinks" -ForegroundColor $(if ($brokenLinks -eq 0) { 'Green' } else { 'Red' })

if ($brokenLinks -eq 0) {
    Write-Host "`n[OK] All TOC links are valid!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERROR] $brokenLinks broken TOC links found!" -ForegroundColor Red
    exit 1
}
```

**Verwendung:**

```powershell
.\Test-Regelwerk-TOC-Links.ps1 -RegelwerkPath ".\PowerShell-Regelwerk-Universal-v10.0.4.md"
```

---

### ✅ 3. Versions-Diff prüfen

```powershell
# Script: Compare-Regelwerk-Versions.ps1
param(
    [Parameter(Mandatory)]
    [string]$OldVersion,  # z.B. "v10.0.3"
    
    [Parameter(Mandatory)]
    [string]$NewVersion   # z.B. "v10.0.4"
)

$oldPath = ".\PowerShell-Regelwerk-Universal-$OldVersion.md"
$newPath = ".\PowerShell-Regelwerk-Universal-$NewVersion.md"

if (-not (Test-Path $oldPath)) {
    Write-Error "Old version not found: $oldPath"
    exit 1
}

if (-not (Test-Path $newPath)) {
    Write-Error "New version not found: $newPath"
    exit 1
}

Write-Host "`n=== Regelwerk Version Diff ===" -ForegroundColor Cyan
Write-Host "OLD: $OldVersion" -ForegroundColor Yellow
Write-Host "NEW: $NewVersion" -ForegroundColor Green

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

Write-Host "`nParagraph Changes:" -ForegroundColor White
Write-Host "  Kept:    $($kept.Count) ($(($kept | Sort-Object) -join ', '))" -ForegroundColor Green
Write-Host "  Added:   $($added.Count) $(if ($added.Count -gt 0) { "($(($added | Sort-Object) -join ', '))" })" -ForegroundColor Cyan
Write-Host "  Removed: $($removed.Count) $(if ($removed.Count -gt 0) { "($(($removed | Sort-Object) -join ', '))" })" -ForegroundColor $(if ($removed.Count -gt 0) { 'Red' } else { 'Green' })

# Größenvergleich
$oldSize = (Get-Item $oldPath).Length
$newSize = (Get-Item $newPath).Length
$sizeDiff = $newSize - $oldSize
$sizePercent = [math]::Round(($sizeDiff / $oldSize) * 100, 2)

Write-Host "`nFile Size:" -ForegroundColor White
Write-Host "  OLD: $([math]::Round($oldSize/1KB, 2)) KB" -ForegroundColor Yellow
Write-Host "  NEW: $([math]::Round($newSize/1KB, 2)) KB" -ForegroundColor Green
Write-Host "  DIFF: $([math]::Round($sizeDiff/1KB, 2)) KB ($sizePercent%)" -ForegroundColor $(if ($sizeDiff -gt 0) { 'Cyan' } else { 'Yellow' })

# Warnung bei Paragraphen-Verlust
if ($removed.Count -gt 0) {
    Write-Host "`n[CRITICAL WARNING] Paragraphs were REMOVED!" -ForegroundColor Red
    Write-Host "This is unusual and requires manual review!" -ForegroundColor Red
    Write-Host "Removed: §$($removed -join ', §')" -ForegroundColor Red
    exit 1
}

# Warnung bei signifikantem Größen-Verlust
if ($sizeDiff -lt -5KB) {
    Write-Host "`n[WARNING] Significant size decrease detected!" -ForegroundColor Yellow
    Write-Host "Content may have been lost. Manual review recommended!" -ForegroundColor Yellow
}

Write-Host "`n[OK] Version comparison complete." -ForegroundColor Green
exit 0
```

**Verwendung:**

```powershell
.\Compare-Regelwerk-Versions.ps1 -OldVersion "v10.0.3" -NewVersion "v10.0.4"
```

---

### ✅ 4. Changelog-Eintrag validieren

**Manuelle Prüfung:**

- [ ] Neuer Versions-Eintrag im Changelog vorhanden?
- [ ] Release-Datum korrekt?
- [ ] Supersedes-Feld aktualisiert?
- [ ] Alle neuen Features dokumentiert?
- [ ] Breaking Changes markiert?
- [ ] Migration-Guide vorhanden (falls Breaking Changes)?

---

### ✅ 5. Compliance-Checkliste aktualisieren

**Manuelle Prüfung:**

- [ ] Compliance-Checkliste enthält ALLE Paragraphen?
- [ ] Neue Paragraphen in Checkliste aufgenommen?
- [ ] Versionsnummer in Überschrift aktualisiert?

---

## 🔄 RELEASE WORKFLOW

### Phase 1: Vorbereitung

1. **Branch erstellen:**

   ```bash
   git checkout -b regelwerk/v10.0.X
   ```

2. **Änderungen durchführen:**
   - Neue Paragraphen hinzufügen
   - Bestehende aktualisieren
   - Version, Datum, Changelog aktualisieren

### Phase 2: Validation

3. **Automatische Tests ausführen:**

   ```powershell
   # Completeness Check
   .\Test-Regelwerk-Completeness.ps1 -RegelwerkPath ".\PowerShell-Regelwerk-Universal-v10.0.X.md"
   
   # TOC Links Check
   .\Test-Regelwerk-TOC-Links.ps1 -RegelwerkPath ".\PowerShell-Regelwerk-Universal-v10.0.X.md"
   
   # Version Diff
   .\Compare-Regelwerk-Versions.ps1 -OldVersion "v10.0.Y" -NewVersion "v10.0.X"
   ```

4. **Manuelle Review:**
   - [ ] Changelog vollständig?
   - [ ] Compliance-Checkliste aktualisiert?
   - [ ] Executive Summary passt zur Version?
   - [ ] Alle neuen Features dokumentiert?

### Phase 3: Deployment

5. **Git Commit & Tag:**

   ```bash
   git add PowerShell-Regelwerk-Universal-v10.0.X.md
   git commit -m "feat(regelwerk): v10.0.X - <Summary>"
   git tag -a regelwerk-v10.0.X -m "Regelwerk v10.0.X"
   ```

6. **Deployment in Projekte:**

   ```powershell
   # CertSurv
   Copy-Item ".\PowerShell-Regelwerk-Universal-v10.0.X.md" "..\..\CertSurv\Docs\" -Force
   
   # CertWebService
   Copy-Item ".\PowerShell-Regelwerk-Universal-v10.0.X.md" "..\..\CertWebService\" -Force
   
   # Andere Projekte...
   ```

7. **Git Push:**

   ```bash
   git push origin regelwerk/v10.0.X
   git push origin regelwerk-v10.0.X
   ```

### Phase 4: Archive

8. **Alte Version archivieren:**

   ```powershell
   $oldVersion = "v10.0.Y"
   $archiveDir = ".\Archive"
   
   if (-not (Test-Path $archiveDir)) {
       New-Item -Path $archiveDir -ItemType Directory | Out-Null
   }
   
   Move-Item ".\PowerShell-Regelwerk-Universal-$oldVersion.md" `
             "$archiveDir\PowerShell-Regelwerk-Universal-$oldVersion.md" -Force
   
   Write-Host "[OK] v$oldVersion archived" -ForegroundColor Green
   ```

---

## 🚨 COMMON MISTAKES

### ❌ Fehler 1: Kopieren statt Erweitern

**Falsch:**

```powershell
# Neues Regelwerk von Grund auf neu schreiben
Copy-Item "template.md" "PowerShell-Regelwerk-Universal-v10.0.4.md"
```

**Richtig:**

```powershell
# Vorherige Version als Basis nehmen
Copy-Item "PowerShell-Regelwerk-Universal-v10.0.3.md" "PowerShell-Regelwerk-Universal-v10.0.4.md"
# Dann erweitern/aktualisieren
```

### ❌ Fehler 2: TOC nicht aktualisieren

**Problem:** Neue Paragraphen hinzufügen, aber Inhaltsverzeichnis nicht aktualisieren

**Lösung:** Nach jedem Paragraph-Add/Remove TOC manuell prüfen und `Test-Regelwerk-TOC-Links.ps1` ausführen

### ❌ Fehler 3: Keine Versions-Diff vor Release

**Problem:** Nicht prüfen ob Inhalte zwischen Versionen verloren gingen

**Lösung:** `Compare-Regelwerk-Versions.ps1` IMMER vor Release ausführen

### ❌ Fehler 4: Changelog vergessen

**Problem:** Version-Nummer aktualisiert, aber Changelog-Eintrag fehlt

**Lösung:** Changelog MUSS Teil der Pre-Release-Checklist sein

---

## 📊 QUALITY METRICS

### Ziel-Metriken für Regelwerk-Qualität

| Metrik | Ziel | Aktuell (v10.0.4) |
|--------|------|-------------------|
| Paragraph-Vollständigkeit | 100% (19/19) | ✅ 100% (19/19) |
| TOC-Link-Integrität | 100% (0 broken) | ⏳ PENDING (nach Merge) |
| Changelog-Vollständigkeit | 100% | ✅ 100% |
| Compliance-Checkliste Vollständigkeit | 100% (19/19) | ⏳ PENDING (nach Merge) |
| Release-Test-Coverage | 100% (3/3 Scripts) | ✅ 100% |

---

## 🔧 TOOL INSTALLATION

### Setup: Test-Scripts erstellen

```powershell
# Erstelle Scripts-Ordner
$scriptsDir = "F:\DEV\repositories\Documentation\Regelwerk\Scripts"
New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null

# Test-Regelwerk-Completeness.ps1
# [Script-Inhalt aus §1 oben einfügen]

# Test-Regelwerk-TOC-Links.ps1
# [Script-Inhalt aus §2 oben einfügen]

# Compare-Regelwerk-Versions.ps1
# [Script-Inhalt aus §3 oben einfügen]

Write-Host "[OK] Regelwerk Maintenance Scripts created in $scriptsDir" -ForegroundColor Green
```

---

## 📝 LESSONS LEARNED (aus v10.0.4 Incident)

### Was ist schief gelaufen?

1. **v10.0.0 → v10.0.1:** Neue §16-§18 hinzugefügt, §1-§15 **vergessen zu kopieren**
2. **Kein Pre-Release-Check:** Completeness-Script hätte Fehler sofort erkannt
3. **TOC täuschte:** Links zeigten ins Leere, aber niemand testete sie
4. **3 Versionen betroffen:** v10.0.1, v10.0.2, v10.0.3 hatten alle das gleiche Problem
5. **Monate unentdeckt:** Erst bei User-Frage ("warum ist Mailconfig nicht drin?") aufgefallen

### Wie hätte es verhindert werden können?

- ✅ **Test-Regelwerk-Completeness.ps1** hätte sofort 13 fehlende Paragraphen gemeldet
- ✅ **Test-Regelwerk-TOC-Links.ps1** hätte 13 broken TOC-Links gefunden
- ✅ **Compare-Regelwerk-Versions.ps1** hätte 90% Größenverlust und fehlende Paragraphen gemeldet

### Wie verhindern wir es zukünftig?

- ✅ **MANDATORY:** Alle 3 Test-Scripts VOR jedem Release ausführen
- ✅ **MANDATORY:** Version-Diff IMMER prüfen
- ✅ **MANDATORY:** TOC-Links IMMER testen
- ✅ **PROCESS:** Dieser Maintenance-Process ist ab sofort MANDATORY

---

## ✅ ERFOLGS-KRITERIEN

Ein Regelwerk-Release gilt als **ERFOLGREICH**, wenn:

1. ✅ Alle Test-Scripts PASS (Exit Code 0)
2. ✅ Versions-Diff zeigt keine unerwarteten Verluste
3. ✅ Changelog ist vollständig und korrekt
4. ✅ Compliance-Checkliste ist aktualisiert
5. ✅ Executive Summary passt zur Version
6. ✅ TOC-Links funktionieren alle
7. ✅ Alte Version ist archiviert
8. ✅ Neue Version ist in Projekten deployed
9. ✅ Git Tag ist erstellt und gepusht

---

**Status:** ✅ **ACTIVE** - Ab sofort für alle Regelwerk-Updates MANDATORY  
**Version:** 1.0  
**Erstellt:** 2025-10-09  
**Autor:** Flecki (Tom) Garnreiter  
**Review:** Jährlich oder nach größeren Incidents
