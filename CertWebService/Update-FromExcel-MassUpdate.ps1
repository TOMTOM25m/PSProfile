#requires -Version 5.1
#Requires -RunAsAdministrator

# Import FL-CredentialManager für 3-Stufen-Strategie
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

<#
.SYNOPSIS
    CertWebService - Excel-Based Mass Update System v2.5.0

.DESCRIPTION
    Liest Server aus Serverliste2025.xlsx und führt intelligente Updates durch:
    1. Excel-Liste einlesen mit Domain/Workgroup-Erkennung
    2. CertWebService-Status prüfen (läuft bereits oder nicht)
    3. Verbindungstyp ermitteln (PSRemoting vs. SMB)
    4. Bulk-Installation für neue Server
    5. Bulk-Update für bestehende Server
    
.VERSION
    2.5.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$WorksheetName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Domain", "Workgroup", "TestOnly")]
    [string]$FilterType = "All",
    
    [Parameter(Mandatory = $false)]
    [string]$FilterValue = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$AnalyzeOnly,
    
    [Parameter(Mandatory = $false)]  
    [switch]$TestConnectivityOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxParallel = 3,
    
    [Parameter(Mandatory = $false)]
    [int]$CertWebServicePort = 9080
)

$Script:Version = "v2.5.0"
$Script:RulebookVersion = "v10.1.0"
$Script:StartTime = Get-Date

# Import PowerShell Version Compatibility Module
try {
    $compatibilityModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility.psm1"
    if (Test-Path $compatibilityModulePath) {
        Import-Module $compatibilityModulePath -Force
        $Global:PSCompatibilityLoaded = $true
        Write-Host "🔧 PowerShell version compatibility module loaded" -ForegroundColor Green
    } else {
        $Global:PSCompatibilityLoaded = $false
        Write-Host "⚠️ PowerShell compatibility module not found - using fallback methods" -ForegroundColor Yellow
    }
} catch {
    $Global:PSCompatibilityLoaded = $false
    Write-Host "⚠️ PowerShell compatibility module failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($Global:PSCompatibilityLoaded) {
    Write-VersionSpecificHeader "CertWebService - Excel-Based Mass Update System" -Version "$Script:Version | Regelwerk: $Script:RulebookVersion" -Color Cyan
} else {
    Write-Host "[START] CertWebService - Excel-Based Mass Update System" -ForegroundColor Cyan
    Write-Host "   Version: $Script:Version | Regelwerk: $Script:RulebookVersion" -ForegroundColor Gray
    Write-Host "   Start Time: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host ""
}

# Global tracking variables
$Global:ExcelResults = @{
    ServersTotal = 0
    ServersFiltered = 0
    HasCertWebService = @()
    NeedsCertWebService = @()
    Unreachable = @()
    PSRemotingAvailable = @()
    NetworkDeploymentOnly = @()
    ManualRequired = @()
    DomainServers = @()
    WorkgroupServers = @()
    ProcessingStartTime = Get-Date
}

#region Excel Processing Functions

