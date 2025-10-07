<#
.SYNOPSIS
    Automated CertWebService Update v2.0.0 - Mit Credential Vault Integration
    
.DESCRIPTION
    Automatisches Update aller CertWebService v2.4.0 → v2.5.0 Server
    Nutzt FL-CredentialManager für sichere Authentifizierung
    
.NOTES
    Author: PowerShell Team
    Date: 07.10.2025
#>

param(
    [switch]$Force,
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"

# Import FL-CredentialManager
Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AUTOMATED CERTWEBSERVICE UPDATE v2.0.0" -ForegroundColor Cyan
Write-Host "  FL-CredentialManager Integration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Define servers that need update
$serversToUpdate = @(
    @{
        Name = "UVWmgmt01"
        FQDN = "UVWmgmt01.uvw.meduniwien.ac.at"
        Domain = "UVW"
        CurrentVersion = "v2.4.0"
        TargetVersion = "v2.5.0"
    },
    @{
        Name = "UVW-FINANZ01"
        FQDN = "UVW-FINANZ01.uvw.meduniwien.ac.at"
        Domain = "UVW"
        CurrentVersion = "v2.4.0"
        TargetVersion = "v2.5.0"
    },
    @{
        Name = "UVWDC001"
        FQDN = "UVWDC001.uvw.meduniwien.ac.at"
        Domain = "UVW"
        CurrentVersion = "v2.4.0"
        TargetVersion = "v2.5.0"
    }
)

Write-Host "Servers scheduled for update:" -ForegroundColor Yellow
foreach ($server in $serversToUpdate) {
    $status = if ($TestOnly) { "(TEST MODE)" } else { "" }
    Write-Host "  [$($server.Name)] $($server.CurrentVersion) → $($server.TargetVersion) $status" -ForegroundColor White
}
Write-Host ""

if (-not $Force -and -not $TestOnly) {
    $confirm = Read-Host "Proceed with PRODUCTION update of $($serversToUpdate.Count) servers? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Update cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

# Get or prompt for UVW domain credentials
Write-Host "Getting UVW Domain credentials..." -ForegroundColor Cyan

$uvwCredential = $null
try {
    # Try to get from vault first
    $uvwCredential = Get-StoredCredential -Target "UVW-Domain" -ErrorAction SilentlyContinue
    if ($uvwCredential -and $uvwCredential.UserName) {
        Write-Host "✓ Using stored UVW credentials: $($uvwCredential.UserName)" -ForegroundColor Green
    } else {
        throw "No stored credentials found"
    }
} catch {
    Write-Host "⚠ No stored credentials found, prompting..." -ForegroundColor Yellow
    $uvwCredential = Get-Credential -UserName "UVW\administrator" -Message "Enter UVW Domain credentials"
    
    if (-not $uvwCredential) {
        Write-Host "✗ No credentials provided - cannot proceed" -ForegroundColor Red
        exit 1
    }
    
    # Offer to save credentials
    $save = Read-Host "Save credentials to Password Vault for future use? (y/N)"
    if ($save -eq 'y' -or $save -eq 'Y') {
        try {
            Save-StoredCredential -Target "UVW-Domain" -Credential $uvwCredential
            Write-Host "✓ Credentials saved to Password Vault" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Failed to save credentials: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Starting CertWebService updates..." -ForegroundColor Cyan
Write-Host ""

$updateResults = @()

foreach ($server in $serversToUpdate) {
    Write-Host "Processing [$($server.Name)]..." -ForegroundColor Yellow
    
    if ($TestOnly) {
        Write-Host "  [TEST MODE] Would update $($server.Name)" -ForegroundColor Yellow
        $updateResults += @{
            Server = $server.Name
            Success = $true
            Action = "TEST MODE - No actual update performed"
            Version = $server.TargetVersion
        }
        continue
    }
    
    try {
        # Test WinRM connection
        Write-Host "  Testing WinRM connection..." -NoNewline
        $testSession = New-PSSession -ComputerName $server.FQDN -Credential $uvwCredential -ErrorAction Stop
        Write-Host " ✓ OK" -ForegroundColor Green
        
        # Copy and update CertWebService
        Write-Host "  Updating CertWebService..." -NoNewline
        
        $updateResult = Invoke-Command -Session $testSession -ScriptBlock {
            param($NewCertWebServiceContent)
            
            try {
                # Stop existing CertWebService
                Get-Process powershell | Where-Object { $_.CommandLine -like "*CertWebService*" } | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                
                # Backup current version
                if (Test-Path "C:\CertWebService\CertWebService.ps1") {
                    $backupPath = "C:\CertWebService\CertWebService-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"
                    Copy-Item "C:\CertWebService\CertWebService.ps1" $backupPath -Force
                }
                
                # Write new version
                $NewCertWebServiceContent | Out-File -FilePath "C:\CertWebService\CertWebService.ps1" -Encoding UTF8 -Force
                
                # Start new service
                Set-Location "C:\CertWebService"
                Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
                
                # Wait and verify
                Start-Sleep -Seconds 5
                $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 15
                $healthData = $response.Content | ConvertFrom-Json
                
                return @{
                    Success = $true
                    Version = $healthData.version
                    CertCount = $healthData.certificateCount
                }
                
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList (Get-Content "$PSScriptRoot\CertWebService.ps1" -Raw)
        
        Remove-PSSession $testSession
        
        if ($updateResult.Success) {
            Write-Host " ✓ SUCCESS" -ForegroundColor Green
            Write-Host "    New version: $($updateResult.Version)" -ForegroundColor Green
            Write-Host "    Certificates: $($updateResult.CertCount)" -ForegroundColor Green
            
            $updateResults += @{
                Server = $server.Name
                Success = $true
                Action = "Updated successfully"
                Version = $updateResult.Version
                CertCount = $updateResult.CertCount
            }
        } else {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            Write-Host "    Error: $($updateResult.Error)" -ForegroundColor Red
            
            $updateResults += @{
                Server = $server.Name
                Success = $false
                Error = $updateResult.Error
                Action = "Update failed"
            }
        }
        
    } catch {
        Write-Host " ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        
        $updateResults += @{
            Server = $server.Name
            Success = $false
            Error = $_.Exception.Message
            Action = "Connection or execution error"
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  UPDATE SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$successful = $updateResults | Where-Object { $_.Success }
$failed = $updateResults | Where-Object { -not $_.Success }

Write-Host ""
Write-Host "Results:" -ForegroundColor Yellow
Write-Host "  Total servers: $($updateResults.Count)" -ForegroundColor White
Write-Host "  Successful: $($successful.Count)" -ForegroundColor Green
Write-Host "  Failed: $($failed.Count)" -ForegroundColor Red
Write-Host ""

if ($successful.Count -gt 0) {
    Write-Host "Successfully Updated:" -ForegroundColor Green
    foreach ($result in $successful) {
        if ($result.Version) {
            Write-Host "  ✓ [$($result.Server)] → $($result.Version) ($($result.CertCount) certificates)" -ForegroundColor Green
        } else {
            Write-Host "  ✓ [$($result.Server)] $($result.Action)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

if ($failed.Count -gt 0) {
    Write-Host "Failed Updates:" -ForegroundColor Red
    foreach ($result in $failed) {
        Write-Host "  ✗ [$($result.Server)] $($result.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

$statusColor = if ($failed.Count -eq 0) { "Green" } else { "Yellow" }
$statusText = if ($TestOnly) { "Test completed!" } else { "Update deployment completed!" }
Write-Host $statusText -ForegroundColor $statusColor