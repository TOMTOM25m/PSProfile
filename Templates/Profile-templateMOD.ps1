<#
.SYNOPSIS
    [DE] Eine Sammlung von Hilfsfunktionen für das PowerShell-Profil, optimiert für PS 5.1 und 7.x.
    [EN] A collection of helper functions for the PowerShell profile, optimized for PS 5.1 and 7.x.
.DESCRIPTION
    [DE] Dieses Modul enthält Hilfsfunktionen für PowerShell-Profile, die sowohl in Windows PowerShell 5.1 
         als auch in PowerShell 7+ verwendet werden können. Die Funktionen sind nach Kategorien gruppiert und 
         werden automatisch vom Hauptprofil geladen.
    [EN] This module contains helper functions for PowerShell profiles that can be used in both Windows PowerShell 5.1
         and PowerShell 7+. The functions are grouped by categories and are automatically loaded by the main profile.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.09
    Last modified:  2025.09.01
    Version:        v6.2.0
    MUW-Regelwerk:  v7.6.0
    Notes:          [DE] Header und Versionen für Konsistenz aktualisiert.
                    [EN] Updated header and versions for consistency.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
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

#region ####################### [3. Netzwerk- & Remote-Verwaltung] ######################

function Set-MUWRemoteExecution {
    <# .SYNOPSIS Aktiviert PowerShell-Remoting auf dem lokalen Computer. #>
    [CmdletBinding(SupportsShouldProcess = $true)] param()
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Aktiviere PowerShell Remoting (WinRM)")) {
        try { Enable-PSRemoting -Force -ErrorAction Stop }
        catch { Write-Error "Fehler beim Aktivieren von PSRemoting: $($_.Exception.Message)" }
    }
}

function Disconnect-MUWAllNetworkConnections {
    <# .SYNOPSIS Trennt alle verbundenen Netzlaufwerke und SMB-Freigaben. #>
    [CmdletBinding(SupportsShouldProcess = $true)] param()

    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like '\\*' } | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.Name, "Trenne Netzlaufwerk")) { Remove-PSDrive -Name $_.Name -Force }
    }

    try {
        if ($global:isModernPS) {
            Get-SmbConnection -ErrorAction SilentlyContinue | ForEach-Object {
                if ($PSCmdlet.ShouldProcess($_.ServerName, "Trenne SMB-Verbindung (PS 7+)")) {
                    Remove-SmbConnection -ServerName $_.ServerName -Force
                }
            }
        }
        else { # PS 5.1
            $connections = net use
            foreach ($line in ($connections | Where-Object { $_ -like '*\\*' })) {
                $path = ($line -split '\s+', 3)[1]
                if ($path -like '\\*') {
                    if ($PSCmdlet.ShouldProcess($path, "Trenne Netzwerkverbindung (net use)")) {
                        net use $path /delete /y | Out-Null
                    }
                }
            }
        }
    }
    catch { Write-Warning "Fehler beim Trennen von SMB-Verbindungen: $($_.Exception.Message)"}
}

#endregion

# --- End of module --- v6.2.0 ; Regelwerk: v7.6.0 ---

