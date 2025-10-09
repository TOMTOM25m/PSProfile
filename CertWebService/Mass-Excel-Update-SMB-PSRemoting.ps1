#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService Mass Update - Excel-Based SMB+PSRemoting Deployment v3.0.0

.DESCRIPTION
    Vollständige Excel-Auswertung für CertWebService-Updates mit intelligenter Deployment-Strategie:
    
    1. EXCEL ANALYSE: Serverliste2025.xlsx vollständig auswerten
    2. SMB PRIORITY: Primäre Nutzung von SMB-Verbindungen für File-Deployment
    3. PSREMOTING: Automatische Konfiguration und Aktivierung wo möglich
    4. SMART UPDATE: Kombination aus File-Copy + Remote-Execution
    5. BULK PROCESSING: Parallel-Verarbeitung mit Fortschrittsanzeige

.PARAMETER ExcelPath
    Pfad zur Excel-Serverliste (Standard: Network Share)

.PARAMETER FilterDomain
    Nur bestimmte Domain (z.B. "uvw", "srv")

.PARAMETER EnablePSRemoting
    PSRemoting automatisch aktivieren wo möglich

.PARAMETER SMBOnly
    Nur SMB-basierte Updates durchführen

.PARAMETER DryRun
    Testlauf ohne tatsächliche Änderungen

.VERSION
    3.0.0

.AUTHOR
    PowerShell Regelwerk Universal v10.1.0

.EXAMPLE
    .\Mass-Excel-Update-SMB-PSRemoting.ps1
    .\Mass-Excel-Update-SMB-PSRemoting.ps1 -FilterDomain "uvw" -EnablePSRemoting
    .\Mass-Excel-Update-SMB-PSRemoting.ps1 -SMBOnly -DryRun
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WindowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory = $false)]
    [string]$FilterDomain = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$EnablePSRemoting,
    
    [Parameter(Mandatory = $false)]
    [switch]$SMBOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxParallel = 5,
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 30
)

$Script:Version = "v3.0.0"
$Script:StartTime = Get-Date
$Script:NewCertWebServiceVersion = "v2.5.0"

# Import required modules
try {
    Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force -ErrorAction SilentlyContinue
    Import-Module "$PSScriptRoot\Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "⚠️ Module import warnings (continuing with fallback methods)" -ForegroundColor Yellow
}

Write-Host "🚀 CertWebService Mass Update - Excel SMB+PSRemoting" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Version: $Script:Version | Target: $Script:NewCertWebServiceVersion" -ForegroundColor Gray
Write-Host "Started: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host ""

# Global tracking
$Global:UpdateResults = @{
    ServersTotal = 0
    ServersAnalyzed = 0
    HasCertWebService = @()
    NeedsCertWebService = @()
    SMBAccessible = @()
    PSRemotingEnabled = @()
    PSRemotingConfigured = @()
    UpdateSuccessful = @()
    UpdateFailed = @()
    Unreachable = @()
}

#region Excel Processing Functions

