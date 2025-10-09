#requires -Version 5.1
<#
.SYNOPSIS
    Remote Setup für Scheduled Task auf wsus Server
.DESCRIPTION
    Dieses Script kann direkt auf wsus.srv.meduniwien.ac.at ausgeführt werden
    oder via Copy & Execute Methode deployed werden
.VERSION
    1.0.0
.REGELWERK
    v10.1.0
#>

param(
    [string]$ServerName = "wsus.srv.meduniwien.ac.at",
    [PSCredential]$Credential
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Remote Scheduled Task Setup for wsus" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Test connectivity
Write-Host "[INFO] Testing connectivity to $ServerName..." -ForegroundColor Cyan
if (-not (Test-Connection -ComputerName $ServerName -Count 1 -Quiet)) {
    Write-Host "[ERROR] Server $ServerName not reachable!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Server reachable" -ForegroundColor Green
Write-Host ""

# Create remote script content
$remoteScriptContent = @'
# Local execution on wsus server
$taskName = "CertWebService-DailyCertScan"
$possiblePaths = @(
    "C:\inetpub\wwwroot\CertWebService\ScanCertificates.ps1",
    "C:\inetpub\CertWebService\ScanCertificates.ps1"
)

Write-Host "[INFO] Creating scheduled task: $taskName" -ForegroundColor Cyan

$scriptPath = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $scriptPath = $path
        Write-Host "[OK] Script found: $scriptPath" -ForegroundColor Green
        break
    }
}

if (-not $scriptPath) {
    Write-Host "[ERROR] ScanCertificates.ps1 not found in any expected location!" -ForegroundColor Red
    exit 1
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null
    Write-Host "[SUCCESS] Scheduled task created for daily certificate scan at 06:00" -ForegroundColor Green
    
    # Test run
    Write-Host ""
    Write-Host "[INFO] Testing task..." -ForegroundColor Cyan
    $task = Get-ScheduledTask -TaskName $taskName
    Write-Host "[OK] Task Name: $($task.TaskName)" -ForegroundColor Green
    Write-Host "[OK] State: $($task.State)" -ForegroundColor Green
    Write-Host "[OK] Next Run: $((Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskInfo).NextRunTime)" -ForegroundColor Green
    
} catch {
    Write-Host "[ERROR] Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
'@

# Copy script to remote server
$remoteScriptPath = "\\$ServerName\c$\Temp\Setup-ScheduledTask-Local.ps1"

Write-Host "[INFO] Copying setup script to $ServerName..." -ForegroundColor Cyan

try {
    # Mount PSDrive if credential provided
    $usePSDrive = $false
    $driveName = "TempDrive$(Get-Random)"
    
    if ($Credential) {
        try {
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root "\\$ServerName\c$" -Credential $Credential -ErrorAction Stop | Out-Null
            $remoteScriptPath = "${driveName}:\Temp\Setup-ScheduledTask-Local.ps1"
            $usePSDrive = $true
            Write-Host "[OK] PSDrive mounted with credentials" -ForegroundColor Green
        } catch {
            Write-Host "[WARN] PSDrive mount failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] Trying direct copy..." -ForegroundColor Cyan
        }
    }
    
    # Ensure Temp directory exists
    $tempDir = Split-Path $remoteScriptPath
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }
    
    # Write script
    $remoteScriptContent | Out-File -FilePath $remoteScriptPath -Encoding ASCII -Force
    Write-Host "[OK] Script copied to: $remoteScriptPath" -ForegroundColor Green
    
    # Cleanup PSDrive
    if ($usePSDrive) {
        Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
    }
    
} catch {
    Write-Host "[ERROR] Failed to copy script: $($_.Exception.Message)" -ForegroundColor Red
    if ($usePSDrive) {
        Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Manual Execution Required" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Due to WinRM/TrustedHosts restrictions, please execute the" -ForegroundColor Yellow
Write-Host "following command LOCALLY on ${ServerName}:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  powershell.exe -ExecutionPolicy Bypass -File C:\Temp\Setup-ScheduledTask-Local.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or via RDP:" -ForegroundColor Yellow
Write-Host "  1. Connect to ${ServerName} via RDP" -ForegroundColor White
Write-Host "  2. Open PowerShell as Administrator" -ForegroundColor White
Write-Host "  3. Run: C:\Temp\Setup-ScheduledTask-Local.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or try PsExec (if available):" -ForegroundColor Yellow
Write-Host "  PsExec.exe \\${ServerName} -s powershell.exe -ExecutionPolicy Bypass -File C:\Temp\Setup-ScheduledTask-Local.ps1" -ForegroundColor White
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan

