# MUW-Regelwerk für PowerShell-Skripte

**Version:** 8.0.0
**Autor:** © Flecki Garnreiter

---

<!-- markdownlint-disable MD033 -->
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
  * **WhatIf-Ausnahme:** Logging, Konfigurationsspeicherung, E-Mail-Benachrichtigungen und Archivierung werden immer ausgeführt, auch im WhatIf-Modus.
* **Mail:** `System.Net.Mail.SmtpClient` verwenden, nicht `Send-MailMessage`.
* **Archivierung:** 7-Zip bevorzugen, mit `Compress-Archive` als Fallback.
* **WhatIf-Modus:** Der WhatIf-Modus darf beim ersten Start nie aktiviert sein, er soll nur über die GUI oder eine bestehende Konfigurationsdatei aktivierbar sein.
* **Modul-Struktur:** Funktionen sollten nur in einem Modul definiert werden, um Redundanzen und Konflikte zu vermeiden. GUI-spezifische Logik gehört in `FL-Gui.psm1`, Konfigurationslogik in `FL-Config.psm1` usw.

</details>
<!-- markdownlint-enable MD033 -->

---

[...]

## 1. Dokumentation & Struktur

### 1.1. Modulare Struktur

Das Skript ist in mehrere Module unterteilt, um die Wartbarkeit und Übersichtlichkeit zu verbessern. Jedes Modul hat eine klare Zuständigkeit:

* **FL-Config.psm1:** Zentrales Modul für das Laden, Speichern und Verwalten der Konfiguration. Enthält die `Invoke-VersionControl`-Funktion.
* **FL-Gui.psm1:** Enthält alle Funktionen zur Erstellung und Verwaltung der grafischen Benutzeroberfläche (GUI). Dieses Modul sollte keine eigene Konfigurationslogik enthalten.
* **FL-Logging.psm1:** Zuständig für das Schreiben von Log-Dateien und Windows Event Log-Einträgen.
* **FL-Maintenance.psm1:** Enthält Wartungsaufgaben wie die Archivierung von Log-Dateien.
* **FL-Utils.psm1:** Sammlung allgemeiner Hilfsfunktionen, die von anderen Modulen verwendet werden.

Durch diese klare Trennung wird vermieden, dass Funktionen doppelt implementiert werden, was zu Fehlern und Inkonsistenzen führen kann.

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
    Insbesondere wird keinerlei Gewähr übernommen für die Marktgängigkeit, die Eignung für einen bestimmten Zweck
    oder die Nichtverletzung von Rechten Dritter.
    Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder Unterstützung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
    In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
    Entwicklung oder Verbreitung dieser Skripte für direkte, indirekte, zufällige, besondere oder Folgeschäden - einschließlich,
    aber nicht beschränkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
    selbst wenn sie auf die Möglichkeit solcher Schäden hingewiesen wurden.
    Durch die Nutzung der Skripte erklären Sie sich mit diesen Bedingungen einverstanden.

    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
    fitness for a particular purpose, and non-infringement.
    There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
    Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
    or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
    including but not not limited to direct, indirect, incidental, consequential, or special damages
    (such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
    By using these scripts, you agree to be bound by the above terms.

.END
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
  * **Fenstertitel:** Zeigt immer den Skriptnamen und die Version an (z.B. `SetupGUI <ScriptName> - v1.2.15`).
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

### 2.3. WhatIf-Modus und kritische Funktionen

Der WhatIf-Modus darf bestimmte kritische Funktionen nicht beeinträchtigen.

* **Nutzen:** Gewährleistet Stabilität und Zuverlässigkeit auch im Simulationsmodus.
* **Details:**
  * **Nicht betroffen:** Logging, Konfigurationsspeicherung, E-Mail-Benachrichtigungen und Archivierung werden immer ausgeführt, auch im WhatIf-Modus.
  * **Anfangszustand:** Der WhatIf-Modus darf beim ersten Start nie aktiviert sein. Er soll nur über die GUI oder eine bestehende Konfigurationsdatei aktiviert werden können.

### 2.4. Verständliche Oberfläche

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
  * **WhatIf-Unabhängigkeit:** Logging-Funktionen werden immer ausgeführt, unabhängig vom WhatIf-Modus, um eine lückenlose Nachvollziehbarkeit zu gewährleisten.

### 3.4. Automatische Archivierung

Alte Log-Dateien werden automatisch aufgeräumt.

* **Nutzen:** Verhindert, dass der Speicherplatz überfüllt wird.
* **Details:** Logs werden nach 30 Tagen komprimiert, Archive nach 90 Tagen gelöscht (konfigurierbar).
* **WhatIf-Unabhängigkeit:** Die Archivierung wird immer durchgeführt, unabhängig vom WhatIf-Modus.

## 4. Robustheit & Betriebssicherheit

### 4.1. Kritische Funktionen und WhatIf

Bestimmte Funktionen sind vom WhatIf-Modus ausgenommen, um die Betriebssicherheit zu gewährleisten.

* **Nutzen:** Sorgt für zuverlässige Protokollierung, Überwachung und Fehlerbehebung.
* **Details:**
  * **Logging:** Logeinträge werden immer geschrieben, auch im WhatIf-Modus.
  * **Konfiguration:** Das Speichern der Konfigurationsdatei wird immer durchgeführt, auch im WhatIf-Modus.
  * **E-Mail-Benachrichtigungen:** Statusmails werden immer versendet, auch im WhatIf-Modus.
  * **Archivierung:** Die Archivierung von Logs wird immer durchgeführt, auch im WhatIf-Modus.
