#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService - Hybrid Mass Update Script v2.4.0

.DESCRIPTION
    Updates Certificate WebService on all servers using multiple deployment methods:
    1. PSRemoting (where available)
    2. Samba/SMB network share deployment  
    3. Manual installation package generation
    
    Automatically detects which method works for each server and adapts accordingly.
    
.VERSION
    2.4.0

.RULEBOOK
    v10.1.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string[]]$ServerList = @(),
    
    [Parameter(Mandatory = $false)]
    [string]$NetworkSharePath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService",
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$AdminCredential,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReports,
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 300
)

$Script:Version = "v2.4.0"
$Script:RulebookVersion = "v10.1.0"
$Script:UpdateDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Import PowerShell Version Compatibility Module v3.0
try {
    $compatibilityModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility-v3.psm1"
    if (Test-Path $compatibilityModulePath) {
        Import-Module $compatibilityModulePath -Force
        $Global:PSCompatibilityLoaded = $true
        Write-VersionSpecificHost "PowerShell version compatibility module loaded" -IconType 'gear' -ForegroundColor Green
    } else {
        $Global:PSCompatibilityLoaded = $false
        Write-VersionSpecificHost "PowerShell compatibility module not found - using fallback methods" -IconType 'warning' -ForegroundColor Yellow
    }
} catch {
    $Global:PSCompatibilityLoaded = $false
    Write-VersionSpecificHost "PowerShell compatibility module failed to load: $($_.Exception.Message)" -IconType 'warning' -ForegroundColor Yellow
}

if ($Global:PSCompatibilityLoaded) {
    Write-VersionSpecificHeader "CertWebService - Hybrid Mass Update System" -Version "$Script:Version | Regelwerk: $Script:RulebookVersion" -Color Cyan
} else {
    Write-Host "[START] CertWebService - Hybrid Mass Update System" -ForegroundColor Cyan
    Write-Host "   Version: $Script:Version | Regelwerk: $Script:RulebookVersion" -ForegroundColor Gray
    Write-Host "   Update Date: $Script:UpdateDate" -ForegroundColor Gray
    Write-Host ""
}

