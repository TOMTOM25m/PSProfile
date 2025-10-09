#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertSurv Test Deployment - Excel Server Auswahl v1.0.0

.DESCRIPTION
    Testet Deployment mit spezifischen Servern aus der Excel-Serverliste.
    Verwendet WSUS oder uvwmgmt01 für initiale Tests.

.PARAMETER ServerName
    Servername zum Testen (WSUS, uvwmgmt01, oder benutzerdefiniert)

.PARAMETER TestOnly
    Nur Test-Modus, kein echtes Deployment

.VERSION
    1.0.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("WSUS", "uvwmgmt01", "Both", "Custom")]
    [string]$ServerName = "WSUS",
    
    [Parameter(Mandatory = $false)]
    [string]$CustomServer = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "CertSurv Test Deployment - Excel Server Selection" -Version "v1.0.0 | Regelwerk: v10.1.0" -Color Cyan

# Konfiguration
$Config = @{
    ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx"
    NetworkSharePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
    
    # Test-Server Mapping
    TestServers = @{
        WSUS = @{
            Name = "WSUS"
            FQDN = "wsus.meduniwien.ac.at"
            SearchPattern = "WSUS"
            Description = "Windows Server Update Services Server"
        }
        uvwmgmt01 = @{
            Name = "uvwmgmt01"
            FQDN = "uvwmgmt01.uvw.meduniwien.ac.at"
            SearchPattern = "uvwmgmt01"
            Description = "UVW Management Server 01"
        }
    }
    
    # CertWebService Settings
    Port = 9080
    UseSSL = $false
}

#region Excel Helper Functions

function Get-ServerFromExcel {
    param(
        [string]$ExcelPath,
        [string]$SearchPattern
    )
    
    Write-VersionSpecificHost "Searching Excel for server: $SearchPattern" -IconType 'file' -ForegroundColor Yellow
    
    try {
        # Excel COM Object erstellen
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        # Workbook öffnen
        if (-not (Test-Path $ExcelPath)) {
            throw "Excel-Datei nicht gefunden: $ExcelPath"
        }
        
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        $Worksheet = $Workbook.Worksheets.Item(1)  # Erstes Worksheet
        
        # Nach Server suchen
        $lastRow = $Worksheet.UsedRange.Rows.Count
        $serverFound = $null
        
        Write-Host "  Durchsuche $lastRow Zeilen..." -ForegroundColor Gray
        
        # Header-Zeile analysieren für Subdomain-Spalte
        $subdomainColumn = -1
        for ($col = 1; $col -le 20; $col++) {
            $headerValue = $Worksheet.Cells.Item(1, $col).Text
            if ($headerValue -match "Domain|Subdomain|Domäne") {
                $subdomainColumn = $col
                Write-Host "  Subdomain-Spalte gefunden: Spalte $col ($headerValue)" -ForegroundColor Gray
                break
            }
        }
        
        for ($row = 2; $row -le $lastRow; $row++) {
            $cellValue = $Worksheet.Cells.Item($row, 1).Text  # Spalte A (Server-Namen)
            
            if ($cellValue -match $SearchPattern) {
                $serverFound = @{
                    Name = $cellValue
                    IP = $Worksheet.Cells.Item($row, 2).Text
                    Row = $row
                    Status = $Worksheet.Cells.Item($row, 3).Text
                    Domain = $null
                    Subdomain = $null
                }
                
                # Subdomain extrahieren (falls Spalte gefunden)
                if ($subdomainColumn -gt 0) {
                    $domainValue = $Worksheet.Cells.Item($row, $subdomainColumn).Text
                    $serverFound.Domain = $domainValue
                    
                    # Subdomain aus "Domain (UVW)" oder "UVW" Format extrahieren
                    if ($domainValue -match '\(([^)]+)\)') {
                        $serverFound.Subdomain = $matches[1].Trim()
                    } elseif ($domainValue -match '^([A-Z]+)$') {
                        $serverFound.Subdomain = $domainValue.Trim()
                    }
                }
                
                # Fallback: Subdomain aus FQDN extrahieren
                if (-not $serverFound.Subdomain -and $cellValue -match '\.([a-z]+)\.') {
                    $serverFound.Subdomain = $matches[1].ToUpper()
                }
                
                Write-VersionSpecificHost "Server gefunden in Zeile $row!" -IconType 'success' -ForegroundColor Green
                if ($serverFound.Subdomain) {
                    Write-Host "  Subdomain: $($serverFound.Subdomain)" -ForegroundColor Cyan
                }
                break
            }
        }
        
        # Cleanup
        $Workbook.Close($false)
        $Excel.Quit()
        
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
        [System.GC]::Collect()
        
        return $serverFound
        
    } catch {
        Write-VersionSpecificHost "Excel-Suche fehlgeschlagen: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
        
        # Cleanup bei Fehler
        if ($Excel) {
            try { $Excel.Quit() } catch { }
        }
        
        return $null
    }
}

