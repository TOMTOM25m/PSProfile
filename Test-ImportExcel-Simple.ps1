#Requires -Version 5.1

<#
.SYNOPSIS
    Test-ImportExcel-Simple.ps1 - Testet ImportExcel direkt
.DESCRIPTION
    Testet ImportExcel Modul ohne komplexe Module-Integration
#>

$ErrorActionPreference = "Stop"
$LogFile = "F:\DEV\repositories\CertSurv\LOG\Test-ImportExcel-Simple-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStamp] [$Level] $Message"
    Write-Host $logLine
    if (-not (Test-Path (Split-Path $LogFile))) { New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

Write-TestLog "=== Test ImportExcel Direct ==="

try {
    # 1. Load config
    $configPath = "F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-TestLog "Config loaded: ExcelPath = $($config.ExcelFilePath)"
    
    # 2. Install/Import ImportExcel
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-TestLog "Installing ImportExcel module..."
        Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
        Write-TestLog "ImportExcel module installed"
    }
    
    Import-Module ImportExcel -Force
    Write-TestLog "ImportExcel module loaded"
    
    # 3. Test reading Excel file
    $excelPath = $config.ExcelFilePath
    $worksheetName = $config.ExcelWorksheetName
    
    Write-TestLog "Reading Excel: $excelPath, Worksheet: $worksheetName"
    $allData = Import-Excel -Path $excelPath -WorksheetName $worksheetName -NoHeader -ErrorAction Stop
    Write-TestLog "Excel data loaded: $($allData.Count) rows"
    
    # 4. Analyze first 20 rows for structure
    Write-TestLog "Analyzing first 20 rows for domain/workgroup structure:"
    $sampleData = $allData | Select-Object -First 20
    
    $headerContext = @{}
    $currentDomain = "srv"
    $currentType = "Workgroup"
    
    foreach ($row in $sampleData) {
        $serverNameCell = $row.P1
        if ([string]::IsNullOrWhiteSpace($serverNameCell)) { continue }
        $serverName = $serverNameCell.ToString().Trim()
        
        Write-TestLog "Processing: '$serverName'"
        
        # Check for domain block: (Domain)XXX
        if ($serverName -match '^\(Domain(?:-[\w]+)?\)([\w-]+)') {
            $currentDomain = $matches[1].Trim().ToLower()
            $currentType = "Domain"
            Write-TestLog "  -> DOMAIN BLOCK DETECTED: '$currentDomain'"
            continue
        }
        
        # Check for workgroup block: (Workgroup)XXX
        if ($serverName -match '^\(Workgroup\)([\w-]+)') {
            $currentDomain = $matches[1].Trim().ToLower()
            $currentType = "Workgroup"
            Write-TestLog "  -> WORKGROUP BLOCK DETECTED: '$currentDomain'"
            continue
        }
        
        # Check for SUMME
        if ($serverName -match '^SUMME:?\s*$') {
            Write-TestLog "  -> BLOCK END DETECTED (SUMME)"
            $currentDomain = "srv"
            $currentType = "Workgroup"
            continue
        }
        
        # Skip headers
        if ($serverName -match "^(Server|Servers|NEUE SERVER|DATACENTER|STANDARD|ServerName)") {
            Write-TestLog "  -> SKIPPED (header)"
            continue
        }
        
        # Treat as server
        if ($serverName.Length -gt 2 -and $serverName -notmatch '^[\s\-_=]+$') {
            $headerContext[$serverName] = @{
                Domain = if ($currentType -eq "Domain") { $currentDomain } else { "" }
                Subdomain = $currentDomain
                IsDomain = ($currentType -eq "Domain")
            }
            Write-TestLog "  -> SERVER: Domain='$($headerContext[$serverName].Domain)', Subdomain='$($headerContext[$serverName].Subdomain)', IsDomain=$($headerContext[$serverName].IsDomain)"
        }
    }
    
    Write-TestLog "=== RESULTS ==="
    Write-TestLog "Header context extracted: $($headerContext.Count) servers"
    $domainServers = ($headerContext.Values | Where-Object { $_.IsDomain }).Count
    $workgroupServers = $headerContext.Count - $domainServers
    Write-TestLog "  - Domain servers: $domainServers"
    Write-TestLog "  - Workgroup servers: $workgroupServers"
    
    Write-TestLog "=== SUCCESS - ImportExcel works correctly ==="
    
} catch {
    Write-TestLog "Test failed: $($_.Exception.Message)" -Level "ERROR"
    Write-TestLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
}