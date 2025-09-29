#requires -Version 5.1

<#
.SYNOPSIS
    FL-Logging Module - Structured logging for Certificate Web Service
.DESCRIPTION
    Provides functions for structured and level-based logging.
    Supports console and file output with configurable log levels.
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

$ModuleName = "FL-Logging"
$ModuleVersion = "v1.0.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

Function Write-Log {
    <#
    .SYNOPSIS
        Writes structured log entries with timestamp and level information
    .DESCRIPTION
        Creates formatted log entries that can be written to console and/or file.
        Supports different log levels (INFO, WARN, ERROR, DEBUG) for filtering.
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        The log level (INFO, WARN, ERROR, DEBUG). Default is INFO.
    .PARAMETER LogFile
        Optional path to log file. If specified, log entry will be appended to file.
    .EXAMPLE
        Write-Log "Certificate created successfully" -Level INFO -LogFile "C:\Logs\webservice.log"
    .EXAMPLE
        Write-Log "Failed to bind certificate" -Level ERROR -LogFile $LogFile
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to console (except DEBUG unless explicitly enabled)
    if ($Level -ne 'DEBUG' -or $env:CERT_WEBSERVICE_DEBUG -eq '1') {
        switch ($Level) {
            'ERROR' { Write-Host $logEntry -ForegroundColor Red }
            'WARN'  { Write-Host $logEntry -ForegroundColor Yellow }
            'DEBUG' { Write-Host $logEntry -ForegroundColor Gray }
            default { Write-Host $logEntry -ForegroundColor White }
        }
    }
    
    # Write to file if specified
    if ($LogFile) {
        try {
            # Ensure log directory exists
            $logDir = Split-Path $LogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Append to log file
            Out-File -FilePath $LogFile -InputObject $logEntry -Append -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file '$LogFile': $($_.Exception.Message)"
        }
    }

    # Write to Windows Event Log for WARNING and ERROR levels
    if ($Level -in @('WARN', 'ERROR')) {
        try {
            $eventLogSource = "CertificateWebService"
            $eventLogName = "Application"
            
            # Create event source if it doesn't exist
            if (-not [System.Diagnostics.EventLog]::SourceExists($eventLogSource)) {
                [System.Diagnostics.EventLog]::CreateEventSource($eventLogSource, $eventLogName)
            }
            
            $eventType = if ($Level -eq 'ERROR') { 'Error' } else { 'Warning' }
            Write-EventLog -LogName $eventLogName -Source $eventLogSource -EntryType $eventType -EventId 1001 -Message $Message
        }
        catch {
            # Silently ignore event log errors to prevent logging loops
        }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function Write-Log

Write-Verbose "FL-Logging module v$ModuleVersion loaded successfully"

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---