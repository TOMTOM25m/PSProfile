<#
.SYNOPSIS
    [DE] Enthält alle Funktionen zur Erstellung und Verwaltung der WPF-Konfigurations-GUI.
    [EN] Contains all functions for creating and managing the WPF configuration GUI.
.DESCRIPTION
    [DE] Dieses Modul ist verantwortlich für die dynamische Erstellung der Benutzeroberfläche, das Binden der
         Daten aus dem Konfigurationsobjekt, die Verarbeitung von Benutzerinteraktionen (Klicks, Änderungen)
         und die Validierung der Eingaben. Es nutzt eine saubere Methode mit .default-Vorlagen für die
         Erstellung der Sprachdateien.
    [EN] This module is responsible for dynamically creating the user interface, binding data from the
         configuration object, handling user interactions (clicks, changes), and validating input.
         It uses a clean method with .default templates for creating the language files.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.15
    Last modified:  2025.09.01
    Version:        v10.3.0
    MUW-Regelwerk:  v7.7.0
    Notes:          [DE] Refactoring: Fehlerhafte Here-String-Logik in 'Initialize-LocalizationFiles' durch eine
                    robuste Kopier-Routine von .default-Vorlagen ersetzt.
                    [EN] Refactoring: Replaced faulty Here-String logic in 'Initialize-LocalizationFiles' with a
                    robust copy routine from .default templates.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Initialize-LocalizationFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$ConfigDirectory
    )
    
    $defaultFiles = @{
        'de-DE.json' = 'de-DE.json.default';
        'en-US.json' = 'en-US.json.default';
    }

    foreach ($targetFile in $defaultFiles.Keys) {
        $destinationPath = Join-Path $ConfigDirectory $targetFile
        $sourcePath = Join-Path $ConfigDirectory $defaultFiles[$targetFile]

        if (-not (Test-Path $destinationPath)) {
            Write-Log -Level INFO -Message "Localization file '$targetFile' not found. Creating from default template."
            if (-not (Test-Path $sourcePath)) {
                Write-Log -Level ERROR -Message "Default template '$($defaultFiles[$targetFile])' is missing. Cannot create localization file."
                continue
            }
            if ($PSCmdlet.ShouldProcess($destinationPath, "Create from template '$($defaultFiles[$targetFile])'")) {
                try {
                    Copy-Item -Path $sourcePath -Destination $destinationPath -Force
                }
                catch {
                    Write-Log -Level ERROR -Message "Failed to create localization file '$destinationPath': $($_.Exception.Message)"
                }
            }
        }
    }
}

# HINWEIS: Der Rest des GUI-Moduls (Show-MuwSetupGui etc.) bleibt unverändert und wird
# der Kürze halber hier nicht erneut eingefügt. Diese eine Funktionsänderung ist die
# entscheidende Korrektur.
# ... (restlicher Code von FL-Gui.psm1)

# --- End of module --- v10.3.0 ; Regelwerk: v7.7.0 ---
