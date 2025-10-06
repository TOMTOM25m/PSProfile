#Requires -Version 5.1

<#
.SYNOPSIS
CertWebService Path Manager - Zentrale Pfadverwaltung
.DESCRIPTION
L?dt alle Pfade aus der zentralen Config-CertWebService.json und stellt sie allen Scripts zur Verf?gung
Regelwerk v10.0.2 konform | Stand: 02.10.2025
.EXAMPLE
$Config = Get-CertWebServiceConfig
Write-Host "Base Directory: $($Config.Paths.BaseDirectory)"
#>

function Get-CertWebServiceConfig {
    [CmdletBinding()]
    param()
    
    try {
        # Finde die Config-Datei relativ zum Script-Pfad
        $configPath = Join-Path $PSScriptRoot "Config\Config-CertWebService.json"
        
        if (-not (Test-Path $configPath)) {
            throw "Config-Datei nicht gefunden: $configPath"
        }
        
        # Lade und parse JSON
        $configContent = Get-Content $configPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        
        # Konvertiere Pfade zu absoluten Pfaden
        $basePath = $config.Paths.BaseDirectory
        
        # Erweitere relative Pfade zu absoluten Pfaden
        $config.Paths | Get-Member -MemberType NoteProperty | ForEach-Object {
            $propertyName = $_.Name
            $propertyValue = $config.Paths.$propertyName
            
            # Pr?fe ob es ein relativer Pfad ist (ohne :\ )
            if ($propertyValue -and $propertyValue -notmatch "^[A-Za-z]:" -and $propertyValue -notmatch "^\\\\") {
                $config.Paths.$propertyName = Join-Path $basePath $propertyValue
            }
        }
        
        return $config
    }
    catch {
        Write-Error "Fehler beim Laden der Konfiguration: $($_.Exception.Message)"
        return $null
    }
}

function Get-CertWebServicePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PathName
    )
    
    $config = Get-CertWebServiceConfig
    if (-not $config) {
        return $null
    }
    
    # Pr?fe Paths-Sektion
    if ($config.Paths.$PathName) {
        return $config.Paths.$PathName
    }
    
    # Pr?fe Scripts-Sektion
    if ($config.Scripts.$PathName) {
        return Join-Path $config.Paths.BaseDirectory $config.Scripts.$PathName
    }
    
    # Pr?fe Files-Sektion
    if ($config.Files.$PathName) {
        return Join-Path $config.Paths.BaseDirectory $config.Files.$PathName
    }
    
    Write-Warning "Pfad '$PathName' nicht in Konfiguration gefunden"
    return $null
}

function Test-CertWebServicePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PathName
    )
    
    $path = Get-CertWebServicePath -PathName $PathName
    if (-not $path) {
        return $false
    }
    
    return Test-Path $path
}

function Initialize-CertWebServiceDirectories {
    [CmdletBinding()]
    param()
    
    $config = Get-CertWebServiceConfig
    if (-not $config) {
        return $false
    }
    
    $directories = @(
        $config.Paths.LogDirectory,
        $config.Paths.ScriptsDirectory,
        $config.Paths.DocumentationDirectory,
        $config.Paths.DeploymentDirectory,
        $config.Paths.ArchiveDirectory
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Host " Verzeichnis erstellt: $dir" -ForegroundColor Green
            }
            catch {
                Write-Error "Fehler beim Erstellen von $dir : $($_.Exception.Message)"
                return $false
            }
        }
    }
    
    return $true
}

# Export f?r andere Scripts
Export-ModuleMember -Function Get-CertWebServiceConfig, Get-CertWebServicePath, Test-CertWebServicePath, Initialize-CertWebServiceDirectories

# Wenn direkt ausgef?hrt, zeige Konfiguration
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "=== CERTWEBSERVICE PFAD-MANAGER ===" -ForegroundColor Green
    Write-Host "Regelwerk v10.0.2 | Stand: 02.10.2025" -ForegroundColor Gray
    Write-Host ""
    
    $config = Get-CertWebServiceConfig
    if ($config) {
        Write-Host " Konfiguration erfolgreich geladen" -ForegroundColor Green
        Write-Host ""
        Write-Host "ZENTRALE PFADE:" -ForegroundColor Cyan
        $config.Paths | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $value = $config.Paths.$name
            Write-Host "  $name : $value" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "SCRIPT-PFADE:" -ForegroundColor Cyan
        $config.Scripts | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name
            $value = $config.Scripts.$name
            Write-Host "  $name : $value" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Verzeichnisse werden initialisiert..." -ForegroundColor Yellow
        Initialize-CertWebServiceDirectories
        
        Write-Host ""
        Write-Host " Pfad-Manager bereit!" -ForegroundColor Green
    }
}
