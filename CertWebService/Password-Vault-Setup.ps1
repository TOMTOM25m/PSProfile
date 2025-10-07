<#
.SYNOPSIS
    Password Vault Setup v1.0.0 - FL-CredentialManager Integration
    
.DESCRIPTION
    Nutzt das FL-CredentialManager System um Domain-Passwörter im Windows Credential Vault zu hinterlegen
    
.NOTES
    Author: PowerShell Team
    Date: 07.10.2025
    
    Requires: FL-CredentialManager-v1.0.psm1
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Action = "Setup"
)

$ErrorActionPreference = "Stop"

# Import FL-CredentialManager
try {
    Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force
    Write-Host "✓ FL-CredentialManager v1.0.0 loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load FL-CredentialManager: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  PASSWORD VAULT SETUP v1.0.0" -ForegroundColor Cyan
Write-Host "  FL-CredentialManager Integration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Define credential targets for different domains/servers
$credentialTargets = @{
    "UVW-Domain" = @{
        Description = "UVW Domain Administrator"
        DefaultUser = "UVW\administrator"
        Servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")
        TestServer = "UVWmgmt01.uvw.meduniwien.ac.at"
    }
    "Main-Domain" = @{
        Description = "Main Domain Administrator"  
        DefaultUser = "MEDUNIWIEN\administrator"
        Servers = @("ITSCMGMT03", "WSUS")
        TestServer = "itscmgmt03.srv.meduniwien.ac.at"
    }
    "Local-Admin" = @{
        Description = "Local Administrator Account"
        DefaultUser = "administrator"
        Servers = @()
        TestServer = $null
    }
}

function Setup-DomainCredentials {
    Write-Host "Setting up domain credentials in Password Vault..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($targetName in $credentialTargets.Keys) {
        $target = $credentialTargets[$targetName]
        
        Write-Host "[$targetName] $($target.Description)" -ForegroundColor Cyan
        Write-Host "  Default User: $($target.DefaultUser)" -ForegroundColor Gray
        Write-Host "  Servers: $($target.Servers -join ', ')" -ForegroundColor Gray
        Write-Host ""
        
        # Check if credentials already exist
        $existingCred = Get-StoredCredential -Target $targetName -ErrorAction SilentlyContinue
        if ($existingCred) {
            Write-Host "  ⚠ Credentials already exist for $targetName" -ForegroundColor Yellow
            Write-Host "    Current user: $($existingCred.UserName)" -ForegroundColor Gray
            
            $update = Read-Host "  Update existing credentials? (y/N)"
            if ($update -ne 'y' -and $update -ne 'Y') {
                Write-Host "  Skipped $targetName" -ForegroundColor Gray
                Write-Host ""
                continue
            }
        }
        
        # Prompt for setup
        $setup = Read-Host "  Setup credentials for $targetName? (y/N)"
        if ($setup -ne 'y' -and $setup -ne 'Y') {
            Write-Host "  Skipped $targetName" -ForegroundColor Gray
            Write-Host ""
            continue
        }
        
        # Get username (with default)
        $username = Read-Host "  Username (default: $($target.DefaultUser))"
        if ([string]::IsNullOrWhiteSpace($username)) {
            $username = $target.DefaultUser
        }
        
        # Get credentials
        $credential = Get-Credential -UserName $username -Message "Enter password for $username"
        if (-not $credential) {
            Write-Host "  ✗ No credentials provided for $targetName" -ForegroundColor Red
            Write-Host ""
            continue
        }
        
        # Save to vault
        try {
            Save-StoredCredential -Target $targetName -Credential $credential
            Write-Host "  ✓ Credentials saved to Password Vault" -ForegroundColor Green
            
            # Test connection if test server is available
            if ($target.TestServer) {
                Write-Host "  Testing connection to $($target.TestServer)..." -NoNewline
                try {
                    $testResult = Test-WSMan -ComputerName $target.TestServer -Credential $credential -ErrorAction Stop
                    Write-Host " ✓ SUCCESS" -ForegroundColor Green
                } catch {
                    Write-Host " ⚠ FAILED" -ForegroundColor Yellow
                    Write-Host "    (Credentials saved but connection test failed)" -ForegroundColor Gray
                }
            }
            
        } catch {
            Write-Host "  ✗ Failed to save credentials: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

function Test-VaultCredentials {
    Write-Host "Testing credentials from Password Vault..." -ForegroundColor Yellow
    Write-Host ""
    
    $allSuccess = $true
    
    foreach ($targetName in $credentialTargets.Keys) {
        $target = $credentialTargets[$targetName]
        
        Write-Host "[$targetName] Testing..." -ForegroundColor Cyan
        
        try {
            $credential = Get-StoredCredential -Target $targetName
            if ($credential) {
                Write-Host "  ✓ Loaded from vault: $($credential.UserName)" -ForegroundColor Green
                
                # Test connection if available
                if ($target.TestServer) {
                    Write-Host "  Testing $($target.TestServer)..." -NoNewline
                    try {
                        $testResult = Test-WSMan -ComputerName $target.TestServer -Credential $credential -ErrorAction Stop
                        Write-Host " ✓ CONNECTION OK" -ForegroundColor Green
                    } catch {
                        Write-Host " ✗ CONNECTION FAILED" -ForegroundColor Red
                        $allSuccess = $false
                    }
                }
            } else {
                Write-Host "  ⚠ No credentials found in vault" -ForegroundColor Yellow
                $allSuccess = $false
            }
        } catch {
            Write-Host "  ✗ Error loading credentials: $($_.Exception.Message)" -ForegroundColor Red
            $allSuccess = $false
        }
        
        Write-Host ""
    }
    
    if ($allSuccess) {
        Write-Host "All credential tests passed! Ready for automated updates." -ForegroundColor Green
    } else {
        Write-Host "Some tests failed. Run setup to fix issues." -ForegroundColor Yellow
    }
}

function Show-VaultStatus {
    Write-Host "Password Vault Status:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($targetName in $credentialTargets.Keys) {
        $target = $credentialTargets[$targetName]
        
        Write-Host "[$targetName] $($target.Description)" -ForegroundColor Cyan
        
        try {
            $credential = Get-StoredCredential -Target $targetName -ErrorAction SilentlyContinue
            if ($credential) {
                Write-Host "  Status: ✓ Configured ($($credential.UserName))" -ForegroundColor Green
                Write-Host "  Servers: $($target.Servers -join ', ')" -ForegroundColor Gray
            } else {
                Write-Host "  Status: ⚠ Not configured" -ForegroundColor Yellow
                Write-Host "  Servers: $($target.Servers -join ', ')" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Status: ✗ Error loading" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

# Main Logic
switch ($Action.ToLower()) {
    "setup" {
        Setup-DomainCredentials
        Write-Host "Password Vault setup completed!" -ForegroundColor Green
    }
    "test" {
        Test-VaultCredentials
    }
    "status" {
        Show-VaultStatus
    }
    default {
        Show-VaultStatus
        Write-Host ""
        Write-Host "Available actions:" -ForegroundColor Yellow
        Write-Host "  -Action Setup  : Configure credentials in Password Vault" -ForegroundColor White
        Write-Host "  -Action Test   : Test stored credentials" -ForegroundColor White
        Write-Host "  -Action Status : Show current vault status" -ForegroundColor White
        Write-Host ""
        Write-Host "Example: .\Password-Vault-Setup.ps1 -Action Setup" -ForegroundColor Cyan
    }
}