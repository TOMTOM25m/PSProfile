<#
.SYNOPSIS
    [DE] Verbindet dynamisch definierte Netzlaufwerke beim Start des Profils.
    [EN] Dynamically connects defined network drives on profile startup.
.DESCRIPTION
    [DE] Diese Erweiterung fÃ¼r das PowerShell-Profil verbindet beim Start automatisch definierte 
         Netzlaufwerke. Die Liste der zu verbindenden Pfade wird dynamisch vom Reset-PowerShellProfiles.ps1 
         Skript befÃ¼llt. Die Verbindungslogik ist fÃ¼r PS 5.1 und PS 7+ optimiert und verwendet jeweils 
         die beste verfÃ¼gbare Methode fÃ¼r die jeweilige PowerShell-Version.
    [EN] This extension for the PowerShell profile automatically connects defined network drives at startup.
         The list of paths to connect is dynamically populated by the Reset-PowerShellProfiles.ps1 script.
         The connection logic is optimized for PS 5.1 and PS 7+ and uses the best available method for 
         each PowerShell version.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.09
    Last modified:  2025.08.05
    old Version:    v5.0.1
    Version now:    v6.0.0
    MUW-Regelwerk:  v6.6.6
    Notes:          [DE] Refactoring: Logik in explizite PS5.1/PS7.x-Funktionen aufgeteilt.
                    [EN] Refactoring: Logic split into explicit PS5.1/PS7.x functions.
    Copyright:      Â© 2025 Flecki Garnreiter
.DISCLAIMER
    [DE] Die bereitgestellten Skripte und die zugehÃ¶rige Dokumentation werden "wie besehen" ("as is")
    ohne ausdrÃ¼ckliche oder stillschweigende GewÃ¤hrleistung jeglicher Art zur VerfÃ¼gung gestellt.
    Insbesondere wird keinerlei GewÃ¤hr Ã¼bernommen fÃ¼r die MarktgÃ¤ngigkeit, die Eignung fÃ¼r einen bestimmten Zweck
    oder die Nichtverletzung von Rechten Dritter.
    Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder UnterstÃ¼tzung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
    In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
    Entwicklung oder Verbreitung dieser Skripte fÃ¼r direkte, indirekte, zufÃ¤llige, besondere oder FolgeschÃ¤den - einschlieÃŸlich,
    aber nicht beschrÃ¤nkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
    selbst wenn sie auf die MÃ¶glichkeit solcher SchÃ¤den hingewiesen wurden.
    Durch die Nutzung der Skripte erklÃ¤ren Sie sich mit diesen Bedingungen einverstanden.

    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
    fitness for a particular purpose, and non-infringement.
    There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
    Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
    or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
    including but not not limited to direct, indirect, incidental, consequential, or special damages
    (such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
    By using these scripts, you agree to be bound by the above terms.
#>

# Die folgende Liste wird dynamisch vom Reset-PowerShellProfiles.ps1 Skript befÃ¼llt.
$networkPaths = @()

# Gemeinsame Logik fÃ¼r beide Versionen
function Connect-MUWDriveInternal {
    param($path)
    try {
        $driveLetter = Get-MUWNextFreeDriveLetter
        New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $path -ErrorAction Stop
        
        $successMessage = "  -> '{0}' erfolgreich als Laufwerk '{1}:' verbunden." -f $path, $driveLetter
        Write-Host $successMessage -ForegroundColor Green
    }
    catch {
        if ($_.Exception.GetBaseException().Message -like '*Zugriff wurde verweigert*') {
            try {
                Write-Warning ("Zugriff auf '{0}' verweigert. Bitte Anmeldeinformationen eingeben." -f $path)
                $credential = Get-Credential -Message ("Anmeldeinformationen fÃ¼r '{0}' eingeben" -f $path)
                $driveLetter = Get-MUWNextFreeDriveLetter
                New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $path -Credential $credential -ErrorAction Stop
                
                $credSuccessMessage = "  -> '{0}' erfolgreich als Laufwerk '{1}:' mit neuen Anmeldeinformationen verbunden." -f $path, $driveLetter
                Write-Host $credSuccessMessage -ForegroundColor Green
            }
            catch { Write-Warning ("Verbindung zu '{0}' fehlgeschlagen: {1}" -f $path, $_.Exception.Message) }
        }
        else { Write-Warning ("Allgemeiner Fehler beim Verbinden von '{0}': {1}" -f $path, $_.Exception.Message) }
    }
}

# Implementierung fÃ¼r PowerShell 5.1
function Connect-MUWDrive_PS5 {
    param($path)
    Connect-MUWDriveInternal -path $path
}

# Implementierung fÃ¼r PowerShell 7+
function Connect-MUWDrive_PS7 {
    param($path)
    Write-Host ("Versuche, '{0}' zu verbinden..." -f $path) -ForegroundColor Yellow
    Connect-MUWDriveInternal -path $path
}

# Haupt-Logik: Ruft die korrekte Funktion basierend auf der PS-Version auf
foreach ($path in $networkPaths) {
    if ([string]::IsNullOrWhiteSpace($path)) { continue }
    if (Test-Path -Path $path -PathType Container -ErrorAction SilentlyContinue) { continue }
    
    if ($global:isModernPS) {
        Connect-MUWDrive_PS7 -path $path
    }
    else {
        Connect-MUWDrive_PS5 -path $path
    }
}

# --- End of the Script, old: v5.0.1 to now: v6.0.0  Regelwerk: v6.6.6 ---




