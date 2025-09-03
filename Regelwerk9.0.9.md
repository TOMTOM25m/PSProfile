# MUW-Regelwerk für PowerShell-Skripte

**Version:** 9.0.9
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
  * **Vorlagen:** `./Templates/Profile-*.ps1` (Template-Dateien)
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
  * **Dynamischer Fenstertitel:** Der Titel muss zur Laufzeit zugewiesen werden, um Probleme mit der Variablenerweiterung in XAML-Here-Strings zu vermeiden. Erstellen Sie den Titel in einer PS-Variable und weisen Sie ihn nach dem Laden des XAML dem `$window.Title`-Property zu.
  * **Templates Tab:** Für dynamische Template-Verwaltung mit Add/Delete-Funktionalität, konfigurierbar über JSON-Konfiguration.
* **Logging:**
  * **Sprache:** Alle Log-Meldungen, die in Dateien oder das EventLog geschrieben werden, müssen auf Englisch sein.
  * **Dateinamen:** `DEV_<ScriptName>_yyyy-MM-dd.log` für Entwicklung, `PROD_<ScriptName>_yyyy-MM-dd.log` für Produktivbetrieb.
  * **Event Log:** `WARNING`- und `ERROR`-Meldungen müssen ins Windows Event Log geschrieben werden (Funktion muss per Konfiguration abschaltbar sein).
  * **WhatIf-Ausnahme:** Logging, Konfigurationsspeicherung, E-Mail-Benachrichtigungen und Archivierung werden immer ausgeführt, auch im WhatIf-Modus.
* **Mail:** `System.Net.Mail.SmtpClient` verwenden, nicht `Send-MailMessage`.
* **Archivierung:** 7-Zip bevorzugen, mit `Compress-Archive` als Fallback.
* **WhatIf-Modus:** Der WhatIf-Modus darf beim ersten Start nie aktiviert sein, er soll nur über die GUI oder eine bestehende Konfigurationsdatei aktivierbar sein.
* **Modul-Struktur:** Funktionen sollten nur in einem Modul definiert werden, um Redundanzen und Konflikte zu vermeiden. GUI-spezifische Logik gehört in `FL-Gui.psm1`, Konfigurationslogik in `FL-Config.psm1` usw.
* **Template-Management:** Templates werden im `Templates/`-Ordner verwaltet und sind über die GUI konfigurierbar. Alle Template-Pfade sind relativ zum Skript-Verzeichnis anzugeben.

</details>
<!-- markdownlint-enable MD033 -->

---

## 1. Dokumentation & Struktur

### 1.1. Modulare Struktur

Das Skript ist in mehrere Module unterteilt, um die Wartbarkeit und Übersichtlichkeit zu verbessern. Jedes Modul hat eine klare Zuständigkeit:

* **FL-Config.psm1:** Zentrales Modul für das Laden, Speichern und Verwalten der Konfiguration. Enthält die `Invoke-VersionControl`-Funktion.
* **FL-Gui.psm1:** Enthält alle Funktionen zur Erstellung und Verwaltung der grafischen Benutzeroberfläche (GUI). Dieses Modul sollte keine eigene Konfigurationslogik enthalten.
* **FL-Logging.psm1:** Zuständig für das Schreiben von Log-Dateien und Windows Event Log-Einträgen.
* **FL-Maintenance.psm1:** Enthält Wartungsaufgaben wie die Archivierung von Log-Dateien.
* **FL-Utils.psm1:** Sammlung allgemeiner Hilfsfunktionen, die von anderen Modulen verwendet werden.

Durch diese klare Trennung wird vermieden, dass Funktionen doppelt implementiert werden, was zu Fehlern und Inkonsistenzen führen kann.

### 1.2. Template-Management

**Neu in Version 9.0.9:** Templates werden in einem dedizierten `Templates/`-Ordner verwaltet und sind über die GUI vollständig konfigurierbar. Dies ermöglicht:

