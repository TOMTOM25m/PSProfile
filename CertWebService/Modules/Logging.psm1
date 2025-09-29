# Logging Module for Certificate Web Service (Regelwerk v9.6.2)
# Provides centralized logging functionality with multiple levels and outputs
# Compatible with PowerShell 5.1 and 7.x

$Global:LogFile = $null

function Initialize-Logging {
    param(
        [string]$LogDirectory = "LOG",
        [string]$LogPrefix = "CertWebService"
    )
    
    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $Global:LogFile = Join-Path $LogDirectory "${LogPrefix}_${timestamp}.log"
    
    Write-Log "Logging initialized: $Global:LogFile" -Level INFO
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole,
        
        [Parameter(Mandatory = $false)]
        [switch]$NoFile
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with PowerShell version compatibility (Regelwerk v9.6.2)
    if (-not $NoConsole) {
        $color = switch ($Level) {
            'DEBUG'   { 'Gray' }
            'INFO'    { 'White' }
            'WARNING' { 'Yellow' }
            'ERROR'   { 'Red' }
            default   { 'White' }
        }
        
        # PowerShell 5.1/7.x compatible output
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $prefix = switch ($Level) {
                'DEBUG'   { '🔍' }
                'INFO'    { 'ℹ️ ' }
                'WARNING' { '⚠️ ' }
                'ERROR'   { '❌' }
                default   { '📝' }
            }
            Write-Host "$prefix $logEntry" -ForegroundColor $color
        } else {
            $prefix = switch ($Level) {
                'DEBUG'   { '[DBG]' }
                'INFO'    { '[INF]' }
                'WARNING' { '[WRN]' }
                'ERROR'   { '[ERR]' }
                default   { '[LOG]' }
            }
            Write-Host "$prefix $logEntry" -ForegroundColor $color
        }
    }
    
    # File output
    if (-not $NoFile -and $Global:LogFile) {
        try {
            Add-Content -Path $Global:LogFile -Value $logEntry -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
    
    # Windows Event Log (for errors and warnings)
    if ($Level -in @('ERROR', 'WARNING')) {
        try {
            $eventType = if ($Level -eq 'ERROR') { 'Error' } else { 'Warning' }
            Write-EventLog -LogName Application -Source "CertificateWebService" -EventId 1001 -EntryType $eventType -Message $Message -ErrorAction SilentlyContinue
        } catch {
            # Ignore event log errors - they're not critical
        }
    }
}

function Write-DebugLog {
    param([string]$Message)
    Write-Log -Message $Message -Level 'DEBUG'
}

function Write-InfoLog {
    param([string]$Message)
    Write-Log -Message $Message -Level 'INFO'
}

function Write-WarningLog {
    param([string]$Message)
    Write-Log -Message $Message -Level 'WARNING'
}

function Write-ErrorLog {
    param([string]$Message)
    Write-Log -Message $Message -Level 'ERROR'
}

function Get-LogHistory {
    param(
        [string]$LogDirectory = "LOG",
        [int]$LastDays = 7,
        [string]$Level = "*"
    )
    
    if (-not (Test-Path $LogDirectory)) {
        return @()
    }
    
    $cutoffDate = (Get-Date).AddDays(-$LastDays)
    $logFiles = Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { 
        $_.CreationTime -ge $cutoffDate 
    }
    
    $logEntries = @()
    
    foreach ($file in $logFiles) {
        try {
            $content = Get-Content $file.FullName
            foreach ($line in $content) {
                if ($line -match '^\[(.+?)\] \[(.+?)\] (.+)$') {
                    $entry = [PSCustomObject]@{
                        Timestamp = [datetime]::ParseExact($matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
                        Level = $matches[2]
                        Message = $matches[3]
                        Source = $file.BaseName
                    }
                    
                    if ($Level -eq "*" -or $entry.Level -eq $Level) {
                        $logEntries += $entry
                    }
                }
            }
        } catch {
            Write-Warning "Failed to parse log file $($file.Name): $_"
        }
    }
    
    return $logEntries | Sort-Object Timestamp -Descending
}

function Clear-OldLogs {
    param(
        [string]$LogDirectory = "LOG",
        [int]$RetentionDays = 30
    )
    
    if (-not (Test-Path $LogDirectory)) {
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $oldFiles = Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { 
        $_.CreationTime -lt $cutoffDate 
    }
    
    $removedCount = 0
    foreach ($file in $oldFiles) {
        try {
            Remove-Item $file.FullName -Force
            $removedCount++
            Write-DebugLog "Removed old log file: $($file.Name)"
        } catch {
            Write-WarningLog "Failed to remove old log file $($file.Name): $_"
        }
    }
    
    if ($removedCount -gt 0) {
        Write-InfoLog "Cleaned up $removedCount old log files (older than $RetentionDays days)"
    }
}

function Export-LogReport {
    param(
        [string]$LogDirectory = "LOG",
        [string]$OutputPath,
        [int]$LastDays = 7,
        [string]$Format = "HTML"
    )
    
    $logEntries = Get-LogHistory -LogDirectory $LogDirectory -LastDays $LastDays
    
    if ($logEntries.Count -eq 0) {
        Write-WarningLog "No log entries found for the last $LastDays days"
        return
    }
    
    switch ($Format.ToUpper()) {
        "HTML" {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Certificate Web Service - Log Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-box { background-color: #e9ecef; padding: 15px; border-radius: 5px; text-align: center; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .DEBUG { color: #6c757d; }
        .INFO { color: #007bff; }
        .WARNING { color: #ffc107; background-color: #fff3cd; }
        .ERROR { color: #dc3545; background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Certificate Web Service - Log Report</h1>
        <p>Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Period: Last $LastDays days</p>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <h3>Total Entries</h3>
            <p>$($logEntries.Count)</p>
        </div>
        <div class="stat-box">
            <h3>Errors</h3>
            <p>$(($logEntries | Where-Object { $_.Level -eq 'ERROR' }).Count)</p>
        </div>
        <div class="stat-box">
            <h3>Warnings</h3>
            <p>$(($logEntries | Where-Object { $_.Level -eq 'WARNING' }).Count)</p>
        </div>
        <div class="stat-box">
            <h3>Info</h3>
            <p>$(($logEntries | Where-Object { $_.Level -eq 'INFO' }).Count)</p>
        </div>
    </div>
    
    <table>
        <thead>
            <tr>
                <th>Timestamp</th>
                <th>Level</th>
                <th>Message</th>
                <th>Source</th>
            </tr>
        </thead>
        <tbody>
"@
            foreach ($entry in $logEntries) {
                $html += "<tr class=`"$($entry.Level)`">"
                $html += "<td>$($entry.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))</td>"
                $html += "<td>$($entry.Level)</td>"
                $html += "<td>$([System.Web.HttpUtility]::HtmlEncode($entry.Message))</td>"
                $html += "<td>$($entry.Source)</td>"
                $html += "</tr>"
            }
            
            $html += @"
        </tbody>
    </table>
</body>
</html>
"@
            
            $html | Out-File $OutputPath -Encoding UTF8
        }
        "CSV" {
            $logEntries | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        }
        "JSON" {
            $logEntries | ConvertTo-Json -Depth 3 | Out-File $OutputPath -Encoding UTF8
        }
        default {
            throw "Unsupported export format: $Format"
        }
    }
    
    Write-InfoLog "Log report exported to: $OutputPath ($Format)"
}

# Initialize event log source if it doesn't exist
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists("CertificateWebService")) {
        New-EventLog -LogName Application -Source "CertificateWebService" -ErrorAction SilentlyContinue
    }
} catch {
    # Ignore - event log creation requires admin rights
}

Export-ModuleMember -Function Initialize-Logging, Write-Log, Write-DebugLog, Write-InfoLog, Write-WarningLog, Write-ErrorLog, Get-LogHistory, Clear-OldLogs, Export-LogReport