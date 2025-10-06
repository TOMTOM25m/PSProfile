# Quick Fix - Deploy ScanCertificates.ps1
param(
    [string[]]$Servers = @("itscmgmt03.srv.meduniwien.ac.at", "wsus.srv.meduniwien.ac.at")
)

$scanScript = ".\ScanCertificates.ps1"

if (-not (Test-Path $scanScript)) {
    Write-Host "ERROR: ScanCertificates.ps1 not found!" -ForegroundColor Red
    exit 1
}

foreach ($server in $Servers) {
    Write-Host "`n=== Server: $server ===" -ForegroundColor Cyan
    
    $targetPath = "\\$server\c$\inetpub\wwwroot\CertWebService"
    
    if (-not (Test-Path $targetPath)) {
        Write-Host "Creating directory..." -ForegroundColor Yellow
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Host "Deploying ScanCertificates.ps1..." -ForegroundColor Yellow
    Copy-Item $scanScript -Destination "$targetPath\ScanCertificates.ps1" -Force
    Write-Host "OK - Script deployed" -ForegroundColor Green
    
    Write-Host "Running scan..." -ForegroundColor Yellow
    Invoke-Command -ComputerName $server -ScriptBlock {
        param($path)
        & powershell.exe -ExecutionPolicy Bypass -File "$path\ScanCertificates.ps1"
    } -ArgumentList "C:\inetpub\wwwroot\CertWebService"
    
    Write-Host "DONE!" -ForegroundColor Green
}
