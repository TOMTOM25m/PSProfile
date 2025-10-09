#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    Update CertSurv Server List from Excel v1.0.0

.DESCRIPTION
    Liest die Serverliste2025.xlsx und aktualisiert die ServerList.txt
    für CertSurv Scanner.

.PARAMETER ExcelPath
    Pfad zur Excel-Serverliste

.PARAMETER TargetServer
    Zielserver (Standard: ITSCMGMT03.srv.meduniwien.ac.at)

.PARAMETER TargetPath
    Pfad zur ServerList.txt auf dem Zielserver

.PARAMETER Credential
    Admin-Credentials

.PARAMETER Filter
    Filter für Server (z.B. "srv.meduniwien.ac.at")

.VERSION
    1.0.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$TargetServer = "ITSCMGMT03.srv.meduniwien.ac.at",
    
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "C:\CertSurv\Config\ServerList.txt",
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [string]$Filter = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowPreview
)

# Import Compatibility Module
Import-Module ".\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force

Write-VersionSpecificHeader "Update CertSurv Server List from Excel" -Version "v1.0.0 | Regelwerk: v10.1.0" -Color Cyan

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Excel Source: $ExcelPath" -ForegroundColor Gray
Write-Host "  Target Server: $TargetServer" -ForegroundColor Gray
Write-Host "  Target File: $TargetPath" -ForegroundColor Gray
if ($Filter) {
    Write-Host "  Filter: $Filter" -ForegroundColor Yellow
}
Write-Host ""

#region Functions