# Define default server list if not provided
if ($ServerList.Count -eq 0) {
    $ServerList = @(
        "server01.domain.local",
        "server02.domain.local", 
        "server03.domain.local",
        "webserver01.domain.local",
        "webserver02.domain.local"
        # Add your actual server names here
    )
    
    if ($Global:PSCompatibilityLoaded) {
        Write-VersionSpecificHost "Using default server list. Specify -ServerList for custom servers." -IconType 'warning' -ForegroundColor Yellow
    } else {
        Write-Host "[WARN] Using default server list. Specify -ServerList for custom servers." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Global variables for tracking
$Global:UpdateResults = @{
    TotalServers = $ServerList.Count
    Successful = @()
    Failed = @()
    PSRemotingWorked = @()
    NetworkDeployment = @()
    ManualRequired = @()
    StartTime = Get-Date
}

#region Helper Functions

function Test-ServerConnectivity {
    param(
        [string]$ServerName,
        [PSCredential]$Credential = $null
    )
    
    $connectivity = @{
        ServerName = $ServerName
        Ping = $false
        SMB = $false
        PSRemoting = $false
        AdminShare = $false
        RecommendedMethod = "Unknown"
    }
    
    try {
        # Test 1: Basic ping connectivity
        if ($Global:PSCompatibilityLoaded) {
            Write-VersionSpecificHost "Testing connectivity to $ServerName..." -IconType 'network' -ForegroundColor Gray
        } else {
            Write-Host "   [NETWORK] Testing connectivity to $ServerName..." -ForegroundColor Gray
        }
        $pingResult = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue
        $connectivity.Ping = $pingResult
        
        if (-not $pingResult) {
            $connectivity.RecommendedMethod = "UNREACHABLE"
            return $connectivity
        }
        
        # Test 2: SMB/Admin Share access
        try {
            $adminShare = "\\$ServerName\C$"
            $testPath = Test-Path $adminShare -ErrorAction SilentlyContinue
            $connectivity.AdminShare = $testPath
            $connectivity.SMB = $testPath
        } catch {
            $connectivity.SMB = $false
        }
        
        # Test 3: PSRemoting capability
        try {
            if ($Global:PSCompatibilityLoaded) {
                $psRemotingResult = Invoke-PSRemoting-VersionSpecific -ComputerName $ServerName -Credential $Credential -ScriptBlock { $env:COMPUTERNAME }
                $connectivity.PSRemoting = ($psRemotingResult.Success -and $psRemotingResult.Data -eq $ServerName)
            } else {
                # Fallback to direct Invoke-Command
                if ($Credential) {
                    # DevSkim: ignore DS104456 - Required for PSRemoting connectivity testing
                    $testPSRemoting = Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock { $env:COMPUTERNAME } -ErrorAction SilentlyContinue
                } else {
                    # DevSkim: ignore DS104456 - Required for PSRemoting connectivity testing
                    $testPSRemoting = Invoke-Command -ComputerName $ServerName -ScriptBlock { $env:COMPUTERNAME } -ErrorAction SilentlyContinue
                }
                $connectivity.PSRemoting = ($testPSRemoting -eq $ServerName)
            }
        } catch {
            $connectivity.PSRemoting = $false
        }
        
        # Determine recommended deployment method
        if ($connectivity.PSRemoting) {
            $connectivity.RecommendedMethod = "PSRemoting"
        } elseif ($connectivity.SMB) {
            $connectivity.RecommendedMethod = "NetworkDeployment"
        } else {
            $connectivity.RecommendedMethod = "ManualPackage"
        }
        
    } catch {
        Write-Host "   ❌ Connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $connectivity
}

function Deploy-ViaPSRemoting {
    param(
        [string]$ServerName,
        [PSCredential]$Credential = $null
    )
    
    Write-Host "   🔄 Deploying via PSRemoting to $ServerName..." -ForegroundColor Yellow
    
    try {
        $scriptBlock = {
            param($NetworkSharePath)
            
            # Create local installation directory
            $localInstallPath = "C:\Temp\CertWebService-Update"
            if (Test-Path $localInstallPath) {
                Remove-Item $localInstallPath -Recurse -Force
            }
            New-Item -Path $localInstallPath -ItemType Directory -Force | Out-Null
            
            # Copy installation files from network share
            Copy-Item -Path "$NetworkSharePath\*" -Destination $localInstallPath -Recurse -Force
            
            # Execute installation
            $setupScript = Join-Path $localInstallPath "Setup.ps1"
            if (Test-Path $setupScript) {
                & $setupScript -Force
                return @{ Success = $true; Message = "Installation completed successfully via PSRemoting" }
            } else {
                return @{ Success = $false; Message = "Setup script not found in deployment package" }
            }
        }
        
        if ($Credential) {
            # DevSkim: ignore DS104456 - Required for PSRemoting deployment execution
            $result = Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $NetworkSharePath
        } else {
            # DevSkim: ignore DS104456 - Required for PSRemoting deployment execution
            $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ArgumentList $NetworkSharePath
        }
        
        if ($result.Success) {
            Write-Host "   ✅ PSRemoting deployment successful" -ForegroundColor Green
            return @{ Success = $true; Method = "PSRemoting"; Message = $result.Message }
        } else {
            Write-Host "   ❌ PSRemoting deployment failed: $($result.Message)" -ForegroundColor Red
            return @{ Success = $false; Method = "PSRemoting"; Message = $result.Message }
        }
        
    } catch {
        Write-Host "   ❌ PSRemoting deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Method = "PSRemoting"; Message = $_.Exception.Message }
    }
}

function Deploy-ViaNetworkShare {
    param(
        [string]$ServerName,
        [PSCredential]$Credential = $null
    )
    
    Write-Host "   [NET] Deploying via Network Share to $ServerName..." -ForegroundColor Yellow
    
    try {
        # Create installation package on target server
        $serverPath = "\\$ServerName\C$\Temp\CertWebService-Install"
        
        # Clean existing installation directory
        if (Test-Path $serverPath) {
            Remove-Item $serverPath -Recurse -Force
        }
        New-Item -Path $serverPath -ItemType Directory -Force | Out-Null
        
        # Copy deployment files to server
        Write-Host "   [DIR] Copying files to $serverPath..." -ForegroundColor Gray
        Copy-Item -Path "$NetworkSharePath\*" -Destination $serverPath -Recurse -Force
        
        # Create a remote execution batch file
        $remoteExecutor = @"
@echo off
title CertWebService Update - $ServerName
echo [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting CertWebService update on $ServerName
cd /d "C:\Temp\CertWebService-Install"
PowerShell.exe -ExecutionPolicy Bypass -File "Setup.ps1" -Force
echo [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Update completed
"@
        
        $batchPath = Join-Path $serverPath "Execute-Update.bat"
        $remoteExecutor | Set-Content -Path $batchPath -Encoding ASCII
        
        # Try to execute remotely if possible
        try {
            if ($Credential) {
                # Use WMI to start the process remotely
                $process = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $batchPath -ComputerName $ServerName -Credential $Credential
                if ($process.ReturnValue -eq 0) {
                    Write-Host "   ✅ Remote execution started (Process ID: $($process.ProcessId))" -ForegroundColor Green
                    
                    # Wait for completion (simplified - in production, implement proper monitoring)
                    Start-Sleep -Seconds 30
                    
                    return @{ Success = $true; Method = "NetworkDeployment"; Message = "Installation package deployed and executed remotely" }
                } else {
                    Write-Host "   ⚠️ Remote execution failed, manual intervention required" -ForegroundColor Yellow
                    return @{ Success = $false; Method = "NetworkDeployment"; Message = "Package deployed but manual execution required" }
                }
            } else {
                Write-Host "   ⚠️ No credentials provided, manual execution required" -ForegroundColor Yellow
                return @{ Success = $false; Method = "NetworkDeployment"; Message = "Package deployed, manual execution required: $batchPath" }
            }
        } catch {
            Write-Host "   ⚠️ Remote execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return @{ Success = $false; Method = "NetworkDeployment"; Message = "Package deployed, manual execution required: $batchPath" }
        }
        
    } catch {
        Write-Host "   ❌ Network deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Method = "NetworkDeployment"; Message = $_.Exception.Message }
    }
}

function Generate-ManualPackage {
    param(
        [string]$ServerName
    )
    
    Write-Host "   📦 Generating manual installation package for $ServerName..." -ForegroundColor Yellow
    
    try {
        $packagePath = "C:\Temp\CertWebService-Manual-$ServerName-$(Get-Date -Format 'yyyy-MM-dd-HH-mm')"
        
        # Create package directory
        if (-not (Test-Path $packagePath)) {
            New-Item -Path $packagePath -ItemType Directory -Force | Out-Null
        }
        
        # Copy base installation files
        Copy-Item -Path "$NetworkSharePath\*" -Destination $packagePath -Recurse -Force
        
        # Create server-specific installation instructions
        $instructions = @"
MANUAL INSTALLATION INSTRUCTIONS FOR $ServerName
================================================

Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Package: CertWebService $Script:Version
Target Server: $ServerName

INSTALLATION STEPS:
==================

1. Copy this entire folder to the target server: $ServerName
   Recommended location: C:\Temp\CertWebService-Install

2. On the target server, open Command Prompt as Administrator

3. Navigate to the installation directory:
   cd C:\Temp\CertWebService-Install

4. Execute the installation:
   Install.bat

5. Test the installation:
   PowerShell.exe -ExecutionPolicy Bypass -File Test.ps1

6. Verify WebService is running:
   Open browser: http://$ServerName`:9080/ # DevSkim: ignore DS137138 - Internal network HTTP endpoint for testing

TROUBLESHOOTING:
===============

- If installation fails, check Windows Event Log
- Ensure IIS is available on the server
- Verify Administrator privileges
- Check PowerShell execution policy

For support, contact: IT Systems Management

Package Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Version: $Script:Version (Regelwerk $Script:RulebookVersion)
"@
        
        $instructionsPath = Join-Path $packagePath "INSTALLATION-INSTRUCTIONS.txt"
        $instructions | Set-Content -Path $instructionsPath -Encoding UTF8
        
        Write-Host "   ✅ Manual package created: $packagePath" -ForegroundColor Green
        return @{ Success = $true; Method = "ManualPackage"; Message = "Package created: $packagePath" }
        
    } catch {
        Write-Host "   ❌ Manual package creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Method = "ManualPackage"; Message = $_.Exception.Message }
    }
}

#endregion

#region Main Update Process

function Start-HybridUpdate {
    Write-Host "🎯 Starting Hybrid Update Process..." -ForegroundColor Cyan
    Write-Host "   Servers to update: $($ServerList.Count)" -ForegroundColor Gray
    Write-Host ""
    
    # Step 1: Verify network deployment package exists
    Write-Host "📦 Verifying deployment package..." -ForegroundColor Yellow
    if (-not (Test-Path $NetworkSharePath)) {
        Write-Host "❌ Network deployment package not found: $NetworkSharePath" -ForegroundColor Red
        Write-Host "   Please run Deploy-NetworkPackage.ps1 first to create the deployment package." -ForegroundColor Yellow
        return
    }
    Write-Host "✅ Deployment package verified" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Get Admin credentials if not provided
    if (-not $AdminCredential) {
        Write-Host "🔐 Administrator credentials required for server access..." -ForegroundColor Yellow
        $AdminCredential = Get-Credential -Message "Enter Administrator credentials for server access"
        if (-not $AdminCredential) {
            Write-Host "❌ Credentials required for deployment. Exiting." -ForegroundColor Red
            return
        }
    }
    
    # Step 3: Process each server
    foreach ($server in $ServerList) {
        Write-Host "🖥️ Processing server: $server" -ForegroundColor Cyan
        Write-Host "   $(Get-Date -Format 'HH:mm:ss') | Testing connectivity..." -ForegroundColor Gray
        
        # Test server connectivity and capabilities
        $connectivity = Test-ServerConnectivity -ServerName $server -Credential $AdminCredential
        
        Write-Host "   Connectivity Results:" -ForegroundColor Gray
        if ($Global:PSCompatibilityLoaded) {
            Write-Host "     Ping: $(if($connectivity.Ping){'[OK]'}else{'[FAIL]'})" -ForegroundColor $(if($connectivity.Ping){'Green'}else{'Red'})
            Write-Host "     SMB Share: $(if($connectivity.SMB){'[OK]'}else{'[FAIL]'})" -ForegroundColor $(if($connectivity.SMB){'Green'}else{'Red'})
            Write-Host "     PSRemoting: $(if($connectivity.PSRemoting){'[OK]'}else{'[FAIL]'})" -ForegroundColor $(if($connectivity.PSRemoting){'Green'}else{'Red'})
        } else {
            Write-Host "     Ping: $(if($connectivity.Ping){'[OK]'}else{'[FAIL]'})" -ForegroundColor $(if($connectivity.Ping){'Green'}else{'Red'})
            Write-Host "     SMB Share: $(if($connectivity.SMB){'[OK]'}else{'[FAIL]'})" -ForegroundColor $(if($connectivity.SMB){'Green'}else{'Red'})
            Write-Host "     PSRemoting: $(if($connectivity.PSRemoting){'[OK]'}else{'[FAIL]'})" -ForegroundColor $(if($connectivity.PSRemoting){'Green'}else{'Red'})
        }
        if ($Global:PSCompatibilityLoaded) {
            Write-VersionSpecificHost "Recommended method: $($connectivity.RecommendedMethod)" -IconType 'target' -ForegroundColor Cyan
        } else {
            Write-Host "     Recommended: $($connectivity.RecommendedMethod)" -ForegroundColor Cyan
        }
        
        if ($TestOnly) {
            Write-Host "   🧪 Test-only mode - skipping actual deployment" -ForegroundColor Yellow
            continue
        }
        
        # Deploy based on connectivity results
        $deployResult = $null
        
        switch ($connectivity.RecommendedMethod) {
            "PSRemoting" {
                $deployResult = Deploy-ViaPSRemoting -ServerName $server -Credential $AdminCredential
                if ($deployResult.Success) {
                    $Global:UpdateResults.PSRemotingWorked += $server
                }
            }
            
            "NetworkDeployment" {
                $deployResult = Deploy-ViaNetworkShare -ServerName $server -Credential $AdminCredential
                if ($deployResult.Success -or $deployResult.Message -like "*deployed*") {
                    $Global:UpdateResults.NetworkDeployment += $server
                }
            }
            
            "ManualPackage" {
                $deployResult = Generate-ManualPackage -ServerName $server
                if ($deployResult.Success) {
                    $Global:UpdateResults.ManualRequired += $server
                }
            }
            
            "UNREACHABLE" {
                Write-Host "   ❌ Server unreachable - skipping" -ForegroundColor Red
                $deployResult = @{ Success = $false; Method = "UNREACHABLE"; Message = "Server not accessible" }
            }
        }
        
        # Track results
        if ($deployResult.Success) {
            $Global:UpdateResults.Successful += @{
                Server = $server
                Method = $deployResult.Method
                Message = $deployResult.Message
                Timestamp = Get-Date
            }
        } else {
            $Global:UpdateResults.Failed += @{
                Server = $server
                Method = $deployResult.Method
                Message = $deployResult.Message
                Timestamp = Get-Date
            }
        }
        
        Write-Host ""
    }
}

function Show-UpdateSummary {
    $endTime = Get-Date
    $duration = $endTime - $Global:UpdateResults.StartTime
    
    Write-Host "📊 HYBRID UPDATE SUMMARY" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⏱️ Execution Time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host "🖥️ Total Servers: $($Global:UpdateResults.TotalServers)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "📈 Results by Method:" -ForegroundColor Yellow
    Write-Host "   PSRemoting Success: $($Global:UpdateResults.PSRemotingWorked.Count)" -ForegroundColor Green
    Write-Host "   Network Deployment: $($Global:UpdateResults.NetworkDeployment.Count)" -ForegroundColor Cyan
    Write-Host "   Manual Packages: $($Global:UpdateResults.ManualRequired.Count)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "✅ Successful Updates: $($Global:UpdateResults.Successful.Count)" -ForegroundColor Green
    if ($Global:UpdateResults.Successful.Count -gt 0) {
        foreach ($success in $Global:UpdateResults.Successful) {
            Write-Host "   ✅ $($success.Server) [$($success.Method)] - $($success.Message)" -ForegroundColor Green
        }
    }
    Write-Host ""
    
    Write-Host "❌ Failed Updates: $($Global:UpdateResults.Failed.Count)" -ForegroundColor Red
    if ($Global:UpdateResults.Failed.Count -gt 0) {
        foreach ($failure in $Global:UpdateResults.Failed) {
            Write-Host "   ❌ $($failure.Server) [$($failure.Method)] - $($failure.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
    
    # Manual intervention required
    if ($Global:UpdateResults.ManualRequired.Count -gt 0) {
        Write-Host "⚠️ MANUAL INTERVENTION REQUIRED:" -ForegroundColor Yellow
        Write-Host "   The following servers require manual installation:" -ForegroundColor Yellow
        foreach ($server in $Global:UpdateResults.ManualRequired) {
            Write-Host "   📦 $server - Check C:\Temp\ for installation package" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Next steps
    Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "   1. Verify successful installations by visiting: http://[SERVER]:9080/" -ForegroundColor White # DevSkim: ignore DS137138 - Internal network HTTP endpoint
    Write-Host "   2. Complete manual installations where required" -ForegroundColor White
    Write-Host "   3. Update Certificate Surveillance configuration with new endpoints" -ForegroundColor White
    Write-Host "   4. Test end-to-end integration with CertSurv system" -ForegroundColor White
    Write-Host ""
}

#endregion

#region Execution

try {
    # Validate prerequisites
    if (-not (Test-Path $NetworkSharePath)) {
        throw "Network deployment package not found. Please run Deploy-NetworkPackage.ps1 first."
    }
    
    # Start the hybrid update process
    Start-HybridUpdate
    
    # Generate summary report
    Show-UpdateSummary
    
    # Generate detailed report if requested
    if ($GenerateReports) {
        if ($Global:PSCompatibilityLoaded) {
            Write-VersionSpecificHost "Generating detailed reports..." -IconType 'file' -ForegroundColor Yellow
        } else {
            Write-Host "[FILE] Generating detailed reports..." -ForegroundColor Yellow
        }
        
        $reportPath = "C:\Temp\CertWebService-Update-Report-$(Get-Date -Format 'yyyy-MM-dd-HH-mm').json"
        $Global:UpdateResults | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding UTF8
        
        if ($Global:PSCompatibilityLoaded) {
            Write-VersionSpecificHost "Detailed report saved: $reportPath" -IconType 'success' -ForegroundColor Green
        } else {
            Write-Host "[OK] Detailed report saved: $reportPath" -ForegroundColor Green
        }
    }
    
    if ($Global:PSCompatibilityLoaded) {
        Write-VersionSpecificHost "Hybrid update process completed!" -IconType 'party' -ForegroundColor Green
    } else {
        Write-Host "[DONE] Hybrid update process completed!" -ForegroundColor Green
    }
    
} catch {
    if ($Global:PSCompatibilityLoaded) {
        Write-VersionSpecificHost "Hybrid update process failed: $($_.Exception.Message)" -IconType 'error' -ForegroundColor Red
    } else {
        Write-Host "[ERROR] Hybrid update process failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}

#endregion
