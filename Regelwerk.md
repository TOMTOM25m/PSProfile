# MUW-Regelwerk für PowerShell-Skripte

**Version:** 7.9.0
**Autor:** © Flecki Garnreiter

---

<!-- markdownlint-disable-next-line MD033 -->
<details>
<summary>KI-Anweisungen (Technische Konventionen)</summary>

Dieser Abschnitt dient als technische Kurzübersicht für die KI-Assistenz.

* **Kodierung:** UTF-8 (ohne BOM) für alle `.ps1`, `.psm1`, `.json` Dateien.
* **Analyse:** `PSScriptAnalyzer`-Regeln (insb. Verb-Noun) sind verbindlich.
* **Kompatibilität:** PowerShell 5.1 und 7+ (`$IsCoreCLR` für Weichen nutzen).
* **Admin:** Skripte mit Admin-Bedarf nutzen `#requires -RunAsAdministrator`.
* **Dateistruktur:**
    * **Hauptskript:** `*.ps1`
    * **Module:** `./Modules/FL-*.psm1`
    * **Konfiguration:** `./Config/Config-<ScriptName>.json`
    * **Sprachdateien:** `./Config/[de-DE|en-US].json` (Versioniert)
    * **Sprachvorlagen:** `./Config/[de-DE|en-US].json.default`
    * **Dokumentation:** `FL-README-<ScriptName>.md`
* **Versionierung (vX.Y.Z):**
    * Muss im Skript-Header (`Version now`), in der `$Global:ScriptVersion`-Variable und im End-Kommentar des Hauptskripts konsistent sein.
    * Die `RulebookVersion` wird ebenfalls im Header und in der Default-Config gepflegt.
* **Header & Footer:**
    * **Header:** Ein standardisierter Kommentar-Header ist für alle `.ps1`- und `.psm1`-Dateien Pflicht.
    * **Footer (.ps1):** `# --- End of Script --- old: vX.Y.Z ; now: vX.Y.Z ; Regelwerk: vX.Y.Z ---`
    * **Footer (.psm1):** `# --- End of module --- vX.Y.Z ; Regelwerk: vX.Y.Z ---`
* **GUI (WPF):**
    * **Aufruf:** `-Setup`-Parameter startet die Konfigurations-GUI.
    * **Auto-Start:** Erfolgt, wenn `config.json` fehlt oder korrupt ist.
    * **Design:** Primärfarbe ist `#111d4e` (Dunkelblau) mit weißer Schrift.
    * **Buttons:** `[Abbrechen]` links, `[Anwenden]` und `[OK]` rechts.
* **Logging:**
    * **Sprache:** Alle Log-Meldungen, die in Dateien oder das EventLog geschrieben werden, müssen auf Englisch sein.
    * **Dateinamen:** `DEV_<ScriptName>_yyyy-MM-dd.log` für Entwicklung, `PROD_<ScriptName>_yyyy-MM-dd.log` für Produktivbetrieb.
    * **Event Log:** `WARNING`- und `ERROR`-Meldungen müssen ins Windows Event Log geschrieben werden (Funktion muss per Konfiguration abschaltbar sein).
* **Mail:** `System.Net.Mail.SmtpClient` verwenden, nicht `Send-MailMessage`.
* **Archivierung:** 7-Zip bevorzugen, mit `Compress-Archive` als Fallback.

</details>

---

[...]

## 1. Dokumentation & Struktur

### Beispiel für einen Skript-Header

```powershell
.SYNOPSIS
    [DE] Setzt alle PowerShell-Profile auf einen Standard zurück und verwaltet die Konfiguration.
    [EN] Resets all PowerShell profiles to a standard and manages the configuration.
.DESCRIPTION
    [DE] Ein vollumfängliches Verwaltungsskript für PowerShell-Profile...
    [EN] A comprehensive management script for PowerShell profiles...
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
    Last modified:  2025.09.01
    Version:        v10.5.0
    MUW-Regelwerk:  v7.8.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
.DISCLAIMER
    [DE] Die bereitgestellten Skripte und die zugehörige Dokumentation werden "wie besehen" ("as is")
    ohne ausdrückliche oder stillschweigende Gewährleistung jeglicher Art zur Verfügung gestellt.
    [...]

    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    [...]
```

### 1.2. Generierte Hilfedatei (README)

Zu jedem Hauptskript (`.ps1`) wird eine separate `FL-README-<ScriptName>.md`-Datei als offizielle Dokumentation erstellt.

