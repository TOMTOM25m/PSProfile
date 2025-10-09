# Regelwerk v10.0.4 COMPLETE - Merge Guide

**Datum:** 2025-10-09  
**Status:** IN PROGRESS - Manuelle Zusammenführung erforderlich  
**Analyst:** Flecki (Tom) Garnreiter

---

## 🎯 ZIEL

Erstelle PowerShell-Regelwerk v10.0.4 COMPLETE mit ALLEN 19 Paragraphen durch Zusammenführung von:

- **v10.0.0:** Basis-Paragraphen §1-§15
- **v10.0.3:** Updated/Neue Paragraphen §11, §14, §16-§19

---

## ✅ BEREITS ERLEDIGT

- ✅ v10.0.4.md erstellt (Kopie von v10.0.3)
- ✅ Header aktualisiert (Version, Release-Date, Supersedes)
- ✅ Executive Summary aktualisiert  
- ✅ Changelog für v10.0.4 hinzugefügt
- ✅ `REGELWERK-MISSING-CONTENT-ANALYSIS.md` erstellt

---

## 📋 MANUELLE SCHRITTE

### Schritt 1: Öffne beide Dateien

```powershell
code "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.0.md"
code "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.4.md"
```

### Schritt 2: Füge §1-§10 ein (aus v10.0.0)

**Position in v10.0.4.md:** Nach dem Inhaltsverzeichnis, vor "## §16: Email Standards"

**Quelle:** v10.0.0.md Zeilen 83-449

**Inhalt kopieren:**

```markdown
# Teil A: Grundlagen-Paragraphen

## §1 Version Management / Versionsverwaltung
[...kompletter Inhalt...]

## §2 Script Headers & Naming / Script-Kopfzeilen & Namensgebung
[...kompletter Inhalt...]

## §3 Functions / Funktionen
[...kompletter Inhalt...]

## §4 Error Handling / Fehlerbehandlung
[...kompletter Inhalt...]

## §5 Logging / Protokollierung
[...kompletter Inhalt...]

## §6 Configuration / Konfiguration
[...kompletter Inhalt...]

## §7 Modules & Repository Structure / Module & Repository-Struktur
[...kompletter Inhalt...]

## §8 PowerShell Compatibility / PowerShell-Kompatibilität
[...kompletter Inhalt...]

## §9 GUI Standards / GUI-Standards
[...kompletter Inhalt...]

---
---

# Teil B: Enterprise-Paragraphen

## §10 Strict Modularity / Strikte Modularität
[...kompletter Inhalt...]

---
```

### Schritt 3: §11 BEHALTEN (aus v10.0.3)

**§11: File Operations** ist bereits in v10.0.4 vorhanden (UPDATED v10.0.1 mit Robocopy MANDATORY)

✅ **NICHTS TUN** - bereits korrekt

### Schritt 4: Füge §12-§13 ein (aus v10.0.0)

**Position in v10.0.4.md:** Nach "## §11: File Operations", vor "## §14: Security Standards"

**Quelle:** v10.0.0.md Zeilen 532-618

**Inhalt kopieren:**

```markdown
## §12 Cross-Script Communication / Script-übergreifende Kommunikation
[...kompletter Inhalt...]

---

## §13 Network Operations / Netzwerkoperationen
[...kompletter Inhalt...]

---
```

### Schritt 5: §14 BEHALTEN (aus v10.0.3)

**§14: Security Standards** mit 3-Tier Credential Strategy ist bereits in v10.0.4 vorhanden (NEW v10.0.3)

✅ **NICHTS TUN** - bereits korrekt

**ABER:** v10.0.0 hatte ein altes §14. Das muss **GELÖSCHT/IGNORIERT** werden!

### Schritt 6: Füge §15 ein (aus v10.0.0)

**Position in v10.0.4.md:** Nach "## §14: Security Standards", vor "## §16: Email Standards"

**Quelle:** v10.0.0.md Zeilen 652-708

**Inhalt kopieren:**

```markdown
## §15 Performance Optimization / Performance-Optimierung
[...kompletter Inhalt...]

---

---

# Teil C: Certificate & Email Standards

```

### Schritt 7: §16-§19 BEHALTEN (aus v10.0.3)

**§16-§19** (Email, Excel, Certs, PS-Version) sind bereits in v10.0.4 vorhanden

✅ **NICHTS TUN** - bereits korrekt

### Schritt 8: Compliance-Checkliste aktualisieren

**Position in v10.0.4.md:** Vor "## 📜 Entwicklungshistorie"

**Ersetze** die vorhandene Compliance-Checkliste mit:

