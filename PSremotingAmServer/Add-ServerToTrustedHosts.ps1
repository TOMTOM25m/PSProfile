#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Add-ServerToTrustedHosts - Fuegt Server zu TrustedHosts hinzu v1.0.0
    
.DESCRIPTION
    Fuegt einen oder mehrere Server zu den lokalen TrustedHosts hinzu,
    damit PSRemoting-Verbindungen funktionieren.
    
.PARAMETER ComputerName
    Server-Name(n) die hinzugefuegt werden sollen
    
.PARAMETER ShowCurrent
    Zeigt nur die aktuellen TrustedHosts an
    
.EXAMPLE
    .\Add-ServerToTrustedHosts.ps1 -ComputerName "EVAEXTEST01.srv.meduniwien.ac.at"
    
.EXAMPLE
    .\Add-ServerToTrustedHosts.ps1 -ComputerName "SERVER01","SERVER02","SERVER03"
    
.EXAMPLE
    .\Add-ServerToTrustedHosts.ps1 -ShowCurrent
    
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Created on:     2025-10-07
    Regelwerk:      v10.0.3
    
    WICHTIG: Dieses Script erweitert TrustedHosts auf dem MANAGEMENT-Server
    (z.B. ITSC020 oder ITSCMGMT03), NICHT auf den Ziel-Servern!
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName,
    
    [switch]$ShowCurrent = $false
)

# ==========================================
# Functions
# ==========================================

function Get-CurrentTrustedHosts {
    try {
        $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction Stop
        return $trustedHosts.Value
    } catch {
        return ""
    }
}

function Add-ToTrustedHosts {
    param(
        [string[]]$Servers
    )
    
    try {
        $current = Get-CurrentTrustedHosts
        
        # Parse current TrustedHosts
        $currentList = @()
        if ($current -and $current -ne "") {
            $currentList = $current -split ',' | ForEach-Object { $_.Trim() }
        }
        
        # Fuege neue Server hinzu (nur wenn noch nicht vorhanden)
        $added = @()
        $skipped = @()
        
        foreach ($server in $Servers) {
            if ($currentList -contains $server) {
                $skipped += $server
                Write-Host "  [SKIP] $server (bereits vorhanden)" -ForegroundColor Gray
            } else {
                $currentList += $server
                $added += $server
                Write-Host "  [ADD] $server" -ForegroundColor Green
            }
        }
        
        # Update TrustedHosts
        if ($added.Count -gt 0) {
            $newValue = $currentList -join ','
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newValue -Force
            
            Write-Host ""
            Write-Host "[SUCCESS] TrustedHosts aktualisiert!" -ForegroundColor Green
            Write-Host "  Hinzugefuegt: $($added.Count) Server" -ForegroundColor White
            if ($skipped.Count -gt 0) {
                Write-Host "  Uebersprungen: $($skipped.Count) Server" -ForegroundColor Gray
            }
            
            return $true
        } else {
            Write-Host ""
            Write-Host "[INFO] Keine Aenderungen notwendig - alle Server bereits in TrustedHosts" -ForegroundColor Cyan
            return $false
        }
        
    } catch {
        Write-Host ""
        Write-Host "[ERROR] Fehler beim Aktualisieren der TrustedHosts:" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ==========================================
# Main
# ==========================================

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Add-ServerToTrustedHosts v1.0.0" -ForegroundColor Cyan
Write-Host "  Erweitert TrustedHosts auf Management-Server" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Admin-Rechte pruefen
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] Administrator-Rechte erforderlich!" -ForegroundColor Red
    Write-Host "Bitte als Administrator ausfuehren." -ForegroundColor Yellow
    exit 1
}

# Aktuelle TrustedHosts anzeigen
Write-Host "AKTUELLE TRUSTEDHOSTS:" -ForegroundColor Yellow
$current = Get-CurrentTrustedHosts

if ($current -and $current -ne "") {
    $currentList = $current -split ',' | ForEach-Object { $_.Trim() }
    foreach ($hostItem in $currentList) {
        Write-Host "  - $hostItem" -ForegroundColor White
    }
} else {
    Write-Host "  <keine konfiguriert>" -ForegroundColor Gray
}

Write-Host ""

# Wenn nur anzeigen
if ($ShowCurrent) {
    Write-Host "=====================================================================" -ForegroundColor Cyan
    exit 0
}

# Server hinzufuegen
if (-not $ComputerName -or $ComputerName.Count -eq 0) {
    Write-Host "[ERROR] Keine Server angegeben!" -ForegroundColor Red
    Write-Host ""
    Write-Host "VERWENDUNG:" -ForegroundColor Yellow
    Write-Host "  .\Add-ServerToTrustedHosts.ps1 -ComputerName 'SERVER01.domain.com'" -ForegroundColor White
    Write-Host ""
    Write-Host "  .\Add-ServerToTrustedHosts.ps1 -ComputerName 'SERVER01','SERVER02'" -ForegroundColor White
    Write-Host ""
    Write-Host "  .\Add-ServerToTrustedHosts.ps1 -ShowCurrent" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "SERVER HINZUFUEGEN:" -ForegroundColor Yellow
$success = Add-ToTrustedHosts -Servers $ComputerName

if ($success) {
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "NEUE TRUSTEDHOSTS:" -ForegroundColor Yellow
    $newCurrent = Get-CurrentTrustedHosts
    $newList = $newCurrent -split ',' | ForEach-Object { $_.Trim() }
    foreach ($hostItem in $newList) {
        if ($ComputerName -contains $hostItem) {
            Write-Host "  + $hostItem" -ForegroundColor Green
        } else {
            Write-Host "  - $hostItem" -ForegroundColor White
        }
    }
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NAECHSTER SCHRITT - Verbindung testen:" -ForegroundColor Yellow
    Write-Host "  Test-WSMan -ComputerName '$($ComputerName[0])'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Oder direkt verbinden:" -ForegroundColor Yellow
    Write-Host "  `$cred = Get-Credential" -ForegroundColor Cyan
    Write-Host "  Enter-PSSession -ComputerName '$($ComputerName[0])' -Credential `$cred" -ForegroundColor Cyan
    Write-Host ""
}
