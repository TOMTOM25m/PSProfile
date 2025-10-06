#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService - Hybrid Mass Update Script v2.5.0 - Pure ASCII

.DESCRIPTION
    Updates Certificate WebService on all servers using multiple deployment methods:
    1. PSRemoting (where available)
    2. Samba/SMB network share deployment  
    3. Manual installation package generation
    
    Automatically detects which method works for each server and adapts accordingly.
    Uses PowerShell version-specific display functions for compatibility.
    
.VERSION
    2.5.0 - Pure ASCII for PS 5.1 compatibility

.RULEBOOK
    v10.0.2
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

$Script:Version = "v2.5.0"
$Script:RulebookVersion = "v10.0.2"
$Script:UpdateDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Import PowerShell Version Compatibility Module v3.1
try {
    $compatibilityModulePath = Join-Path $PSScriptRoot "Modules\FL-PowerShell-VersionCompatibility-v3.1.psm1"
    if (Test-Path $compatibilityModulePath) {
        Import-Module $compatibilityModulePath -Force
        $Global:PSCompatibilityLoaded = $true
        Write-VersionSpecificHost "PowerShell version compatibility module loaded" -IconType 'gear' -ForegroundColor Green
    } else {
        $Global:PSCompatibilityLoaded = $false
        Write-Host "[WARN] PowerShell compatibility module not found - using fallback methods" -ForegroundColor Yellow
    }
} catch {
    $Global:PSCompatibilityLoaded = $false
    Write-Host "[WARN] PowerShell compatibility module failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
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
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    $connectivity = @{
        Server = $ServerName
        Ping = $false
        SMB = $false
        AdminShare = $false
        PSRemoting = $false
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
                $psRemotingResult = Invoke-PSRemotingVersionSpecific -ComputerName $ServerName -Credential $Credential -ScriptBlock { $env:COMPUTERNAME }
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
        Write-Host "   [ERROR] Connectivity test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $connectivity
}

function Deploy-ViaPSRemoting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [string]$NetworkSharePath,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    Write-Host "   [NET] Deploying via PSRemoting to $ServerName..." -ForegroundColor Yellow
    
    try {
        $scriptBlock = {
            param($SharePath)
            
            # Create temporary directory
            $tempDir = "C:\Temp\CertWebService-Update"
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force
            }
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            
            # Copy files from network share
            Copy-Item -Path "$SharePath\*" -Destination $tempDir -Recurse -Force
            
            # Run installation
            $installerPath = Join-Path $tempDir "Install.bat"
            if (Test-Path $installerPath) {
                Start-Process -FilePath $installerPath -Wait -WindowStyle Hidden
                return @{ Success = $true; Message = "Installation completed successfully" }
            } else {
                return @{ Success = $false; Message = "Installer not found" }
            }
        }
        
        if ($Credential) {
            # DevSkim: ignore DS104456 - Required for PS remoting deployment
            $result = Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $NetworkSharePath
        } else {
            # DevSkim: ignore DS104456 - Required for PS remoting deployment
            $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ArgumentList $NetworkSharePath
        }
        
        if ($result.Success) {
            Write-Host "   [OK] PSRemoting deployment successful" -ForegroundColor Green
            return @{ Success = $true; Method = "PSRemoting"; Message = $result.Message }
        } else {
            Write-Host "   [ERROR] PSRemoting deployment failed: $($result.Message)" -ForegroundColor Red
            return @{ Success = $false; Method = "PSRemoting"; Message = $result.Message }
        }
        
    } catch {
        Write-Host "   [ERROR] PSRemoting deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Method = "PSRemoting"; Message = $_.Exception.Message }
    }
}

