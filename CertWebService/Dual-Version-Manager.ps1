# CertWebService Dual Version Manager
# Manages both PowerShell 7.x (UTF-8) and PowerShell 5.1 (ASCII) versions

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("PS7x-UTF8", "PS51-ASCII", "Status", "Switch")]
    [string]$Action,
    
    [int]$Port = 9080
)

Write-Host "=== CertWebService Dual Version Manager ===" -ForegroundColor Cyan
Write-Host "Action: $Action | Port: $Port" -ForegroundColor Gray

$PS7ServiceName = "CertWebService-PS7"
$PS51ServiceName = "CertWebService-PS51"
$ScriptPath = "C:\CertWebService\CertWebService.ps1"

function Stop-AllServices {
    Write-Host "Stopping all CertWebService instances..." -ForegroundColor Yellow
    
    # Stop scheduled tasks
    Get-ScheduledTask -TaskName "*CertWebService*" -ErrorAction SilentlyContinue | Stop-ScheduledTask -ErrorAction SilentlyContinue
    
    # Kill processes
    Get-Process powershell*, pwsh* -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "powershell|pwsh" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Start-Sleep 3
}

function Test-Service {
    param([string]$Version)
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 10 -UseBasicParsing
        $serverHeader = $response.Headers['Server']
        $psVersion = $response.Headers['X-PowerShell-Version']
        $charset = $response.Headers['X-Character-Set']
        
        Write-Host "SUCCESS: $Version service running!" -ForegroundColor Green
        Write-Host "  Server: $serverHeader" -ForegroundColor Gray
        Write-Host "  PS Version: $psVersion" -ForegroundColor Gray
        Write-Host "  Character Set: $charset" -ForegroundColor Gray
        Write-Host "  Status Code: $($response.StatusCode)" -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "ERROR: $Version service not responding - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

switch ($Action) {
    "PS7x-UTF8" {
        Write-Host "`nSwitching to PowerShell 7.x UTF-8 Enhanced Version..." -ForegroundColor Green
        
        Stop-AllServices
        
        # Copy PS 7.x version
        Copy-Item "F:\DEV\repositories\CertSurv\CertWebService-PS7x-Enhanced.ps1" $ScriptPath -Force
        
        # Remove old task
        Get-ScheduledTask -TaskName "$PS51ServiceName" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
        
        # Create PS 7.x task
        $action = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $ScriptPath -ServiceMode"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName "$PS7ServiceName" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName "$PS7ServiceName"
        
        Start-Sleep 10
        Test-Service "PS 7.x UTF-8"
    }
    
    "PS51-ASCII" {
        Write-Host "`nSwitching to PowerShell 5.1 ASCII Compatible Version..." -ForegroundColor Blue
        
        Stop-AllServices
        
        # Copy PS 5.1 version
        Copy-Item "F:\DEV\repositories\CertSurv\CertWebService-PS51-ASCII.ps1" $ScriptPath -Force
        
        # Remove old task
        Get-ScheduledTask -TaskName "$PS7ServiceName" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
        
        # Create PS 5.1 task
        $action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $ScriptPath -ServiceMode"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName "$PS51ServiceName" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName "$PS51ServiceName"
        
        Start-Sleep 10
        Test-Service "PS 5.1 ASCII"
    }
    
    "Status" {
        Write-Host "`nChecking service status..." -ForegroundColor Cyan
        
        # Check tasks
        $ps7Task = Get-ScheduledTask -TaskName "$PS7ServiceName" -ErrorAction SilentlyContinue
        $ps51Task = Get-ScheduledTask -TaskName "$PS51ServiceName" -ErrorAction SilentlyContinue
        
        if ($ps7Task) {
            Write-Host "PS 7.x Task: $($ps7Task.State)" -ForegroundColor Green
        }
        if ($ps51Task) {
            Write-Host "PS 5.1 Task: $($ps51Task.State)" -ForegroundColor Blue
        }
        
        # Check processes
        $ps7Process = Get-Process pwsh* -ErrorAction SilentlyContinue
        $ps51Process = Get-Process powershell* -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "powershell" }
        
        if ($ps7Process) {
            Write-Host "PS 7.x Process: Running (PID: $($ps7Process.Id))" -ForegroundColor Green
        }
        if ($ps51Process) {
            Write-Host "PS 5.1 Process: Running (PID: $($ps51Process.Id))" -ForegroundColor Blue
        }
        
        # Test service
        Write-Host "`nTesting current service..." -ForegroundColor Yellow
        Test-Service "Current"
    }
    
    "Switch" {
        Write-Host "`nDetermining current version and switching..." -ForegroundColor Yellow
        
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 5 -UseBasicParsing
            $psVersion = $response.Headers['X-PowerShell-Version']
            
            if ($psVersion -eq "7.x") {
                Write-Host "Currently running PS 7.x, switching to PS 5.1..." -ForegroundColor Blue
                & $PSCommandPath -Action "PS51-ASCII" -Port $Port
            } else {
                Write-Host "Currently running PS 5.1, switching to PS 7.x..." -ForegroundColor Green
                & $PSCommandPath -Action "PS7x-UTF8" -Port $Port
            }
        } catch {
            Write-Host "No service detected, starting PS 7.x..." -ForegroundColor Yellow
            & $PSCommandPath -Action "PS7x-UTF8" -Port $Port
        }
    }
}

Write-Host "`n=== Management Commands ===" -ForegroundColor Cyan
Write-Host "Switch to PS 7.x UTF-8: .\Dual-Version-Manager.ps1 -Action PS7x-UTF8" -ForegroundColor Gray
Write-Host "Switch to PS 5.1 ASCII: .\Dual-Version-Manager.ps1 -Action PS51-ASCII" -ForegroundColor Gray
Write-Host "Check Status: .\Dual-Version-Manager.ps1 -Action Status" -ForegroundColor Gray
Write-Host "Auto Switch: .\Dual-Version-Manager.ps1 -Action Switch" -ForegroundColor Gray