function Get-ServersFromExcel {
    param(
        [string]$ExcelPath,
        [string]$FilterString = ""
    )
    
    Write-VersionSpecificHost "Reading Excel server list with block structure..." -IconType 'file' -ForegroundColor Cyan
    
    $serverList = @()
    $blockStats = @{}
    
    try {
        # Excel COM Object
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        
        # Workbook öffnen
        if (-not (Test-Path $ExcelPath)) {
            throw "Excel file not found: $ExcelPath"
        }
        
        Write-Host "  Opening: $ExcelPath" -ForegroundColor Gray
        
        $Workbook = $Excel.Workbooks.Open($ExcelPath)
        $Worksheet = $Workbook.Worksheets.Item(1)
        
        # Analyse Header
        $lastRow = $Worksheet.UsedRange.Rows.Count
        $lastCol = $Worksheet.UsedRange.Columns.Count
        
        Write-Host "  Rows: $lastRow, Columns: $lastCol" -ForegroundColor Gray
        
        # Header-Zeile analysieren
        $headers = @{}
        for ($col = 1; $col -le $lastCol; $col++) {
            $headerValue = $Worksheet.Cells.Item(1, $col).Text.Trim()
            if ($headerValue) {
                $headers[$headerValue] = $col
            }
        }
        
        Write-Host "  Headers found: $($headers.Keys -join ', ')" -ForegroundColor Gray
        
        # Server-Namen Spalte finden
        $serverColumn = 1
        if ($headers.ContainsKey("Server")) {
            $serverColumn = $headers["Server"]
        } elseif ($headers.ContainsKey("Name")) {
            $serverColumn = $headers["Name"]
        } elseif ($headers.ContainsKey("Servername")) {
            $serverColumn = $headers["Servername"]
        }
        
        # Domain-Spalte finden (für Block-Header)
        $domainColumn = -1
        if ($headers.ContainsKey("Domain")) {
            $domainColumn = $headers["Domain"]
        } elseif ($headers.ContainsKey("Domäne")) {
            $domainColumn = $headers["Domäne"]
        }
        
        # IP-Spalte (optional)
        $ipColumn = -1
        if ($headers.ContainsKey("IP")) {
            $ipColumn = $headers["IP"]
        } elseif ($headers.ContainsKey("IP Address")) {
            $ipColumn = $headers["IP Address"]
        } elseif ($headers.ContainsKey("IP-Adresse")) {
            $ipColumn = $headers["IP-Adresse"]
        }
        
        # Status-Spalte (optional)
        $statusColumn = -1
        if ($headers.ContainsKey("Status")) {
            $statusColumn = $headers["Status"]
        }
        
        Write-Host "  Using column $serverColumn for server names" -ForegroundColor Gray
        if ($domainColumn -gt 0) {
            Write-Host "  Using column $domainColumn for domain/blocks" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Server lesen mit Block-Struktur
        Write-Host "  Reading servers with block structure..." -ForegroundColor Yellow
        Write-Host "  (Block-Header in Col1: '(Domain)XXX' | Block-End: 'SUMME:')" -ForegroundColor Gray
        Write-Host "  (Skipping strikethrough servers)" -ForegroundColor Gray
        Write-Host ""
        
        $currentBlock = "Unknown"
        $blockServerCount = 0
        $skippedCount = 0
        
        for ($row = 2; $row -le $lastRow; $row++) {
            $cell = $Worksheet.Cells.Item($row, 1)
            $col1Value = $cell.Text.Trim()
            
            # Skip header row
            if ($col1Value -match '^ServerName$') {
                Write-Host "  Skipping header row at $row" -ForegroundColor Gray
                continue
            }
            
            # Block-Header erkennen: (Domain)UVW oder (WORKGROUP)XXX in Spalte 1
            if ($col1Value -match '^\((Domain|WORKGROUP)\)') {
                # Vorheriger Block abschließen
                if ($currentBlock -ne "Unknown" -and $blockServerCount -gt 0) {
                    Write-Host "    -> Block '$currentBlock' completed: $blockServerCount servers" -ForegroundColor Cyan
                }
                
                # Neuer Block
                $currentBlock = $col1Value
                $blockServerCount = 0
                $blockStats[$currentBlock] = 0
                
                Write-Host "  [BLOCK START] $currentBlock (Row $row)" -ForegroundColor Yellow
                continue
            }
            
            # SUMME: Zeile = Block-Ende
            if ($col1Value -match '^SUMME:') {
                if ($currentBlock -ne "Unknown") {
                    $col2Value = $Worksheet.Cells.Item($row, 2).Text.Trim()
                    Write-Host "    [BLOCK END] $currentBlock - SUMME: $col2Value (Row $row)" -ForegroundColor Gray
                }
                continue
            }
            
            # Leere Zeilen überspringen
            if (-not $col1Value) {
                continue
            }
            
            # Server-Zeile
            if ($col1Value) {
                # Check for strikethrough (durchgestrichen = inaktiv)
                $isStrikethrough = $cell.Font.Strikethrough
                
                if ($isStrikethrough) {
                    Write-Host "    [SKIP] $col1Value (Row $row) - Strikethrough (inactive)" -ForegroundColor DarkGray
                    $skippedCount++
                    continue
                }
                
                # Filter ungültige Servernamen
                $invalidPatterns = @(
                    '^SUMME:',                           # SUMME-Zeilen
                    '^ServerName$',                       # Header
                    '^\s*$',                             # Leer
                    'NEUE SERVER',                        # Beschreibungen
                    'Stand:',                            # Datumsangaben
                    'Servers',                           # Plural-Bezeichnung
                    'DATACENTER',                        # Beschreibungen
                    '^\(Domain',                         # Block-Marker
                    '^\(Workgroup',                      # Block-Marker
                    '^\(.*\)',                           # Alles in Klammern
                    '\s+',                               # Enthält Leerzeichen
                    '^[0-9]+$'                          # Nur Zahlen
                )
                
                $isInvalid = $false
                foreach ($pattern in $invalidPatterns) {
                    if ($col1Value -match $pattern) {
                        Write-Host "    [SKIP] $col1Value (Row $row) - Invalid pattern: $pattern" -ForegroundColor DarkGray
                        $skippedCount++
                        $isInvalid = $true
                        break
                    }
                }
                
                if ($isInvalid) {
                    continue
                }
                
                # Minimale Länge-Prüfung (Server-Namen sollten mind. 2 Zeichen haben)
                if ($col1Value.Length -lt 2) {
                    Write-Host "    [SKIP] $col1Value (Row $row) - Too short" -ForegroundColor DarkGray
                    $skippedCount++
                    continue
                }
                
                # Filter anwenden
                if ($FilterString -and $col1Value -notmatch $FilterString) {
                    continue
                }
                
                # FQDN konstruieren basierend auf Block
                $fqdn = $col1Value
                
                # Domain-basierte FQDN-Konstruktion
                if ($currentBlock -match '^\(Domain\)(.+)$') {
                    $domain = $matches[1].ToLower()
                    
                    # Spezial-Domains
                    $domainMap = @{
                        'UVW' = 'uvw.meduniwien.ac.at'
                        'ITSC-TEST' = 'itsc-test.meduniwien.ac.at'
                        'NEURO' = 'neuro.meduniwien.ac.at'
                        'EX' = 'ex.meduniwien.ac.at'
                        'DGMW' = 'dgmw.meduniwien.ac.at'
                        'KHHYG' = 'khhyg.meduniwien.ac.at'
                        'AD' = 'ad.meduniwien.ac.at'
                        'Diagnostic' = 'diagnostic.meduniwien.ac.at'
                    }
                    
                    # Wenn Domain bekannt ist, FQDN konstruieren
                    if ($domainMap.ContainsKey($domain)) {
                        $fqdn = "$col1Value.$($domainMap[$domain])"
                    } else {
                        $fqdn = "$col1Value.$domain.meduniwien.ac.at"
                    }
                    
                # Workgroup-basierte FQDN (SRV Domain)
                } elseif ($currentBlock -match '^\(Workgroup\)SRV$') {
                    $fqdn = "$col1Value.srv.meduniwien.ac.at"
                    
                # Andere Workgroups - versuche mit .meduniwien.ac.at
                } elseif ($currentBlock -match '^\(Workgroup\)') {
                    # Wenn kein Punkt im Namen, füge .meduniwien.ac.at hinzu
                    if ($col1Value -notmatch '\.') {
                        $fqdn = "$col1Value.meduniwien.ac.at"
                    }
                }
                
                $serverInfo = @{
                    Name = $fqdn
                    Hostname = $col1Value
                    IP = if ($ipColumn -gt 0) { $Worksheet.Cells.Item($row, $ipColumn).Text.Trim() } else { "" }
                    Status = if ($statusColumn -gt 0) { $Worksheet.Cells.Item($row, $statusColumn).Text.Trim() } else { "" }
                    OS = $Worksheet.Cells.Item($row, 2).Text.Trim()
                    Notes = $Worksheet.Cells.Item($row, 4).Text.Trim()
                    Block = $currentBlock
                    Row = $row
                }
                
                $serverList += $serverInfo
                $blockServerCount++
                
                if ($blockStats.ContainsKey($currentBlock)) {
                    $blockStats[$currentBlock]++
                }
            }
        }
        
        # Letzten Block abschließen
        if ($currentBlock -ne "Unknown" -and $blockServerCount -gt 0) {
            Write-Host "    Block '$currentBlock' completed: $blockServerCount servers" -ForegroundColor Cyan
        }
        
        # Cleanup
        $Workbook.Close($false)
        $Excel.Quit()
        
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
        [System.GC]::Collect()
        
        Write-Host ""
        Write-Host "  [OK] Found $($serverList.Count) servers in $($blockStats.Keys.Count) blocks" -ForegroundColor Green
        
        if ($skippedCount -gt 0) {
            Write-Host "  [INFO] Skipped $skippedCount strikethrough (inactive) servers" -ForegroundColor Yellow
        }
        
        # Block-Statistik anzeigen
        if ($blockStats.Keys.Count -gt 0) {
            Write-Host ""
            Write-Host "  Block Statistics:" -ForegroundColor Cyan
            foreach ($block in ($blockStats.Keys | Sort-Object)) {
                Write-Host "    $block : $($blockStats[$block]) servers" -ForegroundColor Gray
            }
        }
        
        return $serverList
        
    } catch {
        Write-Host "  [ERROR] Excel read failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Cleanup
        if ($Excel) {
            try { $Excel.Quit() } catch { }
        }
        
        return @()
    }
}

function Update-RemoteServerList {
    param(
        [string]$ServerName,
        [string]$FilePath,
        [array]$ServerList,
        [System.Management.Automation.PSCredential]$Cred
    )
    
    Write-VersionSpecificHost "Updating server list on remote server..." -IconType 'network' -ForegroundColor Cyan
    
    try {
        # Server nach Blöcken gruppieren
        $blockGroups = $ServerList | Group-Object -Property Block | Sort-Object Name
        
        Write-Host "  Servers to write: $($ServerList.Count) in $($blockGroups.Count) blocks" -ForegroundColor Gray
        Write-Host "  Target: $ServerName -> $FilePath" -ForegroundColor Gray
        
        # Content mit Block-Struktur erstellen
        $contentLines = @()
        
        # Header
        $contentLines += "# ========================================="
        $contentLines += "# CertSurv Server List"
        $contentLines += "# Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $contentLines += "# Total Servers: $($ServerList.Count)"
        $contentLines += "# Blocks: $($blockGroups.Count)"
        $contentLines += "# Source: Serverliste2025.xlsx"
        $contentLines += "# ========================================="
        $contentLines += ""
        
        # Server gruppiert nach Blöcken
        foreach ($group in $blockGroups) {
            $blockName = $group.Name
            $servers = $group.Group | Sort-Object Name
            
            $contentLines += "# ========================================="
            $contentLines += "# Block: $blockName"
            $contentLines += "# Servers: $($servers.Count)"
            $contentLines += "# ========================================="
            
            foreach ($server in $servers) {
                $contentLines += $server.Name
            }
            
            $contentLines += ""
        }
        
        # Via PSRemoting updaten
        # DevSkim: ignore DS104456 - Required for server list update
        $result = Invoke-Command -ComputerName $ServerName -Credential $Cred -ScriptBlock {
            param($Path, $Content)
            
            try {
                # Backup erstellen
                if (Test-Path $Path) {
                    $backupPath = $Path -replace '\.txt$', "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                    Copy-Item -Path $Path -Destination $backupPath -Force
                }
                
                # Neue Liste schreiben
                $Content | Out-File -FilePath $Path -Encoding UTF8 -Force
                
                [PSCustomObject]@{
                    Success = $true
                    ServerCount = ($Content | Where-Object { $_ -and $_ -notmatch '^#' -and $_ -notmatch '^\s*$' }).Count
                    Path = $Path
                }
                
            } catch {
                [PSCustomObject]@{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
            
        } -ArgumentList $FilePath, $contentLines -ErrorAction Stop
        
        if ($result.Success) {
            Write-Host "  [OK] Server list updated: $($result.ServerCount) servers" -ForegroundColor Green
            Write-Host "  File: $($result.Path)" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "  [ERROR] Update failed: $($result.Error)" -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host "  [ERROR] Remote update failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Main Execution

try {
    # Credentials - use Credential Manager
    if (-not $Credential) {
        Write-Host ""
        
        # Versuche Credential Manager zu laden
        $credManagerPath = Join-Path $PSScriptRoot "Modules\FL-CredentialManager-v1.0.psm1"
        
        if (Test-Path $credManagerPath) {
            Import-Module $credManagerPath -Force -ErrorAction SilentlyContinue
            
            # Verwende Get-OrPromptCredential wenn verfügbar
            if (Get-Command Get-OrPromptCredential -ErrorAction SilentlyContinue) {
                $computerShortName = $TargetServer.Split('.')[0]
                $Credential = Get-OrPromptCredential -Target $computerShortName -Username "$computerShortName\Administrator" -SaveIfNew
            }
        }
        
        # Fallback: 3-Stufen-Strategie
        if (-not $Credential) {
            $computerShortName = $TargetServer.Split('.')[0]
            Write-Host "[*] Using 3-tier credential strategy (Default -> Vault -> Prompt)..." -ForegroundColor Yellow
            $Credential = Get-OrPromptCredential -Target $TargetServer -Username "$computerShortName\Administrator" -AutoSave
        }
    }
    
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  EXCEL SERVER LIST PROCESSING" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Read Excel
    $servers = Get-ServersFromExcel -ExcelPath $ExcelPath -FilterString $Filter
    
    if ($servers.Count -eq 0) {
        Write-VersionSpecificHost "No servers found in Excel" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # Preview
    if ($ShowPreview -or $servers.Count -le 20) {
        Write-Host "Server List Preview:" -ForegroundColor Cyan
        Write-Host ""
        
        $previewCount = [Math]::Min(20, $servers.Count)
        
        for ($i = 0; $i -lt $previewCount; $i++) {
            $server = $servers[$i]
            $displayText = "  [$($i+1)] $($server.Name)"
            
            if ($server.IP) {
                $displayText += " ($($server.IP))"
            }
            
            if ($server.Domain) {
                $displayText += " [$($server.Domain)]"
            }
            
            Write-Host $displayText -ForegroundColor Gray
        }
        
        if ($servers.Count -gt 20) {
            Write-Host "  ... and $($servers.Count - 20) more servers" -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
    
    # Statistics
    Write-Host "Statistics:" -ForegroundColor Cyan
    Write-Host "  Total Servers: $($servers.Count)" -ForegroundColor White
    
    if ($Filter) {
        Write-Host "  Filter Applied: $Filter" -ForegroundColor Yellow
    }
    
    # Domain Statistics (optional)
    $domains = $servers | Where-Object { $_.Domain } | Group-Object -Property Domain
    if ($domains.Count -gt 0) {
        Write-Host ""
        Write-Host "  Servers by Domain:" -ForegroundColor Gray
        foreach ($domain in $domains | Sort-Object Count -Descending) {
            Write-Host "    $($domain.Name): $($domain.Count)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    # Confirmation
    $confirm = Read-Host "Update server list on $TargetServer? (Y/N)"
    
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "Update cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  UPDATING SERVER LIST" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Update
    $success = Update-RemoteServerList -ServerName $TargetServer -FilePath $TargetPath -ServerList $servers -Cred $Credential
    
    if ($success) {
        Write-Host ""
        Write-VersionSpecificHost "Server list updated successfully!" -IconType 'party' -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Test CertSurv Scanner with new list" -ForegroundColor Gray
        Write-Host "  2. Check Reports: $TargetServer -> C:\CertSurv\Reports\" -ForegroundColor Gray
        Write-Host ""
        exit 0
    } else {
        Write-VersionSpecificHost "Server list update failed" -IconType 'error' -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-VersionSpecificHost "Update failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}

#endregion