function Get-StrikethroughServers {
    param(
        [string]$ExcelPath,
        [string]$WorksheetName
    )
    
    $strikethroughServers = @()
    
    try {
        # Try Excel COM approach for strikethrough detection
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        $workbook = $excel.Workbooks.Open($ExcelPath)
        $worksheet = $workbook.Worksheets.Item($WorksheetName)
        
        $usedRange = $worksheet.UsedRange
        $rowCount = $usedRange.Rows.Count
        
        Write-Host "     📋 Scanning $rowCount rows for strikethrough formatting..." -ForegroundColor Gray
        
        for ($row = 1; $row -le $rowCount; $row++) {
            $cell = $worksheet.Cells.Item($row, 1)  # Column A
            
            if ($cell.Value2 -and $cell.Font.Strikethrough) {
                $serverName = $cell.Value2.ToString().Trim()
                
                # Skip headers and block markers
                if ($serverName -notmatch '^((Domain|Workgroup)' -and 
                    $serverName -notmatch '^SUMME:?$' -and 
                    $serverName -notmatch '^(Server|Servers|NEUE SERVER|DATACENTER|STANDARD|ServerName)') {
                    
                    $strikethroughServers += $serverName
                    Write-Host "       ⚠️ Found strikethrough: $serverName (Row $row)" -ForegroundColor Gray
                }
            }
        }
        
        $workbook.Close($false)
        $excel.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        
    } catch {
        Write-Host "     ⚠️ Excel COM strikethrough detection failed: $($_.Exception.Message)" -ForegroundColor Yellow
        
        # Fallback: Try to use ImportExcel with cell styling (limited)
        try {
            Import-Module ImportExcel -Force -ErrorAction Stop
            
            # ImportExcel doesn't have full strikethrough support, but we can try
            # This is a simplified fallback - may not catch all strikethrough formatting
            $excelData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -NoHeader
            
            Write-Host "     📝 Using ImportExcel fallback (limited strikethrough detection)" -ForegroundColor Yellow
            
            # Note: ImportExcel has limited formatting detection
            # This fallback might miss some strikethrough entries
            
        } catch {
            Write-Host "     ❌ Strikethrough detection completely failed" -ForegroundColor Red
            # Return empty array - process all servers
        }
    }
    
    return $strikethroughServers
}

