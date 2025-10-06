#Requires -Version 5.1

<#
.SYNOPSIS
    Show-CertWebService-FQDNs-Simple.ps1 - Zeigt alle CertWebService-Server mit FQDNs (ohne Emojis)
#>

$foundServers = @(
    "proman.uvw.meduniwien.ac.at",
    "evaextest01.srv.meduniwien.ac.at", 
    "wsus.srv.meduniwien.ac.at",
    "UVWFS01",
    "SUCCESSXPROD01",
    "UVWDC001",
    "C-SQL01",
    "C-Lic01",
    "C-LIC02",
    "UVW-FINANZ02",
    "C-APP01",
    "C-APP02",
    "adonisnpappprod",
    "adonisnpapptst",
    "COORAPPPROD01",
    "UVWDC003",
    "C-FS01",
    "proman",
    "COORAPPTEST01",
    "UVWFS02",
    "UVWFS03",
    "UVWPRINT01",
    "UVWDC002",
    "doxis4dcesdev12",
    "doxis4dcestst12",
    "doxis4aswdev01",
    "doxis4aswtst01"
)

Write-Host "=== CertWebService-Server mit vollstaendigen FQDNs ===" -ForegroundColor Green

foreach ($server in $foundServers) {
    try {
        # DNS-Aufloesung
        $fqdn = $server
        try {
            $dnsResult = [System.Net.Dns]::GetHostEntry($server)
            $fqdn = $dnsResult.HostName
        } catch {
            # DNS-Aufloesung fehlgeschlagen - verwende Original-Namen
        }
        
        # Test CertWebService
        $url = "http://${server}:9080"
        try {
            $response = Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $status = "[OK] RUNNING"
                $color = "Green"
            } else {
                $status = "[??] UNKNOWN"
                $color = "Yellow"
            }
        } catch {
            $status = "[XX] NOT REACHABLE"
            $color = "Red"
        }
        
        # Ausgabe
        if ($fqdn -ne $server) {
            Write-Host "  $server ($fqdn) - $url - $status" -ForegroundColor $color
        } else {
            Write-Host "  $server - $url - $status" -ForegroundColor $color
        }
        
    } catch {
        Write-Host "  $server - ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Insgesamt $($foundServers.Count) CertWebService-Installationen gefunden!" -ForegroundColor Cyan