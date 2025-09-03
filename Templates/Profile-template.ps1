<#
.SYNOPSIS
    [DE] Ein universelles PowerShell-Profil mit getrennten, kodierungssicheren Blöcken für PS 5.1 und PS 7+.
    [EN] A universal PowerShell profile with separate, encoding-safe blocks for PS 5.1 and PS 7+.
.DESCRIPTION
    [DE] Dieses Profil erkennt automatisch die PowerShell-Version und lädt entsprechende Blöcke für PS 5.1 bzw. PS 7+.
         Es stellt eine konsistente Benutzeroberfläche bereit, während es gleichzeitig versionsspezifische 
         Funktionen und Sicherheitseinstellungen anwendet. Das Profil kann durch Module erweitert werden.
    [EN] This profile automatically detects the PowerShell version and loads appropriate blocks for PS 5.1 or PS 7+.
         It provides a consistent user interface while applying version-specific features and security settings.
         The profile can be extended through modules.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.08
    Last modified:  2025.08.05
    old Version:    v23.0.0
    Version now:    v23.0.1
    MUW-Regelwerk:  v6.6.6
    Notes:          [DE] Security-Fix: Hartcodierte TLS-Version entfernt und auf 'SystemDefault' umgestellt (DevSkim DS440020).
                    [EN] Security fix: Removed hardcoded TLS version and switched to 'SystemDefault' (DevSkim DS440020).
    Copyright:      © 2025 Flecki Garnreiter
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
#>
#Requires -Version 5.1

# --- Idempotenz-Prüfung: Verhindert mehrfaches Laden in derselben Sitzung ---
if ($global:ProfileLoaded) { return }
$global:ProfileLoaded = $true

#region ####################### [1. Globale Initialisierung (Für alle Versionen)] #####################

$global:isAdmin = ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
$global:isModernPS = $PSVersionTable.PSVersion.Major -gt 5

$script:powershellDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
@("ProfileMOD.ps1", "profileX.ps1") | ForEach-Object {
    $profileModulePath = Join-Path -Path $script:powershellDirectory -ChildPath $_
    if (Test-Path -Path $profileModulePath -PathType Leaf) {
        try { . $profileModulePath } catch { Write-Warning "Fehler beim Laden des Moduls '$_': $($_.Exception.Message)" }
    }
}

#endregion

if ($global:isModernPS) {
    #region ####################### [2. Block für PowerShell 7+ (Modern)] #############################

    # Verbesserte Systemtyperkennung
    $osMessage = $null
    try {
        # Primärversuch mit Get-ComputerInfo, da es oft aussagekräftiger ist (z.B. 'Desktop').
        $role = (Get-ComputerInfo).PowerPlatformRole.ToString()
        if ($role -in @('Desktop', 'Workstation', 'Mobile')) { $osMessage = "Workstation" }
        elseif ($role -like '*Server*') { $osMessage = "Server" }
    } catch { /* Fehler hier sind nicht kritisch, da der Fallback genutzt wird. */ }

    if ([string]::IsNullOrEmpty($osMessage)) {
        # Fallback auf die klassische WMI-Abfrage, falls Get-ComputerInfo nicht zum Ziel führt.
        $productTypeMap = @{ 1 = "Workstation"; 2 = "Domänencontroller"; 3 = "Server" }
        $osMessage = $productTypeMap[(Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).ProductType]
    }

    if ([string]::IsNullOrEmpty($osMessage)) {
        $osMessage = "unbekannten"
    }
    $Host.UI.WriteLine("Modernes Profil (v23.0.1) auf einem $($osMessage)-System gestartet.")
    if ($global:isAdmin) { $Host.UI.WriteLine("Sitzung läuft mit erhöhten Rechten (Administrator).") }

    function global:prompt {
        if ($?) { Write-Host "✔ " -NoNewline -ForegroundColor Green } else { Write-Host "✘ " -NoNewline -ForegroundColor Red }

        $history = Get-History -Count 1
        if ($history -and $history.StartExecutionTime -and $history.EndExecutionTime) {
            $execTime = $history.EndExecutionTime - $history.StartExecutionTime
            $timeString = "{0:mm}:{0:ss}.{1:d3}" -f $execTime, $execTime.Milliseconds
            Write-Host "[$timeString] " -NoNewline -ForegroundColor White
        }

        Write-Host "$(Get-Location) " -NoNewline -ForegroundColor Yellow
        $userColor = if ($global:isAdmin) { "Red" } else { "Cyan" }
        $userText = if ($global:isAdmin) { "[$($env:USERNAME)@Admin]" } else { "[$($env:USERNAME)]" }
        Write-Host "$userText " -NoNewline -ForegroundColor $userColor

        return "> "
    }

    #endregion
}
else {
    #region ####################### [3. Block für Windows PowerShell 5.1 (Legacy & Encoding-Safe)] ####################

    # Stellt sicher, dass die Konsolenausgabe UTF-8-kodiert ist, um Sonderzeichen korrekt darzustellen.
    $OutputEncoding = [System.Text.UTF8Encoding]::new()

    if ($global:isAdmin) {
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319', 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' | ForEach-Object {
            if (-not (Test-Path $_)) { try { New-Item -Path $_ -Force -ErrorAction Stop | Out-Null } catch { return } }
            Set-ItemProperty -Path $_ -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SystemDefault # DevSkim: ignore DS440020, DS440000
        }
        catch {
            Write-Warning "System-Standard-Sicherheitsprotokolle konnten nicht gesetzt werden. Web-Anfragen könnten fehlschlagen."
        }
    }
    
    Write-Host "Legacy Profil (v23.0.1) für PowerShell 5.1 geladen."

    function global:prompt {
        if ($?) { Write-Host "OK " -NoNewline -ForegroundColor Green } else { Write-Host "X " -NoNewline -ForegroundColor Red }

        $history = Get-History -Count 1
        if ($history -and $history.StartExecutionTime -and $history.EndExecutionTime) {
            $execTime = $history.EndExecutionTime - $history.StartExecutionTime
            $timeString = "{0:mm}:{0:ss}.{1:d3}" -f $execTime, $execTime.Milliseconds
            Write-Host "[$timeString] " -NoNewline
        }

        Write-Host "$(Get-Location) " -NoNewline -ForegroundColor Yellow
        $userColor = if ($global:isAdmin) { "Red" } else { "Cyan" }
        $userText = if ($global:isAdmin) { "[$($env:USERNAME)@Admin]" } else { "[$($env:USERNAME)]" }
        Write-Host "$userText " -NoNewline -ForegroundColor $userColor

        return "> "
    }

    #endregion
}

#region ####################### [4. Aufräumen (Für alle Versionen)] ###########################

Remove-Variable -Name 'script:*' -ErrorAction SilentlyContinue

#endregion

# --- End of the Script, old: v23.0.0 to now: v23.0.1  Regelwerk: v6.6.6 ---

