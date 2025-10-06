#Requires -Version 5.1

<#
.SYNOPSIS
    Show-CertWebService-With-Domain-Context.ps1 - Baut vollständige FQDNs mit Domain-Context
.DESCRIPTION
    Verwendet Domain/Workgroup-Informationen aus Excel-Block-Headern um vollständige FQDNs zu bauen
.NOTES
    Beispiel:
    - Block: (Domain)UVW
    - Hostname: proman
    - Ergebnis: proman.uvw.meduniwien.ac.at
#>

$ErrorActionPreference = "Continue"

function Get-ServersWithDomainContext {
    try {
        # Load Excel data with ImportExcel
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Install-Module -Name ImportExcel -Force -Scope CurrentUser
        }
        Import-Module ImportExcel -Force
        
        $configPath = "F:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
        $config = Get-Content $configPath | ConvertFrom-Json
        
        $excelData = Import-Excel -Path $config.ExcelFilePath -WorksheetName $config.ExcelWorksheet -NoHeader
        
        $serversWithContext = @()
        $currentDomain = "srv" # Default workgroup
        $currentType = "Workgroup"
        
        foreach ($row in $excelData) {
            $serverNameCell = $row.P1
            if ([string]::IsNullOrWhiteSpace($serverNameCell)) { continue }
            $serverName = $serverNameCell.ToString().Trim()
            
            # Check for domain block: (Domain)XXX
            $domainMatch = [regex]::Match($serverName, '^\(Domain(?:-[\w]+)?\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($domainMatch.Success) {
                $currentDomain = $domainMatch.Groups[1].Value.Trim().ToLower()
                $currentType = "Domain"
                Write-Host "Found Domain block: $currentDomain" -ForegroundColor Cyan
                continue
            }
            
            # Check for workgroup block: (Workgroup)XXX
            $workgroupMatch = [regex]::Match($serverName, '^\(Workgroup\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($workgroupMatch.Success) {
                $currentDomain = $workgroupMatch.Groups[1].Value.Trim().ToLower()
                $currentType = "Workgroup"
                Write-Host "Found Workgroup block: $currentDomain" -ForegroundColor Cyan
                continue
            }
            
            # Check for block end: SUMME
            if ($serverName -match '^SUMME:?\s*$') {
                Write-Host "End of block detected. Resetting to default." -ForegroundColor Gray
                $currentDomain = "srv"
                $currentType = "Workgroup"
                continue
            }
            
            # Skip headers
            if ($serverName -match '^(ServerName|Server|Servers|NEUE SERVER|DATACENTER|STANDARD)') {
                continue
            }
            
            # Process as server
            if ($serverName.Length -gt 2 -and $serverName -notmatch '^[\s\-_=]+$') {
                # Build FQDN
                $fqdn = $serverName
                if (-not $serverName.Contains('.')) {
                    # Only hostname provided - build FQDN
                    $fqdn = "${serverName}.${currentDomain}.meduniwien.ac.at"
                }
                
                $serverInfo = [PSCustomObject]@{
                    OriginalName = $serverName
                    FQDN = $fqdn
                    Domain = $currentDomain
                    DomainType = $currentType
                    IsDomain = ($currentType -eq "Domain")
                }
                
                $serversWithContext += $serverInfo
            }
        }
        
        return $serversWithContext
        
    } catch {
        Write-Host "Error reading Excel data: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

Write-Host "=== CertWebService-Server mit korrektem Domain-Context ===" -ForegroundColor Green
Write-Host "Lade Server-Daten mit Domain-Context aus Excel..." -ForegroundColor Yellow

$serversWithContext = Get-ServersWithDomainContext
Write-Host "Geladene Server: $($serversWithContext.Count)" -ForegroundColor Cyan

# Bekannte CertWebService-Server basierend auf bisherigen Tests
$knownCertWebServiceHostnames = @(
    "proman",
    "evaextest01", 
    "wsus",
    "doxis4dcesdev12",
    "doxis4dcestst12",
    "doxis4aswdev01",
    "doxis4aswtst01"
)

Write-Host ""
Write-Host "=== Test CertWebService mit vollständigen FQDNs ===" -ForegroundColor Green

$certWebServiceServers = @()

foreach ($hostname in $knownCertWebServiceHostnames) {
    Write-Host "Suche Server: $hostname..." -ForegroundColor Gray
    
    # Find server in context data
    $serverInfo = $serversWithContext | Where-Object { 
        $_.OriginalName -eq $hostname -or 
        $_.FQDN -eq $hostname -or
        $_.FQDN.StartsWith("$hostname.")
    }
    
    if ($serverInfo) {
        $fqdn = $serverInfo.FQDN
        $domain = $serverInfo.Domain
        $domainType = $serverInfo.DomainType
        
        Write-Host "  Gefunden: $hostname -> $fqdn (${domainType}: $domain)" -ForegroundColor Yellow
        
        # Test CertWebService mit vollständigem FQDN
        try {
            $url = "http://${fqdn}:9080"
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            
            if ($response.StatusCode -eq 200 -and $response.Content -match "Certificate Surveillance Dashboard") {
                $versionMatch = [regex]::Match($response.Content, 'Regelwerk v([\d\.]+)')
                $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "Unknown" }
                
                Write-Host "  [OK] $fqdn - CertWebService v$version - $url" -ForegroundColor Green
                
                $certWebServiceServers += [PSCustomObject]@{
                    Hostname = $hostname
                    FQDN = $fqdn
                    Domain = $domain
                    DomainType = $domainType
                    Version = $version
                    Url = $url
                    Status = "Running"
                }
                
            } else {
                Write-Host "  [??] $fqdn - Port 9080 open but NO CertWebService Dashboard - $url" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "  [XX] $fqdn - Not reachable: $($_.Exception.Message) - $url" -ForegroundColor Red
        }
        
    } else {
        Write-Host "  [!!] $hostname - Nicht in Excel-Daten gefunden!" -ForegroundColor Magenta
        
        # Fallback: Try common domains
        $commonDomains = @("uvw.meduniwien.ac.at", "srv.meduniwien.ac.at")
        foreach ($domain in $commonDomains) {
            $testFqdn = "${hostname}.${domain}"
            Write-Host "    Fallback-Test: $testFqdn" -ForegroundColor Gray
            
            try {
                $url = "http://${testFqdn}:9080"
                $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
                
                if ($response.StatusCode -eq 200 -and $response.Content -match "Certificate Surveillance Dashboard") {
                    Write-Host "    [OK] $testFqdn - CertWebService gefunden! - $url" -ForegroundColor Green
                    break
                }
            } catch {
                # Continue with next domain
            }
        }
    }
}

Write-Host ""
Write-Host "=== ZUSAMMENFASSUNG ===" -ForegroundColor Cyan
Write-Host "Getestete Hostnamen: $($knownCertWebServiceHostnames.Count)" -ForegroundColor White
Write-Host "CertWebService gefunden: $($certWebServiceServers.Count)" -ForegroundColor Green

if ($certWebServiceServers.Count -gt 0) {
    Write-Host ""
    Write-Host "=== AKTIVE CertWebService-Server ===" -ForegroundColor Green
    foreach ($server in $certWebServiceServers) {
        Write-Host "✅ $($server.Hostname) -> $($server.FQDN)" -ForegroundColor Green
        Write-Host "   Domain: $($server.Domain) ($($server.DomainType))" -ForegroundColor Gray
        Write-Host "   Version: $($server.Version)" -ForegroundColor Gray
        Write-Host "   URL: $($server.Url)" -ForegroundColor Gray
        Write-Host ""
    }
}