# Dokumentation für `Reset-PowerShellProfiles.ps1`

**Version:** `v09.03.00`

---

## Übersicht (Synopsis)

Dieses Skript setzt alle PowerShell-Profile auf einen Standard zurück, versioniert Vorlagen und verwaltet die gesamte Konfiguration über eine grafische Benutzeroberfläche (GUI).

This script resets all PowerShell profiles to a standard, versions templates, and manages the configuration via a GUI.

---

## Beschreibung (Description)

Ein vollumfängliches Verwaltungsskript für PowerShell-Profile gemäss MUW-Regeln. Es erzwingt Administratorrechte, stellt die UTF-8-Kodierung sicher und bietet eine WPF-basierte GUI (-Setup) zur Konfiguration. Bei fehlender oder korrupter Konfiguration startet die GUI automatisch. Das Skript führt eine Versionskontrolle der Konfiguration durch, versioniert die Profil-Vorlagen, schreibt in das Windows Event Log und beinhaltet eine voll funktionsfähige Log-Archivierung sowie einen Mail-Versand.

A comprehensive management script for PowerShell profiles according to MUW rules. It enforces administrator rights, ensures UTF-8 encoding, and provides a WPF-based GUI (-Setup) for configuration. The GUI starts automatically if the configuration is missing or corrupt. The script performs version control of the configuration, versions the profile templates, writes to the Windows Event Log, and includes fully functional log archiving and mail sending.

---

## Parameter

### `-Setup`

*   **Typ:** Switch
*   **Beschreibung:** Startet die WPF-Konfigurations-GUI, um die Einstellungen zu bearbeiten.
    (Starts the WPF configuration GUI to edit the settings.)

### `-Versionscontrol`

*   **Typ:** Switch
*   **Beschreibung:** Prüft die Konfigurationsdatei gegen die Skript-Version, zeigt Unterschiede an und aktualisiert sie bei Bedarf.
    (Checks the configuration file against the script version, displays differences, and updates it.)

### `-ConfigFile`

*   **Typ:** String
*   **Beschreibung:** Pfad zur JSON-Konfigurationsdatei. Wird dieser Parameter nicht angegeben, wird der Standardpfad `Config\Config-Reset-PowerShellProfiles.ps1.json` im Skriptverzeichnis verwendet.
    (Path to the JSON configuration file. Default: `Config\Config-Reset-PowerShellProfiles.ps1.json` in the script directory.)

---

## Beispiele (Examples)

### Beispiel 1: Standardausführung

```powershell
.\Reset-PowerShellProfiles.ps1
```
*Führt das Skript aus. Setzt die Profile zurück und fordert bei Bedarf Admin-Rechte an. Startet die GUI bei Erstkonfiguration.*

### Beispiel 2: Konfigurationsoberfläche starten

```powershell
.\Reset-PowerShellProfiles.ps1 -Setup
```
*Öffnet die Konfigurations-GUI, um die aktuellen Einstellungen zu ändern.*

---

## Notizen & Versionierung (Notes)

*   **Author:** Flecki (Tom) Garnreiter
*   **Created on:** 2025.07.11
*   **Last modified:** 2025.08.29
*   **Current Version:** `v09.03.00` (Previous: `v09.02.00`)
*   **Ruleset Version:** `v7.2.0`
*   **License:** MIT License
*   **Copyright:** © 2025 Flecki Garnreiter

---

*Dieses Dokument wurde automatisch aus dem Skript-Header generiert.*