```markdown
---

## ✅ Compliance-Checkliste v10.0.4

- **[§1]**: `VERSION.ps1` existiert und ist korrekt formatiert.
- **[§2]**: Alle Skripte und Funktionen haben vollständige Comment-Based Help.
- **[§3]**: Alle Funktionen verwenden `[CmdletBinding()]` und Parameter-Validierung.
- **[§4]**: Kritischer Code ist in `try-catch` Blöcken. `$ErrorActionPreference` ist auf `Stop`.
- **[§5]**: Eine zentrale `Write-Log` Funktion wird verwendet.
- **[§6]**: Konfiguration ist in externer `config-*.json` Datei.
- **[§7]**: Das Projekt folgt der Standard-Verzeichnisstruktur. Logik ist in `FL-` Modulen.
- **[§8]**: Code ist kompatibel mit PS 5.1 und 7.x (keine Emojis in PS 5.1).
- **[§9]**: Eine WPF-basierte Setup-GUI ist vorhanden und nutzt das Corporate Design.
- **[§10]**: Hauptskripte sind unter 300 Zeilen.
- **[§11]**: `Robocopy` wird für ALLE File-Operations verwendet (MANDATORY v10.0.1).
- **[§12]**: Script-übergreifende Kommunikation erfolgt über JSON-Dateien.
- **[§13]**: Netzwerkoperationen haben eine Retry-Logik und Timeouts.
- **[§14]**: 3-Tier Credential Strategy wird für PSRemoting verwendet (NEW v10.0.3).
- **[§15]**: Parallelverarbeitung wird für rechenintensive Aufgaben genutzt.
- **[§16]**: MedUni Wien SMTP-Konfiguration (`smtpi.meduniwien.ac.at:25`) wird verwendet.
- **[§17]**: Excel-Operationen folgen standardisierten Column-Mappings.
- **[§18]**: Certificate Surveillance mit CertWebService-Integration.
- **[§19]**: PowerShell-Versionserkennung mit ASCII/UTF-8 Encoding-Strategie.

---
```

### Schritt 9: Entwicklungshistorie aktualisieren

**Position in v10.0.4.md:** Am Ende des Dokuments

**PREPEND** (vor v10.0.3 Historie einfügen):

```markdown
## 📜 Entwicklungshistorie

### v10.0.4 (2025-10-09) - COMPLETE EDITION

- **🔴 CRITICAL FIX**: Alle fehlenden Basis-Paragraphen §1-§10, §12-§13, §15 wiederhergestellt
- **✅ COMPLETE**: Jetzt ALLE 19 Paragraphen vollständig verfügbar
- **🔗 TOC FIXED**: Alle Inhaltsverzeichnis-Links funktionieren jetzt
- **📚 COMPREHENSIVE**: Vollständige Enterprise-PowerShell-Standards in einem Dokument
- **🎯 PRODUCTION-READY**: 100% produktionsreif für alle Projekte
- **📦 MERGED**: v10.0.0 (§1-§10,§12-§13,§15) + v10.0.3 (§11,§14,§16-§19)

### v10.0.3 (2025-10-07)
[...bestehende Historie...]
```

---

## 🔍 VERIFIKATION

Nach der manuellen Zusammenführung prüfe:

### 1. Struktur-Check

```powershell
$content = Get-Content "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.4.md" -Raw

# Prüfe ob alle Paragraphen vorhanden
$paragraphs = [regex]::Matches($content, '## §(\d+)[:\s]')
$foundNumbers = $paragraphs | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object

Write-Host "Gefundene Paragraphen: $($foundNumbers -join ', ')" -ForegroundColor Cyan

if ($foundNumbers.Count -eq 19 -and ($foundNumbers -join ',') -eq '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19') {
    Write-Host "[OK] ALLE 19 Paragraphen vorhanden!" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Paragraphen fehlen oder sind in falscher Reihenfolge!" -ForegroundColor Red
}
```

### 2. TOC-Link-Check

```powershell
# Prüfe ob alle TOC-Links funktionieren
$tocLinks = [regex]::Matches($content, '\[§(\d+):.*?\]\(#([^)]+)\)')
$anchors = [regex]::Matches($content, '^## (§\d+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)

Write-Host "`nTOC-Link-Validation:" -ForegroundColor Yellow
$brokenLinks = 0
foreach ($link in $tocLinks) {
    $linkText = $link.Groups[1].Value
    $linkTarget = $link.Groups[2].Value
    
    # Suche ob Anchor existiert
    $anchorExists = $content -match "^## §$linkText" 
    
    if (-not $anchorExists) {
        Write-Host "  [X] §$linkText -> $linkTarget (BROKEN)" -ForegroundColor Red
        $brokenLinks++
    }
}

if ($brokenLinks -eq 0) {
    Write-Host "  [OK] Alle TOC-Links funktionieren!" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] $brokenLinks broken links gefunden!" -ForegroundColor Red
}
```

### 3. Größen-Check

```powershell
$v1004 = Get-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.4.md"
$v1000 = Get-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.0.md"
$v1003 = Get-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.3.md"

