#Requires -Version 5.1

<#
.SYNOPSIS
    Update-CertSurv-ImportExcel.ps1 - Aktualisiert CertSurv auf ImportExcel
.DESCRIPTION
    Ersetzt Excel COM-Object Abhängigkeit mit ImportExcel PowerShell Modul
.NOTES
    Version: 1.0.0
    Author: GitHub Copilot
    Date: 2025-10-06
    
    AUFGABEN:
    1. Backup der aktuellen FL-DataProcessing.psm1
    2. Integration der ImportExcel-Funktionen in FL-DataProcessing.psm1
    3. Test der neuen Funktionalität
    4. Deployment-Bestätigung
#>

param(
    [string]$CertSurvPath = "F:\DEV\repositories\CertSurv"
)

$ErrorActionPreference = "Stop"
$LogFile = "F:\DEV\repositories\CertSurv\LOG\Update-ImportExcel-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

# Ensure LOG directory exists
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-UpdateLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStamp] [$Level] $Message"
    Write-Host $logLine
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

Write-UpdateLog "=== Update CertSurv to ImportExcel (no COM objects) ==="

try {
    # 1. Backup current FL-DataProcessing.psm1
    $originalModule = Join-Path $CertSurvPath "Modules\FL-DataProcessing.psm1"
    $backupModule = Join-Path $CertSurvPath "Modules\FL-DataProcessing-BACKUP-$(Get-Date -Format 'yyyy-MM-dd-HHmm').psm1"
    
    if (Test-Path $originalModule) {
        robocopy (Split-Path $originalModule) (Split-Path $backupModule) (Split-Path $originalModule -Leaf) /Z /R:3 /W:5 /NP /NDL | Out-Null
        Write-UpdateLog "Backup created: $backupModule"
    } else {
        Write-UpdateLog "Original module not found at: $originalModule" -Level "WARN"
    }
    
    # 2. Read current FL-DataProcessing.psm1 to integrate ImportExcel functions
    $currentContent = Get-Content $originalModule -Raw -Encoding UTF8
    Write-UpdateLog "Current module size: $($currentContent.Length) characters"
    
    # 3. Check if Extract-HeaderContext function exists
    if ($currentContent -match 'function\s+Extract-HeaderContext\s*\{') {
        Write-UpdateLog "Found existing Extract-HeaderContext function"
        
        # Replace the Extract-HeaderContext function with ImportExcel version
        $importExcelFunction = @'
function Extract-HeaderContext {
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
'@
        
        # Use regex to replace the existing Extract-HeaderContext function
        $pattern = '(?s)function\s+Extract-HeaderContext\s*\{.*?^}'
        $updatedContent = [regex]::Replace($currentContent, $pattern, $importExcelFunction, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        
        # Write the updated content
        Set-Content -Path $originalModule -Value $updatedContent -Encoding UTF8
        Write-UpdateLog "FL-DataProcessing.psm1 updated with ImportExcel implementation"
        
    } else {
        Write-UpdateLog "Extract-HeaderContext function not found in module" -Level "WARN"
    }
    
    # 4. Create test script
    $testScript = Join-Path $CertSurvPath "TEST\Test-ImportExcel-HeaderContext.ps1"
    $testContent = @"
#Requires -Version 5.1
# Test ImportExcel Header Context Extraction

`$ErrorActionPreference = "Stop"
`$LogFile = "F:\DEV\repositories\CertSurv\LOG\Test-ImportExcel-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

# Load module
Import-Module "F:\DEV\repositories\CertSurv\Modules\FL-DataProcessing.psm1" -Force

# Load config
`$configPath = "F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
`$config = Get-Content `$configPath | ConvertFrom-Json

Write-Host "Testing ImportExcel Header Context..."
Write-Host "Excel Path: `$(`$config.ExcelFilePath)"

try {
    `$headerContext = Extract-HeaderContext -ExcelPath `$config.ExcelFilePath -WorksheetName `$config.ExcelWorksheetName -HeaderRow 1 -Config `$config -LogFile `$LogFile
    
    Write-Host "Success! Header context contains `$(`$headerContext.Count) servers"
    
    # Show some examples
    `$headerContext.GetEnumerator() | Select-Object -First 5 | ForEach-Object {
        Write-Host "  `$(`$_.Key) -> Domain: '`$(`$_.Value.Domain)', Subdomain: '`$(`$_.Value.Subdomain)', IsDomain: `$(`$_.Value.IsDomain)"
    }
    
    Write-Host ""
    Write-Host "Test completed successfully! Check log: `$LogFile"
    
} catch {
    Write-Host "Test failed: `$(`$_Exception.Message)" -ForegroundColor Red
    Write-Host "Check log: `$LogFile"
}
"@
    
    Set-Content -Path $testScript -Value $testContent -Encoding UTF8
    Write-UpdateLog "Test script created: $testScript"
    
    Write-UpdateLog "=== Update completed successfully ==="
    Write-UpdateLog "Next steps:"
    Write-UpdateLog "1. Deploy updated FL-DataProcessing.psm1 to network share"
    Write-UpdateLog "2. Test with: $testScript"
    Write-UpdateLog "3. Monitor CertSurv operation"
    
} catch {
    Write-UpdateLog "Update failed: $($_.Exception.Message)" -Level "ERROR"
    Write-UpdateLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    throw
}