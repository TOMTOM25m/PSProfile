#Requires -Version 5.1

<#
.SYNOPSIS
    Install-ImportExcel-Solution.ps1 - Installiert ImportExcel-basierte Lösung auf Server
.DESCRIPTION
    Ersetzt COM-Objects mit ImportExcel Modul auf dem Zielserver
.NOTES
    Version: 1.0.0
    Author: GitHub Copilot
    Date: 2025-10-06
    
    AUSFÜHRUNG AUF SERVER ITSCMGMT03:
    1. ImportExcel Modul installieren
    2. FL-DataProcessing.psm1 mit ImportExcel-Version ersetzen
    3. Tests ausführen
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\CertSurv\LOG\Install-ImportExcel-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log"

function Write-InstallLog {
    param([string]$Message, [string]$Level = "INFO")
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timeStamp] [$Level] $Message"
    Write-Host $logLine
    if (-not (Test-Path (Split-Path $LogFile))) { New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
}

Write-InstallLog "=== Install ImportExcel Solution on Server ==="

try {
    # 1. Install ImportExcel Module
    Write-InstallLog "Installing ImportExcel PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Install-Module -Name ImportExcel -Force -Scope AllUsers -ErrorAction Stop
        Write-InstallLog "ImportExcel module installed successfully"
    } else {
        Write-InstallLog "ImportExcel module already available"
    }
    
    Import-Module ImportExcel -Force
    Write-InstallLog "ImportExcel module loaded and ready"
    
    # 2. Backup current FL-DataProcessing.psm1
    $modulePath = "C:\CertSurv\Modules\FL-DataProcessing.psm1"
    $backupPath = "C:\CertSurv\Modules\FL-DataProcessing-BACKUP-COM-$(Get-Date -Format 'yyyy-MM-dd-HHmm').psm1"
    
    if (Test-Path $modulePath) {
        Copy-Item $modulePath $backupPath -Force
        Write-InstallLog "Backup created: $backupPath"
    } else {
        Write-InstallLog "Module not found at: $modulePath" -Level "WARN"
    }
    
    # 3. Copy ImportExcel version from network share
    $networkModulePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\FL-DataProcessing-NoExcelCOM.psm1"
    
    if (Test-Path $networkModulePath) {
        Write-InstallLog "Copying ImportExcel module from network share..."
        
        # Read the ImportExcel version
        $importExcelContent = Get-Content $networkModulePath -Raw -Encoding UTF8
        
        # Create new FL-DataProcessing.psm1 with minimal required functions
        $newModuleContent = @"
#Requires -Version 5.1

<#
.SYNOPSIS
    FL-DataProcessing.psm1 - Excel Data Processing with ImportExcel
.DESCRIPTION
    Certificate Surveillance Excel processing using ImportExcel instead of COM objects
.NOTES
    Version: 1.2.0 - ImportExcel Edition
    Author: GitHub Copilot  
    Date: 2025-10-06
#>

# Import required modules
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}
Import-Module ImportExcel -Force

# Logging function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = `$true)]
        [string]`$Message,
        
        [Parameter(Mandatory = `$false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]`$Level = 'INFO',
        
        [Parameter(Mandatory = `$true)]
        [string]`$LogFile
    )
    
    `$timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logLine = "[`$timeStamp] [`$Level] `$Message"
    
    # Ensure log directory exists
    `$logDir = Split-Path `$LogFile -Parent
    if (-not (Test-Path `$logDir)) {
        New-Item -ItemType Directory -Path `$logDir -Force | Out-Null
    }
    
    Add-Content -Path `$LogFile -Value `$logLine -Encoding UTF8
}

# Filter Excel Block Headers
function Filter-ExcelBlockHeaders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = `$true)]
        [array]`$InputData,
        
        [Parameter(Mandatory = `$true)]
        [object]`$Config,
        
        [Parameter(Mandatory = `$true)]
        [string]`$LogFile
    )
    
    Write-Log "Filtering Excel block headers..." -LogFile `$LogFile
    
    `$filteredData = @()
    `$skippedCount = 0
    
    foreach (`$row in `$InputData) {
        `$serverName = `$row.(`$Config.Excel.ServerNameColumnName)
        
        if ([string]::IsNullOrWhiteSpace(`$serverName)) { continue }
        `$serverName = `$serverName.ToString().Trim()
        
        # Skip domain/workgroup headers and SUMME footers
        if (`$serverName -match '^\(Domain(?:-[\w]+)?\)' -or 
            `$serverName -match '^\(Workgroup\)' -or 
            `$serverName -match '^SUMME:?\s*`$') {
            `$skippedCount++
            Write-Log "Skipped block header/footer: '`$serverName'" -LogFile `$LogFile
            continue
        }
        
        `$filteredData += `$row
    }
    
    Write-Log "Block header filtering complete: `$(`$filteredData.Count) servers remain, `$skippedCount headers/footers skipped" -LogFile `$LogFile
    return `$filteredData
}

$importExcelContent

# Export functions
Export-ModuleMember -Function @(
    'Extract-HeaderContext-NoExcelCOM',
    'Filter-ExcelBlockHeaders',
    'Write-Log'
)
"@
        
        Set-Content -Path $modulePath -Value $newModuleContent -Encoding UTF8
        Write-InstallLog "FL-DataProcessing.psm1 updated with ImportExcel version"
        
    } else {
        Write-InstallLog "Network module not found: $networkModulePath" -Level "ERROR"
        throw "Cannot access ImportExcel module from network share"
    }
    
    # 4. Test the new module
    Write-InstallLog "Testing new module..."
    Remove-Module FL-DataProcessing -Force -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force
    Write-InstallLog "Module imported successfully"
    
    # 5. Test ImportExcel functionality
    $configPath = "C:\CertSurv\Config\Config-Cert-Surveillance.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        $testResult = Extract-HeaderContext-NoExcelCOM -ExcelPath $config.ExcelFilePath -WorksheetName $config.ExcelWorksheet -HeaderRow 1 -Config $config -LogFile $LogFile
        Write-InstallLog "Test extraction successful: $($testResult.Count) servers processed"
    } else {
        Write-InstallLog "Config file not found for testing" -Level "WARN"
    }
    
    Write-InstallLog "=== Installation completed successfully ==="
    Write-InstallLog "ImportExcel solution is now active and replaces COM objects"
    
} catch {
    Write-InstallLog "Installation failed: $($_.Exception.Message)" -Level "ERROR"
    Write-InstallLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    throw
}