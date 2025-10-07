<#
.SYNOPSIS
    Direct CertWebService Update v1.0.0 - Immediate Update für identifizierte Server

.DESCRIPTION
    Führt sofortiges Update für die 3 UVW-Server durch:
    - UVWmgmt01
    - UVW-FINANZ01  
    - UVWDC001
    
    Alle haben CertWebService v2.4.0 und benötigen Update auf v2.5.0

.NOTES
    Author: PowerShell Team
    Date: 07.10.2025
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Import FL-CredentialManager für Authentifizierung
try {
    Import-Module "$PSScriptRoot\Modules\FL-CredentialManager-v1.0.psm1" -Force -ErrorAction Stop
    Write-Host "[✓] FL-CredentialManager loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[✗] Failed to load FL-CredentialManager: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[!] Continuing without credential manager..." -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  DIRECT CERTWEBSERVICE UPDATE v1.0.0" -ForegroundColor Cyan
Write-Host "  Immediate Update für UVW-Server" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Definiere die Server die ein Update benötigen
$serversToUpdate = @(
    @{
        Name = "UVWmgmt01"
        FQDN = "UVWmgmt01.uvw.meduniwien.ac.at"
        CurrentVersion = "v2.4.0"
        TargetVersion = "v2.5.0"
    },
    @{
        Name = "UVW-FINANZ01"  
        FQDN = "UVW-FINANZ01.uvw.meduniwien.ac.at"
        CurrentVersion = "v2.4.0"
        TargetVersion = "v2.5.0"
    },
    @{
        Name = "UVWDC001"
        FQDN = "UVWDC001.uvw.meduniwien.ac.at"
        CurrentVersion = "v2.4.0"
        TargetVersion = "v2.5.0"
    }
)

Write-Host "Servers scheduled for update:" -ForegroundColor Yellow
foreach ($server in $serversToUpdate) {
    Write-Host "  [$($server.Name)] $($server.CurrentVersion) → $($server.TargetVersion)" -ForegroundColor White
}
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Proceed with updating $($serversToUpdate.Count) servers? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Update cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "[STEP 1] Preparing credentials..." -ForegroundColor Cyan

# 3-Tier Credential Strategy
$credential = $null
try {
    # Tier 1: Try credential manager
    if (Get-Command "Get-FL-Credential" -ErrorAction SilentlyContinue) {
        $credential = Get-FL-Credential -Name "AdminDefault"
        if ($credential) {
            Write-Host "  ✓ Using stored credentials from FL-CredentialManager" -ForegroundColor Green
        }
    }
    
    # Tier 2: Fallback to manual prompt
    if (-not $credential) {
        Write-Host "  ! No stored credentials found, prompting for admin credentials..." -ForegroundColor Yellow
        $credential = Get-Credential -Message "Enter Administrator credentials for server access"
        if (-not $credential) {
            throw "No credentials provided"
        }
        Write-Host "  ✓ Manual credentials entered" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Credential setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[STEP 2] Updating CertWebService on servers..." -ForegroundColor Cyan

$updateResults = @()

foreach ($server in $serversToUpdate) {
    Write-Host ""
    Write-Host "Processing [$($server.Name)]..." -ForegroundColor Yellow
    
    try {
        # Test connection first
        Write-Host "  Testing connection..." -NoNewline
        $testConnection = Test-NetConnection -ComputerName $server.FQDN -Port 5985 -InformationLevel Quiet -WarningAction SilentlyContinue
        
        if (-not $testConnection) {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            $updateResults += @{
                Server = $server.Name
                Success = $false
                Error = "WinRM connection failed"
                Action = "Connection test failed"
            }
            continue
        }
        Write-Host " ✓ OK" -ForegroundColor Green
        
        # Copy new CertWebService.ps1 to server
        Write-Host "  Copying CertWebService v2.5.0..." -NoNewline
        
        $scriptBlock = {
            param($SourcePath, $TargetPath)
            
            # Stop existing service if running
            $existingProcess = Get-Process -Name "powershell" | Where-Object { 
                $_.CommandLine -like "*CertWebService*" -or $_.ProcessName -eq "CertWebService"
            } -ErrorAction SilentlyContinue
            
            if ($existingProcess) {
                Stop-Process -Id $existingProcess.Id -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            
            # Backup existing file
            if (Test-Path $TargetPath) {
                $backupPath = "$TargetPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $TargetPath $backupPath -Force
            }
            
            # Copy new version
            Copy-Item $SourcePath $TargetPath -Force
            
            # Verify version
            $content = Get-Content $TargetPath -Raw
            if ($content -match 'version.*v2\.5\.0') {
                return @{ Success = $true; Version = "v2.5.0" }
            } else {
                return @{ Success = $false; Error = "Version verification failed" }
            }
        }
        
        # Execute update via PSRemoting
        $sourcePath = "$PSScriptRoot\CertWebService.ps1"
        $targetPath = "C:\CertWebService\CertWebService.ps1"
        
        $result = Invoke-Command -ComputerName $server.FQDN -Credential $credential -ScriptBlock $scriptBlock -ArgumentList $sourcePath, $targetPath
        
        if ($result.Success) {
            Write-Host " ✓ SUCCESS" -ForegroundColor Green
            
            # Restart CertWebService
            Write-Host "  Restarting CertWebService..." -NoNewline
            
            $restartScript = {
                try {
                    Set-Location "C:\CertWebService"
                    Start-Process powershell -ArgumentList "-File CertWebService.ps1" -WindowStyle Hidden
                    Start-Sleep -Seconds 3
                    
                    # Verify service is running
                    $response = Invoke-WebRequest -Uri "http://localhost:9080/health.json" -TimeoutSec 10 -ErrorAction Stop
                    $healthData = $response.Content | ConvertFrom-Json
                    
                    return @{ 
                        Success = $true; 
                        Version = $healthData.version;
                        Status = "Running"
                    }
                } catch {
                    return @{ 
                        Success = $false; 
                        Error = $_.Exception.Message 
                    }
                }
            }
            
            $restartResult = Invoke-Command -ComputerName $server.FQDN -Credential $credential -ScriptBlock $restartScript
            
            if ($restartResult.Success) {
                Write-Host " ✓ OK (Version: $($restartResult.Version))" -ForegroundColor Green
                
                $updateResults += @{
                    Server = $server.Name
                    Success = $true
                    OldVersion = $server.CurrentVersion
                    NewVersion = $restartResult.Version
                    Action = "Updated and restarted successfully"
                }
            } else {
                Write-Host " ✗ RESTART FAILED" -ForegroundColor Red
                $updateResults += @{
                    Server = $server.Name
                    Success = $false
                    Error = $restartResult.Error
                    Action = "File updated but restart failed"
                }
            }
        } else {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            $updateResults += @{
                Server = $server.Name
                Success = $false
                Error = $result.Error
                Action = "File copy failed"
            }
        }
        
    } catch {
        Write-Host " ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $updateResults += @{
            Server = $server.Name
            Success = $false
            Error = $_.Exception.Message
            Action = "General error during update"
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  UPDATE SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$successful = $updateResults | Where-Object { $_.Success }
$failed = $updateResults | Where-Object { -not $_.Success }

Write-Host ""
Write-Host "Results:" -ForegroundColor Yellow
Write-Host "  Total servers: $($updateResults.Count)" -ForegroundColor White
Write-Host "  Successful: $($successful.Count)" -ForegroundColor Green
Write-Host "  Failed: $($failed.Count)" -ForegroundColor Red
Write-Host ""

if ($successful.Count -gt 0) {
    Write-Host "Successfully Updated:" -ForegroundColor Green
    foreach ($result in $successful) {
        Write-Host "  ✓ [$($result.Server)] $($result.OldVersion) → $($result.NewVersion)" -ForegroundColor Green
    }
    Write-Host ""
}

if ($failed.Count -gt 0) {
    Write-Host "Failed Updates:" -ForegroundColor Red
    foreach ($result in $failed) {
        Write-Host "  ✗ [$($result.Server)] $($result.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Direct CertWebService Update completed!" -ForegroundColor $(if($failed.Count -eq 0){'Green'}else{'Yellow'})