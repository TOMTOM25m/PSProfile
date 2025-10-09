# MUW-Regelwerk (Standard für die MUW PowerShell-Skripte v6.1.0 (C) Flecki Garnreiter)

## Allgemein

### Allgemeine Vorgaben

- **Kodierung:** Für alle Skript- und Konfigurationsdateien ist die optimalste Kodierung der Powershell-Version zu verwenden um Probleme mit Umlauten zu vermeiden. (Wichtig )
- **Administratorrechte:** Skripte, die administrative Rechte benötigen, müssen einen Mechanismus zur Selbst-Erhöhung ("Self-Elevation") enthalten, falls sie nicht bereits als Administrator gestartet wurden.
- **PowerShell-Version:** Bevorzugt ist die automatische Auswahl der PowerShell Version `PS.X`. Der Code muss jede Powershellversion erkennen und dem entsprechnde `PS5.1` oder `PS7.x` "functions" verwenden. In einer `ConfigGUI` soll die Zielversion auswählbar sein (Standard: `PS.X`,1; `PS 7.x` 2; `PS 5.1`).
- **Pfad-Validierung:** Pfade, in die das Skript schreiben soll (z.B. für Logs oder Reports oder Logos und andere) und die in der Konfiguration definiert sind, müssen beim Skriptstart überprüft und bei Nicht-Existenz automatisch erstellt werden.
- **Scriptnormungen:** Es sind die Konventionen des `PSScriptAnalyzer` zwingend anzuwenden (z.B. `Verb-Noun` für Funktionen), um Warnungen zu vermeiden.
- **Initialisierungslogik verbessern:** Das Skript prüft nun nicht mehr nur, ob eine Konfigurationsdatei existiert, sondern auch, ob sie die notwendigen Einträge enthält. Ist dies nicht der Fall, wird die `ConfigGUI` korrekt gestartet.

### Konfiguration (`ConfigFile`)

- **Externalisierung:** Alle externen Parameter (Pfade, Formate, Farb-Codes, Server etc.) müssen in eine `.json`-Konfigurationsdatei ausgelagert werden.
- **Dateiname & Pfad:** Der Name soll dem Muster `config-<ScriptName>.json` folgen. Der Pfad zur Datei wird mit dem `-ConfigFile` Parameter übergeben, mit einem Fallback auf das Skriptverzeichnis.
- **Versions-Abgleich:** Das Skript sollte beim Start seine eigene Version (aus dem Header) mit der Version in der Konfigurationsdatei vergleichen. Bei Abweichungen ist eine deutliche Warnung auszugeben, um auf mögliche Inkompatibilitäten hinzuweisen.
- kannst du mir den Parameter `-Versionscontrol` einführen, das automatisch das CONFIG-FIle abgleicht mit dem laufenden script .. bitte die Differenzen anzeigen und das config-file aktualisieren zur aktuellen version .
- Bitte auch die Version der MUW-regeln im Configfile hinterlegen zum abgleichen.

### Diagnose (`DebugMode`)

- **Implementierung:** Ein `DebugMode` muss implementiert sein, der eine extrem detaillierte Protokollierung zur Analyse des Skriptablaufs ermöglicht. Dies schließt die Ausgabe von Variablenzuständen, detaillierten Schritten und erweiterten Fehlermeldungen mit ein.
- **Steuerung:** Der Modus wird über einen `True`/`False`-Switch in der `config.json` gesteuert. Der Standardwert ist `true`.
- **Zweck:** Dient **ausschließlich der Steuerung der Protokolltiefe** (z. B. durch `Write-Log -Level DEBUG`). Diese Einstellung beeinflusst keine anderen Skriptfunktionen oder -verhalten.

### Umgebung (`Environment`)

- **Definition:** Legt fest, ob das Skript in der **Entwicklungs- (`DEV`)** oder **Produktionsumgebung (`PROD`)** läuft. Dies ist die primäre Einstellung, um das Verhalten des Skripts zu steuern.
- **Steuerung:** Die Auswahl erfolgt über die `config.json` und muss in der `ConfigGUI` einstellbar sein.
- **Funktionsunterschiede:** Die `Environment`-Einstellung steuert das Verhalten des Skripts. Beispiele hierfür sind:
  - **Mailversand:** Im `DEV`-Modus werden Mails an den Entwickler, im `PROD`-Modus an den produktiven Verteiler gesendet.
  - **Server-Pfade:** Es können unterschiedliche Zielsysteme oder Datenbanken für `DEV` und `PROD` verwendet werden.
  - **Workflow-Optimierung:** Der `DEV`-Modus kann den Entwicklungs-Workflow aktiv unterstützen, z.B. durch das automatische Öffnen eines Dateiauswahl-Dialogs anstelle eines kompletten Verzeichnis-Scans bei Skriptstart.