* **Flexible Template-Verwaltung:** Add/Delete-Funktionalität über die GUI
* **Dynamische Konfiguration:** Templates können zur Laufzeit hinzugefügt oder entfernt werden
* **Strukturierte Organisation:** Alle Templates in einem zentralen Ordner
* **Minimalistisches Design:** Einfache Add/Delete-Buttons für Benutzerfreundlichkeit

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
    MUW-Regelwerk:  v9.0.9
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
    including but not limited to direct, indirect, incidental, consequential, or special damages
    (such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
    By using these scripts, you agree to be bound by the above terms.
```

---

## 2. Konfigurationsmanagement

### 2.1. JSON-Konfigurationsdateien

Alle Konfigurationsdateien folgen dem Standard-Schema:

```json
{
  "ScriptVersion": "v10.5.0",
  "RulebookVersion": "v9.0.9",
  "Language": "en-US",
  "Environment": "DEV",
  "WhatIf": false,
  "Templates": [
    {
      "Name": "Standard Profile",
      "FilePath": "Templates\\Profile-template.ps1",
      "Enabled": true,
      "Description": "Default PowerShell profile template"
    }
  ],
  "NetworkProfiles": [
    {
      "Name": "Example Network Share",
      "Path": "\\\\server\\share",
      "Enabled": false,
      "Username": "",
      "EncryptedPassword": ""
    }
  ]
}
```

### 2.2. Template-Konfiguration

Templates werden in der Konfigurationsdatei als Array verwaltet:

* **Name:** Anzeigename des Templates
* **FilePath:** Relativer Pfad zur Template-Datei (meist im `Templates/`-Ordner)
* **Enabled:** Gibt an, ob das Template aktiv ist
* **Description:** Beschreibung des Templates

---

## 3. GUI-Design & Usability

### 3.1. WPF-Grundlagen

* **Design-Sprache:** Modernes, flaches Design mit der Primärfarbe `#111d4e`
* **Button-Anordnung:** Konsistent mit Windows-Standards (`[Abbrechen]` links, `[Anwenden]` und `[OK]` rechts)
* **Fenstertitel:** Dynamisch zur Laufzeit zuweisen, nicht in XAML-Here-Strings

### 3.2. Templates Tab

Der Templates Tab bietet folgende Funktionalität:

* **DataGrid:** Anzeige aller konfigurierten Templates mit Enabled, Name, FilePath, Description
* **Add Template:** Button zum Hinzufügen neuer Templates über einen Dialog
* **Delete Template:** Button zum Löschen ausgewählter Templates mit Bestätigung
* **Template Dialog:** Browse-Funktionalität, Validierung und Test-Möglichkeit für Templates

#### Template Dialog Funktionen

* **File Browse:** Auswahl von Template-Dateien über OpenFileDialog
* **Validation:** Überprüfung ob Template-Datei existiert und erreichbar ist
* **Test Template:** Möglichkeit das Template zu testen/validieren
* **Localization:** Vollständig lokalisierte Benutzeroberfläche

---

## 4. Lokalisierung

### 4.1. Sprachdateien

Sprachdateien müssen für alle GUI-Elemente vollständige Übersetzungen enthalten:

**Neue Template-bezogene Schlüssel (ab v9.0.9):**

```json
{
  "TabTemplates": "Templates / Vorlagen",
  "BtnAddTemplate": "Add Template / Vorlage hinzufügen",
  "BtnDeleteTemplate": "Delete Template / Vorlage löschen",
  "TemplateDialogTitle": "Template Configuration / Vorlagen-Konfiguration",
  "LblTemplateName": "Name:",
  "LblTemplateFilePath": "File Path: / Dateipfad:",
  "LblTemplateDescription": "Description: / Beschreibung:",
  "BtnTestTemplate": "Test Template / Vorlage testen",
  "MsgSelectTemplate": "Please select a template to delete. / Bitte wählen Sie eine Vorlage zum Löschen aus.",
  "MsgConfirmDeleteTemplate": "Are you sure you want to delete the template '{0}'? / Sind Sie sicher, dass Sie die Vorlage '{0}' löschen möchten?",
  "MsgTemplateDeleted": "Template '{0}' has been deleted. / Vorlage '{0}' wurde gelöscht.",
  "MsgEnterTemplateName": "Please enter a template name. / Bitte geben Sie einen Vorlagennamen ein.",
  "MsgEnterTemplateFilePath": "Please enter a template file path. / Bitte geben Sie einen Vorlagen-Dateipfad ein.",
  "MsgTemplateFileNotFound": "Template file not found: {0} / Vorlagen-Datei nicht gefunden: {0}",
  "MsgTemplateTestSuccess": "Template test successful! / Vorlagen-Test erfolgreich!",
  "MsgTemplateTestFailed": "Template test failed: {0} / Vorlagen-Test fehlgeschlagen: {0}",
  "MsgErrorAddingTemplate": "Error adding template: {0} / Fehler beim Hinzufügen der Vorlage: {0}",
  "MsgErrorDeletingTemplate": "Error deleting template: {0} / Fehler beim Löschen der Vorlage: {0}"
}
```

---

## 5. Code-Signing und EXE-Erstellung

### 5.1. Zertifikat-Management

Für die Signierung von PowerShell-Skripten und die Erstellung von EXE-Dateien:

1. **Selbstsigniertes Zertifikat erstellen:**

   ```powershell
   $cert = New-SelfSignedCertificate -Subject "CN=Flecki Garnreiter Code Signing" -Type CodeSigning -KeyUsage DigitalSignature -FriendlyName "Flecki Code Signing Certificate" -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy ExportableEncrypted -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256
   ```

2. **Zertifikat vertrauenswürdig machen:**

   ```powershell
   Export-Certificate -Cert $cert -FilePath "FleckiCodeSigning.cer"
   Import-Certificate -FilePath "FleckiCodeSigning.cer" -CertStoreLocation Cert:\LocalMachine\Root
   ```

3. **Skripte signieren:**

   ```powershell
   Set-AuthenticodeSignature -FilePath "Script.ps1" -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
   ```

### 5.2. EXE-Erstellung mit ps2exe

Installation und Verwendung von ps2exe:

```powershell
Install-Module ps2exe -Scope CurrentUser
Invoke-PS2EXE -inputFile "Reset-PowerShellProfiles.ps1" -outputFile "Reset-PowerShellProfiles.exe" -noConsole -title "PowerShell Profile Reset Tool" -description "Reset PowerShell Profiles" -company "Flecki Garnreiter" -product "PSProfile Tools" -copyright "© 2025 Flecki Garnreiter" -version "10.5.0.0"
```

**Nachträgliche Signierung der EXE:**

```powershell
Set-AuthenticodeSignature -FilePath "Reset-PowerShellProfiles.exe" -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
```

---

## 6. Best Practices

### 6.1. Template-Management

* **Ordnerstruktur:** Alle Templates im `Templates/`-Ordner
* **Relative Pfade:** Template-Pfade relativ zum Skript-Verzeichnis
* **Konfigurierbarkeit:** Templates über GUI add/delete-fähig
* **Validation:** Template-Dateien auf Existenz prüfen
* **Testing:** Möglichkeit Templates zu testen vor Verwendung

### 6.2. GUI-Entwicklung

* **Konsistenz:** Templates Tab folgt dem gleichen Muster wie NetworkProfiles Tab
* **Lokalisierung:** Alle Texte über Sprachdateien
* **Error Handling:** Umfassende Fehlerbehandlung mit lokalisierten Fehlermeldungen
* **User Experience:** Bestätigungsdialoge bei kritischen Aktionen (Delete)

### 6.3. Konfiguration

* **Default Templates:** Standardmäßig drei Templates (Standard, Extended, Modern)
* **Flexible Struktur:** Templates-Array erweiterbar
* **Backwards Compatibility:** Alte Konfigurationen migrierbar
* **Validation:** Template-Konfiguration validieren beim Laden

---

## 7. Versionsverwaltung

### 7.1. Regelwerk-Evolution

* **Version 8.0.2:** Basis mit NetworkProfiles
* **Version 9.0.9:** Template-Management hinzugefügt
  * Templates-Ordner-Struktur
  * Templates Tab in GUI
  * Template-Konfiguration in JSON
  * Lokalisierung für Template-Features
  * Template Dialog mit Browse/Test-Funktionalität

### 7.2. Upgrade-Pfad

Bei Updates müssen bestehende Konfigurationen erweitert werden:

```powershell
# Migration zu v9.0.9: Templates hinzufügen falls nicht vorhanden
if (-not $config.Templates) {
    $config.Templates = @(
        @{
            Name = "Standard Profile"
            FilePath = "Templates\Profile-template.ps1"
            Enabled = $true
            Description = "Default PowerShell profile template"
        }
    )
}
```

---

**Ende des Regelwerks v9.0.9**
© 2025 Flecki Garnreiter - Alle Rechte vorbehalten.