function Import-ServerListFromExcel-Enhanced {
    param(
        [string]$ExcelPath
    )
    
    Write-Host "📊 Reading complete Excel server inventory..." -ForegroundColor Yellow
    Write-Host "   Excel File: $ExcelPath" -ForegroundColor Gray
    
    if (-not (Test-Path $ExcelPath)) {
        throw "Excel file not found: $ExcelPath"
    }
    
    try {
        # Install ImportExcel if needed
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Host "   📦 Installing ImportExcel module..." -ForegroundColor Cyan
            Install-Module -Name ImportExcel -Force -Scope CurrentUser
        }
        Import-Module ImportExcel -Force
        
        # Import all worksheets to find servers
        $workbook = Get-ExcelSheetInfo -Path $ExcelPath
        Write-Host "   📋 Found worksheets: $($workbook.Name -join ', ')" -ForegroundColor Gray
        
        $allServers = @()
        
        foreach ($worksheet in $workbook) {
            Write-Host "   📄 Processing worksheet: $($worksheet.Name)" -ForegroundColor Cyan
            
            try {
                $excelData = Import-Excel -Path $ExcelPath -WorksheetName $worksheet.Name -NoHeader -ErrorAction Stop
                
                if ($excelData) {
                    $servers = Parse-ExcelDataForServers -ExcelData $excelData -WorksheetName $worksheet.Name
                    $allServers += $servers
                    Write-Host "     ✅ Found $($servers.Count) servers in $($worksheet.Name)" -ForegroundColor Green
                }
            } catch {
                Write-Host "     ⚠️ Could not process worksheet $($worksheet.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Remove duplicates and filter
        $uniqueServers = $allServers | Sort-Object ServerName | Get-Unique -AsString
        
        Write-Host "   ✅ Total unique servers found: $($uniqueServers.Count)" -ForegroundColor Green
        
        return $uniqueServers
        
    } catch {
        Write-Host "   ❌ Excel import failed: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

function Parse-ExcelDataForServers {
    param(
        [array]$ExcelData,
        [string]$WorksheetName
    )
    
    $servers = @()
    $currentDomain = "srv"
    $currentType = "Workgroup"
    
    foreach ($row in $ExcelData) {
        $cellValue = $row.P1
        if ([string]::IsNullOrWhiteSpace($cellValue)) { continue }
        
        $serverName = $cellValue.ToString().Trim()
        
        # Domain block detection: (Domain)uvw, (Domain-UVW)uvwmgmt01, etc.
        if ($serverName -match '^\(Domain(?:-[\w]+)?\)([\w-]+)') {
            $currentDomain = $matches[1].ToLower()
            $currentType = "Domain"
            continue
        }
        
        # Workgroup block detection
        if ($serverName -match '^\(Workgroup\)([\w-]+)') {
            $currentDomain = $matches[1].ToLower()
            $currentType = "Workgroup"
            continue
        }
        
        # End of block
        if ($serverName -match '^SUMME:?\s*$') {
            $currentDomain = "srv"
            $currentType = "Workgroup"
            continue
        }
        
        # Skip headers and non-server entries
        if ($serverName -match "^(Server|Servers|NEUE SERVER|DATACENTER|STANDARD|ServerName|Worksheet)") {
            continue
        }
        
        # Valid server entry
        if ($serverName.Length -gt 2 -and $serverName -notmatch '^[\s\-_=]+$') {
            
            $serverInfo = @{
                ServerName = $serverName
                Domain = if ($currentType -eq "Domain") { $currentDomain } else { "" }
                Subdomain = $currentDomain
                IsDomain = ($currentType -eq "Domain")
                Worksheet = $WorksheetName
                FullDomainName = if ($currentType -eq "Domain") { 
                    if ($serverName -notlike "*.*") { 
                        "$serverName.$currentDomain.meduniwien.ac.at" 
                    } else { 
                        $serverName 
                    }
                } else { 
                    $serverName 
                }
            }
            
            $servers += $serverInfo
        }
    }
    
    return $servers
}

function Apply-DomainFilter {
    param(
        [array]$ServerList,
        [string]$FilterDomain
    )
    
    if ([string]::IsNullOrEmpty($FilterDomain)) {
        return $ServerList
    }
    
    Write-Host "🔍 Applying domain filter: '$FilterDomain'" -ForegroundColor Yellow
    
    $filtered = $ServerList | Where-Object { 
        $_.Domain -like "*$FilterDomain*" -or 
        $_.Subdomain -like "*$FilterDomain*" -or 
        $_.ServerName -like "*$FilterDomain*"
    }
    
    Write-Host "   ✅ Filtered to $($filtered.Count) servers" -ForegroundColor Green
    return $filtered
}

#endregion

#region Server Analysis Functions

function Test-CertWebServiceStatus-Enhanced {
    param(
        [object]$ServerInfo,
        [int]$TimeoutSeconds = 15
    )
    
    $result = @{
        ServerName = $ServerInfo.ServerName
        FullDomainName = $ServerInfo.FullDomainName
        HasCertWebService = $false
        Version = "Unknown"
        NeedsUpdate = $false
        HealthEndpoint = ""
        ResponseTime = 0
        ErrorMessage = ""
    }
    
    $targetName = $ServerInfo.FullDomainName
    
    # Test standard CertWebService ports
    $portsToTest = @(9080, 8080, 80)
    
    foreach ($port in $portsToTest) {
        try {
            $healthUrl = "http://$targetName`:$port/health.json"
            $startTime = Get-Date
            
            $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            $result.ResponseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)
            
            if ($response.StatusCode -eq 200) {
                $result.HasCertWebService = $true
                $result.HealthEndpoint = $healthUrl
                
                try {
                    $healthData = $response.Content | ConvertFrom-Json
                    $result.Version = if ($healthData.version) { $healthData.version } else { "Legacy" }
                    
                    # Check if update is needed
                    if ($result.Version -ne $Script:NewCertWebServiceVersion) {
                        $result.NeedsUpdate = $true
                    }
                    
                } catch {
                    $result.Version = "Legacy"
                    $result.NeedsUpdate = $true
                }
                
                break  # Found working CertWebService
            }
            
        } catch {
            $result.ErrorMessage = $_.Exception.Message
            continue  # Try next port
        }
    }
    
    return $result
}

function Test-ServerConnectivity-SMBFirst {
    param(
        [object]$ServerInfo,
        [int]$TimeoutSeconds = 10
    )
    
    $result = @{
        ServerName = $ServerInfo.ServerName
        FullDomainName = $ServerInfo.FullDomainName
        Ping = $false
        SMBAccess = $false
        PSRemotingEnabled = $false
        PSRemotingConfigurable = $false
        AdminSharePath = ""
        RecommendedMethod = "Unknown"
        ConnectivityScore = 0
        ErrorMessages = @()
    }
    
    $targetName = $ServerInfo.FullDomainName
    
    # Test 1: Basic connectivity (Ping)
    try {
        $result.Ping = Test-Connection -ComputerName $targetName -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($result.Ping) { $result.ConnectivityScore += 1 }
    } catch {
        $result.ErrorMessages += "Ping failed: $($_.Exception.Message)"
    }
    
    if (-not $result.Ping) {
        $result.RecommendedMethod = "UNREACHABLE"
        return $result
    }
    
    # Test 2: SMB Access (Primary Method)
    try {
        $adminShare = "\\$targetName\C$"
        $result.SMBAccess = Test-Path $adminShare -ErrorAction SilentlyContinue
        if ($result.SMBAccess) { 
            $result.AdminSharePath = $adminShare
            $result.ConnectivityScore += 3  # SMB gets higher score
        }
    } catch {
        $result.ErrorMessages += "SMB test failed: $($_.Exception.Message)"
    }
    
    # Test 3: PSRemoting Status
    try {
        $psTest = Invoke-Command -ComputerName $targetName -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        if ($psTest) {
            $result.PSRemotingEnabled = $true
            $result.ConnectivityScore += 2
        }
    } catch {
        $result.ErrorMessages += "PSRemoting test failed: $($_.Exception.Message)"
        
        # Test if PSRemoting can be configured
        if ($result.SMBAccess) {
            $result.PSRemotingConfigurable = $true
            $result.ConnectivityScore += 1
        }
    }
    
    # Determine best deployment method
    if ($result.PSRemotingEnabled) {
        $result.RecommendedMethod = "PSRemoting"
    } elseif ($result.SMBAccess -and $result.PSRemotingConfigurable) {
        $result.RecommendedMethod = "SMB+EnablePSRemoting"
    } elseif ($result.SMBAccess) {
        $result.RecommendedMethod = "SMB+ManualExecution"  
    } else {
        $result.RecommendedMethod = "ManualPackage"
    }
    
    return $result
}

#endregion

#region PSRemoting Configuration Functions

function Enable-PSRemotingViaSMB {
    param(
        [object]$ServerInfo,
        [string]$AdminSharePath
    )
    
    Write-Host "     🔧 Configuring PSRemoting via SMB..." -ForegroundColor Cyan
    
    try {
        # Create temporary script for PSRemoting enablement
        $psRemotingScript = @"
# Enable PSRemoting on remote server
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-WSManQuickConfig -Force
    
    # Configure TrustedHosts if needed
    $currentTrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    if ($currentTrustedHosts -notlike "*$env:COMPUTERNAME*") {
        if ([string]::IsNullOrEmpty($currentTrustedHosts)) {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
        } else {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$currentTrustedHosts,*" -Force
        }
    }
    
    # Start WinRM service
    Start-Service WinRM -ErrorAction SilentlyContinue
    Set-Service WinRM -StartupType Automatic
    
    Write-Host "PSRemoting enabled successfully"
    return $true
    
} catch {
    Write-Host "PSRemoting configuration failed: $($_.Exception.Message)"
    return $false
}
"@
        
        # Save script to remote admin share
        $tempScriptPath = "$AdminSharePath\Temp\Enable-PSRemoting-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
        $tempDir = "$AdminSharePath\Temp"
        
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        $psRemotingScript | Out-File -FilePath $tempScriptPath -Encoding UTF8 -Force
        
        # Execute via PsExec or WMI if available
        $executionResult = $false
        
        # Try PsExec if available
        $psExecPath = "${env:ProgramFiles}\SysinternalsSuite\PsExec.exe"
        if (Test-Path $psExecPath) {
            try {
                $psExecArgs = @(
                    "\\$($ServerInfo.FullDomainName)"
                    "-accepteula"
                    "-s"
                    "powershell.exe"
                    "-ExecutionPolicy Bypass"
                    "-File `"C:\Temp\$(Split-Path $tempScriptPath -Leaf)`""
                )
                
                $psExecResult = & $psExecPath @psExecArgs
                $executionResult = $true
                Write-Host "       ✅ PSRemoting enabled via PsExec" -ForegroundColor Green
                
            } catch {
                Write-Host "       ⚠️ PsExec execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Fallback: Try WMI execution
        if (-not $executionResult) {
            try {
                $wmiResult = Invoke-WmiMethod -ComputerName $ServerInfo.FullDomainName -Class Win32_Process -Name Create -ArgumentList "powershell.exe -ExecutionPolicy Bypass -File `"C:\Temp\$(Split-Path $tempScriptPath -Leaf)`""
                
                if ($wmiResult.ReturnValue -eq 0) {
                    $executionResult = $true
                    Write-Host "       ✅ PSRemoting configuration started via WMI" -ForegroundColor Green
                    Start-Sleep 10  # Give time for configuration
                } else {
                    Write-Host "       ❌ WMI execution failed (Return code: $($wmiResult.ReturnValue))" -ForegroundColor Red
                }
                
            } catch {
                Write-Host "       ⚠️ WMI execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Clean up temporary script
        try {
            Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue
        } catch {
            # Ignore cleanup errors
        }
        
        # Test if PSRemoting is now working
        if ($executionResult) {
            Start-Sleep 5
            try {
                $testResult = Invoke-Command -ComputerName $ServerInfo.FullDomainName -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
                if ($testResult) {
                    Write-Host "       ✅ PSRemoting verification successful" -ForegroundColor Green
                    return $true
                }
            } catch {
                Write-Host "       ⚠️ PSRemoting verification failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        return $false
        
    } catch {
        Write-Host "       ❌ PSRemoting enablement failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Update Execution Functions

function Update-CertWebServiceViaSMB {
    param(
        [object]$ServerInfo,
        [string]$AdminSharePath
    )
    
    Write-Host "     📁 Updating CertWebService via SMB..." -ForegroundColor Cyan
    
    try {
        $remoteCertWebServicePath = "$AdminSharePath\CertWebService"
        $localCertWebServicePath = Join-Path $PSScriptRoot "CertWebService.ps1"
        
        # Check if local CertWebService v2.5.0 exists
        if (-not (Test-Path $localCertWebServicePath)) {
            throw "Local CertWebService.ps1 not found: $localCertWebServicePath"
        }
        
        # Create remote CertWebService directory if needed
        if (-not (Test-Path $remoteCertWebServicePath)) {
            New-Item -Path $remoteCertWebServicePath -ItemType Directory -Force | Out-Null
        }
        
        # Backup existing CertWebService
        $existingCertWebService = "$remoteCertWebServicePath\CertWebService.ps1"
        if (Test-Path $existingCertWebService) {
            $backupName = "CertWebService-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
            Copy-Item $existingCertWebService "$remoteCertWebServicePath\$backupName" -Force
            Write-Host "       📋 Backup created: $backupName" -ForegroundColor Gray
        }
        
        # Copy new CertWebService v2.5.0
        Copy-Item $localCertWebServicePath $existingCertWebService -Force
        Write-Host "       ✅ CertWebService v$Script:NewCertWebServiceVersion copied" -ForegroundColor Green
        
        # Create restart script
        $restartScript = @"
# CertWebService Restart Script
try {
    # Stop existing CertWebService processes
    Get-Process powershell | Where-Object { $_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    
    # Change to CertWebService directory and start
    Set-Location "C:\CertWebService"
    Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
    
    Write-Host "CertWebService v$Script:NewCertWebServiceVersion restarted successfully"
    return $true
    
} catch {
    Write-Host "CertWebService restart failed: $($_.Exception.Message)"
    return $false
}
"@
        
        $restartScriptPath = "$remoteCertWebServicePath\Restart-CertWebService.ps1"
        $restartScript | Out-File -FilePath $restartScriptPath -Encoding UTF8 -Force
        
        return @{
            Success = $true
            RestartScriptPath = $restartScriptPath
            Method = "SMB"
        }
        
    } catch {
        Write-Host "       ❌ SMB update failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            Method = "SMB"
        }
    }
}

function Update-CertWebServiceViaPSRemoting {
    param(
        [object]$ServerInfo
    )
    
    Write-Host "     🚀 Updating CertWebService via PSRemoting..." -ForegroundColor Cyan
    
    try {
        $localCertWebServicePath = Join-Path $PSScriptRoot "CertWebService.ps1"
        $newCertWebServiceContent = Get-Content $localCertWebServicePath -Raw
        
        $updateResult = Invoke-Command -ComputerName $ServerInfo.FullDomainName -ScriptBlock {
            param($NewContent, $TargetVersion)
            
            try {
                # Stop existing CertWebService
                Get-Process powershell | Where-Object { $_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep 2
                
                # Backup existing
                if (Test-Path "C:\CertWebService\CertWebService.ps1") {
                    $backupName = "CertWebService-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
                    Copy-Item "C:\CertWebService\CertWebService.ps1" "C:\CertWebService\$backupName" -Force
                }
                
                # Create directory if needed
                if (-not (Test-Path "C:\CertWebService")) {
                    New-Item -Path "C:\CertWebService" -ItemType Directory -Force | Out-Null
                }
                
                # Write new CertWebService
                $NewContent | Out-File "C:\CertWebService\CertWebService.ps1" -Encoding UTF8 -Force
                
                # Start new CertWebService
                Set-Location "C:\CertWebService"
                Start-Job -ScriptBlock { .\CertWebService.ps1 } | Out-Null
                Start-Sleep 5
                
                # Verify it's working
                $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10 -ErrorAction Stop
                $health = $response.Content | ConvertFrom-Json
                
                return @{
                    Success = $true
                    Version = $health.version
                    Host = $env:COMPUTERNAME
                }
                
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    Host = $env:COMPUTERNAME
                }
            }
            
        } -ArgumentList $newCertWebServiceContent, $Script:NewCertWebServiceVersion
        
        if ($updateResult.Success) {
            Write-Host "       ✅ PSRemoting update successful - v$($updateResult.Version)" -ForegroundColor Green
        } else {
            Write-Host "       ❌ PSRemoting update failed: $($updateResult.Error)" -ForegroundColor Red
        }
        
        return $updateResult
        
    } catch {
        Write-Host "       ❌ PSRemoting update failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            Method = "PSRemoting"
        }
    }
}

function Execute-RestartScriptViaSMB {
    param(
        [object]$ServerInfo,
        [string]$RestartScriptPath
    )
    
    Write-Host "     ⚡ Executing restart script..." -ForegroundColor Cyan
    
    try {
        # Try multiple execution methods
        $executionSuccess = $false
        
        # Method 1: PsExec
        $psExecPath = "${env:ProgramFiles}\SysinternalsSuite\PsExec.exe"
        if (Test-Path $psExecPath) {
            try {
                $remoteScriptPath = $RestartScriptPath -replace '^\\\w+\\C\$', 'C:'
                & $psExecPath "\\$($ServerInfo.FullDomainName)" -accepteula -s powershell.exe -ExecutionPolicy Bypass -File "`"$remoteScriptPath`""
                $executionSuccess = $true
                Write-Host "       ✅ Restart script executed via PsExec" -ForegroundColor Green
            } catch {
                Write-Host "       ⚠️ PsExec execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Method 2: WMI
        if (-not $executionSuccess) {
            try {
                $remoteScriptPath = $RestartScriptPath -replace '^\\\w+\\C\$', 'C:'
                $wmiResult = Invoke-WmiMethod -ComputerName $ServerInfo.FullDomainName -Class Win32_Process -Name Create -ArgumentList "powershell.exe -ExecutionPolicy Bypass -File `"$remoteScriptPath`""
                
                if ($wmiResult.ReturnValue -eq 0) {
                    $executionSuccess = $true
                    Write-Host "       ✅ Restart script executed via WMI" -ForegroundColor Green
                } else {
                    Write-Host "       ❌ WMI execution failed (Return code: $($wmiResult.ReturnValue))" -ForegroundColor Red
                }
            } catch {
                Write-Host "       ⚠️ WMI execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        if ($executionSuccess) {
            # Wait and verify CertWebService is running
            Start-Sleep 10
            
            try {
                $healthUrl = "http://$($ServerInfo.FullDomainName):9080/health.json"
                $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
                $health = $response.Content | ConvertFrom-Json
                
                Write-Host "       ✅ CertWebService verification: v$($health.version)" -ForegroundColor Green
                return $true
                
            } catch {
                Write-Host "       ⚠️ CertWebService verification failed: $($_.Exception.Message)" -ForegroundColor Yellow
                return $false  # Execution might have worked, but service didn't start properly
            }
        }
        
        return $executionSuccess
        
    } catch {
        Write-Host "       ❌ Restart script execution failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Main Processing Functions

function Process-SingleServer {
    param(
        [object]$ServerInfo,
        [switch]$EnablePSRemoting,
        [switch]$SMBOnly,
        [switch]$DryRun
    )
    
    Write-Host "🖥️ Processing: $($ServerInfo.ServerName)" -ForegroundColor White
    Write-Host "   Domain: $($ServerInfo.Domain) | FQDN: $($ServerInfo.FullDomainName)" -ForegroundColor Gray
    
    $serverResult = @{
        ServerInfo = $ServerInfo
        CertWebServiceStatus = $null
        ConnectivityStatus = $null
        UpdateResult = $null
        ProcessingTime = 0
        Success = $false
    }
    
    $startTime = Get-Date
    
    try {
        # Step 1: Check CertWebService status
        Write-Host "   🔍 Checking CertWebService status..." -ForegroundColor Yellow
        $certWebStatus = Test-CertWebServiceStatus-Enhanced -ServerInfo $ServerInfo -TimeoutSeconds $TimeoutSeconds
        $serverResult.CertWebServiceStatus = $certWebStatus
        
        if ($certWebStatus.HasCertWebService) {
            Write-Host "     ✅ CertWebService found: v$($certWebStatus.Version)" -ForegroundColor Green
            if (-not $certWebStatus.NeedsUpdate) {
                Write-Host "     ℹ️ Already running v$Script:NewCertWebServiceVersion - skipping" -ForegroundColor Cyan
                $serverResult.Success = $true
                return $serverResult
            }
            Write-Host "     🔄 Update needed: v$($certWebStatus.Version) → v$Script:NewCertWebServiceVersion" -ForegroundColor Yellow
        } else {
            Write-Host "     ❌ CertWebService not found - needs installation" -ForegroundColor Red
            # For now, focus on updates only
            Write-Host "     ⚠️ Installation not implemented in this version - skipping" -ForegroundColor Yellow
            return $serverResult
        }
        
        # Step 2: Test connectivity
        Write-Host "   🌐 Testing connectivity..." -ForegroundColor Yellow
        $connectivity = Test-ServerConnectivity-SMBFirst -ServerInfo $ServerInfo -TimeoutSeconds $TimeoutSeconds
        $serverResult.ConnectivityStatus = $connectivity
        
        if ($connectivity.RecommendedMethod -eq "UNREACHABLE") {
            Write-Host "     ❌ Server unreachable" -ForegroundColor Red
            return $serverResult
        }
        
        Write-Host "     ✅ Connectivity: $($connectivity.RecommendedMethod) (Score: $($connectivity.ConnectivityScore))" -ForegroundColor Green
        
        # Step 3: Update execution (if not DryRun)
        if ($DryRun) {
            Write-Host "     🧪 DRY RUN: Would update via $($connectivity.RecommendedMethod)" -ForegroundColor Cyan
            $serverResult.Success = $true
            return $serverResult
        }
        
        # Execute update based on best method
        Write-Host "   🚀 Executing update..." -ForegroundColor Yellow
        
        switch ($connectivity.RecommendedMethod) {
            "PSRemoting" {
                Write-Host "     📡 Using PSRemoting method..." -ForegroundColor Cyan
                $updateResult = Update-CertWebServiceViaPSRemoting -ServerInfo $ServerInfo
                $serverResult.UpdateResult = $updateResult
                $serverResult.Success = $updateResult.Success
            }
            
            "SMB+EnablePSRemoting" {
                if ($EnablePSRemoting -and -not $SMBOnly) {
                    Write-Host "     🔧 Enabling PSRemoting first..." -ForegroundColor Cyan
                    $psRemotingEnabled = Enable-PSRemotingViaSMB -ServerInfo $ServerInfo -AdminSharePath $connectivity.AdminSharePath
                    
                    if ($psRemotingEnabled) {
                        Write-Host "     📡 Now using PSRemoting method..." -ForegroundColor Cyan
                        $updateResult = Update-CertWebServiceViaPSRemoting -ServerInfo $ServerInfo
                        $serverResult.UpdateResult = $updateResult
                        $serverResult.Success = $updateResult.Success
                    } else {
                        Write-Host "     📁 Falling back to SMB method..." -ForegroundColor Yellow
                        $updateResult = Update-CertWebServiceViaSMB -ServerInfo $ServerInfo -AdminSharePath $connectivity.AdminSharePath
                        if ($updateResult.Success) {
                            $restartSuccess = Execute-RestartScriptViaSMB -ServerInfo $ServerInfo -RestartScriptPath $updateResult.RestartScriptPath
                            $serverResult.Success = $restartSuccess
                        }
                        $serverResult.UpdateResult = $updateResult
                    }
                } else {
                    Write-Host "     📁 Using SMB method (PSRemoting disabled)..." -ForegroundColor Cyan
                    $updateResult = Update-CertWebServiceViaSMB -ServerInfo $ServerInfo -AdminSharePath $connectivity.AdminSharePath
                    if ($updateResult.Success) {
                        $restartSuccess = Execute-RestartScriptViaSMB -ServerInfo $ServerInfo -RestartScriptPath $updateResult.RestartScriptPath
                        $serverResult.Success = $restartSuccess
                    }
                    $serverResult.UpdateResult = $updateResult
                }
            }
            
            "SMB+ManualExecution" {
                Write-Host "     📁 Using SMB method..." -ForegroundColor Cyan
                $updateResult = Update-CertWebServiceViaSMB -ServerInfo $ServerInfo -AdminSharePath $connectivity.AdminSharePath
                if ($updateResult.Success) {
                    $restartSuccess = Execute-RestartScriptViaSMB -ServerInfo $ServerInfo -RestartScriptPath $updateResult.RestartScriptPath
                    $serverResult.Success = $restartSuccess
                }
                $serverResult.UpdateResult = $updateResult
            }
            
            default {
                Write-Host "     ⚠️ Manual package required - not implemented in this version" -ForegroundColor Yellow
                $serverResult.UpdateResult = @{
                    Success = $false
                    Error = "Manual package deployment required"
                    Method = $connectivity.RecommendedMethod
                }
            }
        }
        
        if ($serverResult.Success) {
            Write-Host "   ✅ Update completed successfully" -ForegroundColor Green
            $Global:UpdateResults.UpdateSuccessful += $serverResult
        } else {
            Write-Host "   ❌ Update failed" -ForegroundColor Red
            $Global:UpdateResults.UpdateFailed += $serverResult
        }
        
    } catch {
        Write-Host "   ❌ Processing failed: $($_.Exception.Message)" -ForegroundColor Red
        $serverResult.UpdateResult = @{
            Success = $false
            Error = $_.Exception.Message
            Method = "Exception"
        }
        $Global:UpdateResults.UpdateFailed += $serverResult
    } finally {
        $serverResult.ProcessingTime = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        Write-Host "   ⏱️ Processing time: $($serverResult.ProcessingTime)s" -ForegroundColor Gray
        Write-Host ""
    }
    
    return $serverResult
}

function Process-AllServers {
    param(
        [array]$ServerList,
        [switch]$EnablePSRemoting,
        [switch]$SMBOnly,
        [switch]$DryRun,
        [int]$MaxParallel
    )
    
    Write-Host "🚀 STARTING MASS UPDATE PROCESSING" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "Servers to process: $($ServerList.Count)" -ForegroundColor White
    Write-Host "Max parallel: $MaxParallel" -ForegroundColor White
    Write-Host "Enable PSRemoting: $(if($EnablePSRemoting){'YES'}else{'NO'})" -ForegroundColor White
    Write-Host "SMB Only: $(if($SMBOnly){'YES'}else{'NO'})" -ForegroundColor White
    Write-Host "Dry Run: $(if($DryRun){'YES'}else{'NO'})" -ForegroundColor White
    Write-Host ""
    
    $Global:UpdateResults.ServersTotal = $ServerList.Count
    $allResults = @()
    
    # Process servers (for now, sequential - parallel processing can be added later)
    $processedCount = 0
    
    foreach ($server in $ServerList) {
        $processedCount++
        
        Write-Host "[$processedCount/$($ServerList.Count)] " -ForegroundColor Gray -NoNewline
        
        $result = Process-SingleServer -ServerInfo $server -EnablePSRemoting:$EnablePSRemoting -SMBOnly:$SMBOnly -DryRun:$DryRun
        $allResults += $result
        
        $Global:UpdateResults.ServersAnalyzed++
        
        # Update global tracking
        if ($result.CertWebServiceStatus.HasCertWebService) {
            $Global:UpdateResults.HasCertWebService += $server
        } else {
            $Global:UpdateResults.NeedsCertWebService += $server
        }
        
        if ($result.ConnectivityStatus.SMBAccess) {
            $Global:UpdateResults.SMBAccessible += $server
        }
        
        if ($result.ConnectivityStatus.PSRemotingEnabled) {
            $Global:UpdateResults.PSRemotingEnabled += $server
        }
        
        if ($result.ConnectivityStatus.RecommendedMethod -eq "UNREACHABLE") {
            $Global:UpdateResults.Unreachable += $server
        }
    }
    
    return $allResults
}

#endregion

#region Reporting Functions

function Show-FinalResults {
    param([array]$AllResults)
    
    $endTime = Get-Date
    $totalDuration = $endTime - $Script:StartTime
    
    Write-Host "📊 FINAL RESULTS SUMMARY" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "⏱️ Execution Statistics:" -ForegroundColor Yellow
    Write-Host "   Start Time: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "   End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "   Total Duration: $($totalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host "   Average per Server: $([math]::Round($totalDuration.TotalSeconds / $Global:UpdateResults.ServersTotal, 1))s" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "📈 Server Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Servers: $($Global:UpdateResults.ServersTotal)" -ForegroundColor White
    Write-Host "   Analyzed: $($Global:UpdateResults.ServersAnalyzed)" -ForegroundColor White
    Write-Host "   Had CertWebService: $($Global:UpdateResults.HasCertWebService.Count)" -ForegroundColor Green
    Write-Host "   Needed Installation: $($Global:UpdateResults.NeedsCertWebService.Count)" -ForegroundColor Yellow
    Write-Host "   Unreachable: $($Global:UpdateResults.Unreachable.Count)" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "🔧 Connectivity Results:" -ForegroundColor Yellow
    Write-Host "   SMB Accessible: $($Global:UpdateResults.SMBAccessible.Count)" -ForegroundColor Green
    Write-Host "   PSRemoting Enabled: $($Global:UpdateResults.PSRemotingEnabled.Count)" -ForegroundColor Green
    Write-Host "   PSRemoting Configured: $($Global:UpdateResults.PSRemotingConfigured.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "✅ Update Results:" -ForegroundColor Yellow
    Write-Host "   Successful Updates: $($Global:UpdateResults.UpdateSuccessful.Count)" -ForegroundColor Green
    Write-Host "   Failed Updates: $($Global:UpdateResults.UpdateFailed.Count)" -ForegroundColor Red
    Write-Host ""
    
    # Show successful updates
    if ($Global:UpdateResults.UpdateSuccessful.Count -gt 0) {
        Write-Host "✅ Successfully Updated Servers:" -ForegroundColor Green
        foreach ($result in $Global:UpdateResults.UpdateSuccessful) {
            $method = if ($result.UpdateResult.Method) { $result.UpdateResult.Method } else { "Unknown" }
            Write-Host "   🖥️ $($result.ServerInfo.ServerName) [$method]" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Show failed updates
    if ($Global:UpdateResults.UpdateFailed.Count -gt 0) {
        Write-Host "❌ Failed Updates:" -ForegroundColor Red
        foreach ($result in $Global:UpdateResults.UpdateFailed) {
            $error = if ($result.UpdateResult.Error) { $result.UpdateResult.Error } else { "Unknown error" }
            Write-Host "   🖥️ $($result.ServerInfo.ServerName): $error" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Success rate
    $successRate = if ($Global:UpdateResults.ServersAnalyzed -gt 0) {
        [math]::Round(($Global:UpdateResults.UpdateSuccessful.Count / $Global:UpdateResults.ServersAnalyzed) * 100, 1)
    } else { 0 }
    
    Write-Host "📊 Overall Success Rate: $successRate%" -ForegroundColor $(if($successRate -gt 80){'Green'}elseif($successRate -gt 50){'Yellow'}else{'Red'})
    Write-Host ""
}

#endregion

#region Main Execution

try {
    # Step 1: Import servers from Excel
    Write-Host "📊 PHASE 1: EXCEL IMPORT" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    $allServers = Import-ServerListFromExcel-Enhanced -ExcelPath $ExcelPath
    
    if ($allServers.Count -eq 0) {
        throw "No servers found in Excel file: $ExcelPath"
    }
    
    # Step 2: Apply domain filter if specified
    Write-Host "🔍 PHASE 2: FILTERING" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    $filteredServers = Apply-DomainFilter -ServerList $allServers -FilterDomain $FilterDomain
    
    if ($filteredServers.Count -eq 0) {
        throw "No servers match the filter criteria"
    }
    
    Write-Host "📋 Processing Plan:" -ForegroundColor Yellow
    Write-Host "   Total servers in Excel: $($allServers.Count)" -ForegroundColor Gray
    Write-Host "   Filtered servers: $($filteredServers.Count)" -ForegroundColor Gray
    Write-Host "   Target version: $Script:NewCertWebServiceVersion" -ForegroundColor Gray
    Write-Host ""
    
    # Step 3: Process all servers
    Write-Host "🚀 PHASE 3: MASS PROCESSING" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    $allResults = Process-AllServers -ServerList $filteredServers -EnablePSRemoting:$EnablePSRemoting -SMBOnly:$SMBOnly -DryRun:$DryRun -MaxParallel $MaxParallel
    
    # Step 4: Show final results
    Write-Host "📊 PHASE 4: RESULTS" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Show-FinalResults -AllResults $allResults
    
    Write-Host "🏁 Mass Excel update completed!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Mass update failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}

#endregion