### Datums- und Versionsformat

- **Datum:** Das Datumsformat `yyyy.MM.dd` ist für alle Anzeigen und Log-Einträge zu verwenden.
- **Versionierung:** Das Schema ist `vXX.YY.ZZ` (z.B. `v01.02.05`).
  - `vXX`: Hauptversion. Wird bei grossen, inkompatiblen Änderungen manuell erhöht.
  - `YY`: Minor-Version. Wird bei neuen Features oder grösseren funktionalen Änderungen erhöht.
  - `ZZ`: Patch-Version. Wird bei Bugfixes und kleineren Optimierungen erhöht.
  - **Automatik:** Die Version soll bei jedem Scriptausgabe durch dich erfolgen. denn du musst den überblick behalten. überall wo eine Versionierung auftaucht.

### GUI-Funktionalität (`ConfigGUI`)

- **Technologie:** Die GUI ist als modaler Dialog mit WPF zu realisieren.
- **Aufruflogik:**
  - **Wichtig:** Falls beim Skriptstart **keine** oder eine **fehlerhafte/korrupte** Konfigurationsdatei gefunden wird, startet die `ConfigGUI` automatisch zur Ersteinrichtung.
  - Eine bestehende Konfiguration kann jederzeit durch Aufruf des Skripts mit dem Parameter `-Setup` bearbeitet werden.

### Corporate Design & Layout

- **Logo / Icon:** Logos und Icons werden aus einem konfigurierbaren Pfad (`LogoPath`) der ConfigGUI geladen, der sowohl lokale Pfade als auch UNC-Pfade unterstützen muss. Der Zugriff auf die Logos und Icons, sollen immer lokal sein. Existiert bei jeden Setupaufruf eine der Dateien nicht, wird diese von den defaultwerten (Standard-Logo, Standard-Icon) in das Unterverzeichnis `Images` heruntergeladen und es wird eine Warnung ausgegeben, ohne dass das Skript abstürzt.
Der Zugriff auf die Dateien erfolgt immer local aus dem Unterverzeichnis `Images`

  - Standard-Logo: `\\itscmgmt03.srv.meduniwien.ac.at\iso\MUWLogo\MedUniWien_logo.png`
  - Standard-Icon: `\\itscmgmt03.srv.meduniwien.ac.at\iso\MUWLogo\MedUniWien_logo.ico`

- **Farbgebung:** Ausgewählte Reiter und primäre Buttons verwenden das offizielle Dunkelblau: `#111d4e`. Die Schriftfarbe wird zur Gewährleistung der Lesbarkeit auf Weiss invertiert.
- **Hover-Effekte:** Interaktive Elemente wie der primäre "OK"-Button müssen einen klaren Hover-Effekt haben.
- **Button-Struktur:** Die untere Button-Leiste sollte standardmässig die Buttons `Abbrechen` (linksbündig) sowie `Anwenden` und `OK` (rechtsbündig) enthalten.
- **Fenstertitel:** Muss dynamisch den Skriptnamen und die Version (die, die aktuelle Version widerspiegelt) anzeigen: `ConfigGUI <ScriptName> - vXX.YY.ZZ`

### Benutzerfreundlichkeit (Usability)

- **Pfad-Auswahl:** Alle Eingabefelder für Pfade müssen einen "Durchsuchen..."-Button besitzen, der einen passenden Datei- (`OpenFileDialog`) oder Verzeichnis-Auswahldialog (`FolderBrowserDialog`) öffnet.
- **Sprachauswahl:** Texte müssen mindestens auf Deutsch und Englisch verfügbar sein. Die Sprachauswahl erfolgt über die GUI und wird in der Konfiguration gespeichert. Standard ist `EN`.
- **Fortschrittsanzeige:** Bei länger andauernden, blockierenden Operationen (> 2-3 Sekunden), wie dem Laden der GUI, ist dem Benutzer mittels `Write-Progress` ein visuelles Feedback zu geben.
- **Steuerelemente:** Für sich gegenseitig ausschliessende Optionen sind `RadioButtons` anstelle mehrerer `CheckBoxes` zu verwenden, um die Auswahl eindeutig zu machen.

---

## Weitere Funktions-Regeln

### Passwörter

- **Sicherheit:** Passwörter dürfen nicht im Klartext in der Konfigurationsdatei gespeichert werden (ausser die unten genannte Ausnahme). Wo immer möglich, ist die Nutzung des Windows Credential Managers anzuwenden.
- **Ausnahme:** Das SMTP-Passwort kann aus Kompatibilitätsgründen eigenständig (z.B. Base64-kodiert) in der Konfigurationsdatei verbleiben. WICHTIG !!!

### Logging und Reporting

