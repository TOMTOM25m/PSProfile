# Debug Domain UVW Header Processing
# Purpose: Debug why servers under "(Domain)UVW" are not processed correctly
# Author: Certificate Surveillance System
# Date: September 9, 2025

# Import required modules
$ModulePath = "f:\DEV\repositories\CertSurv\Modules"
Import-Module "$ModulePath\FL-NetworkOperations.psm1" -Force

Write-Host "=== Debug Domain UVW Header Processing ===" -ForegroundColor Green

# Test the specific case: (Domain)UVW header
$testHeader = "(Domain)UVW"
$testServer = "na0fs1bkp"

Write-Host "`n[DEBUG] Testing header: '$testHeader'" -ForegroundColor Cyan

# Test 1: Header recognition
$isSubdomainHeader = Test-IsSubdomainHeader -ServerName $testHeader
Write-Host "  Is Subdomain Header: $isSubdomainHeader" -ForegroundColor Yellow

# Test 2: Domain header detection
$isDomainHeader = Test-IsDomainHeader -HeaderValue $testHeader
Write-Host "  Is Domain Header: $isDomainHeader" -ForegroundColor Yellow

# Test 3: Subdomain extraction
if ($isSubdomainHeader) {
    $extractedSubdomain = Get-SubdomainFromHeader -HeaderValue $testHeader
    Write-Host "  Extracted Subdomain: '$extractedSubdomain'" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Header not recognized as subdomain header!" -ForegroundColor Red
}

# Test 4: Server type determination
Write-Host "`n[DEBUG] Testing server classification for: '$testServer'" -ForegroundColor Cyan

# Simulate the context that should be set after processing the header
$currentDomainContext = if ($isDomainHeader) { "Domain" } else { "" }
$currentSubdomain = if ($isSubdomainHeader) { Get-SubdomainFromHeader -HeaderValue $testHeader } else { "" }

Write-Host "  Current Domain Context: '$currentDomainContext'" -ForegroundColor Blue
Write-Host "  Current Subdomain: '$currentSubdomain'" -ForegroundColor Blue

# Get server type
$serverType = Get-ServerType -ServerName $testServer -CurrentDomainContext $currentDomainContext

Write-Host "  Server Type Result:" -ForegroundColor White
Write-Host "    Type: $($serverType.ServerType)" -ForegroundColor $(if ($serverType.IsDomain) { "Cyan" } else { "Green" })
Write-Host "    Is Domain: $($serverType.IsDomain)" -ForegroundColor Gray
Write-Host "    Is Workgroup: $($serverType.IsWorkgroup)" -ForegroundColor Gray
Write-Host "    Reason: $($serverType.Reason)" -ForegroundColor Gray

# Test 5: FQDN construction for domain server
Write-Host "`n[DEBUG] Testing FQDN construction" -ForegroundColor Cyan

$cleanServerName = Format-ServerName -ServerName $testServer
Write-Host "  Clean Server Name: '$cleanServerName'" -ForegroundColor Yellow

if ($serverType.IsDomain) {
    # For domain servers, we should build FQDN differently
    Write-Host "  [DOMAIN SERVER] Should use domain-appropriate FQDN construction" -ForegroundColor Cyan
    
    # Test with subdomain
    $domainFQDN = Build-IntelligentFQDN -ServerName $cleanServerName -Subdomain $currentSubdomain -MainDomain "meduniwien.ac.at"
    Write-Host "    Domain FQDN with subdomain: '$domainFQDN'" -ForegroundColor Green
    
    # Test without subdomain (direct to main domain)
    $directFQDN = Build-IntelligentFQDN -ServerName $cleanServerName -Subdomain "" -MainDomain "meduniwien.ac.at"
    Write-Host "    Direct FQDN: '$directFQDN'" -ForegroundColor Green
    
} else {
    Write-Host "  [WORKGROUP SERVER] Using workgroup FQDN construction" -ForegroundColor Green
    $workgroupFQDN = Build-IntelligentFQDN -ServerName $cleanServerName -Subdomain $currentSubdomain -MainDomain "meduniwien.ac.at"
    Write-Host "    Workgroup FQDN: '$workgroupFQDN'" -ForegroundColor Green
}

Write-Host "`n=== Expected vs Actual ===" -ForegroundColor Magenta
Write-Host "Expected:" -ForegroundColor Yellow
Write-Host "  - Server Type: Domain (because under '(Domain)UVW' header)" -ForegroundColor Gray
Write-Host "  - Subdomain: UVW" -ForegroundColor Gray
Write-Host "  - FQDN: na0fs1bkp.UVW.meduniwien.ac.at OR na0fs1bkp.meduniwien.ac.at" -ForegroundColor Gray

Write-Host "`nActual from log:" -ForegroundColor Yellow
Write-Host "  - Server Type: Workgroup (WRONG!)" -ForegroundColor Red
Write-Host "  - Subdomain: SRV (WRONG!)" -ForegroundColor Red
Write-Host "  - FQDN: na0fs1bkp.SRV.meduniwien.ac.at (WRONG!)" -ForegroundColor Red

Write-Host "`n=== Diagnosis ===" -ForegroundColor Red
if (!$isSubdomainHeader) {
    Write-Host "❌ Problem: Header '(Domain)UVW' not recognized as subdomain header" -ForegroundColor Red
}
if (!$isDomainHeader) {
    Write-Host "❌ Problem: Header '(Domain)UVW' not recognized as domain header" -ForegroundColor Red
}
if ($serverType.IsWorkgroup) {
    Write-Host "❌ Problem: Server incorrectly classified as Workgroup instead of Domain" -ForegroundColor Red
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Fix header recognition pattern if needed" -ForegroundColor Gray
Write-Host "2. Ensure domain context is properly set and maintained" -ForegroundColor Gray
Write-Host "3. Fix server type classification logic" -ForegroundColor Gray
Write-Host "4. Ensure Update-DomainServer is called instead of Update-WorkgroupServer" -ForegroundColor Gray
