# **MUW-Regelwerk**  **Standard für die MUW PowerShell-Skripte v6.6.6 © Flecki Garnreiter**

## **Allgemein**

### **Allgemeine Vorgaben**

* **Kodierung:** Für alle Skript- und Konfigurationsdateien ist die Kodierung UTF-8 zu verwenden.  
* **Administratorrechte:** Skripte müssen einen Mechanismus zur Selbst-Erhöhung (\`Self-Elevation\`) enthalten.  
* **PowerShell-Version:** Der Code muss die laufende PowerShell-Version erkennen und entsprechend versionsspezifische Funktionen verwenden.  
* **Pfad-Validierung:** In der Konfiguration definierte Pfade müssen beim Skriptstart überprüft und bei Bedarf automatisch erstellt werden.  
* **Script-Normungen:** Die Konventionen des PSScriptAnalyzer (z. B. Verb-Noun) sind anzuwenden.  
* **Initialisierungslogik:** Das Skript muss prüfen, ob eine Konfigurationsdatei existiert und valides JSON enthält. Andernfalls startet die SetupGUI.

### **Datums- und Versionsformat**

* **Datum:** Das Datumsformat yyyy.MM.dd ist zu verwenden.  
* **Versionierung:** Das Schema ist vX.Y.Z (Major.Minor.Patch).  
* **Automatik:** Die Versionierung wird bei jeder Skriptausgabe durch den Entwicklungsassistenten konsistent gehalten.

### **Corporate Design & Layout**

* **Logo / Icon:** Logos/Icons werden aus einem konfigurierbaren Pfad geladen. Bei Erst-Einrichtung werden sie vom Standard-UNC-Pfad in ein lokales Images\-Verzeichnis kopiert.  
* **Farbgebung:** Primäre UI-Elemente verwenden \#111d4e (Dunkelblau) mit weißer Schrift.  
* **Button-Struktur:** Die untere Button-Leiste enthält Abbrechen (linksbündig) sowie Anwenden und OK (rechtsbündig).  
* **Fenstertitel:** Muss dynamisch sein: SetupGUI \<ScriptName\> - vX.Y.Z.

## **Konfiguration**

### **ConfigFile**

* **Verortung** Alle `.json` Dateien werden in einem `Config`-Ordner gespeichern,
                bzw. die schon vorhandenen `.json` Datein werden vom scriptroot da hinein kopieren und dann wenn alles oke ist im scriptroot dann gelöschen
* **Externalisierung:** Alle Parameter müssen in eine `config-\<ScriptName\>.json\`-Datei ausgelagert werden.  
* **Dateiname:** Der Name wird dynamisch vom Base-Skriptname abgeleitet.  
* **Versions-Abgleich:** Das Skript vergleicht seine Version mit der in der Config-Datei und warnt bei Abweichungen.  
* **Parameter \-Versionscontrol:** Gleicht die Config-Datei mit dem Skript ab und aktualisiert sie.  
* **Regelwerk-Version:** Die Version des Regelwerks ist in der Config-Datei zu hinterlegen.

### **Entwicklungsumgebung (Environment),WhatIf Mode und den  Produktivbetrieb (Production)**

* **Definition:** ein Switch (SetupGUI) egt fest, ob das Skript in `DEV` oder `PROD` Betrieb läuft.
                  es gibt einen Switch (SetupGUI) mit `PRODEmpänger` und `DEVEmpänger` . dieser bestimmt welche E-Mailadresse gegenommen wird ,  im Tab `E-Mail` dind die beiden Adresse hinterlegt. es können pro definition (`PRODEmpänger` oder `DEVEmpänger`) mehrere Mailadresse getrennt mit `;` hinterlegt werden.
* **Steuerung:** Die Auswahl erfolgt über die `SetupGUI`.

## **GUI**

### **Tab Allgemein (SetupGUI)**

#### **Switch DEV**

Das Sript schreibt alles im verbose mode und debugmode in ein Logfile  im LogVerzeichnis `DEBUG_\<scriptName\>.log`
Der DebugMode legt den Mailversand und die Empfänger der E-Mail fest

#### **Switch PROD**

jeglicher debug Mode, Whatif mode oder Verbose Mode wird ausgeschaltet. es beginnt der Produktiv Modus.
der Debugmode legt den mailversand und die Empfänger der E-Mail fest

#### **Switch WhatIf**

**WICHTIG** bitte den DEV-Modus und den whatIf Modus der functions scharf schalten damit das logfile alle fehler auffängt...
**Ausgenommen** das Logsystem und der Mailversand sind NICHT mit `whatif` auszustatten

### **SetupGUI-Funktionalität (SetupGUI)**

* **Technologie:** WPF.  
* **Aufruflogik:** Startet automatisch bei fehlender/fehlerhafter Config oder manuell via \-Setup.
* **TABS** Zwingend notwendige Tabs im SetupGUI: Allgemein, Pfade,Backup, E-Mail
*          bitte in der Setupgui mehr Anleitungen auf der SetupGUI anzeigen

### **WorkGUIGUI-Funktionalität (WorkGUI)**

* **Technologie:** WPF.  
* **Aufruflogik:** Startet automatisch wenn es seiten des Scripts notwendig ist

### **Benutzerfreundlichkeit (Usability)**

* **Pfad-Auswahl:** Alle Pfad-Eingabefelder müssen einen \`Durchsuchen...\`-Button haben.  
* **Sprachauswahl & Lokalisierung:** Über externe de-DE.json und en-US.json Dateien.  
* **Erst-Einrichtung:** Die GUI muss eine Starthilfe bieten (Standardwerte, Beispiel-Einträge).  
* **Blockierende Operationen:** Der Benutzer muss durch eine Dialogbox informiert werden, wenn die GUI vorübergehend nicht reagiert.

### **Tab Pfad (SetupGUI)**

* **Pfade** auf diesen Tab sollen alle Pfade angegeben werden.
* **Pfad-Auswahl:** Alle Pfad-Eingabefelder müssen einen \`Durchsuchen...\`-Button haben.  

## **Weitere Funktions-Regeln**

* **Logging:** Log-Meldungen müssen **ausschließlich auf Englisch** sein.  
* **Windows Event Log:** ERROR und WARNING müssen ins Event Log geschrieben werden; dies muss über EnableEventLog: true/false deaktivierbar sein.  
* **Archivierung:** Logs werden nach 30 Tagen komprimiert, Archive nach 90 Tagen gelöscht.  
* **Mailversand:** Erfolgt über .NET (System.Net.Mail.SmtpClient) nach einem Test-NetConnection.

## **Skript-Struktur**

### **Header (ISO/IEC/IEEE 26512/DIN)**

Muss exakt folgendes Format haben:

\<\#  
.SYNOPSIS  
\[DE\] Kurzbeschreibung der Skriptfunktion.
\[EN\] Brief Description of Script Functionality
.DESCRIPTION  
\[DE\] Ausführliche Beschreibung inkl. Parameter, Voraussetzungen etc.
\[EN\] Detailed Description incl. Parameters, Requirements, etc.
.PARAMETER ParameterName
\[DE\] Beschreibung mit Datentyp und Pflichtangabe.
\[EN\] Description including data type and requirement status.
.PARAMETER ...  
.EXAMPLE  
    \.\<ScriptName\>.ps1 -Parameter1 "Wert"\...
    \[DE\] ...  
    \[EN\] ...  
.NOTES  
    Author:         Flecki (Tom) Garnreiter  
    Created on:     yyyy.MM.dd  
    Last modified:  yyyy.MM.dd  
    old Version:    vX.Y.Z  
    Version now:    vX.Y.Z  
    MUW-Regelwerk:  vX.Y.Z  
    Notes:          \[DE\] ...  
                    \[EN\] ...  
    Copyright:      © 2025 Flecki Garnreiter  
.DISCLAIMER  
\[DE\] Die bereitgestellten Skripte und die zugehörige Dokumentation werden "wie besehen" ("as is")
ohne ausdrückliche oder stillschweigende Gewährleistung jeglicher Art zur Verfügung gestellt.
Insbesondere wird keinerlei Gewähr übernommen für die Marktgängigkeit, die Eignung für einen bestimmten Zweck
oder die Nichtverletzung von Rechten Dritter.
Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder Unterstützung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
Entwicklung oder Verbreitung dieser Skripte für direkte, indirekte, zufällige, besondere oder Folgeschäden - einschließlich,
aber nicht beschränkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
selbst wenn sie auf die Möglichkeit solcher Schäden hingewiesen wurden.
Durch die Nutzung der Skripte erklären Sie sich mit diesen Bedingungen einverstanden.

\[EN\] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
fitness for a particular purpose, and non-infringement.
There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
including but not limited to direct, indirect, incidental, consequential, or special damages
(such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
By using these scripts, you agree to be bound by the above terms.
\#>

### **ScriptEnd**

**Der Kommentar am Ende \!\!\!\! Wichtig**

Jedes Skript muss mit einem statischen Kommentar enden, der die aktuellen Versionen widerspiegelt: das ist sehr wichtig für die Entwicklung des Scriptes

 \ #--- End of Script old: vX.Y.Z ; now: vX.Y.Z ; Regelwerk: vX.Y.Z---\#
