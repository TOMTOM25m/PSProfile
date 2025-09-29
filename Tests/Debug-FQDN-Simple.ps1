# Simple FQDN Debug Test
# Purpose: Test why FQDN construction is not working
# Author: Certificate Surveillance System
# Date: September 9, 2025

# Import required modules
$ModulePath = "f:\DEV\repositories\CertSurv\Modules"
Import-Module "$ModulePath\FL-NetworkOperations.psm1" -Force

Write-Host "=== FQDN Debug Test ===" -ForegroundColor Green

# Simulate config values
$MainDomain = "meduniwien.ac.at"
$FqdnColumnName = "FQDN"

Write-Host "Main Domain: $MainDomain" -ForegroundColor Yellow
Write-Host "FQDN Column: $FqdnColumnName" -ForegroundColor Yellow

# Test cases
$testCases = @(
    @{ ServerName = "ZUKO"; ExistingFqdn = "ZUKO.meduniwien.ac.at"; Description = "Server with simple FQDN" },
    @{ ServerName = "itsclic07"; ExistingFqdn = "itsclic07.meduniwien.ac.at"; Description = "Server with simple FQDN" },
    @{ ServerName = "HCS01"; ExistingFqdn = ""; Description = "Server with no existing FQDN" },
    @{ ServerName = "test01"; ExistingFqdn = "test01.SRV.meduniwien.ac.at"; Description = "Server with SRV subdomain" }
)

foreach ($test in $testCases) {
    Write-Host "`n[TEST] $($test.Description)" -ForegroundColor Cyan
    Write-Host "  Server: '$($test.ServerName)'" -ForegroundColor White
    Write-Host "  Existing FQDN: '$($test.ExistingFqdn)'" -ForegroundColor Gray
    
    # Clean server name
    $cleanName = Format-ServerName -ServerName $test.ServerName
    $currentSubdomain = ""  # Simulate empty subdomain from Excel processing
    $workgroupSubdomain = if ([string]::IsNullOrWhiteSpace($currentSubdomain)) { "SRV" } else { $currentSubdomain }
    
    Write-Host "  Clean Name: '$cleanName'" -ForegroundColor Gray
    Write-Host "  Workgroup Subdomain: '$workgroupSubdomain'" -ForegroundColor Gray
    
    # Simulate the Update-WorkgroupServer logic
    if ($test.ExistingFqdn -and -not [string]::IsNullOrWhiteSpace($test.ExistingFqdn)) {
        Write-Host "  [EXISTING] Has existing FQDN: '$($test.ExistingFqdn)'" -ForegroundColor Red
        
        # Check if it matches simple pattern: server.domain (no subdomain)
        $pattern = "^([^.]+)\.($([regex]::Escape($MainDomain)))$"
        Write-Host "  [PATTERN] Testing pattern: $pattern" -ForegroundColor DarkGray
        
        if ($test.ExistingFqdn -match $pattern) {
            $newFqdn = Build-IntelligentFQDN -ServerName $cleanName -Subdomain $workgroupSubdomain -MainDomain $MainDomain
            Write-Host "  [REBUILD] Pattern matches! Should rebuild to: '$newFqdn'" -ForegroundColor Yellow
        } else {
            Write-Host "  [KEEP] Pattern doesn't match, keeping: '$($test.ExistingFqdn)'" -ForegroundColor Green
        }
    } else {
        $newFqdn = Build-IntelligentFQDN -ServerName $cleanName -Subdomain $workgroupSubdomain -MainDomain $MainDomain
        Write-Host "  [NEW] No existing FQDN, building new: '$newFqdn'" -ForegroundColor Green
    }
}

Write-Host "`n=== Key Insights ===" -ForegroundColor Magenta
Write-Host "1. If Excel has existing FQDN values, they are used unless pattern matches" -ForegroundColor Yellow
Write-Host "2. Pattern detection should rebuild server.domain to server.SRV.domain" -ForegroundColor Yellow
Write-Host "3. The issue might be that Excel already contains simple FQDNs" -ForegroundColor Yellow

Write-Host "`n=== Debug Complete ===" -ForegroundColor Green
