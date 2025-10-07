<#
.SYNOPSIS
    Domain Credential Manager v1.0.0 - Multi-Domain Authentication Setup
    
.DESCRIPTION
    Sammelt und speichert Domain-spezifische Credentials für automatisierte Updates
    Unterstützt verschiedene Domains und Server-spezifische Benutzer
    
.NOTES
    Author: PowerShell Team
    Date: 07.10.2025
#>

param(
    [switch]$Setup,
    [switch]$Test,
    [switch]$Clear
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  DOMAIN CREDENTIAL MANAGER v1.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Credential Storage Path
$credentialPath = "$PSScriptRoot\Credentials"
if (-not (Test-Path $credentialPath)) {
    New-Item -Path $credentialPath -ItemType Directory -Force | Out-Null
}

# Known domains and servers
$domainMapping = @{
    "UVW" = @{
        Domain = "uvw.meduniwien.ac.at"
        Servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")
        CredentialFile = "$credentialPath\UVW-Domain.xml"
    }
    "MAIN" = @{
        Domain = "srv.meduniwien.ac.at"
        Servers = @()
        CredentialFile = "$credentialPath\MAIN-Domain.xml"
    }
    "LOCAL" = @{
        Domain = "WORKGROUP"
        Servers = @()
        CredentialFile = "$credentialPath\LOCAL-Admin.xml"
    }
}

function Store-DomainCredential {
    param(
        [string]$DomainKey,
        [hashtable]$DomainInfo
    )
    
    Write-Host "Setting up credentials for $DomainKey domain..." -ForegroundColor Yellow
    Write-Host "  Domain: $($DomainInfo.Domain)" -ForegroundColor Gray
    Write-Host "  Servers: $($DomainInfo.Servers -join ', ')" -ForegroundColor Gray
    Write-Host ""
    
    $username = Read-Host "Enter username for $($DomainInfo.Domain)"
    
    # Add domain prefix if not present
    if ($username -notcontains '\' -and $DomainInfo.Domain -ne "WORKGROUP") {
        $domainPrefix = ($DomainInfo.Domain -split '\.')[0].ToUpper()
        $fullUsername = "$domainPrefix\$username"
    } else {
        $fullUsername = $username
    }
    
    Write-Host "Full username: $fullUsername" -ForegroundColor Gray
    
    $credential = Get-Credential -UserName $fullUsername -Message "Enter password for $fullUsername"
    
    if ($credential) {
        # Store encrypted credential
        $credential | Export-CliXml -Path $DomainInfo.CredentialFile
        Write-Host "  ✓ Credentials stored for $DomainKey" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ✗ No credentials provided for $DomainKey" -ForegroundColor Red
        return $false
    }
}

function Load-DomainCredential {
    param(
        [string]$DomainKey,
        [hashtable]$DomainInfo
    )
    
    if (Test-Path $DomainInfo.CredentialFile) {
        try {
            $credential = Import-CliXml -Path $DomainInfo.CredentialFile
            Write-Host "  ✓ Loaded credentials for $DomainKey ($($credential.UserName))" -ForegroundColor Green
            return $credential
        } catch {
            Write-Host "  ✗ Failed to load credentials for $DomainKey" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "  ⚠ No stored credentials for $DomainKey" -ForegroundColor Yellow
        return $null
    }
}

function Test-DomainCredential {
    param(
        [string]$DomainKey,
        [hashtable]$DomainInfo,
        [PSCredential]$Credential
    )
    
    Write-Host "Testing credentials for $DomainKey..." -ForegroundColor Yellow
    
    if ($DomainInfo.Servers.Count -eq 0) {
        Write-Host "  ⚠ No test servers defined for $DomainKey" -ForegroundColor Yellow
        return $true
    }
    
    $testServer = $DomainInfo.Servers[0]
    $fqdn = if ($DomainKey -eq "UVW") { "$testServer.uvw.meduniwien.ac.at" } else { "$testServer.$($DomainInfo.Domain)" }
    
    try {
        # Test WinRM connection
        $testResult = Test-WSMan -ComputerName $fqdn -Credential $Credential -ErrorAction Stop
        Write-Host "  ✓ WinRM connection successful to $fqdn" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  ✗ WinRM connection failed to $fqdn" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
        return $false
    }
}

# Main Logic
if ($Clear) {
    Write-Host "Clearing all stored credentials..." -ForegroundColor Yellow
    foreach ($domain in $domainMapping.Keys) {
        $credFile = $domainMapping[$domain].CredentialFile
        if (Test-Path $credFile) {
            Remove-Item $credFile -Force
            Write-Host "  ✓ Cleared credentials for $domain" -ForegroundColor Green
        }
    }
    Write-Host "All credentials cleared!" -ForegroundColor Green
    exit 0
}

if ($Setup) {
    Write-Host "Setting up domain credentials..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($domainKey in $domainMapping.Keys) {
        $domainInfo = $domainMapping[$domainKey]
        
        Write-Host "[$domainKey] Domain Configuration:" -ForegroundColor Yellow
        Write-Host "  Domain: $($domainInfo.Domain)" -ForegroundColor White
        Write-Host "  Servers: $($domainInfo.Servers -join ', ')" -ForegroundColor White
        
        $setup = Read-Host "Setup credentials for $domainKey domain? (y/N)"
        if ($setup -eq 'y' -or $setup -eq 'Y') {
            Store-DomainCredential -DomainKey $domainKey -DomainInfo $domainInfo
        } else {
            Write-Host "  Skipped $domainKey" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Domain credential setup completed!" -ForegroundColor Green
    exit 0
}

if ($Test) {
    Write-Host "Testing stored credentials..." -ForegroundColor Cyan
    Write-Host ""
    
    $allSuccessful = $true
    
    foreach ($domainKey in $domainMapping.Keys) {
        $domainInfo = $domainMapping[$domainKey]
        
        Write-Host "[$domainKey] Testing..." -ForegroundColor Yellow
        
        $credential = Load-DomainCredential -DomainKey $domainKey -DomainInfo $domainInfo
        if ($credential) {
            $testResult = Test-DomainCredential -DomainKey $domainKey -DomainInfo $domainInfo -Credential $credential
            if (-not $testResult) {
                $allSuccessful = $false
            }
        } else {
            $allSuccessful = $false
        }
        Write-Host ""
    }
    
    if ($allSuccessful) {
        Write-Host "All credential tests passed! ✓" -ForegroundColor Green
    } else {
        Write-Host "Some credential tests failed! ✗" -ForegroundColor Red
    }
    exit 0
}

# Default: Show current status
Write-Host "Current credential status:" -ForegroundColor Yellow
Write-Host ""

foreach ($domainKey in $domainMapping.Keys) {
    $domainInfo = $domainMapping[$domainKey]
    
    Write-Host "[$domainKey] $($domainInfo.Domain)" -ForegroundColor Cyan
    Write-Host "  Servers: $($domainInfo.Servers -join ', ')" -ForegroundColor Gray
    
    if (Test-Path $domainInfo.CredentialFile) {
        try {
            $cred = Import-CliXml $domainInfo.CredentialFile
            Write-Host "  Status: ✓ Stored ($($cred.UserName))" -ForegroundColor Green
        } catch {
            Write-Host "  Status: ✗ Corrupted" -ForegroundColor Red
        }
    } else {
        Write-Host "  Status: ⚠ Not configured" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "  -Setup    : Configure domain credentials" -ForegroundColor White
Write-Host "  -Test     : Test stored credentials" -ForegroundColor White
Write-Host "  -Clear    : Clear all credentials" -ForegroundColor White
Write-Host ""

# Show next steps
$unconfigured = @()
foreach ($domainKey in $domainMapping.Keys) {
    if (-not (Test-Path $domainMapping[$domainKey].CredentialFile)) {
        $unconfigured += $domainKey
    }
}

if ($unconfigured.Count -gt 0) {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Run: .\Domain-Credential-Manager.ps1 -Setup" -ForegroundColor Cyan
    Write-Host "2. Configure credentials for: $($unconfigured -join ', ')" -ForegroundColor White
    Write-Host "3. Test with: .\Domain-Credential-Manager.ps1 -Test" -ForegroundColor Cyan
} else {
    Write-Host "All domains configured! Ready for automated updates." -ForegroundColor Green
}