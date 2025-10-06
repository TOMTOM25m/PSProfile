#Requires -Version 5.1

<#
.SYNOPSIS
    Fix-FL-DataProcessing-ImportExcel.ps1 - Repariert FL-DataProcessing.psm1 und integriert ImportExcel
.DESCRIPTION
    Stellt das Backup wieder her und integriert ImportExcel sauberer
#>

param(
    [string]$CertSurvPath = "F:\DEV\repositories\CertSurv"
)

$ErrorActionPreference = "Stop"
$LogFile = "F:\DEV\repositories\CertSurv\LOG\Fix-ImportExcel-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

function Write-FixLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStamp] [$Level] $Message"
    Write-Host $logLine
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

Write-FixLog "=== Fix FL-DataProcessing ImportExcel Integration ==="

try {
    # 1. Restore clean backup
    $originalModule = Join-Path $CertSurvPath "Modules\FL-DataProcessing.psm1"
    $backupModule = Join-Path $CertSurvPath "Modules\FL-DataProcessing-BACKUP-2025-10-06-1139.psm1"
    
    if (Test-Path $backupModule) {
        Copy-Item $backupModule $originalModule -Force
        Write-FixLog "Restored clean backup to FL-DataProcessing.psm1"
    } else {
        Write-FixLog "Backup file not found: $backupModule" -Level "ERROR"
        throw "Cannot restore backup"
    }
    
    # 2. Read the clean module
    $moduleContent = Get-Content $originalModule -Raw -Encoding UTF8
    Write-FixLog "Clean module loaded: $($moduleContent.Length) characters"
    
    # 3. Create a complete new Extract-HeaderContext function
    $newFunction = @'
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
    
    # 4. Find and replace the existing Extract-HeaderContext function more precisely
    $startPattern = 'function Extract-HeaderContext \{'
    $endPattern = '^\}'
    
    $lines = $moduleContent -split "`r?`n"
    $newLines = @()
    $inFunction = $false
    $braceCount = 0
    $functionReplaced = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        if (-not $inFunction -and $line -match $startPattern) {
            # Start of Extract-HeaderContext function
            Write-FixLog "Found Extract-HeaderContext function at line $($i + 1)"
            $inFunction = $true
            $braceCount = 0
            $newLines += $newFunction -split "`r?`n"
            $functionReplaced = $true
            continue
        }
        
        if ($inFunction) {
            # Count braces to find end of function
            $openBraces = [regex]::Matches($line, '\{').Count
            $closeBraces = [regex]::Matches($line, '\}').Count
            $braceCount += $openBraces - $closeBraces
            
            if ($braceCount -le 0 -and $line -match '^\}') {
                # End of function
                Write-FixLog "End of Extract-HeaderContext function at line $($i + 1)"
                $inFunction = $false
                continue
            }
            # Skip lines inside the old function
            continue
        }
        
        # Keep all other lines
        $newLines += $line
    }
    
    if ($functionReplaced) {
        $newModuleContent = $newLines -join "`r`n"
        Set-Content -Path $originalModule -Value $newModuleContent -Encoding UTF8
        Write-FixLog "Extract-HeaderContext function successfully replaced with ImportExcel version"
    } else {
        Write-FixLog "Extract-HeaderContext function not found in module" -Level "WARN"
    }
    
    Write-FixLog "=== Fix completed successfully ==="
    
} catch {
    Write-FixLog "Fix failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}