Write-Host "`nDateigrößen-Vergleich:" -ForegroundColor Yellow
Write-Host "  v10.0.0: $([math]::Round($v1000.Length/1KB, 2)) KB (Basis §1-§15)" -ForegroundColor Cyan
Write-Host "  v10.0.3: $([math]::Round($v1003.Length/1KB, 2)) KB (§11,§14,§16-§19)" -ForegroundColor Cyan
Write-Host "  v10.0.4: $([math]::Round($v1004.Length/1KB, 2)) KB (COMPLETE §1-§19)" -ForegroundColor Green

$expectedMin = $v1000.Length + ($v1003.Length * 0.3)  # Mindestens 30% von v10.0.3 zusätzlich
if ($v1004.Length -gt $expectedMin) {
    Write-Host "`n[OK] v10.0.4 hat plausible Größe (größer als v10.0.0 + Teile von v10.0.3)" -ForegroundColor Green
} else {
    Write-Host "`n[WARNING] v10.0.4 scheint zu klein - eventuell fehlen Paragraphen!" -ForegroundColor Yellow
}
```

---

## 📊 FORTSCHRITT

| Aufgabe | Status | Notiz |
|---------|--------|-------|
| v10.0.4 Basis erstellen | ✅ DONE | Kopie von v10.0.3 |
| Header aktualisieren | ✅ DONE | Version, Date, Supersedes |
| Executive Summary | ✅ DONE | Beschreibung angepasst |
| Changelog v10.0.4 | ✅ DONE | Eingefügt |
| §1-§10 einfügen | ⏳ **TODO** | Aus v10.0.0 Zeilen 83-449 |
| §11 prüfen | ✅ DONE | Bereits vorhanden (v10.0.3) |
| §12-§13 einfügen | ⏳ **TODO** | Aus v10.0.0 Zeilen 532-618 |
| §14 prüfen | ✅ DONE | Bereits vorhanden (v10.0.3 NEU) |
| §15 einfügen | ⏳ **TODO** | Aus v10.0.0 Zeilen 652-708 |
| §16-§19 prüfen | ✅ DONE | Bereits vorhanden (v10.0.3) |
| Compliance-Checkliste | ⏳ **TODO** | Auf v10.0.4 aktualisieren |
| Historie aktualisieren | ⏳ **TODO** | v10.0.4 Eintrag prependen |
| Verifikation | ⏳ **TODO** | Scripts ausführen |

---

## 🚀 NACH FERTIGSTELLUNG

### 1. Deployment in Projekte

```powershell
# CertSurv
Copy-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.4.md" `
          "F:\DEV\repositories\CertSurv\Docs\" -Force

# CertWebService
Copy-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.4.md" `
          "F:\DEV\repositories\CertWebService\" -Force
```

### 2. Archive alte Versionen

```powershell
# v10.0.1, v10.0.2, v10.0.3 als INCOMPLETE markieren
Move-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.1.md" `
          "F:\DEV\repositories\Documentation\Regelwerk\INCOMPLETE\v10.0.1-INCOMPLETE.md" -Force

Move-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.2.md" `
          "F:\DEV\repositories\Documentation\Regelwerk\INCOMPLETE\v10.0.2-INCOMPLETE.md" -Force

Move-Item "F:\DEV\repositories\Documentation\Regelwerk\PowerShell-Regelwerk-Universal-v10.0.3.md" `
          "F:\DEV\repositories\Documentation\Regelwerk\INCOMPLETE\v10.0.3-INCOMPLETE.md" -Force
```

### 3. Git Commit

```bash
cd F:\DEV\repositories\Documentation\Regelwerk
git add PowerShell-Regelwerk-Universal-v10.0.4.md
git add REGELWERK-MISSING-CONTENT-ANALYSIS.md
git add REGELWERK-MERGE-GUIDE.md
git commit -m "feat(regelwerk): v10.0.4 COMPLETE - Restore all missing paragraphs (§1-§10,§12-§13,§15)

- CRITICAL FIX: Restored foundation paragraphs from v10.0.0
- All 19 paragraphs now available (§1-§19)
- Fixed broken TOC links
- Merged v10.0.0 (basis) + v10.0.3 (extended)
- Added comprehensive analysis docs
"
git tag -a regelwerk-v10.0.4 -m "Regelwerk v10.0.4 COMPLETE Edition"
```

---

## 📝 LESSONS LEARNED

### Warum sind Paragraphen verloren gegangen?

1. **v10.0.0 → v10.0.1:** Neue §16-§18 hinzugefügt, aber §1-§15 **vergessen zu kopieren**
2. **Kein Diff-Review:** Niemand hat vor Release verglichen ob Inhalte fehlen
3. **TOC täuscht:** Inhaltsverzeichnis war korrekt, aber Inhalte fehlten → sah komplett aus
4. **Keine Tests:** Keine automatische Prüfung ob alle TOC-Links funktionieren

### Wie verhindern wir das zukünftig?

→ **Siehe Phase 3: Regelwerk-Pflege-Process**

---

**Status:** ⏳ **IN PROGRESS** - Manuelle Schritte 2-9 ausstehend  
**Erstellt:** 2025-10-09 09:00  
**Autor:** Flecki (Tom) Garnreiter
