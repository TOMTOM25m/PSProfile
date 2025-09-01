# KI-Anweisungen (Technische Konventionen)

*Dieser Abschnitt dient als technische Kurzübersicht für die KI-Assistenz.*

---

- **Kodierung:** UTF-8 (ohne BOM) für alle `.ps1`, `.psm1`, `.json` Dateien.
- **Analyse:** `PSScriptAnalyzer`-Regeln (insb. `Verb-Noun`) sind verbindlich.
- **Kompatibilität:** PowerShell 5.1 und 7+ (`$IsCoreCLR` für Weichen nutzen).
- **Admin:** Skripte mit Admin-Bedarf nutzen `#requires -RunAsAdministrator`.

- **Dateistruktur:**
    - Hauptskript: `*.ps1`
    - Module: `./Modules/FL-*.psm1`
    - Konfiguration: `./Config/Config-<ScriptName>.json`
    - Sprachdateien: `./Config/[de-DE|en-US].json` (Versioniert)
    - Dokumentation: `FL-README-<ScriptName>.md`

- **Versionierung (`vX.Y.Z`):**
    - Muss im Skript-Header (`Version now`), in der `$Global:ScriptVersion`-Variable und im End-Kommentar des Hauptskripts konsistent sein.
    - Die `RulebookVersion` wird ebenfalls im Header und in der Default-Config gepflegt.

- **Header & Footer:**
    - **Header:** Ein standardisierter Kommentar-Header ist für **alle** `.ps1`- und `.psm1`-Dateien Pflicht.
    - **Footer (.ps1):** `# --- End of Script --- old: vX.Y.Z ; now: vX.Y.Z ; Regelwerk: vX.Y.Z ---`
    - **Footer (.psm1):** `# --- End of module --- vX.Y.Z ; Regelwerk: vX.Y.Z ---`

- **GUI (WPF):**
    - **Aufruf:** `-Setup`-Parameter startet die Konfigurations-GUI.
    - **Auto-Start:** Erfolgt, wenn `config.json` fehlt oder korrupt ist.
    - **Design:** Primärfarbe ist `#111d4e` (Dunkelblau) mit weißer Schrift.
    - **Buttons:** [Abbrechen] links, [Anwenden] und [OK] rechts.

- **Logging:**
    - **Sprache:** Alle Log-Meldungen, die in Dateien oder das EventLog geschrieben werden, müssen **auf Englisch** sein.
    - **Dateinamen:** `DEV_<ScriptName>_yyyy-MM-dd.log` für Entwicklung, `PROD_<ScriptName>_yyyy-MM-dd.log` für Produktivbetrieb.
    - **Event Log:** `WARNING`- und `ERROR`-Meldungen müssen ins Windows Event Log geschrieben werden (Funktion muss per Konfiguration abschaltbar sein).

- **Mail:** `System.Net.Mail.SmtpClient` verwenden, nicht `Send-MailMessage`.
- **Archivierung:** `7-Zip` bevorzugen, mit `Compress-Archive` als Fallback.

---
---

# MUW-Regelwerk für PowerShell-Skripte

**Version 7.3.0 © Flecki Garnreiter**

### Einleitung: Warum dieses Regelwerk?

Dieses Dokument definiert die Standards für die Entwicklung von PowerShell-Skripten an der MedUni Wien. Das Ziel ist es, Skripte zu erstellen, die nicht nur technisch exzellent sind, sondern auch **sicher, verständlich, wartbar und für alle Anwender einfach zu bedienen**.

Ein einheitlicher Standard sorgt dafür, dass jedes Skript eine hohe Qualität aufweist und sich für Benutzer und Administratoren vertraut anfühlt.

---

## 1. Konsistenz & Wiedererkennung

*Alle Skripte sollen einem einheitlichen Erscheinungsbild und einer logischen Struktur folgen.*

### **1.1. Einheitliche Dokumentation (Script-Header)**
Jede Skript- und Moduldatei (`.ps1`, `.psm1`) beginnt mit einem standardisierten Header. Dieser dient als "Visitenkarte" der Datei und muss vollständig ausgefüllt werden.

* **Nutzen:** Man erkennt auf den ersten Blick, was das Skript tut, wer es geschrieben hat und welche Version aktuell ist.