- **Log-Level:** `INFO`, `WARNING`, `ERROR`, `DEBUG`.
- **Konsolenausgabe:** Farbig strukturiert je nach Log-Level.
- **Pfade:** Die Pfade für Log-Dateien (`LOG`), Reporte (`REPORTS`)oder Bilder (`IMAGES`) müssen in der Konfiguration einstellbar sein.
             alle konfigurierbaren Pfade müssen in den `Pfade-Tab` der ConfigGUI
- **Dienste/Services** alle benötigten Services müssen in den `Dienste-Tab` der ConfigGUI
-- **Windows Event Log Integration:** Um eine zentrale Überwachung und die Integration in Standard-Monitoring-Tools (z.B. SIEM) zu gewährleisten, müssen wichtige Skript-Ereignisse (insbesondere `ERROR` und `WARNING`) auch in das Windows-Ereignisprotokoll geschrieben werden. Hierfür sollte eine dedizierte Ereignisquelle (Event Source) für das Skript registriert werden, um die Einträge eindeutig zuordnen zu können.

### Archivierung

- **Log-Rotation:** Logs älter als 30 Tage werden zu einem Monats-Archiv (`<ScriptName>_JAHR_MONAT.zip`) komprimiert und danach gelöscht.
- **Archiv-Bereinigung:** ZIP-Archive älter als 90 Tage werden gelöscht.
- **Zeiträume:** Alle Zeiträume (30/90 Tage) sind in der Konfiguration einstellbar.
- **Komprimierung:** Bevorzugt wird 7-Zip (Pfad konfigurierbar). Falls nicht vorhanden, wird der Standard-Windows-Befehl `Compress-Archive` als Fallback genutzt.

### Mailversand

- **Technologie:** Der Versand erfolgt ausschliesslich über `.NET` (`System.Net.Mail.SmtpClient`). `Send-MailMessage` ist unzulässig.
- **Erreichbarkeits-Prüfung:** Vor dem Sendeversuch ist die Erreichbarkeit des SMTP-Servers zu prüfen (z.B. mittels `Test-NetConnection`). Bei Nichterreichbarkeit wird dies als Warnung behandelt (kein Fehler) und eine konfigurierbare Fallback-Aktion (z.B. Anzeige des Reports in einem Fenster) wird ausgeführt.
- **Konfigurierbarkeit:** Alle Parameter (Absender, Empfänger für `DEV`/`PROD`, Server, Port, SSL, Credentials) sind über die GUI und Konfigurationsdatei konfigurierbar.

### Powershell-Versionen

Für jede Powershell Version eine eigene parallele Versionsstruktur (eigene "PS5.1" Funktion und "PS7.x" Funktion) um inkompatibilitäten zu vermeiden . Automatische Funktionsauswahl je nach Version beim start des scriptes.

---

## Skript-Struktur

### Header (ISO/IEC/IEEE 26512/DIN)

Das Skript muss einen Header im folgenden Format enthalten:
Der folgende dienstrechtlicher Disclaimer ist verpflichtend in den Header aufzunehmen: WICHTIG !!!

´´´
`<#
.SYNOPSIS
    [DE] Kurzbeschreibung der Skriptfunktion.
    [EN] Brief Description of Script Functionality

.DESCRIPTION
    [DE] Ausführliche Beschreibung inkl. Parameter, Voraussetzungen etc.
    [EN] Detailed Description incl. Parameters, Requirements, etc.

.PARAMETER ParameterName
    [DE] Beschreibung mit Datentyp und Pflichtangabe.
    [EN] Description including data type and requirement status.

.EXAMPLE
    .\<ScriptName>.ps1 -Parameter1 "Wert"
    [DE] Beschreibung des Beispiels.
    [EN] Description of the example.

.NOTES
    Author: Flecki (Tom) Garnreiter
    Created on:       yyyy.MM.dd
    Last modified:    yyyy.MM.dd
    Version:        vXX.YY.ZZ
    MUW-Regelwerk:  vX.Y.Z
    Notes:  [DE] Hinweise, Einschränkungen, bekannte Fehler.
            [EN] Notes, Limitations, Known Issues.
    Copyright: (c) Flecki Garnreiter

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
`#>
´´´

### Befehle am Ende

bitte IMMER die alte UND die neue Script-Versionsnummer anzeigen am Ende des scripts und immer in unserer Konversation am Anfang und am Ende.
bitte auch die Versionsnummer vom MUW Regelwerk mit einbauen.
bitte immer das vollständige Script am Schluss ausgeben und anzeigen damit man das Script kopieren kann nach VSCode.

## Der Kommentar am Ende !!!! Wichtig

Jedes Skript muss mit einem statischen Kommentar enden, der die aktuelle Versionen widerspiegelt:

`# --- End of the Script, old: vXX.YY.ZZ to now: vXX.YY.ZZ  Regelwerk: v.X.Y.Z---`
