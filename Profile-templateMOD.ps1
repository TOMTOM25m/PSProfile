<#
.SYNOPSIS
    [DE] Eine Sammlung von Hilfsfunktionen für das PowerShell-Profil, optimiert für PS 5.1 und 7.x.
    [EN] A collection of helper functions for the PowerShell profile, optimized for PS 5.1 and 7.x.
.DESCRIPTION
    [DE] Dieses Modul enthält Hilfsfunktionen für PowerShell-Profile, die sowohl in Windows PowerShell 5.1 
         als auch in PowerShell 7+ verwendet werden können. Die Funktionen sind nach Kategorien gruppiert und 
         werden automatisch vom Hauptprofil geladen. Funktionen mit versionsspezifischer Implementierung 
         erkennen automatisch die laufende PowerShell-Version.
    [EN] This module contains helper functions for PowerShell profiles that can be used in both Windows PowerShell 5.1
         and PowerShell 7+. The functions are grouped by categories and are automatically loaded by the main profile.
         Functions with version-specific implementation automatically detect the running PowerShell version.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.09
    Last modified:  2025.08.05
    old Version:    v5.0.0
    Version now:    v6.0.0
    MUW-Regelwerk:  v6.6.6
    Notes:          [DE] Refactoring: Funktionen in explizite PS5.1/PS7.x-Versionen aufgeteilt, um der Regel strikt zu folgen.
                    [EN] Refactoring: Functions split into explicit PS5.1/PS7.x versions to strictly follow the rule.
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

#region ####################### [1. PowerShell- & System-Verwaltung] #######################

function Get-MUWNextFreeDriveLetter {
    <# .SYNOPSIS Findet den nächsten freien Laufwerksbuchstaben von D bis Z. #>
    'D'..'Z' | ForEach-Object { if ($_ -notin (Get-PSDrive -PSProvider FileSystem).Name) { return $_ } }
    throw 'Kein freier Laufwerksbuchstabe von D-Z gefunden.'
}

function Update-MUWPowerShell {
    <# .SYNOPSIS Installiert oder aktualisiert PowerShell 7. #>
    [CmdletBinding()] param ([Switch]$Preview)
    try {
        $uri = 'https://aka.ms/install-powershell.ps1'
        $scriptContent = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        $params = @{ UseMSI = $true; EnablePSRemoting = $true; AddExplorerContextMenu = $true }
        if ($Preview) { $params.Add('Preview', $true) }
        & ([scriptblock]::Create($scriptContent)) @params
    } catch { Write-Error "Fehler beim Ausführen des PowerShell-Installationsskripts: $($_.Exception.Message)" }
}

#endregion

#region ####################### [2. Anwendungs- & Feature-Verwaltung] #####################

function Connect-MUWExchangeShell {
    <# .SYNOPSIS Stellt eine Verbindung zur lokalen Exchange Management Shell her (nur PS 5.1). #>
    if ($global:isModernPS) {
        Write-Warning "Diese Funktion ist nur für Windows PowerShell 5.1 mit installierten Exchange Management Tools vorgesehen."
        return
    }
    try {
        if ((Get-Service -Name 'MSExchangeTransport' -ErrorAction Stop).Status -eq 'Running') {
            Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction Stop
            . (Join-Path -Path $env:ExchangeInstallPath -ChildPath 'bin\RemoteExchange.ps1')
            Connect-ExchangeServer -Auto -ClientApplication:ManagementShell -ErrorAction Stop
        }
    } catch { Write-Warning "Verbindung zur Exchange Shell nicht möglich: $($_.Exception.Message)" }
}

function Install-MUWWindowsFeature {
    <# .SYNOPSIS Installiert ein Windows-Feature (erfordert 'ServerManager' Modul). #>
    [CmdletBinding(SupportsShouldProcess = $true)] param ([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Module -ListAvailable -Name ServerManager)) { Write-Error "Das 'ServerManager' Modul wird benötigt und wurde nicht gefunden."; return }
    try {
        $feature = Get-WindowsFeature $Name -ErrorAction Stop
        if ($feature.Installed) { Write-Host "Feature '$Name' ist bereits installiert."; return }
        if ($PSCmdlet.ShouldProcess($Name, "Installiere Windows Feature")) {
            Install-WindowsFeature -Name $Name
        }
    } catch { Write-Error "Fehler bei Feature '$Name': $($_.Exception.Message)" }
}

#endregion

#region ####################### [3. Netzwerk- & Remote-Verwaltung (Versionstrennung)] ######################

function Set-MUWRemoteExecution {
    <# .SYNOPSIS Aktiviert PowerShell-Remoting auf dem lokalen Computer. #>
    [CmdletBinding(SupportsShouldProcess = $true)] param()
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Aktiviere PowerShell Remoting (WinRM)")) {
        try { Enable-PSRemoting -Force -ErrorAction Stop }
        catch { Write-Error "Fehler beim Aktivieren von PSRemoting: $($_.Exception.Message)" }
    }
}

# Private Implementierung für PowerShell 5.1
function Disconnect-MUWSmbConnection_PS5 {
    [CmdletBinding(SupportsShouldProcess = $true)] param()
    $connections = net use
    foreach ($line in ($connections | Where-Object { $_ -like '*\\*' })) {
        # Zerlegt die Zeile, um den Pfad zu extrahieren. Robustere Methode.
        $path = ($line -split '\s+', 3)[1]
        if ($path -like '\\*') {
            if ($PSCmdlet.ShouldProcess($path, "Trenne Netzwerkverbindung (net use)")) {
                net use $path /delete /y | Out-Null
            }
        }
    }
}

# Private Implementierung für PowerShell 7+
function Disconnect-MUWSmbConnection_PS7 {
    [CmdletBinding(SupportsShouldProcess = $true)] param()
    Get-SmbConnection -ErrorAction SilentlyContinue | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.ServerName, "Trenne SMB-Verbindung (PS 7+)")) {
            Remove-SmbConnection -ServerName $_.ServerName -Force
        }
    }
}

function Disconnect-MUWAllNetworkConnections {
    <# .SYNOPSIS Trennt alle verbundenen Netzlaufwerke und SMB-Freigaben. Wählt automatisch die korrekte Methode je nach PS-Version. #>
    [CmdletBinding(SupportsShouldProcess = $true)] param()

    # Netzlaufwerke trennen (funktioniert in beiden Versionen identisch)
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like '\\*' } | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, "Trenne Netzlaufwerk")) { Remove-PSDrive -Name $_.Name -Force }
    }

    # SMB-Verbindungen trennen (ruft die versionsspezifische Funktion auf)
    try {
        if ($global:isModernPS) {
            Disconnect-MUWSmbConnection_PS7
        }
        else {
            Disconnect-MUWSmbConnection_PS5
        }
    }
    catch { Write-Warning "Fehler beim Trennen von SMB-Verbindungen: $($_.Exception.Message)"}
}

#endregion

# --- End of the Script, old: v5.0.0 to now: v6.0.0  Regelwerk: v6.6.6 ---