# Test Complete Excel Processing Flow  
# Purpose: Simulate complete Excel processing to debug Domain UVW issue
# Author: Certificate Surveillance System
# Date: September 9, 2025

# Import required modules
$ModulePath = "f:\DEV\repositories\CertSurv\Modules"
Import-Module "$ModulePath\FL-NetworkOperations.psm1" -Force

Write-Host "=== Complete Excel Processing Flow Debug ===" -ForegroundColor Green

# Simulate Excel data with the problematic case
$simulatedExcelData = @(
    # Previous headers/servers (to test context tracking)
    @{ ServerName = "(Workgroup)ZUKO"; Type = "Header" },
    @{ ServerName = "HCS01"; Type = "Server" },
    @{ ServerName = "(Domain)UVW"; Type = "Header" },  # The problematic header
    @{ ServerName = "na0fs1bkp"; Type = "Server" },     # The problematic server
    @{ ServerName = "uvwes01"; Type = "Server" },       # Another server in same section
    @{ ServerName = "(Workgroup)immunologie"; Type = "Header" },
    @{ ServerName = "ifi-medicalnet"; Type = "Server" }
)

# Simulate config
$Config = @{
    Excel = @{
        ServerNameColumnName = "ServerName"
        FqdnColumnName = "FQDN"
        DomainStatusColumnName = "DomainStatus"
    }
    MainDomain = "meduniwien.ac.at"
}

# Convert to objects with proper properties
$ServerData = @()
foreach ($item in $simulatedExcelData) {
    $obj = New-Object PSObject -Property @{
        ServerName = $item.ServerName
        FQDN = ""
        DomainStatus = ""
        Type = $item.Type
    }
    $ServerData += $obj
}

Write-Host "`n=== Simulating Excel Processing Logic ===" -ForegroundColor Cyan

# Replicate the exact logic from Invoke-NetworkOperations
$currentDomain = ""
$currentSubdomain = ""
$domainServersCount = 0
$workgroupServersCount = 0

foreach ($row in $ServerData) {
    $serverName = $row.ServerName
    $domainStatusValue = $row.DomainStatus
    
    Write-Host "`n[PROCESSING] '$serverName' (Type: $($row.Type))" -ForegroundColor White
    
    # Check for subdomain header row (Domain, Domain-ADsync, Workgroup, etc.)
    if (Test-IsSubdomainHeader -ServerName $serverName) {
        Write-Host "  → Detected as subdomain header" -ForegroundColor Blue
        
        # Extract subdomain from patterns like "(Domain)NEURO", "(Domain-ADsync)syncad", "(Workgroup)SRV"
        $extractedSubdomain = Get-SubdomainFromHeader -HeaderValue $serverName
        if ($extractedSubdomain) {
            $currentSubdomain = $extractedSubdomain
            Write-Host "  → Subdomain context set to: '$currentSubdomain'" -ForegroundColor Blue
        }
        
        # Set domain context based on header type
        if (Test-IsDomainHeader -HeaderValue $serverName) {
            $currentDomain = "Domain"  # Headers with "(Domain)" indicate domain servers
            Write-Host "  → Domain context set to: '$currentDomain'" -ForegroundColor Blue
        } else {
            $currentDomain = ""  # Headers without "Domain" indicate workgroup servers
            Write-Host "  → Domain context cleared (workgroup header)" -ForegroundColor Blue
        }
        continue
    }
    
    # Skip empty server names
    if ([string]::IsNullOrWhiteSpace($serverName)) { continue }
    
    # Clean server name (remove (Domain-ADsync), (Workgroup) etc.)
    $cleanServerName = Clean-ServerName -ServerName $serverName
    if ([string]::IsNullOrWhiteSpace($cleanServerName)) {
        Write-Host "  → Skip: Empty server name after cleaning" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "  → Processing server '$serverName' -> cleaned: '$cleanServerName'" -ForegroundColor Yellow
    Write-Host "  → Current context - Domain: '$currentDomain', Subdomain: '$currentSubdomain'" -ForegroundColor Gray
    
    # Determine server type based on current domain context
    $serverTypeInfo = Get-ServerType -ServerName $serverName -CurrentDomainContext $currentDomain -DomainStatusValue $domainStatusValue
    
    Write-Host "  → Server identified as $($serverTypeInfo.ServerType) (Reason: $($serverTypeInfo.Reason))" -ForegroundColor $(if ($serverTypeInfo.IsDomain) { "Cyan" } else { "Green" })
    
    # Process based on server type
    if ($serverTypeInfo.IsWorkgroup) {
        $workgroupServersCount++
        Write-Host "  → Will call Update-WorkgroupServer" -ForegroundColor Green
        # Simulate workgroup processing
        $workgroupSubdomain = if ([string]::IsNullOrWhiteSpace($currentSubdomain)) { "SRV" } else { $currentSubdomain }
        $fqdn = Build-IntelligentFQDN -ServerName $cleanServerName -Subdomain $workgroupSubdomain -MainDomain $Config.MainDomain
        Write-Host "    → Workgroup FQDN: '$fqdn'" -ForegroundColor Green
    }
    elseif ($serverTypeInfo.IsDomain -and -not [string]::IsNullOrWhiteSpace($currentDomain)) {
        $domainServersCount++
        Write-Host "  → Will call Update-DomainServer" -ForegroundColor Cyan
        # Simulate domain processing
        if ([string]::IsNullOrWhiteSpace($currentSubdomain)) {
            $fqdn = "$cleanServerName.$currentDomain.$($Config.MainDomain)"
        } else {
            $fqdn = Build-IntelligentFQDN -ServerName $cleanServerName -Subdomain $currentSubdomain -MainDomain $Config.MainDomain
        }
        Write-Host "    → Domain FQDN: '$fqdn'" -ForegroundColor Cyan
    }
    else {
        Write-Host "  → SKIP: Invalid type or no domain context" -ForegroundColor Red
        Write-Host "    → IsDomain: $($serverTypeInfo.IsDomain)" -ForegroundColor Red
        Write-Host "    → CurrentDomain: '$currentDomain'" -ForegroundColor Red
        continue
    }
}

Write-Host "`n=== Results Summary ===" -ForegroundColor Magenta
Write-Host "Domain servers processed: $domainServersCount" -ForegroundColor Cyan
Write-Host "Workgroup servers processed: $workgroupServersCount" -ForegroundColor Green

Write-Host "`n=== Expected for na0fs1bkp ===" -ForegroundColor Yellow
Write-Host "Should be: Domain server under UVW subdomain" -ForegroundColor Gray
Write-Host "Expected FQDN: na0fs1bkp.UVW.meduniwien.ac.at" -ForegroundColor Gray
