#Requires -Version 5.1

<#
.SYNOPSIS
    FL-DataProcessing-NoExcelCOM.psm1 - Excel Data Processing ohne COM-Objects
.DESCRIPTION
    Ersetzt Excel COM mit ImportExcel PowerShell Modul
.NOTES
    Version: 1.1.0
    Author: GitHub Copilot
    Date: 2025-10-06
    
    HAUPTUNTERSCHIED:
    - Verwendet ImportExcel statt Excel COM-Objects
    - Funktioniert ohne Excel-Installation auf dem Server
    - Header-Context Extraktion mit reinem PowerShell
#>

<#
.SYNOPSIS
    [DE] Extrahiert Header-Kontext ohne Excel COM-Objects
    [EN] Extracts header context without Excel COM objects
.DESCRIPTION
    [DE] Verwendet ImportExcel Modul um Header-Kontext zu extrahieren
    [EN] Uses ImportExcel module to extract header context
#>
function Extract-HeaderContext-NoExcelCOM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $true)]
        [int]$HeaderRow,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Extracting domain context using ImportExcel (no COM objects)..." -LogFile $LogFile
    
    try {
        # Check if ImportExcel module is available
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Log "ImportExcel module not available - attempting to install..." -LogFile $LogFile
            Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
            Write-Log "ImportExcel module installed successfully" -LogFile $LogFile
        }
        
        Import-Module ImportExcel -Force
        Write-Log "ImportExcel module loaded" -LogFile $LogFile
        
        # Read all Excel data to analyze structure
        $allData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -NoHeader -ErrorAction Stop
        Write-Log "Excel data loaded: $($allData.Count) rows" -LogFile $LogFile
        
        $headerContext = @{}
        $currentDomain = "srv" # Default workgroup
        $currentType = "Workgroup"
        $processedServers = 0
        
        foreach ($row in $allData) {
            # Get server name from first column (P1 = Column A)
            $serverNameCell = $row.P1
            
            if ([string]::IsNullOrWhiteSpace($serverNameCell)) { continue }
            $serverName = $serverNameCell.ToString().Trim()
            
            # Check for domain block start: (Domain)XXX
            $domainMatch = [regex]::Match($serverName, '^\(Domain(?:-[\w]+)?\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($domainMatch.Success) {
                $currentDomain = $domainMatch.Groups[1].Value.Trim().ToLower()
                $currentType = "Domain"
                Write-Log "Found Domain block: '$currentDomain' (Full: '$serverName')" -LogFile $LogFile
                continue
            }
            
            # Check for workgroup block start: (Workgroup)XXX
            $workgroupMatch = [regex]::Match($serverName, '^\(Workgroup\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($workgroupMatch.Success) {
                $currentDomain = $workgroupMatch.Groups[1].Value.Trim().ToLower()
                $currentType = "Workgroup"
                Write-Log "Found Workgroup block: '$currentDomain' (Full: '$serverName')" -LogFile $LogFile
                continue
            }
            
            # Check for block end marker: SUMME
            if ($serverName -match '^SUMME:?\s*$') {
                Write-Log "End of block detected for '$currentDomain'. Resetting to default." -LogFile $LogFile
                $currentDomain = "srv"
                $currentType = "Workgroup"
                continue
            }
            
            # Skip obvious header rows and non-server entries
            if ($serverName -match "^(Server|Servers|NEUE SERVER|DATACENTER|STANDARD|ServerName)") {
                continue
            }
            
            # This looks like a real server - add to context
            if ($serverName.Length -gt 2 -and $serverName -notmatch '^[\s\-_=]+$') {
                $headerContext[$serverName] = @{
                    Domain = if ($currentType -eq "Domain") { $currentDomain } else { "" }
                    Subdomain = $currentDomain
                    IsDomain = ($currentType -eq "Domain")
                }
                $processedServers++
            }
        }
        
        Write-Log "Header context extracted: $($headerContext.Count) servers mapped (processed $processedServers)." -LogFile $LogFile
        $domainServers = ($headerContext.Values | Where-Object { $_.IsDomain }).Count
        $workgroupServers = $headerContext.Count - $domainServers
        Write-Log "  - Domain servers: $domainServers" -LogFile $LogFile
        Write-Log "  - Workgroup servers: $workgroupServers" -LogFile $LogFile
        
        return $headerContext
    }
    catch {
        Write-Log "Could not extract header context (ImportExcel): $($_.Exception.Message)" -Level WARN -LogFile $LogFile
        return @{}
    }
}

# Test function to verify ImportExcel approach
function Test-ImportExcelApproach {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcelPath,
        
        [Parameter(Mandatory = $true)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    
    Write-Log "Testing ImportExcel approach..." -LogFile $LogFile
    
    try {
        # Install/Import ImportExcel if needed
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Log "Installing ImportExcel module..." -LogFile $LogFile
            Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
        }
        
        Import-Module ImportExcel -Force
        Write-Log "ImportExcel module ready" -LogFile $LogFile
        
        # Test reading Excel
        $testData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -NoHeader -ErrorAction Stop | Select-Object -First 10
        
        Write-Log "Test successful: Read $($testData.Count) sample rows" -LogFile $LogFile
        Write-Log "Sample data from first column (P1):" -LogFile $LogFile
        
        foreach ($row in $testData) {
            if ($row.P1) {
                Write-Log "  - '$($row.P1)'" -LogFile $LogFile
            }
        }
        
        return $true
    }
    catch {
        Write-Log "ImportExcel test failed: $($_.Exception.Message)" -Level ERROR -LogFile $LogFile
        return $false
    }
}

Export-ModuleMember -Function @(
    'Extract-HeaderContext-NoExcelCOM',
    'Test-ImportExcelApproach'
)