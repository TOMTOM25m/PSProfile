#requires -Version 5.1

<#
.SYNOPSIS
    Manages Certificate Web Service scheduled tasks
.DESCRIPTION
    Provides functions to start, stop, enable, disable and monitor the 
    Certificate Web Service update task. Follows     Regelwerk: v9.4.0 (PowerShell Version Adaptation + Character Encoding Standardization) standards.
.PARAMETER Action
    Action to perform: Start, Stop, Enable, Disable, Status, Remove
.PARAMETER TaskName
    Name of the scheduled task (default: "CertWebService-DailyUpdate")
.EXAMPLE
    .\Manage-CertWebServiceTask.ps1 -Action Status
    .\Manage-CertWebServiceTask.ps1 -Action Start
    .\Manage-CertWebServiceTask.ps1 -Action Remove
.AUTHOR
    System Administrator
.VERSION
    v1.2.0
.RULEBOOK
    v9.4.0
#>

#----------------------------------------------------------[Parameters]----------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop", "Enable", "Disable", "Status", "Remove", "History")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "CertWebService-DailyUpdate"
)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:ScriptVersion = "v1.0.0"
$Global:ModulePath = Join-Path $Global:ScriptDirectory "Modules"
$Global:ConfigPath = Join-Path $Global:ScriptDirectory "Config"

#----------------------------------------------------------[Modules]----------------------------------------------------------

Import-Module (Join-Path $Global:ModulePath "FL-Config.psm1") -Force
Import-Module (Join-Path $Global:ModulePath "FL-Logging.psm1") -Force

#----------------------------------------------------------[Functions]----------------------------------------------------------

function Show-ManagementBanner {
    $banner = @"

╔══════════════════════════════════════════════════════════════════════════════╗
║              Certificate Web Service Task Management                         ║
║                                                                              ║
║  Manage scheduled task for certificate data updates                         ║
║  Action: $($Action.PadRight(10))  Task: $($TaskName.PadRight(35))           ║
║  Version: $Global:ScriptVersion                                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Green
}