**Beispiel eines vollständigen Headers für ein Hauptskript:**
```powershell
<#
.SYNOPSIS
    [DE] Setzt alle PowerShell-Profile auf einen Standard zurück und verwaltet die Konfiguration.
    [EN] Resets all PowerShell profiles to a standard and manages the configuration.

.DESCRIPTION
    [DE] Ein vollumfängliches Verwaltungsskript für PowerShell-Profile. Es erzwingt Administratorrechte, stellt die UTF-8-Kodierung sicher und bietet eine WPF-basierte GUI (-Setup) zur Konfiguration. Bei fehlender oder korrupter Konfiguration startet die GUI automatisch. Das Skript führt eine Versionskontrolle der Konfiguration durch, versioniert die Profil-Vorlagen, schreibt in das Windows Event Log und beinhaltet eine voll funktionsfähige Log-Archivierung sowie einen Mail-Versand.
    [EN] A comprehensive management script for PowerShell profiles according to MUW rules. It enforces administrator rights, ensures UTF-8 encoding, and provides a WPF-based GUI (-Setup) for configuration. The GUI starts automatically if the configuration is missing or corrupt. The script performs version control of the configuration, versions the profile templates, writes to the Windows Event Log, and includes fully functional log archiving and mail sending.

.PARAMETER Setup
    [DE] Startet die WPF-Konfigurations-GUI, um die Einstellungen zu bearbeiten.
    [EN] Starts the WPF configuration GUI to edit the settings.

.EXAMPLE
    .\Reset-PowerShellProfiles.ps1 -Setup
    [DE] Öffnet die Konfigurations-GUI, um die aktuellen Einstellungen zu ändern.
    [EN] Opens the configuration GUI to change the current settings.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.11
    Last modified:  2025.08.29
    Version:        v09.03.00
    MUW-Regelwerk:  v7.2.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>
```

### **1.2. Generierte Hilfedatei (README)**
Zu jedem Hauptskript (`.ps1`) wird eine separate `FL-README-<ScriptName>.md`-Datei als offizielle Dokumentation erstellt.

* **Nutzen:** Stellt eine leicht zugängliche und lesbare Dokumentation für Anwender bereit, ohne dass diese den Skript-Code öffnen müssen.
* **Inhalt:** Diese Markdown-Datei enthält die formatierten Inhalte des Skript-Headers (Synopsis, Beschreibung, Parameter, Beispiele etc.).
* **Erstellung:** Die Datei kann bei Bedarf manuell oder durch einen Assistenten (wie Gemini) aus dem Skript-Header generiert werden.

### **1.3. Einheitlicher Skript-Abschluss (Footer)**
Jede Datei wird mit einem definierten Kommentar abgeschlossen.

* **Nutzen:** Dies signalisiert klar das Ende der Datei und gibt bei Hauptskripten eine schnelle Übersicht über die relevanten Versionen.

**Footer für Hauptskripte (`.ps1`):**
```powershell
# --- End of Script --- old: v09.02.00 ; now: v09.03.00 ; Regelwerk: v7.2.0 ---
```

**Footer für Moduldateien (`.psm1`):**
```powershell
# --- End of module --- v09.03.00 ; Regelwerk: v7.2.0 ---
```

### **1.4. Einheitliche Versionierung**
Die Versionierung folgt dem klaren Schema `vX.Y.Z` (z.B. `v1.2.15`).

* **Nutzen:** Änderungen sind klar nachvollziehbar. Die Version wird im Header, in der globalen `$Global:ScriptVersion`-Variable und im Footer des Hauptskripts synchron gehalten.

### **1.5. Einheitliches Design der Benutzeroberfläche**
Grafische Benutzeroberflächen (GUIs) folgen dem Corporate Design der MedUni Wien.

* **Nutzen:** Sorgt für ein professionelles und vertrautes Erscheinungsbild bei allen Skripten.
* **Details:**
    * **Farbschema:** Primäre Elemente nutzen Dunkelblau (`#111d4e`) mit weißer Schrift.
    * **Fenstertitel:** Zeigt immer den Skriptnamen und die Version an (z.B. `SetupGUI MeinSkript - v1.2.15`).
    * **Button-Anordnung:** `Abbrechen` steht immer links; `Anwenden` und `OK` stehen immer rechts.