* **Nutzen:** Stellt eine leicht zugängliche und lesbare Dokumentation für Anwender bereit, ohne dass diese den Skript-Code öffnen müssen.
* **Inhalt:** Diese Markdown-Datei enthält die formatierten Inhalte des Skript-Headers.
* **Erstellung:** Die Datei kann manuell oder durch einen Assistenten (wie Gemini) aus dem Skript-Header generiert werden.

### 1.3. Einheitlicher Skript-Abschluss (Footer)

Jede Datei wird mit einem definierten Kommentar abgeschlossen.

* **Nutzen:** Signalisiert klar das Ende der Datei und gibt eine schnelle Übersicht über die relevanten Versionen.
* **Footer für Hauptskripte (.ps1):**

    ```powershell
    # --- End of Script --- old: v10.4.1 ; now: v10.5.0 ; Regelwerk: v7.8.0 ---
    ```

* **Footer für Moduldateien (.psm1):**

    ```powershell
    # --- End of module --- v10.5.0 ; Regelwerk: v7.8.0 ---
    ```

### 1.4. Einheitliche Versionierung

Die Versionierung folgt dem klaren Schema `vX.Y.Z` (z.B. `v1.2.15`).

* **Nutzen:** Änderungen sind klar nachvollziehbar und werden im Header, in globalen Variablen und im Footer synchron gehalten.

### 1.5. Einheitliches Design der Benutzeroberfläche

Grafische Benutzeroberflächen (GUIs) folgen dem Corporate Design der MedUni Wien.

* **Nutzen:** Sorgt für ein professionelles und vertrautes Erscheinungsbild.
* **Details:**
    * **Farbschema:** Primäre Elemente nutzen Dunkelblau (`#111d4e`) mit weißer Schrift.
    * **Fenstertitel:** Zeigt immer den Skriptnamen und die Version an (z.B. `SetupGUI MeinSkript - v1.2.15`).
    * **Button-Anordnung:** `Abbrechen` steht immer links; `Anwenden` und `OK` stehen immer rechts.

## 2. Benutzerfreundlichkeit & Bedienbarkeit

Skripte müssen so gestaltet sein, dass sie auch von technisch weniger versierten Personen einfach und sicher konfiguriert und bedient werden können.

### 2.1. Einfache Konfiguration per GUI (SetupGUI)

Jedes Skript verfügt über eine grafische Oberfläche zur Konfiguration, die mit dem Parameter `-Setup` aufgerufen wird.

* **Nutzen:** Einstellungen können bequem per Mausklick vorgenommen werden.
* **Automatische Ersteinrichtung:** Fehlt die Konfigurationsdatei, startet die GUI automatisch.

### 2.2. Klare und sichere Umgebungssteuerung

In der GUI kann klar zwischen `DEV` (Test) und `PROD` (Produktiv) umgeschaltet werden.

* **Nutzen:** Verhindert, dass versehentlich Test-Einstellungen im produktiven Einsatz verwendet werden.
* **Simulations-Modus (WhatIf):** Im `DEV`-Modus kann eine Simulation aktiviert werden, die nur anzeigt, was das Skript tun würde.

### 2.3. Verständliche Oberfläche

Die GUI ist selbsterklärend aufgebaut.

* **Nutzen:** Reduziert Anwendungsfehler und Rückfragen.
* **Details:**
    * **Hilfetexte:** Kurze, informative Texte erklären die Einstellungen direkt im Fenster.
    * **Sprachauswahl:** Die Oberfläche kann zwischen Deutsch und Englisch umgeschaltet werden.
    * **Dateipfade auswählen:** Alle Pfadangaben verfügen über einen "Durchsuchen..."-Button.

## 3. Stabilität & Wartbarkeit

[...]

Alle Einstellungen werden in einer separaten JSON-Datei im `Config`-Ordner gespeichert (`Config-<ScriptName>.json`).

* **Nutzen:** Trennt Konfiguration vom Code und minimiert das Fehlerrisiko bei Änderungen.

### 3.3. Aussagekräftiges Logging

Das Skript protokolliert seine Aktivitäten in Log-Dateien.

* **Nutzen:** Ermöglicht eine schnelle Fehleranalyse.
* **Details:**
    * **Sprache:** Alle Log-Einträge sind ausschließlich auf Englisch.
    * **Dateiname:** `[DEV|PROD]_<ScriptName>_yyyy-MM-dd.log`.
    * **Event Log:** Kritische Fehler und Warnungen werden zusätzlich ins Windows Event Log geschrieben.

### 3.4. Automatische Archivierung

Alte Log-Dateien werden automatisch aufgeräumt.

* **Nutzen:** Verhindert, dass der Speicherplatz überfüllt wird.
* **Details:** Logs werden nach 30 Tagen komprimiert, Archive nach 90 Tagen gelöscht (konfigurierbar).
