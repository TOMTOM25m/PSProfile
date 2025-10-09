#requires -version 5.1
#requires -runasadministrator

<#
.SYNOPSIS
    Sets up a scheduled task for Certificate Web Service daily updates.

.DESCRIPTION
    This script creates a Windows scheduled task that runs the Update-CertificateWebService 
    script daily at 17:00 to keep certificate data current.

.PARAMETER TaskName
    Name of the scheduled task (default: "CertWebService-DailyUpdate")

.PARAMETER UpdateTime
    Time to run the daily update (default: "17:00")

.EXAMPLE
    .\Install-CertWebServiceTask.ps1
    Creates task with default settings

.EXAMPLE
    .\Install-CertWebServiceTask.ps1 -TaskName "MyCertTask" -UpdateTime "18:30"
    Creates custom task

.AUTHOR
    System Administrator

.VERSION
    1.0.0

.RULEBOOK
    v9.3.0
#>

[CmdletBinding()]
param(
    [string]$TaskName = "CertWebService-DailyUpdate",
    [string]$UpdateTime = "17:00"
)

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

# Script Metadata
$Global:ScriptVersion = "1.0.0"
$Global:RulebookVersion = "v9.3.0"
$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Global:sLogFile = Join-Path $Global:ScriptDirectory "LOG\Install-CertWebServiceTask_$(Get-Date -Format 'yyyy-MM-dd').log"

# Ensure LOG directory exists
if (-not (Test-Path (Split-Path $Global:sLogFile -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $Global:sLogFile -Parent) -Force | Out-Null
}

#----------------------------------------------------------[Imports]-------------------------------------------------------------

# Import required modules
$modulePaths = @(
    ".\Modules\FL-Config.psm1",
    ".\Modules\FL-Logging.psm1"
)

foreach ($modulePath in $modulePaths) {
    $fullPath = Join-Path $Global:ScriptDirectory $modulePath
    if (Test-Path $fullPath) {
        Import-Module $fullPath -Force
        Write-Host "Module loaded: $modulePath" -ForegroundColor Green
    } else {
        Write-Error "Required module not found: $fullPath"
        exit 1
    }
}

#---------------------------------------------------------[# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
Functions]------------------------------------------------------------

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Show-Banner {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host " Certificate Web Service Task Installer v$Global:ScriptVersion" -ForegroundColor White
    Write-Host " Rulebook Version: $Global:RulebookVersion" -ForegroundColor Gray
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    Write-Log $Message -Level $Level -LogFile $Global:sLogFile
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Show-Banner
    
    Write-LogMessage "=== Certificate Web Service Task Installer $Global:ScriptVersion Started ==="
    Write-LogMessage "Rulebook Version: $Global:RulebookVersion"
    Write-LogMessage "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-LogMessage "Operating System: $([System.Environment]::OSVersion.VersionString)"
    Write-LogMessage "Current User: $([System.Environment]::UserName)"
    
    # Load configuration
    Write-Host "Loading configuration..." -ForegroundColor Yellow
    $configResult = Get-ScriptConfiguration -ScriptDirectory $Global:ScriptDirectory
    $Config = $configResult.Config
    
    if (-not $Config) {
        throw "Failed to load configuration"
    }
    
    Write-Host "   Configuration loaded successfully" -ForegroundColor Green
    
    # Task parameters
    $updateScript = Join-Path $Global:ScriptDirectory "Update-CertificateWebService.ps1"
    if (-not (Test-Path $updateScript)) {
        throw "Update script not found: $updateScript"
    }
    
    Write-Host "Task configuration:" -ForegroundColor Cyan
    Write-Host "   Task Name: $TaskName" -ForegroundColor Gray
    Write-Host "   Update Time: $UpdateTime daily" -ForegroundColor Gray
    Write-Host "   Update Script: $updateScript" -ForegroundColor Gray
    Write-Host "   Log File: $Global:sLogFile" -ForegroundColor Gray
    
    # Check if task already exists
    try {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Write-Host "Task '$TaskName' already exists. Removing..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-LogMessage "Existing task '$TaskName' removed"
    }
    catch {
        Write-Host "   No existing task found (this is normal)" -ForegroundColor Gray
    }
    
    # Create task action
    Write-Host "Creating scheduled task..." -ForegroundColor Yellow
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$updateScript`""
    
    # Create task trigger (daily at specified time)
    $trigger = New-ScheduledTaskTrigger -Daily -At $UpdateTime
    
    # Create task settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd
    
    # Create task principal (run as SYSTEM)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Register the task
    $task = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Daily update of Certificate Web Service data at $UpdateTime"
    
    if ($task) {
        Write-Host "   Scheduled task created successfully" -ForegroundColor Green
        Write-LogMessage "Scheduled task '$TaskName' created successfully"
        
        # Test task creation
        Write-Host "Testing task..." -ForegroundColor Yellow
        $taskInfo = Get-ScheduledTask -TaskName $TaskName
        if ($taskInfo.State -eq "Ready") {
            Write-Host "   Task is ready and properly configured" -ForegroundColor Green
            Write-LogMessage "Task '$TaskName' is ready and properly configured"
        } else {
            Write-Host "   Warning: Task state is $($taskInfo.State)" -ForegroundColor Yellow
            Write-LogMessage "Warning: Task state is $($taskInfo.State)" -Level "WARNING"
        }
        
        Write-Host "Task setup completed successfully!" -ForegroundColor Green
        Write-Host "   Task Name: $TaskName" -ForegroundColor Cyan
        Write-Host "   Daily execution: $UpdateTime" -ForegroundColor Cyan
        Write-Host "   Next run: $((Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo).NextRunTime)" -ForegroundColor Cyan
        Write-Host "   Log file: $Global:sLogFile" -ForegroundColor Gray
        
        Write-Host "Management commands:" -ForegroundColor Yellow
        Write-Host "   Start task manually: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
        Write-Host "   Check task status: Get-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
        Write-Host "   View task history: Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=201}" -ForegroundColor Gray
        
        Write-LogMessage "Certificate Web Service task installation completed successfully"
    } else {
        throw "Failed to create scheduled task"
    }
}
catch {
    Write-Host "Task scheduler setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogMessage "Task scheduler setup failed: $($_.Exception.Message)" -Level "Error"
    exit 1
}

# --- End of Script --- old: v1.0.0 ; now: v1.0.0 ; Regelwerk: v9.3.0 ---