---

## 2. Benutzerfreundlichkeit & Bedienbarkeit

*Skripte müssen so gestaltet sein, dass sie auch von technisch weniger versierten Personen einfach und sicher konfiguriert und bedient werden können.*

### **2.1. Einfache Konfiguration per GUI (`SetupGUI`)**
Jedes Skript verfügt über eine grafische Oberfläche zur Konfiguration, die mit dem Parameter `-Setup` aufgerufen wird.

* **Nutzen:** Einstellungen können bequem per Mausklick vorgenommen werden, ohne den Code ändern zu müssen.
* **Automatische Ersteinrichtung:** Fehlt die Konfigurationsdatei, startet die GUI automatisch und führt den Anwender durch die Ersteinrichtung.

### **2.2. Klare und sichere Umgebungssteuerung**
In der GUI kann klar zwischen `DEV` (Test) und `PROD` (Produktiv) umgeschaltet werden.

* **Nutzen:** Dies ist die wichtigste Sicherheitsfunktion. Sie verhindert, dass versehentlich Test-Einstellungen (z.B. Test-Empfänger für E-Mails) im produktiven Einsatz verwendet werden.
* **Simulations-Modus (`WhatIf`):** Im DEV-Modus kann zusätzlich eine Simulation aktiviert werden. Das Skript zeigt dann nur an, was es tun würde, ohne Änderungen am System vorzunehmen.

### **2.3. Verständliche Oberfläche**
Die GUI ist selbsterklärend aufgebaut.

* **Nutzen:** Reduziert Anwendungsfehler und Rückfragen.
* **Details:**
    * **Hilfetexte:** Kurze, informative Texte erklären die Funktion der jeweiligen Einstellungen direkt im Fenster.
    * **Sprachauswahl:** Die Oberfläche kann zwischen Deutsch und Englisch umgeschaltet werden.
    * **Dateipfade auswählen:** Alle Pfadangaben verfügen über einen "Durchsuchen..."-Button, um Fehleingaben zu vermeiden.

---

## 3. Stabilität & Wartbarkeit

*Die technische Umsetzung muss robust, sicher und für andere Entwickler leicht nachvollziehbar sein.*

### **3.1. Modularer Aufbau (Baukasten-System)**
Zentrale Funktionen wie Logging, Konfigurations-Handling oder Mailversand werden in wiederverwendbare Module ausgelagert und im Unterordner `Modules` gespeichert.

* **Nutzen:** Statt das Rad neu zu erfinden, nutzen alle Skripte die gleiche, bewährte Code-Basis. Das macht die Skripte schlanker, zuverlässiger und einfacher zu warten.

### **3.2. Ausgelagerte Konfiguration**
Alle Einstellungen werden in einer separaten JSON-Datei im `Config`-Ordner gespeichert (`Config-ScriptName.json`).

* **Nutzen:** Die Konfiguration kann einfach gesichert oder angepasst werden, ohne den Programmcode zu berühren. Dies minimiert das Risiko, bei Änderungen Fehler zu verursachen.

### **3.3. Aussagekräftiges Logging**
Das Skript protokolliert seine Aktivitäten in Log-Dateien.

* **Nutzen:** Im Fehlerfall kann schnell nachvollzogen werden, was passiert ist.
* **Details:**
    * **Sprache:** Alle Log-Einträge sind **ausschließlich auf Englisch**.
    * **Dateiname:** Die Namen der Log-Dateien folgen einem klaren Schema: `[DEV|PROD]_<ScriptName>_yyyy-MM-dd.log`.
    * **Event Log:** Kritische Fehler und Warnungen werden zusätzlich ins Windows Event Log geschrieben, um eine zentrale Überwachung zu ermöglichen.

### **3.4. Automatische Archivierung**
Alte Log-Dateien und Archive werden automatisch aufgeräumt.

* **Nutzen:** Verhindert, dass der Speicherplatz mit alten Log-Dateien überfüllt wird.
* **Details:** Logs werden nach 30 Tagen komprimiert, die Archive nach 90 Tagen gelöscht (Werte sind konfigurierbar).
