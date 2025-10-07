#requires -Version 5.1

<#
.SYNOPSIS
    Test Credential Manager Integration v1.0.0

.DESCRIPTION
    Testet und verwendet FL-CredentialManager für ITSCMGMT03 Zugriff.
#>

# Import Credential Manager
Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1" -Force

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CREDENTIAL MANAGER TEST" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Option 1: Credential speichern (einmalig)
Write-Host "[OPTION 1] Save new credential" -ForegroundColor Yellow
Write-Host "  Target: ITSCMGMT03" -ForegroundColor Gray
Write-Host "  Example Username: itscmgmt03\Administrator" -ForegroundColor Gray
Write-Host ""
Write-Host "Save credential now? (Y/N): " -ForegroundColor Yellow -NoNewline
$save = Read-Host

if ($save -eq "Y" -or $save -eq "y") {
    $cred = Get-Credential -UserName "itscmgmt03\Administrator" -Message "Enter credentials for ITSCMGMT03"
    
    if ($cred) {
        $result = Save-StoredCredential -Target "ITSCMGMT03" -Credential $cred
        
        if ($result) {
            Write-Host "[OK] Credential saved successfully!" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Failed to save credential" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Option 2: Credential laden und testen
Write-Host "[OPTION 2] Load and test credential" -ForegroundColor Yellow
Write-Host ""

# Automatisches Laden mit Fallback
$cred = Get-OrPromptCredential -Target "ITSCMGMT03" -Username "itscmgmt03\Administrator" -SaveIfNew

if ($cred) {
    Write-Host "[OK] Credential loaded: $($cred.UserName)" -ForegroundColor Green
    Write-Host ""
    
    # Test: Remote Command
    Write-Host "[TEST] Testing remote connection..." -ForegroundColor Yellow
    
    try {
        # DevSkim: ignore DS104456 - Required for credential test
        $result = Invoke-Command -ComputerName ITSCMGMT03.srv.meduniwien.ac.at -Credential $cred -ScriptBlock {
            [PSCustomObject]@{
                Computer = $env:COMPUTERNAME
                User = $env:USERNAME
                Domain = $env:USERDOMAIN
                Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        } -ErrorAction Stop
        
        Write-Host "[OK] Connection successful!" -ForegroundColor Green
        Write-Host "  Computer: $($result.Computer)" -ForegroundColor Gray
        Write-Host "  User: $($result.Domain)\$($result.User)" -ForegroundColor Gray
        Write-Host "  Time: $($result.Time)" -ForegroundColor Gray
        
    } catch {
        Write-Host "[ERROR] Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "[ERROR] No credential available" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Option 3: Credential löschen
Write-Host "[OPTION 3] Remove credential" -ForegroundColor Yellow
Write-Host ""
Write-Host "Remove stored credential? (Y/N): " -ForegroundColor Yellow -NoNewline
$remove = Read-Host

if ($remove -eq "Y" -or $remove -eq "y") {
    $result = Remove-StoredCredential -Target "ITSCMGMT03"
    
    if ($result) {
        Write-Host "[OK] Credential removed" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Credential not found or already removed" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  USAGE IN SCRIPTS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Import Module" -ForegroundColor Gray
Write-Host 'Import-Module ".\Modules\FL-CredentialManager-v1.0.psm1"' -ForegroundColor White
Write-Host ""
Write-Host "# Get Credential (auto-load or prompt)" -ForegroundColor Gray
Write-Host '$cred = Get-OrPromptCredential -Target "ITSCMGMT03" -SaveIfNew' -ForegroundColor White
Write-Host ""
Write-Host "# Use Credential" -ForegroundColor Gray
Write-Host 'Invoke-Command -ComputerName ITSCMGMT03 -Credential $cred -ScriptBlock { ... }' -ForegroundColor White
Write-Host ""
