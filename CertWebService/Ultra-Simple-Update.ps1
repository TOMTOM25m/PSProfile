param([switch]$Force)

Write-Host "CertWebService Update v1.0" -ForegroundColor Cyan
Write-Host ""

$servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")

if (-not $Force) {
    $confirm = Read-Host "Update $($servers.Count) servers? (y/N)"
    if ($confirm -ne 'y') { exit 0 }
}

foreach ($server in $servers) {
    Write-Host "Updating $server..." -ForegroundColor Yellow
    
    $fqdn = "$server.uvw.meduniwien.ac.at"
    if ($server -eq "UVW-FINANZ01") { $fqdn = "$server.uvw.meduniwien.ac.at" }
    if ($server -eq "UVWDC001") { $fqdn = "$server.uvw.meduniwien.ac.at" }
    
    $path = "\\$fqdn\C$\CertWebService\CertWebService.ps1"
    
    try {
        if (Test-Path "\\$fqdn\C$\CertWebService") {
            Copy-Item "CertWebService.ps1" $path -Force
            Write-Host "  SUCCESS" -ForegroundColor Green
        } else {
            Write-Host "  NO ACCESS" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ERROR" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Files updated. Restart services manually on each server." -ForegroundColor Yellow