function Test-ServerPreDeployment {
    param(
        [string]$ServerName,
        [hashtable]$ServerInfo = $null,
        [System.Management.Automation.PSCredential]$Credential = $null
    )
    
    Write-VersionSpecificHost "Pre-Deployment Check für $ServerName" -IconType 'shield' -ForegroundColor Cyan
    
    $checks = @{
        Server = $ServerName
        Ping = $false
        SMB = $false
        AdminShare = $false
        AdminShareMethod = "Unknown"
        PSRemoting = $false
        Port9080 = $false
        CertWebServiceInstalled = $false
        CredentialUsed = "None"
        Domain = $null
        Subdomain = $null
        Recommendation = "Unknown"
    }
    
    # Server-Info extrahieren (Domain/Subdomain)
    if ($ServerInfo) {
        $checks.Domain = $ServerInfo.Domain
        $checks.Subdomain = $ServerInfo.Subdomain
        
        if ($ServerInfo.Subdomain) {
            Write-Host "  Server-Domain: $($ServerInfo.Subdomain)" -ForegroundColor Cyan
        }
    }
    
    try {
        # 1. Ping Test
        Write-Host "  [1/6] Ping Test..." -ForegroundColor Gray
        $checks.Ping = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        if ($checks.Ping) {
            Write-Host "    [OK] Server erreichbar" -ForegroundColor Green
        } else {
            Write-Host "    [ERROR] Server nicht erreichbar" -ForegroundColor Red
            $checks.Recommendation = "Server offline oder Name nicht auflösbar"
            return $checks
        }
        
        # 2. SMB Test mit Credential-Fallback
        Write-Host "  [2/6] SMB Share Test (mit Credential-Fallback)..." -ForegroundColor Gray
        try {
            $adminShare = "\\$ServerName\C$"
            
            # Methode 1: Ohne Credentials (Current User)
            Write-Host "    [2a] Test ohne Credentials (Current User)..." -ForegroundColor Gray
            $checks.AdminShare = Test-Path $adminShare -ErrorAction SilentlyContinue
            
            if ($checks.AdminShare) {
                $checks.SMB = $true
                $checks.AdminShareMethod = "Current User"
                $checks.CredentialUsed = "Current User ($env:USERNAME)"
                Write-Host "    [OK] Admin-Share erreichbar (Current User)" -ForegroundColor Green
            } else {
                Write-Host "    [INFO] Current User hat keinen Zugriff" -ForegroundColor Yellow
                
                # Credential-Strategie basierend auf Server-Domain
                $credentialOptions = @()
                
                # Computer-Kurzname extrahieren
                $computerShortName = $ServerName.Split('.')[0]
                
                # Option 1: Subdomain aus Excel (z.B. UVW\Administrator)
                if ($checks.Subdomain) {
                    $credentialOptions += @{
                        Username = "$($checks.Subdomain)\Administrator"
                        Description = "Subdomain Administrator (aus Excel)"
                    }
                }
                
                # Option 2: Local Administrator (ComputerName\Administrator)
                $credentialOptions += @{
                    Username = "$computerShortName\Administrator"
                    Description = "Local Administrator"
                }
                
                # Option 3: Subdomain aus FQDN (falls nicht aus Excel)
                if (-not $checks.Subdomain -and $ServerName -match '\.([a-z]+)\.') {
                    $fqdnSubdomain = $matches[1].ToUpper()
                    $credentialOptions += @{
                        Username = "$fqdnSubdomain\Administrator"
                        Description = "Subdomain Administrator (aus FQDN)"
                    }
                }
                
                # Alle Credential-Optionen durchprobieren
                $credentialTested = $false
                foreach ($credOption in $credentialOptions) {
                    if ($checks.SMB) { break }  # Bereits erfolgreich
                    
                    Write-Host "    [2b] Test mit $($credOption.Description): $($credOption.Username)..." -ForegroundColor Gray
                    
                    try {
                        # Credentials anfordern (wenn noch nicht vorhanden)
                        if (-not $Credential -or $credentialTested) {
                            Write-Host "    [INFO] Requesting credentials for $($credOption.Username)..." -ForegroundColor Yellow
                            $Credential = Get-Credential -UserName $credOption.Username -Message "Administrator credentials for $ServerName`n$($credOption.Description)"
                        }
                        $credentialTested = $true
                        
                        # Credentials testen mit New-PSDrive
                        $driveLetter = "TestDrive$(Get-Random -Minimum 100 -Maximum 999)"
                        $drive = New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $adminShare -Credential $Credential -ErrorAction Stop
                        
                        if ($drive) {
                            $checks.AdminShare = $true
                            $checks.SMB = $true
                            $checks.AdminShareMethod = $credOption.Description
                            $checks.CredentialUsed = $credOption.Username
                            Write-Host "    [OK] Admin-Share erreichbar ($($credOption.Description))" -ForegroundColor Green
                            
                            # Cleanup
                            Remove-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
                        }
                    } catch {
                        Write-Host "    [WARN] $($credOption.Description) Zugriff fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
                        $Credential = $null  # Reset für nächsten Versuch
                    }
                }
                
                # Fallback: SMB Connectivity ohne Admin-Share
                if (-not $checks.SMB) {
                    Write-Host "    [2c] Test SMB-Konnektivität (Port 445)..." -ForegroundColor Gray
                    try {
                        $tcpClient = New-Object System.Net.Sockets.TcpClient
                        $connect = $tcpClient.BeginConnect($ServerName, 445, $null, $null)
                        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
                        
                        if ($wait) {
                            $tcpClient.EndConnect($connect)
                            Write-Host "    [INFO] Port 445 (SMB) erreichbar - Credentials könnten helfen" -ForegroundColor Yellow
                        } else {
                            Write-Host "    [WARN] Port 445 (SMB) nicht erreichbar" -ForegroundColor Yellow
                        }
                        $tcpClient.Close()
                    } catch {
                        Write-Host "    [WARN] SMB-Port 445 nicht erreichbar" -ForegroundColor Yellow
                    }
                    
                    $checks.AdminShareMethod = "Failed - All methods"
                }
            }
            
        } catch {
            Write-Host "    [ERROR] SMB-Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # 3. PSRemoting Test
        Write-Host "  [3/6] PSRemoting Test..." -ForegroundColor Gray
        try {
            # DevSkim: ignore DS104456 - Required for PSRemoting test
            $testResult = Invoke-Command -ComputerName $ServerName -ScriptBlock { $env:COMPUTERNAME } -ErrorAction SilentlyContinue
            $checks.PSRemoting = ($testResult -eq $ServerName)
            
            if ($checks.PSRemoting) {
                Write-Host "    [OK] PSRemoting verfügbar" -ForegroundColor Green
            } else {
                Write-Host "    [WARN] PSRemoting nicht verfügbar" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [WARN] PSRemoting-Test fehlgeschlagen" -ForegroundColor Yellow
        }
        
        # 4. Port 9080 Test (CertWebService - HTTP ohne SSL)
        Write-Host "  [4/6] Port 9080 Test (HTTP)..." -ForegroundColor Gray
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ServerName, 9080, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
            
            if ($wait) {
                $tcpClient.EndConnect($connect)
                $checks.Port9080 = $true
                Write-Host "    [INFO] Port 9080 bereits offen (CertWebService installiert?)" -ForegroundColor Yellow
            } else {
                Write-Host "    [OK] Port 9080 geschlossen (erwartetes Verhalten)" -ForegroundColor Green
            }
            $tcpClient.Close()
        } catch {
            Write-Host "    [OK] Port 9080 geschlossen" -ForegroundColor Green
        }
        
        # 5. CertWebService Installation Check (HTTP ohne SSL)
        Write-Host "  [5/6] CertWebService Check (HTTP)..." -ForegroundColor Gray
        if ($checks.Port9080) {
            try {
                # DevSkim: ignore DS137138 - HTTP used intentionally (no SSL yet)
                $response = Invoke-WebRequest -Uri "http://${ServerName}:9080/certificates" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                
                if ($response.StatusCode -eq 200) {
                    $checks.CertWebServiceInstalled = $true
                    $certData = $response.Content | ConvertFrom-Json
                    $certCount = ($certData | Measure-Object).Count
                    Write-Host "    [INFO] CertWebService BEREITS INSTALLIERT ($certCount Zertifikate)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "    [OK] CertWebService nicht installiert" -ForegroundColor Green
            }
        } else {
            Write-Host "    [OK] CertWebService nicht installiert" -ForegroundColor Green
        }
        
        # 6. Deployment-Empfehlung
        Write-Host "  [6/6] Deployment-Empfehlung..." -ForegroundColor Gray
        if ($checks.CertWebServiceInstalled) {
            $checks.Recommendation = "Update - CertWebService bereits installiert"
        } elseif ($checks.PSRemoting) {
            $checks.Recommendation = "PSRemoting Deployment (schnellste Methode)"
        } elseif ($checks.SMB) {
            $checks.Recommendation = "Network Share Deployment (SMB)"
        } else {
            $checks.Recommendation = "Manual Package erforderlich"
        }
        
        Write-Host "    Empfehlung: $($checks.Recommendation)" -ForegroundColor Cyan
        
    } catch {
        Write-Host "    [ERROR] Pre-Deployment Check fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        $checks.Recommendation = "Fehler - Manuelle Überprüfung erforderlich"
    }
    
    return $checks
}

#endregion

#region Main Execution

try {
    Write-Host ""
    
    # Server-Auswahl
    $targetServers = @()
    
    switch ($ServerName) {
        "WSUS" {
            Write-VersionSpecificHost "Test-Server: WSUS (Windows Server Update Services)" -IconType 'target' -ForegroundColor Cyan
            $targetServers += $Config.TestServers.WSUS.FQDN
        }
        "uvwmgmt01" {
            Write-VersionSpecificHost "Test-Server: uvwmgmt01 (UVW Management Server)" -IconType 'target' -ForegroundColor Cyan
            $targetServers += $Config.TestServers.uvwmgmt01.FQDN
        }
        "Both" {
            Write-VersionSpecificHost "Test-Server: Beide (WSUS + uvwmgmt01)" -IconType 'target' -ForegroundColor Cyan
            $targetServers += $Config.TestServers.WSUS.FQDN
            $targetServers += $Config.TestServers.uvwmgmt01.FQDN
        }
        "Custom" {
            if ($CustomServer) {
                Write-VersionSpecificHost "Test-Server: Custom ($CustomServer)" -IconType 'target' -ForegroundColor Cyan
                $targetServers += $CustomServer
            } else {
                Write-VersionSpecificHost "ERROR: Custom server name required with -CustomServer parameter" -IconType 'error' -ForegroundColor Red
                exit 1
            }
        }
    }
    
    Write-Host ""
    
    # Excel-Suche für Server-Info (Domain/Subdomain)
    Write-VersionSpecificHost "Checking Excel for server information..." -IconType 'file' -ForegroundColor Yellow
    Write-Host ""
    
    $serverInfoMap = @{}
    foreach ($server in $targetServers) {
        $excelInfo = Get-ServerFromExcel -ExcelPath $Config.ExcelPath -SearchPattern $server.Split('.')[0]
        
        if ($excelInfo) {
            $serverInfoMap[$server] = $excelInfo
            
            Write-Host "  $server - Excel Info:" -ForegroundColor Cyan
            Write-Host "    Name: $($excelInfo.Name)" -ForegroundColor Gray
            Write-Host "    IP: $($excelInfo.IP)" -ForegroundColor Gray
            Write-Host "    Status: $($excelInfo.Status)" -ForegroundColor Gray
            
            if ($excelInfo.Domain) {
                Write-Host "    Domain: $($excelInfo.Domain)" -ForegroundColor Gray
            }
            if ($excelInfo.Subdomain) {
                Write-Host "    Subdomain: $($excelInfo.Subdomain) (wird für Credentials verwendet)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  $server - Server nicht in Excel gefunden (oder Excel nicht erreichbar)" -ForegroundColor Yellow
            Write-Host "    Verwende Fallback: FQDN-Analyse für Subdomain" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Pre-Deployment Checks
    Write-VersionSpecificHost "Running Pre-Deployment Checks..." -IconType 'shield' -ForegroundColor Cyan
    Write-Host ""
    
    $checkResults = @()
    foreach ($server in $targetServers) {
        $serverInfo = $serverInfoMap[$server]
        $result = Test-ServerPreDeployment -ServerName $server -ServerInfo $serverInfo
        $checkResults += $result
        Write-Host ""
    }
    
    # Zusammenfassung
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  PRE-DEPLOYMENT CHECK SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($result in $checkResults) {
        Write-Host "$($result.Server):" -ForegroundColor White
        if ($result.Subdomain) {
            Write-Host "  Domain: $($result.Subdomain)" -ForegroundColor Cyan
        }
        Write-Host "  Ping: $($result.Ping)" -ForegroundColor $(if($result.Ping){'Green'}else{'Red'})
        Write-Host "  SMB Share: $($result.SMB) ($($result.AdminShareMethod))" -ForegroundColor $(if($result.SMB){'Green'}else{'Yellow'})
        Write-Host "  Credentials: $($result.CredentialUsed)" -ForegroundColor Gray
        Write-Host "  PSRemoting: $($result.PSRemoting)" -ForegroundColor $(if($result.PSRemoting){'Green'}else{'Yellow'})
        Write-Host "  Port 9080: $(if($result.Port9080){'Open'}else{'Closed'})" -ForegroundColor $(if($result.Port9080){'Yellow'}else{'Green'})
        Write-Host "  CertWebService: $(if($result.CertWebServiceInstalled){'Installed'}else{'Not Installed'})" -ForegroundColor $(if($result.CertWebServiceInstalled){'Yellow'}else{'Green'})
        Write-Host "  Recommendation: $($result.Recommendation)" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Deployment-Entscheidung
    if ($TestOnly) {
        Write-VersionSpecificHost "TEST MODE - No deployment will be performed" -IconType 'warning' -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To perform actual deployment, run without -TestOnly parameter" -ForegroundColor Gray
        exit 0
    }
    
    # Bestätigung für echtes Deployment
    Write-Host "Ready to deploy CertWebService to:" -ForegroundColor Yellow
    foreach ($server in $targetServers) {
        Write-Host "  - $server" -ForegroundColor White
    }
    Write-Host ""
    
    $confirm = Read-Host "Continue with deployment? (Y/N)"
    
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-VersionSpecificHost "Deployment cancelled by user." -IconType 'warning' -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host ""
    Write-Host "Requesting administrator credentials..." -ForegroundColor Yellow
    $creds = Get-Credential -Message "Administrator credentials for server deployment"
    
    # Deployment ausführen
    Write-Host ""
    Write-VersionSpecificHost "Starting deployment via Update-AllServers-Hybrid..." -IconType 'rocket' -ForegroundColor Cyan
    Write-Host ""
    
    .\Update-AllServers-Hybrid-v2.5.ps1 `
        -ServerList $targetServers `
        -NetworkSharePath $Config.NetworkSharePath `
        -AdminCredential $creds `
        -GenerateReports `
        -Verbose
    
    Write-Host ""
    Write-VersionSpecificHost "Deployment completed!" -IconType 'party' -ForegroundColor Green
    
    # Post-Deployment Verification
    Write-Host ""
    Write-VersionSpecificHost "Running Post-Deployment Verification..." -IconType 'shield' -ForegroundColor Cyan
    Write-Host ""
    
    Start-Sleep -Seconds 5  # Warten bis Service gestartet ist
    
    .\Monitor-CertSurv-Infrastructure.ps1 -Servers $targetServers -Detailed
    
} catch {
    Write-VersionSpecificHost "Deployment failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}

#endregion