function Import-ServerListFromExcel {
    param(
        [string]$ExcelPath,
        [string]$WorksheetName,
        [object]$Config = $null
    )
    
    Write-Host "📊 Importing server list from Excel..." -ForegroundColor Yellow
    Write-Host "   Excel: $ExcelPath" -ForegroundColor Gray
    Write-Host "   Worksheet: $WorksheetName" -ForegroundColor Gray
    
    try {
        # Install/Import ImportExcel module if needed
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Host "   📦 Installing ImportExcel module..." -ForegroundColor Cyan
            Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "   ✅ ImportExcel module installed" -ForegroundColor Green
        }
        
        Import-Module ImportExcel -Force
        
        # Read Excel data using version-specific method
        if ($Global:PSCompatibilityLoaded) {
            if ($Global:PSCompatibilityLoaded) {
                Write-VersionSpecificHost "Using PowerShell version-specific Excel import..." -IconType 'gear' -ForegroundColor Cyan
            } else {
                Write-Host "   [TOOL] Using PowerShell version-specific Excel import..." -ForegroundColor Cyan
            }
            $excelResult = Import-ExcelData-VersionSpecific -ExcelPath $ExcelPath -WorksheetName $WorksheetName -IncludeStrikethrough
            
            if ($excelResult.Success) {
                $allData = $excelResult.Data
                $strikethroughServers = $excelResult.StrikethroughServers
                if ($Global:PSCompatibilityLoaded) {
                    Write-VersionSpecificHost "Loaded $($allData.Count) rows from Excel ($($excelResult.Method))" -IconType 'file' -ForegroundColor Green
                    if ($strikethroughServers.Count -gt 0) {
                        Write-VersionSpecificHost "Detected $($strikethroughServers.Count) strikethrough servers (will be ignored)" -IconType 'warning' -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "   [FILE] Loaded $($allData.Count) rows from Excel ($($excelResult.Method))" -ForegroundColor Green
                    if ($strikethroughServers.Count -gt 0) {
                        Write-Host "   [WARN] Detected $($strikethroughServers.Count) strikethrough servers (will be ignored)" -ForegroundColor Yellow
                    }
                }
            } else {
                throw "Excel import failed: $($excelResult.ErrorMessage)"
            }
        } else {
            # Fallback to direct ImportExcel
            if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                Write-Host "   📦 Installing ImportExcel module..." -ForegroundColor Cyan
                Install-Module -Name ImportExcel -Force -Scope CurrentUser -ErrorAction Stop
            }
            Import-Module ImportExcel -Force
            $allData = Import-Excel -Path $ExcelPath -WorksheetName $WorksheetName -NoHeader -ErrorAction Stop
            $strikethroughServers = @()  # Fallback can't detect strikethrough
            Write-Host "   📄 Loaded $($allData.Count) rows from Excel (Fallback ImportExcel)" -ForegroundColor Green
        }
        
        # Parse server structure with domain/workgroup context
        $serverList = @()
        $currentDomain = "srv"
        $currentType = "Workgroup"
        $processedCount = 0
        $skippedStrikethrough = 0
        
        Write-Host "   🔍 Parsing domain/workgroup structure..." -ForegroundColor Yellow
        
        # Strikethrough detection is now handled by the version-specific Excel import above
        # The $strikethroughServers array is already populated from Import-ExcelData-VersionSpecific
        
        $configToUse = if ($Config) { $Config } else { $Global:SystemConfig }
        if ($configToUse -and -not $configToUse.IgnoreStrikethroughServers) {
            Write-Host "   📋 Strikethrough detection disabled in config - processing all servers" -ForegroundColor Gray
            $strikethroughServers = @()  # Clear strikethrough list if disabled in config
        }
        
        foreach ($row in $allData) {
            $serverNameCell = $row.P1
            if ([string]::IsNullOrWhiteSpace($serverNameCell)) { continue }
            $serverName = $serverNameCell.ToString().Trim()
            
            # Domain block detection: (Domain)XXX or (Domain-XXX)YYY
            $domainMatch = [regex]::Match($serverName, '^\(Domain(?:-[\w]+)?\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($domainMatch.Success) {
                $currentDomain = $domainMatch.Groups[1].Value.Trim().ToLower()
                $currentType = "Domain"
                Write-Host "     🏢 Domain block: '$currentDomain'" -ForegroundColor Cyan
                continue
            }
            
            # Workgroup block detection: (Workgroup)XXX
            $workgroupMatch = [regex]::Match($serverName, '^\(Workgroup\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($workgroupMatch.Success) {
                $currentDomain = $workgroupMatch.Groups[1].Value.Trim().ToLower()
                $currentType = "Workgroup"
                Write-Host "     🏠 Workgroup block: '$currentDomain'" -ForegroundColor Yellow
                continue
            }
            
            # Block end detection: SUMME
            if ($serverName -match '^SUMME:?\s*$') {
                Write-Host "     📊 End of block (SUMME) - resetting to default" -ForegroundColor Gray
                $currentDomain = "srv"
                $currentType = "Workgroup"
                continue
            }
            
            # Skip headers and non-server entries
            if ($serverName -match "^(Server|Servers|NEUE SERVER|DATACENTER|STANDARD|ServerName)") {
                continue
            }
            
            # Valid server entry
            if ($serverName.Length -gt 2 -and $serverName -notmatch '^[\s\-_=]+$') {
                
                # Check if server is in strikethrough list
                if ($strikethroughServers -contains $serverName) {
                    Write-Host "     ⚠️ Skipping strikethrough server: $serverName" -ForegroundColor Gray
                    $skippedStrikethrough++
                    continue
                }
                
                $serverInfo = @{
                    ServerName = $serverName
                    Domain = if ($currentType -eq "Domain") { $currentDomain } else { "" }
                    Subdomain = $currentDomain
                    IsDomain = ($currentType -eq "Domain")
                    FullDomainName = if ($currentType -eq "Domain") { 
                        if ($serverName -notlike "*.*") { "$serverName.$currentDomain.ac.at" } else { $serverName }
                    } else { 
                        $serverName 
                    }
                }
                
                $serverList += $serverInfo
                $processedCount++
            }
        }
        
        $Global:ExcelResults.ServersTotal = $serverList.Count
        $Global:ExcelResults.DomainServers = @($serverList | Where-Object { $_.IsDomain })
        $Global:ExcelResults.WorkgroupServers = @($serverList | Where-Object { -not $_.IsDomain })
        
        Write-Host "   ✅ Parsed $processedCount servers:" -ForegroundColor Green
        Write-Host "     🏢 Domain servers: $($Global:ExcelResults.DomainServers.Count)" -ForegroundColor Cyan
        Write-Host "     🏠 Workgroup servers: $($Global:ExcelResults.WorkgroupServers.Count)" -ForegroundColor Yellow
        if ($skippedStrikethrough -gt 0) {
            Write-Host "     ⚠️ Skipped strikethrough: $skippedStrikethrough servers" -ForegroundColor Gray
        }
        Write-Host ""
        
        return $serverList
        
    } catch {
        Write-Host "   ❌ Failed to import Excel: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

function Apply-ServerFilter {
    param(
        [array]$ServerList,
        [string]$FilterType,
        [string]$FilterValue
    )
    
    Write-Host "🔍 Applying server filter..." -ForegroundColor Yellow
    Write-Host "   Filter Type: $FilterType" -ForegroundColor Gray
    Write-Host "   Filter Value: $FilterValue" -ForegroundColor Gray
    
    $filteredList = switch ($FilterType) {
        "All" { $ServerList }
        "Domain" { 
            if ($FilterValue) {
                $ServerList | Where-Object { $_.IsDomain -and $_.Domain -like "*$FilterValue*" }
            } else {
                $ServerList | Where-Object { $_.IsDomain }
            }
        }
        "Workgroup" {
            if ($FilterValue) {
                $ServerList | Where-Object { -not $_.IsDomain -and $_.Subdomain -like "*$FilterValue*" }
            } else {
                $ServerList | Where-Object { -not $_.IsDomain }
            }
        }
        "TestOnly" {
            # Filter for common test server patterns
            $ServerList | Where-Object { 
                $_.ServerName -match "(test|dev|staging|sandbox)" -or 
                $_.Subdomain -match "(test|dev|staging|sandbox)"
            }
        }
        default { $ServerList }
    }
    
    $Global:ExcelResults.ServersFiltered = $filteredList.Count
    
    Write-Host "   ✅ Filtered result: $($filteredList.Count) servers" -ForegroundColor Green
    Write-Host ""
    
    return $filteredList
}

#endregion

#region Server Analysis Functions

function Test-CertWebServiceStatus {
    param(
        [object]$ServerInfo,
        [int]$Port = 9080,
        [int]$TimeoutSeconds = 10
    )
    
    $result = @{
        ServerName = $ServerInfo.ServerName
        FullDomainName = $ServerInfo.FullDomainName
        HasCertWebService = $false
        Version = "Unknown"
        HealthStatus = "Unknown"
        ResponseTime = 0
        ErrorMessage = ""
    }
    
    try {
        $targetName = $ServerInfo.FullDomainName
        # DevSkim: ignore DS137138 - Internal network HTTP endpoint for CertWebService health check
        $healthUrl = "http://$targetName`:$Port/health.json"
        
        $startTime = Get-Date
        
        if ($Global:PSCompatibilityLoaded) {
            $response = Invoke-WebRequest-VersionSpecific -Uri $healthUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        }
        
        $result.ResponseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
        
        if ($response.StatusCode -eq 200) {
            try {
                $healthData = $response.Content | ConvertFrom-Json
                $result.HasCertWebService = $true
                $result.Version = if ($healthData.version) { $healthData.version } else { "Unknown" }
                $result.HealthStatus = if ($healthData.status) { $healthData.status } else { "Unknown" }
            } catch {
                $result.HasCertWebService = $true
                $result.Version = "Legacy"
                $result.HealthStatus = "Running"
            }
        }
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
        
        # Try alternative ports if main port failed
        if ($Port -eq 9080) {
            try {
                # DevSkim: ignore DS137138 - Internal network HTTP endpoint for alternative port testing
                $altUrl = "http://$($ServerInfo.FullDomainName):8080/health.json"
                
                if ($Global:PSCompatibilityLoaded) {
                    $altResponse = Invoke-WebRequest-VersionSpecific -Uri $altUrl -TimeoutSec 5 -UseBasicParsing
                } else {
                    $altResponse = Invoke-WebRequest -Uri $altUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
                }
                if ($altResponse.StatusCode -eq 200) {
                    $result.HasCertWebService = $true
                    $result.Version = "Port8080"
                    $result.HealthStatus = "Running"
                    $result.ErrorMessage = "Running on port 8080 instead of 9080"
                }
            } catch {
                # Port 8080 also failed, keep original error
            }
        }
    }
    
    return $result
}

function Test-ServerConnectivity-Enhanced {
    param(
        [object]$ServerInfo,
        [PSCredential]$Credential = $null
    )
    
    $result = @{
        ServerName = $ServerInfo.ServerName
        FullDomainName = $ServerInfo.FullDomainName
        Ping = $false
        SMB = $false
        PSRemoting = $false
        WMI = $false
        RecommendedMethod = "Unknown"
        ErrorMessages = @()
    }
    
    try {
        # Test 1: Ping connectivity
        $result.Ping = Test-Connection -ComputerName $ServerInfo.FullDomainName -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        if (-not $result.Ping) {
            $result.RecommendedMethod = "UNREACHABLE"
            $result.ErrorMessages += "Server not reachable via ping"
            return $result
        }
        
        # Test 2: SMB/Admin Share
        try {
            $adminShare = "\\$($ServerInfo.FullDomainName)\C$"
            $result.SMB = Test-Path $adminShare -ErrorAction SilentlyContinue
        } catch {
            $result.ErrorMessages += "SMB test failed: $($_.Exception.Message)"
        }
        
        # Test 3: WMI/CIM Access (alternative to PSRemoting)
        try {
            if ($Global:PSCompatibilityLoaded) {
                $systemInfo = Get-SystemInfo-VersionSpecific -ComputerName $ServerInfo.FullDomainName -Credential $Credential
                $result.WMI = $true
            } else {
                # Fallback to direct WMI
                if ($Credential) {
                    $systemInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ServerInfo.FullDomainName -Credential $Credential -ErrorAction Stop
                } else {
                    $systemInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ServerInfo.FullDomainName -ErrorAction Stop
                }
                $result.WMI = $true
            }
        } catch {
            $result.ErrorMessages += "WMI/CIM test failed: $($_.Exception.Message)"
        }
        
        # Test 4: PSRemoting (if not already tested in main script)
        try {
            if ($Global:PSCompatibilityLoaded) {
                $psRemotingResult = Invoke-PSRemoting-VersionSpecific -ComputerName $ServerInfo.FullDomainName -Credential $Credential -ScriptBlock { $env:COMPUTERNAME }
                $result.PSRemoting = ($psRemotingResult.Success -and $psRemotingResult.Data -eq $ServerInfo.FullDomainName)
            } else {
                # Fallback to direct Invoke-Command
                if ($Credential) {
                    # DevSkim: ignore DS104456 - Required for PSRemoting connectivity testing
                    $psTest = Invoke-Command -ComputerName $ServerInfo.FullDomainName -Credential $Credential -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
                } else {
                    # DevSkim: ignore DS104456 - Required for PSRemoting connectivity testing
                    $psTest = Invoke-Command -ComputerName $ServerInfo.FullDomainName -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
                }
                $result.PSRemoting = ($psTest -eq $ServerInfo.FullDomainName)
            }
            $result.PSRemoting = ($psTest -eq $ServerInfo.ServerName -or $psTest -eq $ServerInfo.FullDomainName)
        } catch {
            $result.ErrorMessages += "PSRemoting test failed: $($_.Exception.Message)"
        }
        
        # Determine recommended method
        if ($result.PSRemoting) {
            $result.RecommendedMethod = "PSRemoting"
        } elseif ($result.SMB -and $result.WMI) {
            $result.RecommendedMethod = "NetworkDeployment"
        } elseif ($result.SMB) {
            $result.RecommendedMethod = "ManualCopy"
        } else {
            $result.RecommendedMethod = "ManualPackage"
        }
        
    } catch {
        $result.ErrorMessages += "General connectivity test failed: $($_.Exception.Message)"
        $result.RecommendedMethod = "ERROR"
    }
    
    return $result
}

#endregion

#region Analysis and Categorization

function Analyze-ServerInventory {
    param(
        [array]$ServerList,
        [PSCredential]$Credential = $null,
        [int]$CertWebServicePort = 9080
    )
    
    Write-Host "🔍 Analyzing server inventory..." -ForegroundColor Cyan
    Write-Host "   Servers to analyze: $($ServerList.Count)" -ForegroundColor Gray
    Write-Host "   CertWebService Port: $CertWebServicePort" -ForegroundColor Gray
    Write-Host ""
    
    $analysis = @{
        TotalServers = $ServerList.Count
        CompletedAnalysis = 0
        HasCertWebService = @()
        NeedsCertWebService = @()
        Unreachable = @()
        PSRemotingAvailable = @()
        NetworkDeploymentOnly = @()
        ManualRequired = @()
        AnalysisDetails = @()
    }
    
    foreach ($serverInfo in $ServerList) {
        Write-Host "   🖥️ Analyzing: $($serverInfo.ServerName)" -ForegroundColor White
        
        # Test CertWebService status
        Write-Host "     🔍 Checking CertWebService..." -ForegroundColor Gray -NoNewline
        $certWebStatus = Test-CertWebServiceStatus -ServerInfo $serverInfo -Port $CertWebServicePort
        
        if ($certWebStatus.HasCertWebService) {
            Write-Host " ✅ Running (v$($certWebStatus.Version))" -ForegroundColor Green
            $analysis.HasCertWebService += $serverInfo
        } else {
            Write-Host " ❌ Not found" -ForegroundColor Red
            $analysis.NeedsCertWebService += $serverInfo
        }
        
        # Test connectivity capabilities
        Write-Host "     🌐 Testing connectivity..." -ForegroundColor Gray -NoNewline
        $connectivity = Test-ServerConnectivity-Enhanced -ServerInfo $serverInfo -Credential $Credential
        
        if ($connectivity.RecommendedMethod -eq "UNREACHABLE") {
            Write-Host " ❌ Unreachable" -ForegroundColor Red
            $analysis.Unreachable += $serverInfo
        } elseif ($connectivity.PSRemoting) {
            Write-Host " ✅ PSRemoting" -ForegroundColor Green
            $analysis.PSRemotingAvailable += $serverInfo
        } elseif ($connectivity.RecommendedMethod -eq "NetworkDeployment") {
            Write-Host " 🌐 Network" -ForegroundColor Cyan
            $analysis.NetworkDeploymentOnly += $serverInfo
        } else {
            Write-Host " 📦 Manual" -ForegroundColor Yellow
            $analysis.ManualRequired += $serverInfo
        }
        
        # Store detailed analysis
        $detailedAnalysis = @{
            ServerInfo = $serverInfo
            CertWebServiceStatus = $certWebStatus
            ConnectivityStatus = $connectivity
            RecommendedAction = if ($certWebStatus.HasCertWebService) { "UPDATE" } else { "INSTALL" }
            RecommendedMethod = $connectivity.RecommendedMethod
        }
        
        $analysis.AnalysisDetails += $detailedAnalysis
        $analysis.CompletedAnalysis++
        
        Write-Host ""
    }
    
    return $analysis
}

function Show-AnalysisResults {
    param([object]$Analysis)
    
    Write-Host "📊 SERVER INVENTORY ANALYSIS RESULTS" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📈 Overall Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Servers Analyzed: $($Analysis.TotalServers)" -ForegroundColor White
    Write-Host "   Analysis Completed: $($Analysis.CompletedAnalysis)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🎯 CertWebService Status:" -ForegroundColor Yellow
    Write-Host "   ✅ Already Installed: $($Analysis.HasCertWebService.Count)" -ForegroundColor Green
    Write-Host "   📦 Needs Installation: $($Analysis.NeedsCertWebService.Count)" -ForegroundColor Red
    Write-Host "   ❌ Unreachable: $($Analysis.Unreachable.Count)" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "🔧 Deployment Capabilities:" -ForegroundColor Yellow
    Write-Host "   🚀 PSRemoting Available: $($Analysis.PSRemotingAvailable.Count)" -ForegroundColor Green
    Write-Host "   🌐 Network Deployment: $($Analysis.NetworkDeploymentOnly.Count)" -ForegroundColor Cyan
    Write-Host "   📋 Manual Required: $($Analysis.ManualRequired.Count)" -ForegroundColor Yellow
    Write-Host ""
    
    # Show servers that already have CertWebService
    if ($Analysis.HasCertWebService.Count -gt 0) {
        Write-Host "✅ Servers with CertWebService (Update candidates):" -ForegroundColor Green
        foreach ($server in $Analysis.HasCertWebService) {
            $details = $Analysis.AnalysisDetails | Where-Object { $_.ServerInfo.ServerName -eq $server.ServerName }
            $version = $details.CertWebServiceStatus.Version
            $method = $details.ConnectivityStatus.RecommendedMethod
            Write-Host "   🖥️ $($server.ServerName) (v$version) [$method]" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Show servers that need CertWebService installation
    if ($Analysis.NeedsCertWebService.Count -gt 0) {
        Write-Host "📦 Servers needing CertWebService installation:" -ForegroundColor Red
        foreach ($server in $Analysis.NeedsCertWebService) {
            $details = $Analysis.AnalysisDetails | Where-Object { $_.ServerInfo.ServerName -eq $server.ServerName }
            $method = $details.ConnectivityStatus.RecommendedMethod
            Write-Host "   🖥️ $($server.ServerName) [$method]" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Show unreachable servers
    if ($Analysis.Unreachable.Count -gt 0) {
        Write-Host "❌ Unreachable servers:" -ForegroundColor Red
        foreach ($server in $Analysis.Unreachable) {
            Write-Host "   🖥️ $($server.ServerName)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

#endregion

#region Main Execution Logic

function Start-ExcelBasedMassUpdate {
    try {
        # Step 1: Import server list from Excel
        $serverList = Import-ServerListFromExcel -ExcelPath $ExcelPath -WorksheetName $WorksheetName -Config $config
        
        if ($serverList.Count -eq 0) {
            throw "No servers found in Excel file"
        }
        
        # Step 2: Apply filters
        $filteredServers = Apply-ServerFilter -ServerList $serverList -FilterType $FilterType -FilterValue $FilterValue
        
        if ($filteredServers.Count -eq 0) {
            throw "No servers match the specified filter criteria"
        }
        
        # Step 3: Get credentials if not in analyze-only mode
        $adminCredential = $null
        if (-not $AnalyzeOnly -and -not $TestConnectivityOnly) {
            Write-Host "🔐 Using 3-tier credential strategy (Default -> Vault -> Prompt)..." -ForegroundColor Yellow
            $adminCredential = Get-OrPromptCredential -Target "CertWebService-MassUpdate" -Username "Administrator" -AutoSave
            if (-not $adminCredential) {
                throw "Administrator credentials are required for deployment operations"
            }
        }
        
        # Step 4: Analyze server inventory
        $analysis = Analyze-ServerInventory -ServerList $filteredServers -Credential $adminCredential -CertWebServicePort $CertWebServicePort
        
        # Step 5: Show analysis results
        Show-AnalysisResults -Analysis $analysis
        
        # Step 6: Exit if analyze-only mode
        if ($AnalyzeOnly) {
            Write-Host "📋 Analysis completed. Use -AnalyzeOnly:`$false to proceed with deployment." -ForegroundColor Yellow
            return
        }
        
        if ($TestConnectivityOnly) {
            Write-Host "🔍 Connectivity test completed." -ForegroundColor Green
            return
        }
        
        if ($DryRun) {
            Write-Host "🧪 DRY RUN MODE - No actual deployments will be performed" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "PLANNED ACTIONS:" -ForegroundColor Cyan
            Write-Host "   📦 New Installations: $($analysis.NeedsCertWebService.Count) servers" -ForegroundColor Yellow
            Write-Host "   🔄 Updates: $($analysis.HasCertWebService.Count) servers" -ForegroundColor Cyan
            Write-Host "   🚀 PSRemoting Deployments: $($analysis.PSRemotingAvailable.Count) servers" -ForegroundColor Green
            Write-Host "   🌐 Network Deployments: $($analysis.NetworkDeploymentOnly.Count) servers" -ForegroundColor Cyan
            Write-Host "   📋 Manual Packages: $($analysis.ManualRequired.Count) servers" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To execute deployment:" -ForegroundColor Yellow
            Write-Host "   Remove -DryRun parameter and run again" -ForegroundColor White
            return
        }
        
        # Step 7: Execute deployment (this would integrate with existing hybrid update system)
        Write-Host "🚀 DEPLOYMENT PHASE" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "📋 Ready to execute mass deployment..." -ForegroundColor Yellow
        Write-Host "   Integration with existing Update-AllServers-Hybrid.ps1 system..." -ForegroundColor Gray
        Write-Host ""
        
        # Prepare server list for hybrid update system
        $hybridServerList = @()
        foreach ($server in $filteredServers) {
            $hybridServerList += $server.FullDomainName
        }
        
        # Call existing hybrid update system
        $hybridUpdatePath = Join-Path $PSScriptRoot "Update-AllServers-Hybrid.ps1"
        if (Test-Path $hybridUpdatePath) {
            Write-Host "▶️ Executing hybrid update system..." -ForegroundColor Green
            & $hybridUpdatePath -ServerList $hybridServerList -AdminCredential $adminCredential -GenerateReports
        } else {
            Write-Host "⚠️ Hybrid update system not found: $hybridUpdatePath" -ForegroundColor Yellow
            Write-Host "   Deployment would continue with individual server processing..." -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "❌ Excel-based mass update failed: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

#endregion

#region Configuration Loading

# Load Excel path and worksheet from config if not provided
if ([string]::IsNullOrEmpty($ExcelPath) -or [string]::IsNullOrEmpty($WorksheetName)) {
    Write-Host "📋 Loading configuration from config file..." -ForegroundColor Yellow
    
    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            
            if ([string]::IsNullOrEmpty($ExcelPath)) {
                $ExcelPath = $config.ExcelFilePath
                Write-Host "   ✅ Excel path from config: $ExcelPath" -ForegroundColor Green
            }
            
            if ([string]::IsNullOrEmpty($WorksheetName)) {
                $WorksheetName = $config.ExcelWorksheet
                Write-Host "   ✅ Worksheet from config: $WorksheetName" -ForegroundColor Green
            }
            
        } else {
            Write-Host "   ⚠️ Config file not found: $ConfigPath" -ForegroundColor Yellow
            
            # Set fallback defaults
            if ([string]::IsNullOrEmpty($ExcelPath)) {
                $ExcelPath = "F:\DEV\repositories\Data\Serverliste2025.xlsx"
            }
            if ([string]::IsNullOrEmpty($WorksheetName)) {
                $WorksheetName = "Servers"
            }
            
            Write-Host "   📝 Using fallback defaults" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "   ❌ Config loading failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Set fallback defaults
        if ([string]::IsNullOrEmpty($ExcelPath)) {
            $ExcelPath = "F:\DEV\repositories\Data\Serverliste2025.xlsx"
        }
        if ([string]::IsNullOrEmpty($WorksheetName)) {
            $WorksheetName = "Servers"
        }
        
        Write-Host "   📝 Using fallback defaults due to config error" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Make config available globally for functions
$Global:SystemConfig = $config

#endregion

#region Main Execution

try {
    # Verify Excel file exists
    if (-not (Test-Path $ExcelPath)) {
        throw "Excel file not found: $ExcelPath`nConfig file checked: $ConfigPath`nPlease verify ExcelFilePath in config or provide valid -ExcelPath parameter"
    }
    
    Write-Host "📋 Configuration:" -ForegroundColor Yellow
    Write-Host "   Excel File: $ExcelPath" -ForegroundColor Gray
    Write-Host "   Worksheet: $WorksheetName" -ForegroundColor Gray
    Write-Host "   Filter: $FilterType $(if($FilterValue){"($FilterValue)"})" -ForegroundColor Gray
    Write-Host "   Port: $CertWebServicePort" -ForegroundColor Gray
    Write-Host "   Mode: $(if($AnalyzeOnly){"Analysis Only"}elseif($TestConnectivityOnly){"Test Connectivity"}elseif($DryRun){"Dry Run"}else{"Full Deployment"})" -ForegroundColor Gray
    Write-Host ""
    
    # Execute main logic
    Start-ExcelBasedMassUpdate
    
    $endTime = Get-Date
    $duration = $endTime - $Script:StartTime
    
    Write-Host "🏁 Excel-based mass update completed!" -ForegroundColor Green
    Write-Host "   Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host "   End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}

#endregion