function Deploy-ViaNetworkShare {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [string]$NetworkSharePath,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
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
cd /d C:\Temp\CertWebService-Install
call Install.bat
echo [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] CertWebService update completed on $ServerName
pause
"@
        
        $batchPath = "$serverPath\Execute-Update.bat"
        Set-Content -Path $batchPath -Value $remoteExecutor -Encoding ASCII
        
        # Try to execute remotely if credentials are available
        if ($Credential) {
            try {
                # DevSkim: ignore DS104456 - Required for remote process execution
                $process = Invoke-Command -ComputerName $ServerName -Credential $Credential -ScriptBlock {
                    Start-Process -FilePath "C:\Temp\CertWebService-Install\Execute-Update.bat" -PassThru
                } -ErrorAction Stop
                
                if ($process) {
                    Write-Host "   [OK] Remote execution started (Process ID: $($process.ProcessId))" -ForegroundColor Green
                    return @{ 
                        Success = $true
                        Method = "NetworkDeployment-Remote"
                        Message = "Remote execution started successfully"
                    }
                } else {
                    Write-Host "   [WARN] Remote execution failed, manual intervention required" -ForegroundColor Yellow
                    return @{ 
                        Success = $true
                        Method = "NetworkDeployment-Manual"
                        Message = "Files deployed, manual execution required"
                    }
                }
            } catch {
                Write-Host "   [WARN] No credentials provided, manual execution required" -ForegroundColor Yellow
                return @{ 
                    Success = $true
                    Method = "NetworkDeployment-Manual"
                    Message = "Files deployed, manual execution required"
                }
            }
        } else {
            Write-Host "   [WARN] Remote execution failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return @{ Success = $true; Method = "NetworkDeployment-Manual"; Message = "Files deployed, manual execution required" }
        }
        
    } catch {
        Write-Host "   [ERROR] Network deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Method = "NetworkDeployment"; Message = $_.Exception.Message }
    }
}

function New-ManualPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [string]$NetworkSharePath
    )
    
    Write-Host "   [FILE] Creating manual deployment package for $ServerName..." -ForegroundColor Yellow
    
    try {
        $packageDir = "C:\Temp\CertWebService-ManualDeployment"
        $packagePath = "$packageDir\$ServerName-Package"
        
        # Create package directory
        if (-not (Test-Path $packageDir)) {
            New-Item -Path $packageDir -ItemType Directory -Force | Out-Null
        }
        
        if (Test-Path $packagePath) {
            Remove-Item $packagePath -Recurse -Force
        }
        New-Item -Path $packagePath -ItemType Directory -Force | Out-Null
        
        # Copy installation files
        Copy-Item -Path "$NetworkSharePath\*" -Destination $packagePath -Recurse -Force
        
        # Create deployment instructions
        $instructions = @"
CertWebService Manual Deployment Instructions for $ServerName
================================================================

1. Copy this entire folder to the target server: $ServerName
2. Place it in C:\Temp\CertWebService-Install\
3. Run Install.bat as Administrator
4. Verify the service is running after installation

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Source: $NetworkSharePath
Target: $ServerName

"@
        
        Set-Content -Path "$packagePath\DEPLOYMENT-INSTRUCTIONS.txt" -Value $instructions -Encoding UTF8
        
        Write-Host "   [OK] Manual package created: $packagePath" -ForegroundColor Green
        return @{ Success = $true; Method = "ManualPackage"; Message = "Package created at: $packagePath" }
        
    } catch {
        Write-Host "   [ERROR] Manual package creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Method = "ManualPackage"; Message = $_.Exception.Message }
    }
}

#endregion

#region Main Execution

