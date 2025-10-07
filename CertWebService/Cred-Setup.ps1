Write-Host "Credential Setup v1.0" -ForegroundColor Cyan
Write-Host ""

$credPath = "$PSScriptRoot\Credentials"
if (-not (Test-Path $credPath)) {
    New-Item -Path $credPath -ItemType Directory -Force
}

Write-Host "Setting up UVW Domain credentials..." -ForegroundColor Yellow
Write-Host ""

$username = Read-Host "Enter UVW username (e.g., UVW\administrator)"
$cred = Get-Credential -UserName $username -Message "Enter password for $username"

if ($cred) {
    $credFile = "$credPath\UVW-Credentials.xml"
    $cred | Export-CliXml -Path $credFile
    Write-Host "✓ Credentials saved to $credFile" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Testing connection..." -ForegroundColor Yellow
    
    try {
        $testResult = Test-WSMan -ComputerName "UVWmgmt01.uvw.meduniwien.ac.at" -Credential $cred -ErrorAction Stop
        Write-Host "✓ Connection test successful!" -ForegroundColor Green
        Write-Host "Ready for automated updates." -ForegroundColor Green
    } catch {
        Write-Host "⚠ Connection test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Credentials saved but connection needs verification." -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ No credentials provided" -ForegroundColor Red
}

Write-Host ""
Write-Host "Setup completed!" -ForegroundColor Cyan