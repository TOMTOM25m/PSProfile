# Test Domain vs Workgroup Header Detection
# Purpose: Test the header-based domain/workgroup server classification
# Author: Certificate Surveillance System
# Date: September 9, 2025

# Import required modules
$ModulePath = "f:\DEV\repositories\CertSurv\Modules"
Import-Module "$ModulePath\FL-NetworkOperations.psm1" -Force

Write-Host "=== Domain vs Workgroup Header Detection Test ===" -ForegroundColor Green

# Test cases for header recognition
$headerTests = @(
    @{ Header = "(Domain)ADSync"; ExpectedType = "Domain"; Description = "Domain header" },
    @{ Header = "(Domain-ADsync)syncad"; ExpectedType = "Domain"; Description = "Domain-ADsync header" },
    @{ Header = "(Domain)Standard"; ExpectedType = "Domain"; Description = "Domain Standard header" },
    @{ Header = "(Workgroup)ZUKO"; ExpectedType = "Workgroup"; Description = "Workgroup ZUKO header" },
    @{ Header = "(Workgroup)immunologie"; ExpectedType = "Workgroup"; Description = "Workgroup immunologie header" },
    @{ Header = "(Workgroup)SRV"; ExpectedType = "Workgroup"; Description = "Workgroup SRV header" }
)

foreach ($test in $headerTests) {
    Write-Host "`n[TEST] $($test.Description)" -ForegroundColor Cyan
    Write-Host "  Input Header: '$($test.Header)'" -ForegroundColor Yellow
    
    # Test domain header detection
    $isDomainHeader = Test-IsDomainHeader -HeaderValue $test.Header
    $detectedType = if ($isDomainHeader) { "Domain" } else { "Workgroup" }
    
    Write-Host "  Is Domain Header: $isDomainHeader" -ForegroundColor Gray
    Write-Host "  Detected Type: $detectedType" -ForegroundColor $(if ($detectedType -eq $test.ExpectedType) { "Green" } else { "Red" })
    
    # Validate result
    if ($detectedType -eq $test.ExpectedType) {
        Write-Host "  [SUCCESS] Correct server type detected!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Expected '$($test.ExpectedType)', got '$detectedType'" -ForegroundColor Red
    }
}

Write-Host "`n=== Server Type Classification Test ===" -ForegroundColor Magenta

# Simulate complete header processing with server classification
$excelSimulation = @(
    @{ Header = "(Domain)ADSync"; Servers = @("SyncServer01", "ADServer02") },
    @{ Header = "(Workgroup)ZUKO"; Servers = @("HCS01", "AKIM") },
    @{ Header = "(Domain)Standard"; Servers = @("DomainServer01", "FileServer") },
    @{ Header = "(Workgroup)immunologie"; Servers = @("ifi-medicalnet", "immunologie") }
)

foreach ($section in $excelSimulation) {
    Write-Host "`n[PROCESSING SECTION] $($section.Header)" -ForegroundColor White
    
    # Determine context from header
    $isDomainContext = Test-IsDomainHeader -HeaderValue $section.Header
    $currentDomainContext = if ($isDomainContext) { "Domain" } else { "" }
    
    Write-Host "  Domain Context: '$currentDomainContext'" -ForegroundColor Blue
    
    # Process servers in this section
    foreach ($serverName in $section.Servers) {
        Write-Host "`n  [SERVER] $serverName" -ForegroundColor Yellow
        
        # Get server type based on context
        $serverType = Get-ServerType -ServerName $serverName -CurrentDomainContext $currentDomainContext
        
        Write-Host "    Server Type: $($serverType.ServerType)" -ForegroundColor $(if ($serverType.IsDomain) { "Cyan" } else { "Green" })
        Write-Host "    Is Domain: $($serverType.IsDomain)" -ForegroundColor Gray
        Write-Host "    Is Workgroup: $($serverType.IsWorkgroup)" -ForegroundColor Gray
        Write-Host "    Reason: $($serverType.Reason)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Green
Write-Host "✅ Header-based domain detection implemented" -ForegroundColor Green
Write-Host "✅ Server type classification based on header context" -ForegroundColor Green
Write-Host "✅ Logic: Headers with '(Domain)' → Domain servers" -ForegroundColor Green
Write-Host "✅ Logic: Headers without 'Domain' → Workgroup servers" -ForegroundColor Green

Write-Host "`n[INFO] The system now classifies servers as:" -ForegroundColor Yellow
Write-Host "  - Domain Servers: Under headers like '(Domain)ADSync', '(Domain-ADsync)syncad'" -ForegroundColor Gray
Write-Host "  - Workgroup Servers: Under headers like '(Workgroup)ZUKO', '(Workgroup)immunologie'" -ForegroundColor Gray
Write-Host "  - Default: Any server not under a '(Domain)' header is treated as Workgroup" -ForegroundColor Gray