try {
    # Pre-flight checks
    Write-Host "[INFO] Performing pre-flight checks..." -ForegroundColor Yellow
    
    # Check network deployment package availability
    if (-not (Test-Path $NetworkSharePath)) {
        Write-Host "[ERROR] Network deployment package not found: $NetworkSharePath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] Deployment package verified" -ForegroundColor Green
    
    # Verify credentials if not in TestOnly mode
    if (-not $TestOnly -and -not $AdminCredential) {
        try {
            $AdminCredential = Get-Credential -Message "Enter administrator credentials for remote deployment"
        } catch {
            Write-Host "[ERROR] Credentials required for deployment. Exiting." -ForegroundColor Red
            exit 1
        }
    }
    
    # Process each server
    foreach ($server in $ServerList) {
        Write-Host "[PC] Processing server: $server" -ForegroundColor Cyan
        Write-Host "=================================" -ForegroundColor Cyan
        
        # Test connectivity
        $connectivity = Test-ServerConnectivity -ServerName $server -Credential $AdminCredential
        
        Write-Host "   Ping: $($connectivity.Ping)" -ForegroundColor $(if($connectivity.Ping){'Green'}else{'Red'})
        Write-Host "   SMB Share: $($connectivity.SMB)" -ForegroundColor $(if($connectivity.SMB){'Green'}else{'Red'})
        Write-Host "   PSRemoting: $($connectivity.PSRemoting)" -ForegroundColor $(if($connectivity.PSRemoting){'Green'}else{'Red'})
        Write-Host "   Recommended Method: $($connectivity.RecommendedMethod)" -ForegroundColor Yellow
        
        if ($TestOnly) {
            Write-Host "   [INFO] Test mode - skipping deployment" -ForegroundColor Gray
            continue
        }
        
        $deploymentResult = $null
        
        switch ($connectivity.RecommendedMethod) {
            "PSRemoting" {
                $deploymentResult = Deploy-ViaPSRemoting -ServerName $server -NetworkSharePath $NetworkSharePath -Credential $AdminCredential
                if ($deploymentResult.Success) {
                    $Global:UpdateResults.PSRemotingWorked += @{
                        Server = $server
                        Method = $deploymentResult.Method
                        Message = $deploymentResult.Message
                        Timestamp = Get-Date
                    }
                }
            }
            
            "NetworkDeployment" {
                $deploymentResult = Deploy-ViaNetworkShare -ServerName $server -NetworkSharePath $NetworkSharePath -Credential $AdminCredential
                if ($deploymentResult.Success) {
                    $Global:UpdateResults.NetworkDeployment += @{
                        Server = $server
                        Method = $deploymentResult.Method
                        Message = $deploymentResult.Message
                        Timestamp = Get-Date
                    }
                }
            }
            
            "ManualPackage" {
                $deploymentResult = New-ManualPackage -ServerName $server -NetworkSharePath $NetworkSharePath
                if ($deploymentResult.Success) {
                    $Global:UpdateResults.ManualRequired += @{
                        Server = $server
                        Method = $deploymentResult.Method
                        Message = $deploymentResult.Message
                        Timestamp = Get-Date
                    }
                }
            }
            
            "UNREACHABLE" {
                Write-Host "   [ERROR] Server unreachable - skipping" -ForegroundColor Red
                $deploymentResult = @{ Success = $false; Method = "None"; Message = "Server unreachable" }
            }
        }
        
        # Record results
        if ($deploymentResult) {
            if ($deploymentResult.Success) {
                $Global:UpdateResults.Successful += @{
                    Server = $server
                    Method = $deploymentResult.Method
                    Message = $deploymentResult.Message
                    Timestamp = Get-Date
                }
            } else {
                $Global:UpdateResults.Failed += @{
                    Server = $server
                    Method = $deploymentResult.Method
                    Message = $deploymentResult.Message
                    Timestamp = Get-Date
                }
            }
        }
        
        Write-Host ""
    }
    
    # Final summary
    $Global:UpdateResults.EndTime = Get-Date
    $duration = $Global:UpdateResults.EndTime - $Global:UpdateResults.StartTime
    
    Write-Host "[CHART] HYBRID UPDATE SUMMARY" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[TIME] Execution Time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host "[PC] Total Servers: $($Global:UpdateResults.TotalServers)" -ForegroundColor Gray
    Write-Host ""
    
    # Successful updates
    if ($Global:UpdateResults.Successful.Count -gt 0) {
        Write-Host "[OK] Successful Updates: $($Global:UpdateResults.Successful.Count)" -ForegroundColor Green
        foreach ($success in $Global:UpdateResults.Successful) {
            Write-Host "   [OK] $($success.Server) [$($success.Method)] - $($success.Message)" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    # Failed updates
    if ($Global:UpdateResults.Failed.Count -gt 0) {
        Write-Host "[ERROR] Failed Updates: $($Global:UpdateResults.Failed.Count)" -ForegroundColor Red
        foreach ($failure in $Global:UpdateResults.Failed) {
            Write-Host "   [ERROR] $($failure.Server) [$($failure.Method)] - $($failure.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Method breakdown
    Write-Host "[INFO] Method Breakdown:" -ForegroundColor Cyan
    Write-Host "   PSRemoting: $($Global:UpdateResults.PSRemotingWorked.Count)" -ForegroundColor $(if($Global:UpdateResults.PSRemotingWorked.Count -gt 0){'Green'}else{'Gray'})
    Write-Host "   Network Deployment: $($Global:UpdateResults.NetworkDeployment.Count)" -ForegroundColor $(if($Global:UpdateResults.NetworkDeployment.Count -gt 0){'Yellow'}else{'Gray'})
    Write-Host "   Manual Required: $($Global:UpdateResults.ManualRequired.Count)" -ForegroundColor $(if($Global:UpdateResults.ManualRequired.Count -gt 0){'Yellow'}else{'Gray'})
    
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