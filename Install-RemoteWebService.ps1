#!/usr/bin/env powershell
#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Remote installation script for Certificate Web Service on ISO-Server
.DESCRIPTION
    Installs the Certificate Web Service remotely on itscmgmt03.srv.meduniwien.ac.at
    with custom ports 9080 (HTTP) and 9443 (HTTPS) to avoid standard port conflicts.
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

param(
    [string]$TargetServer = "itscmgmt03.srv.meduniwien.ac.at",
    [int]$HttpPort = 9080,
    [int]$HttpsPort = 9443,
    [string]$RemotePath = "F:\DEV\repositories\CertWebService",
    [switch]$TestConnection = $false
)

# [SUCCESS]/[ERROR]/[INFO] markers for PowerShell 5.1 compatibility
function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    
    switch ($Level) {
        "SUCCESS" { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        "ERROR"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        "WARN"    { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        default   { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
    }
}

Write-Status "=== REMOTE WEBSERVICE INSTALLATION ===" "INFO"
Write-Status "Target Server: $TargetServer" "INFO"
Write-Status "HTTP Port: $HttpPort" "INFO"
Write-Status "HTTPS Port: $HttpsPort" "INFO"
Write-Status "Remote Path: $RemotePath" "INFO"

# Test connection to target server
Write-Status "Testing connection to $TargetServer..." "INFO"
try {
    $pingResult = Test-Connection -ComputerName $TargetServer -Count 1 -Quiet
    if (-not $pingResult) {
        Write-Status "Cannot reach $TargetServer" "ERROR"
        exit 1
    }
    Write-Status "Server $TargetServer is reachable" "SUCCESS"
} catch {
    Write-Status "Connection test failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Test WinRM/PowerShell Remoting
Write-Status "Testing PowerShell Remoting to $TargetServer..." "INFO"
try {
    $testRemoting = Test-WSMan -ComputerName $TargetServer -ErrorAction Stop
    Write-Status "PowerShell Remoting is available" "SUCCESS"
} catch {
    Write-Status "PowerShell Remoting test failed: $($_.Exception.Message)" "ERROR"
    Write-Status "Trying to enable WinRM on target server..." "WARN"
    
    # Try to enable WinRM (if we have admin rights)
    try {
        Invoke-Command -ComputerName $TargetServer -ScriptBlock { 
            Enable-PSRemoting -Force -SkipNetworkProfileCheck
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
        } -ErrorAction Stop
        Write-Status "WinRM enabled successfully" "SUCCESS"
    } catch {
        Write-Status "Cannot enable WinRM. Manual setup required on $TargetServer" "ERROR"
        Write-Status "Run this on $TargetServer: Enable-PSRemoting -Force" "INFO"
        exit 1
    }
}

if ($TestConnection) {
    Write-Status "Connection test completed successfully" "SUCCESS"
    exit 0
}

# Execute remote installation
Write-Status "Starting remote installation on $TargetServer..." "INFO"
try {
    $scriptBlock = {
        param($HttpPort, $HttpsPort, $RemotePath)
        
        # Change to the correct directory
        Set-Location $RemotePath
        
        # Run the installation with custom ports
        & ".\Install-CertWebService-Safe.ps1" -HttpPort $HttpPort -HttpsPort $HttpsPort
        
        return $LASTEXITCODE
    }
    
    $result = Invoke-Command -ComputerName $TargetServer -ScriptBlock $scriptBlock -ArgumentList $HttpPort, $HttpsPort, $RemotePath
    
    if ($result -eq 0) {
        Write-Status "Remote installation completed successfully" "SUCCESS"
    } else {
        Write-Status "Remote installation failed with exit code: $result" "ERROR"
        exit 1
    }
    
} catch {
    Write-Status "Remote installation failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Test the new WebService endpoints
Write-Status "Testing WebService endpoints..." "INFO"

# Test HTTP endpoint
Write-Status "Testing HTTP endpoint (Port $HttpPort)..." "INFO"
try {
    $httpTest = Test-NetConnection -ComputerName $TargetServer -Port $HttpPort
    if ($httpTest.TcpTestSucceeded) {
        Write-Status "HTTP Port $HttpPort is accessible" "SUCCESS"
        
        # Test HTTP API
        try {
            $httpResponse = Invoke-WebRequest -Uri "http://${TargetServer}:${HttpPort}/api/certificates.json" -UseBasicParsing -TimeoutSec 10
            if ($httpResponse.StatusCode -eq 200) {
                Write-Status "HTTP API is responding correctly" "SUCCESS"
            }
        } catch {
            Write-Status "HTTP API test failed: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Status "HTTP Port $HttpPort is not accessible" "ERROR"
    }
} catch {
    Write-Status "HTTP endpoint test failed: $($_.Exception.Message)" "ERROR"
}

# Test HTTPS endpoint
Write-Status "Testing HTTPS endpoint (Port $HttpsPort)..." "INFO"
try {
    $httpsTest = Test-NetConnection -ComputerName $TargetServer -Port $HttpsPort
    if ($httpsTest.TcpTestSucceeded) {
        Write-Status "HTTPS Port $HttpsPort is accessible" "SUCCESS"
        
        # Test HTTPS API (with SSL bypass for self-signed cert)
        try {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $httpsResponse = Invoke-WebRequest -Uri "https://${TargetServer}:${HttpsPort}/api/certificates.json" -UseBasicParsing -TimeoutSec 10
            if ($httpsResponse.StatusCode -eq 200) {
                Write-Status "HTTPS API is responding correctly" "SUCCESS"
            }
        } catch {
            Write-Status "HTTPS API test failed: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Status "HTTPS Port $HttpsPort is not accessible" "ERROR"
    }
} catch {
    Write-Status "HTTPS endpoint test failed: $($_.Exception.Message)" "ERROR"
}

Write-Status "=== REMOTE INSTALLATION COMPLETED ===" "SUCCESS"
Write-Status "WebService URLs:" "INFO"
Write-Status "  HTTP:  http://${TargetServer}:${HttpPort}" "INFO"
Write-Status "  HTTPS: https://${TargetServer}:${HttpsPort}" "INFO"
Write-Status "You can now test Certificate Surveillance on this client" "INFO"

# End of Script - v1.0.0 - Regelwerk v9.3.0