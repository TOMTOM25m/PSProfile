#Requires -Version 5.1

<#
.SYNOPSIS
    Show-ONLY-CertWebService-Servers.ps1 - Zeigt NUR die Server die tatsächlich CertWebService haben
.DESCRIPTION
    Basierend auf deinem Feedback - zeigt nur die echten CertWebService-Server mit korrekten FQDNs
#>

# Nur die Server die du bestätigt hast + die vom Script gefundenen
$confirmedCertWebServiceServers = @(
    "proman.uvw.meduniwien.ac.at",
    "evaextest01.srv.meduniwien.ac.at", 
    "wsus.srv.meduniwien.ac.at"
)

# Die vom Script als "FOUND" gemeldeten Server (basierend auf deiner Ausgabe)
$detectedCertWebServiceServers = @(
    "doxis4dcesdev12",
    "doxis4dcestst12", 
    "doxis4aswdev01",
    "doxis4aswtst01"
    # Hinweis: Andere Server aus der Excel-Liste haben wahrscheinlich KEIN CertWebService
    # sondern nur Port 9080 offen für andere Dienste
)

$allCertWebServiceServers = $confirmedCertWebServiceServers + $detectedCertWebServiceServers

Write-Host "=== NUR ECHTE CertWebService-Server ===" -ForegroundColor Green
Write-Host "Teste nur die Server die nachweislich CertWebService haben..." -ForegroundColor Yellow
Write-Host ""

$runningCount = 0
$notRunningCount = 0

foreach ($server in $allCertWebServiceServers) {
    Write-Host "Testing $server..." -ForegroundColor Gray
    
    try {
        # 1. DNS-Aufloesung fuer FQDN
        $fqdn = $server
        $dnsStatus = "Original"
        try {
            $dnsResult = [System.Net.Dns]::GetHostEntry($server)
            if ($dnsResult.HostName -ne $server) {
                $fqdn = $dnsResult.HostName
                $dnsStatus = "Resolved"
            }
        } catch {
            $dnsStatus = "DNS Failed"
        }
        
        # 2. Test CertWebService Dashboard
        $url = "http://${server}:9080"
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            
            if ($response.StatusCode -eq 200 -and $response.Content -match "Certificate Surveillance Dashboard") {
                # Extract version
                $versionMatch = [regex]::Match($response.Content, 'Regelwerk v([\d\.]+)')
                $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "Unknown" }
                
                # Success - echtes CertWebService gefunden
                $displayName = if ($fqdn -ne $server) { "$server ($fqdn)" } else { $server }
                Write-Host "  [OK] $displayName - CertWebService v$version - $url" -ForegroundColor Green
                $runningCount++
                
            } else {
                # Port offen aber kein CertWebService Dashboard
                $displayName = if ($fqdn -ne $server) { "$server ($fqdn)" } else { $server }
                Write-Host "  [??] $displayName - Port 9080 open but NO CertWebService Dashboard - $url" -ForegroundColor Yellow
                $notRunningCount++
            }
            
        } catch {
            # Nicht erreichbar
            $displayName = if ($fqdn -ne $server) { "$server ($fqdn)" } else { $server }
            Write-Host "  [XX] $displayName - Not reachable - DNS: $dnsStatus - $url" -ForegroundColor Red
            $notRunningCount++
        }
        
    } catch {
        Write-Host "  [ERROR] $server - Exception: $($_.Exception.Message)" -ForegroundColor Red
        $notRunningCount++
    }
}

Write-Host ""
Write-Host "=== ZUSAMMENFASSUNG ===" -ForegroundColor Cyan
Write-Host "Getestete Server: $($allCertWebServiceServers.Count)" -ForegroundColor White
Write-Host "CertWebService läuft: $runningCount" -ForegroundColor Green
Write-Host "Nicht erreichbar/kein CertWebService: $notRunningCount" -ForegroundColor Red
Write-Host ""
Write-Host "HINWEIS: Viele Server in der Excel-Liste haben nur zufällig Port 9080 offen," -ForegroundColor Yellow
Write-Host "aber KEIN Certificate Surveillance Dashboard!" -ForegroundColor Yellow