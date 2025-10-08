# PSRemoting Installation - Quick Test

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  PSRemoting Installation Test" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Network Share
Write-Host "[TEST 1] Teste Network Share Zugriff..." -ForegroundColor Yellow
$networkShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\PSremotingAMServer"

if (Test-Path $networkShare) {
    Write-Host "[SUCCESS] Network Share erreichbar" -ForegroundColor Green
    Write-Host "  Path: $networkShare" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Network Share nicht erreichbar!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Script-Dateien
Write-Host "[TEST 2] Pruefe Script-Dateien..." -ForegroundColor Yellow
$requiredFiles = @(
    "Configure-PSRemoting.ps1",
    "Show-PSRemotingWhitelist.ps1", 
    "Install-PSRemoting.bat"
)

$allFilesFound = $true
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $networkShare $file
    if (Test-Path $filePath) {
        Write-Host "[SUCCESS] $file" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] $file - FEHLT!" -ForegroundColor Red
        $allFilesFound = $false
    }
}

if (-not $allFilesFound) {
    Write-Host ""
    Write-Host "[ERROR] Nicht alle Dateien vorhanden!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Script-Syntax
Write-Host "[TEST 3] Teste Script-Syntax..." -ForegroundColor Yellow
$scriptPath = Join-Path $networkShare "Configure-PSRemoting.ps1"

try {
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
    
    if ($errors.Count -eq 0) {
        Write-Host "[SUCCESS] Keine Syntax-Fehler" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Syntax-Fehler gefunden!" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  $($error.Message)" -ForegroundColor Red
        }
        exit 1
    }
} catch {
    Write-Host "[ERROR] Konnte Script nicht laden: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 4: Admin-Rechte
Write-Host "[TEST 4] Pruefe Administrator-Rechte..." -ForegroundColor Yellow
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "[SUCCESS] Administrator-Rechte vorhanden" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Keine Administrator-Rechte!" -ForegroundColor Yellow
    Write-Host "  Installation erfordert Admin-Rechte" -ForegroundColor Gray
}

Write-Host ""

# Zusammenfassung
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  TEST ABGESCHLOSSEN" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

if ($allFilesFound -and $isAdmin) {
    Write-Host "[SUCCESS] Alle Tests bestanden!" -ForegroundColor Green
    Write-Host ""
    Write-Host "BEREIT FUR INSTALLATION:" -ForegroundColor Yellow
    Write-Host "  $networkShare\Install-PSRemoting.bat" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Oder PowerShell:" -ForegroundColor Yellow  
    Write-Host "  cd '$networkShare'" -ForegroundColor Cyan
    Write-Host "  .\Configure-PSRemoting.ps1" -ForegroundColor Cyan
} else {
    if (-not $isAdmin) {
        Write-Host "[WARNING] Als Administrator ausfuehren!" -ForegroundColor Yellow
    }
}

Write-Host ""
