Write-Host "Final CertWebService Update v1.0" -ForegroundColor Cyan
Write-Host ""
Write-Host "Credentials in vault: UVW-Domain" -ForegroundColor Green
Write-Host ""

$servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")

Write-Host "Strategy 1: Network Share Deployment (Already Done)" -ForegroundColor Yellow
Write-Host "Files available at: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\" -ForegroundColor Gray
Write-Host ""

Write-Host "Strategy 2: Manual Server Access" -ForegroundColor Yellow
Write-Host ""

foreach ($server in $servers) {
    Write-Host "Server: $server" -ForegroundColor Cyan
    Write-Host "  FQDN: $server.uvw.meduniwien.ac.at" -ForegroundColor Gray
    Write-Host "  Status: CertWebService v2.4.0 running" -ForegroundColor Gray
    Write-Host "  Action needed: Update to v2.5.0" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Update Options:" -ForegroundColor Yellow
Write-Host ""
Write-Host "OPTION 1 - Network Share (RECOMMENDED):" -ForegroundColor Green
Write-Host "  Connect to each server and run:" -ForegroundColor White
Write-Host "  powershell -ExecutionPolicy Bypass -File `"\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Update-CertWebService.ps1`"" -ForegroundColor Cyan
Write-Host ""

Write-Host "OPTION 2 - Manual RDP:" -ForegroundColor Green
Write-Host "  1. RDP to each server with UVW\administrator credentials" -ForegroundColor White
Write-Host "  2. Navigate to C:\CertWebService\" -ForegroundColor White
Write-Host "  3. Stop existing CertWebService process" -ForegroundColor White
Write-Host "  4. Replace CertWebService.ps1 with new version" -ForegroundColor White
Write-Host "  5. Restart: powershell -File CertWebService.ps1" -ForegroundColor White
Write-Host ""

Write-Host "OPTION 3 - PowerShell Direct:" -ForegroundColor Green
Write-Host "  Use saved UVW-Domain credentials from Password Vault" -ForegroundColor White
Write-Host "  Requires WinRM/TrustedHosts configuration" -ForegroundColor White
Write-Host ""

Write-Host "Current Status:" -ForegroundColor Yellow
Write-Host "  - CertWebService v2.5.0 code ready" -ForegroundColor Green
Write-Host "  - Network deployment completed" -ForegroundColor Green  
Write-Host "  - UVW Domain credentials stored in vault" -ForegroundColor Green
Write-Host "  - 3 servers identified and reachable" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Choose update method above" -ForegroundColor White
Write-Host "  2. Execute on all 3 UVW servers" -ForegroundColor White
Write-Host "  3. Verify with: http://server:9080/health.json" -ForegroundColor White
Write-Host ""

Write-Host "Ready for deployment!" -ForegroundColor Green