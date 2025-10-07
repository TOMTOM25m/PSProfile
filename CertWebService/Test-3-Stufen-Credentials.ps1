#requires -Version 5.1

<#
.SYNOPSIS
    Test 3-Stufen Credential-Strategie v1.0.0

.DESCRIPTION
    Testet die intelligente Credential-Beschaffung:
    1. Default-Admin-Passwort
    2. Passwort-Vault
    3. Benutzer-Prompt mit Auto-Save
#>

Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1" -Force

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  3-STUFEN CREDENTIAL-STRATEGIE TEST" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "STRATEGIE:" -ForegroundColor Yellow
Write-Host "  [1] Default-Admin-Passwort (Environment-Variable)" -ForegroundColor Gray
Write-Host "  [2] Passwort-Vault (Windows Credential Manager)" -ForegroundColor Gray
Write-Host "  [3] Benutzer-Prompt (mit Auto-Save)" -ForegroundColor Gray
Write-Host ""

# SETUP: Default-Passwort setzen
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  SETUP: DEFAULT ADMIN PASSWORD" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Set default admin password? (Y/N): " -ForegroundColor Yellow -NoNewline
$setDefault = Read-Host

if ($setDefault -eq "Y" -or $setDefault -eq "y") {
    $defaultPass = Read-Host "Enter default admin password" -AsSecureString
    Set-DefaultAdminPassword -Password $defaultPass -Scope User
    Write-Host ""
}

# TEST 1: Mit Default-Passwort
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  TEST 1: DEFAULT PASSWORD" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$cred1 = Get-OrPromptCredential -Target "ITSCMGMT03" -Username "itscmgmt03\Administrator" -AutoSave

if ($cred1) {
    Write-Host "[OK] Credential obtained: $($cred1.UserName)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] No credential" -ForegroundColor Red
}

Write-Host ""

# TEST 2: Aus Vault (sollte jetzt gespeichert sein)
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  TEST 2: FROM VAULT (2nd run)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$cred2 = Get-OrPromptCredential -Target "ITSCMGMT03" -Username "itscmgmt03\Administrator" -AutoSave

if ($cred2) {
    Write-Host "[OK] Credential obtained: $($cred2.UserName)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] No credential" -ForegroundColor Red
}

Write-Host ""

# REMOTE TEST
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  REMOTE CONNECTION TEST" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($cred2) {
    Write-Host "Testing connection to ITSCMGMT03..." -ForegroundColor Yellow
    
    try {
        # DevSkim: ignore DS104456 - Required for credential test
        $result = Invoke-Command -ComputerName ITSCMGMT03.srv.meduniwien.ac.at -Credential $cred2 -ScriptBlock {
            [PSCustomObject]@{
                Computer = $env:COMPUTERNAME
                User = "$env:USERDOMAIN\$env:USERNAME"
                OS = (Get-CimInstance Win32_OperatingSystem).Caption
                Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            }
        } -ErrorAction Stop
        
        Write-Host "[OK] Connection successful!" -ForegroundColor Green
        Write-Host "  Computer: $($result.Computer)" -ForegroundColor Gray
        Write-Host "  User: $($result.User)" -ForegroundColor Gray
        Write-Host "  OS: $($result.OS)" -ForegroundColor Gray
        Write-Host "  Uptime: $([Math]::Round($result.Uptime.TotalHours, 1)) hours" -ForegroundColor Gray
        
    } catch {
        Write-Host "[ERROR] Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# CLEANUP OPTIONS
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CLEANUP OPTIONS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Remove stored credential from vault" -ForegroundColor Gray
Write-Host "[2] Remove default admin password" -ForegroundColor Gray
Write-Host "[3] Remove both" -ForegroundColor Gray
Write-Host "[4] Keep all" -ForegroundColor Gray
Write-Host ""
Write-Host "Select option (1-4): " -ForegroundColor Yellow -NoNewline
$cleanup = Read-Host

switch ($cleanup) {
    "1" {
        Remove-StoredCredential -Target "ITSCMGMT03"
        Write-Host "[OK] Vault credential removed" -ForegroundColor Green
    }
    "2" {
        Remove-DefaultAdminPassword -Scope User
        Write-Host "[OK] Default password removed" -ForegroundColor Green
    }
    "3" {
        Remove-StoredCredential -Target "ITSCMGMT03"
        Remove-DefaultAdminPassword -Scope User
        Write-Host "[OK] All credentials removed" -ForegroundColor Green
    }
    "4" {
        Write-Host "[INFO] Keeping all credentials" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  USAGE IN SCRIPTS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "# Setup (once):" -ForegroundColor Yellow
Write-Host 'Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1"' -ForegroundColor White
Write-Host 'Set-DefaultAdminPassword -Password "YourDefaultPassword"' -ForegroundColor White
Write-Host ""

Write-Host "# Usage in scripts:" -ForegroundColor Yellow
Write-Host '$cred = Get-OrPromptCredential `' -ForegroundColor White
Write-Host '    -Target "ITSCMGMT03" `' -ForegroundColor White
Write-Host '    -Username "itscmgmt03\Administrator" `' -ForegroundColor White
Write-Host '    -AutoSave' -ForegroundColor White
Write-Host ""

Write-Host "# Script will automatically:" -ForegroundColor Yellow
Write-Host "  1. Try default password" -ForegroundColor Gray
Write-Host "  2. Check vault" -ForegroundColor Gray
Write-Host "  3. Prompt user (if needed)" -ForegroundColor Gray
Write-Host "  4. Save for next time" -ForegroundColor Gray
Write-Host ""