function Get-TaskStatus {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        
        Write-Host "[INFO] Task Status Report:" -ForegroundColor Cyan
        Write-Host "   Task Name: $($task.TaskName)" -ForegroundColor White
        Write-Host "   State: $($task.State)" -ForegroundColor $(if ($task.State -eq 'Ready') { 'Green' } else { 'Yellow' })
        Write-Host "   Description: $($task.Description)" -ForegroundColor Gray
        Write-Host "   Author: $($task.Author)" -ForegroundColor Gray
        Write-Host "   URI: $($task.URI)" -ForegroundColor Gray
        
        Write-Host "`n[INFO] Execution Information:" -ForegroundColor Cyan
        Write-Host "   Last Run: $($taskInfo.LastRunTime)" -ForegroundColor White
        Write-Host "   Next Run: $($taskInfo.NextRunTime)" -ForegroundColor White
        Write-Host "   Last Result: $($taskInfo.LastTaskResult) $(if ($taskInfo.LastTaskResult -eq 0) { '(Success)' } else { '(Error)' })" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { 'Green' } else { 'Red' })
        Write-Host "   Number of Missed Runs: $($taskInfo.NumberOfMissedRuns)" -ForegroundColor $(if ($taskInfo.NumberOfMissedRuns -eq 0) { 'Green' } else { 'Yellow' })
        
        Write-Host "`n[CONFIG] Task Configuration:" -ForegroundColor Cyan
        $triggers = $task.Triggers
        foreach ($trigger in $triggers) {
            Write-Host "   Trigger Type: $($trigger.CimClass.CimClassName)" -ForegroundColor White
            if ($trigger.StartBoundary) {
                $startTime = [DateTime]::Parse($trigger.StartBoundary).ToString("HH:mm")
                Write-Host "   Start Time: $startTime" -ForegroundColor White
            }
            if ($trigger.DaysInterval) {
                Write-Host "   Frequency: Every $($trigger.DaysInterval) day(s)" -ForegroundColor White
            }
        }
        
        $actions = $task.Actions
        foreach ($action in $actions) {
            Write-Host "   Executable: $($action.Execute)" -ForegroundColor White
            Write-Host "   Arguments: $($action.Arguments)" -ForegroundColor Gray
        }
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Task '$TaskName' not found or inaccessible" -ForegroundColor Red
        Write-LogMessage "Task status check failed: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Start-TaskExecution {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        Write-Host "Starting task '$TaskName'..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2
        
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Host "   [SUCCESS] Task started successfully" -ForegroundColor Green
        Write-Host "   Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor Gray
        
        Write-LogMessage "Task '$TaskName' started manually" -Level "Info"
        return $true
    }
    catch {
        Write-Host "   [ERROR] Failed to start task: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Failed to start task '$TaskName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Stop-TaskExecution {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        Write-Host "⏹️  Stopping task '$TaskName'..." -ForegroundColor Yellow
        Stop-ScheduledTask -TaskName $TaskName
        Write-Host "   [SUCCESS] Task stopped successfully" -ForegroundColor Green
        
        Write-LogMessage "Task '$TaskName' stopped manually" -Level "Info"
        return $true
    }
    catch {
        Write-Host "   [ERROR] Failed to stop task: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Failed to stop task '$TaskName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Enable-TaskExecution {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        Write-Host "Enabling task '$TaskName'..." -ForegroundColor Yellow
        Enable-ScheduledTask -TaskName $TaskName
        Write-Host "   [SUCCESS] Task enabled successfully" -ForegroundColor Green
        
        Write-LogMessage "Task '$TaskName' enabled" -Level "Info"
        return $true
    }
    catch {
        Write-Host "   [ERROR] Failed to enable task: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Failed to enable task '$TaskName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Disable-TaskExecution {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        Write-Host "⏸️  Disabling task '$TaskName'..." -ForegroundColor Yellow
        Disable-ScheduledTask -TaskName $TaskName
        Write-Host "   [SUCCESS] Task disabled successfully" -ForegroundColor Green
        
        Write-LogMessage "Task '$TaskName' disabled" -Level "Info"
        return $true
    }
    catch {
        Write-Host "   [ERROR] Failed to disable task: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Failed to disable task '$TaskName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Remove-TaskExecution {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        Write-Host "🗑️  Removing task '$TaskName'..." -ForegroundColor Yellow
        Write-Host "   [WARN] This action cannot be undone!" -ForegroundColor Red
        
        $confirmation = Read-Host "   Are you sure you want to remove the task? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "   [WARN] Task removal cancelled" -ForegroundColor Yellow
            return $false
        }
        
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "   [SUCCESS] Task removed successfully" -ForegroundColor Green
        
        Write-LogMessage "Task '$TaskName' removed" -Level "Warning"
        return $true
    }
    catch {
        Write-Host "   [ERROR] Failed to remove task: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Failed to remove task '$TaskName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Show-TaskHistory {
    [CmdletBinding()]
    param([string]$TaskName)
    
    try {
        Write-Host "[INFO] Task History for '$TaskName':" -ForegroundColor Cyan
        
        # Get task scheduler events
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-TaskScheduler/Operational'
            ID = 100, 101, 102, 200, 201
        } -MaxEvents 50 -ErrorAction SilentlyContinue | Where-Object { $_.Message -like "*$TaskName*" }
        
        if ($events) {
            $events | ForEach-Object {
                $eventType = switch ($_.Id) {
                    100 { "Task Started" }
                    101 { "Task Failed to Start" }
                    102 { "Task Completed" }
                    200 { "Action Started" }
                    201 { "Action Completed" }
                    default { "Other Event" }
                }
                
                $color = switch ($_.Id) {
                    100, 200 { "Yellow" }
                    102, 201 { "Green" }
                    101 { "Red" }
                    default { "Gray" }
                }
                
                Write-Host "   $($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) - $eventType" -ForegroundColor $color
            }
        } else {
            Write-Host "   No recent history found for task '$TaskName'" -ForegroundColor Gray
        }
        
        return $true
    }
    catch {
        Write-Host "   [ERROR] Failed to retrieve task history: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogMessage "Failed to retrieve task history for '$TaskName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    # Initialize configuration and logging
    Initialize-ConfigData -ConfigPath (Join-Path $Global:ConfigPath "Config-CertWebService.json")
    Initialize-Logging -ScriptName "Manage-CertWebServiceTask" -LogLevel "Info"
    
    Show-ManagementBanner
    
    # Import TaskScheduler module
    Import-Module ScheduledTasks -ErrorAction Stop
    
    # Execute requested action
    $result = switch ($Action) {
        "Status" { Get-TaskStatus -TaskName $TaskName }
        "Start" { Start-TaskExecution -TaskName $TaskName }
        "Stop" { Stop-TaskExecution -TaskName $TaskName }
        "Enable" { Enable-TaskExecution -TaskName $TaskName }
        "Disable" { Disable-TaskExecution -TaskName $TaskName }
        "Remove" { Remove-TaskExecution -TaskName $TaskName }
        "History" { Show-TaskHistory -TaskName $TaskName }
    }
    
    if ($result) {
        Write-Host "`n[SUCCESS] Task management action '$Action' completed successfully!" -ForegroundColor Green
        Write-LogMessage "Task management action '$Action' completed for '$TaskName'" -Level "Info"
    } else {
        Write-Host "`n[WARN] Task management action '$Action' completed with warnings" -ForegroundColor Yellow
        Write-LogMessage "Task management action '$Action' completed with warnings for '$TaskName'" -Level "Warning"
    }
}
catch {
    Write-Host "`n[ERROR] Task management failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogMessage "Task management failed: $($_.Exception.Message)" -Level "Error"
    exit 1
}

# --- End of Script --- old: v1.0.0 ; now: v1.0.0 ; Regelwerk: v9.3.0 ---