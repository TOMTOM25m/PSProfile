#requires -Version 5.1
<#
.SYNOPSIS
    Credential Manager Test & Management Tool
    
.DESCRIPTION
    Interactive tool for testing and managing secure credentials for CertWebService
    
.EXAMPLE
    .\Test-CredentialManager.ps1
    
.NOTES
    Version: 1.0.0
    Regelwerk: v10.1.0
#>

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Import-Module (Join-Path $scriptRoot "Modules\FL-CredentialManager.psm1") -Force

function Show-Menu {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      CertWebService Credential Manager v1.0.0           ║" -ForegroundColor White
    Write-Host "║              Regelwerk v10.1.0                           ║" -ForegroundColor Gray
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. ➕ Add/Update Credential" -ForegroundColor Green
    Write-Host "  2. 🔍 View Stored Credentials" -ForegroundColor Cyan
    Write-Host "  3. ✅ Test Credential" -ForegroundColor Yellow
    Write-Host "  4. ❌ Remove Credential" -ForegroundColor Red
    Write-Host "  5. 🧪 Test Deployment with Stored Credentials" -ForegroundColor Magenta
    Write-Host "  6. ℹ️  Show Credential Store Path" -ForegroundColor Gray
    Write-Host "  0. 🚪 Exit" -ForegroundColor White
    Write-Host ""
}

function Add-UpdateCredential {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Add/Update Credential                       ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $targetName = Read-Host "Enter target name (e.g., wsus.srv.meduniwien.ac.at)"
    
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        Write-Host "❌ Invalid target name!" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "Please enter credentials for: $targetName" -ForegroundColor Yellow
    $cred = Get-Credential -Message "Credentials for $targetName"
    
    if ($cred) {
        $success = Save-SecureCredential -Credential $cred -TargetName $targetName
        if ($success) {
            Write-Host "✅ Credential saved successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Failed to save credential!" -ForegroundColor Red
        }
    }
    else {
        Write-Host "⚠️  Operation cancelled" -ForegroundColor Yellow
    }
}

function View-StoredCredentials {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Stored Credentials                          ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $creds = Get-StoredCredentials
    
    if ($creds.Count -eq 0) {
        Write-Host "ℹ️  No credentials stored" -ForegroundColor Yellow
    }
    else {
        Write-Host "📋 Found $($creds.Count) stored credential(s):" -ForegroundColor Green
        Write-Host ""
        
        $creds | Format-Table @(
            @{Label='Target'; Expression={$_.TargetName}; Width=30},
            @{Label='Username'; Expression={$_.Username}; Width=25},
            @{Label='Created'; Expression={$_.CreatedDate}; Width=20},
            @{Label='Machine'; Expression={$_.MachineName}; Width=15}
        ) -AutoSize
    }
}

function Test-StoredCredential {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Test Credential                             ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $targetName = Read-Host "Enter target name to test"
    
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        Write-Host "❌ Invalid target name!" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "🔍 Testing credential for: $targetName" -ForegroundColor Cyan
    
    $exists = Test-SecureCredential -TargetName $targetName
    
    if ($exists) {
        Write-Host "✅ Credential exists and is valid" -ForegroundColor Green
        
        $cred = Get-SecureCredential -TargetName $targetName
        if ($cred) {
            Write-Host "   Username: $($cred.UserName)" -ForegroundColor Gray
            Write-Host "   Password: $('*' * 8)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "❌ Credential not found or invalid" -ForegroundColor Red
    }
}

function Remove-StoredCredential {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Remove Credential                           ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $targetName = Read-Host "Enter target name to remove"
    
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        Write-Host "❌ Invalid target name!" -ForegroundColor Red
        return
    }
    
    $confirm = Read-Host "⚠️  Are you sure you want to remove credential for '$targetName'? (yes/no)"
    
    if ($confirm -eq 'yes') {
        $success = Remove-SecureCredential -TargetName $targetName
        if ($success) {
            Write-Host "✅ Credential removed successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Failed to remove credential (might not exist)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "⚠️  Operation cancelled" -ForegroundColor Yellow
    }
}

function Test-DeploymentWithCredentials {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         Test Deployment with Stored Credentials          ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $targetName = Read-Host "Enter server name (e.g., wsus.srv.meduniwien.ac.at)"
    
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        Write-Host "❌ Invalid server name!" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "🔍 Retrieving credential for: $targetName" -ForegroundColor Cyan
    
    $cred = Get-SecureCredential -TargetName $targetName -PromptIfNotFound
    
    if (-not $cred) {
        Write-Host "❌ No credential available!" -ForegroundColor Red
        return
    }
    
    Write-Host "✅ Credential retrieved: $($cred.UserName)" -ForegroundColor Green
    Write-Host ""
    Write-Host "🧪 Testing network access..." -ForegroundColor Cyan
    
    try {
        $testPath = "\\$targetName\c$"
        
        # Try to mount PSDrive
        $driveName = "TestDrive$(Get-Random)"
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $testPath -Credential $cred -ErrorAction Stop | Out-Null
        
        Write-Host "✅ Network access successful!" -ForegroundColor Green
        Write-Host "   Path: $testPath" -ForegroundColor Gray
        
        # Test write access
        $testFile = "${driveName}:\test_$(Get-Random).tmp"
        "Test" | Out-File $testFile -Force
        Remove-Item $testFile -Force
        
        Write-Host "✅ Write access confirmed!" -ForegroundColor Green
        
        Remove-PSDrive -Name $driveName -Force
    }
    catch {
        Write-Host "❌ Network access failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-CredentialStorePath {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Credential Store Information                   ║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $storePath = "$env:ProgramData\CertWebService\Credentials"
    
    Write-Host "📁 Credential Store Path:" -ForegroundColor Cyan
    Write-Host "   $storePath" -ForegroundColor White
    Write-Host ""
    
    if (Test-Path $storePath) {
        Write-Host "✅ Store exists" -ForegroundColor Green
        
        $files = Get-ChildItem $storePath -Filter "*.cred" -ErrorAction SilentlyContinue
        Write-Host "📄 Files: $($files.Count)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "🔒 Security:" -ForegroundColor Yellow
        Write-Host "   - Encrypted with Windows DPAPI" -ForegroundColor Gray
        Write-Host "   - Can only be decrypted by current user on this machine" -ForegroundColor Gray
        Write-Host "   - Protected by file system ACLs (SYSTEM + Current User)" -ForegroundColor Gray
    }
    else {
        Write-Host "ℹ️  Store does not exist yet (will be created when first credential is saved)" -ForegroundColor Yellow
    }
}

# Main Loop
do {
    Show-Menu
    $choice = Read-Host "Select option"
    
    switch ($choice) {
        '1' { Add-UpdateCredential }
        '2' { View-StoredCredentials }
        '3' { Test-StoredCredential }
        '4' { Remove-StoredCredential }
        '5' { Test-DeploymentWithCredentials }
        '6' { Show-CredentialStorePath }
        '0' { 
            Write-Host "`n👋 Goodbye!" -ForegroundColor Green
            break
        }
        default { 
            Write-Host "`n❌ Invalid choice!" -ForegroundColor Red
        }
    }
    
    if ($choice -ne '0') {
        Write-Host ""
        Read-Host "Press Enter to continue"
    }
} while ($choice -ne '0')

