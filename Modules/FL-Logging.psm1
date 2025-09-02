<#
.SYNOPSIS
    [DE] Modul für Logging-Funktionen.
    [EN] Module for logging functions.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.09.02
    Version:        v11.2.0
    MUW-Regelwerk:  v8.2.0
    Notes:          [DE] Versionsnummer für Release-Konsistenz aktualisiert.
                    [EN] Updated version number for release consistency.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Write-Log {
    param (
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")][string]$Level = "INFO",
        [switch]$NoHostWrite
    )
    $isDev = $Global:Config -and $Global:Config.Environment -eq "DEV"
    if ($Level -eq "DEBUG" -and -not $isDev) { return }

    $timestamp = Get-Date -Format "yyyy.MM.dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    if (-not $NoHostWrite) {
        $colorMap = @{ INFO = "White"; WARNING = "Yellow"; ERROR = "Red"; DEBUG = "Cyan" }
        Write-Host $logEntry -ForegroundColor $colorMap[$Level]
    }

    try {
        if ($Global:Config -and $Global:Config.Logging.LogPath) {
            $logPath = $Global:Config.Logging.LogPath
            if (-not (Test-Path $logPath)) { 
                # Logging ist kritisch und wird immer ausgeführt, unabhängig vom WhatIf-Modus
                New-Item -Path $logPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null 
            }
            
            $logFileBaseName = $Global:ScriptName -replace '\.ps1', ''
            $logFileName = if ($isDev) { "DEV_$($logFileBaseName)_$(Get-Date -Format 'yyyy-MM-dd').log" } else { "PROD_$($logFileBaseName)_$(Get-Date -Format 'yyyy-MM-dd').log" }
            $logFile = Join-Path $logPath $logFileName
            
            # Logging erfolgt immer, unabhängig vom WhatIf-Modus
            Add-Content -Path $logFile -Value $logEntry -Force
        }
    }
    catch { Write-Warning "Could not write to log file. Reason: $($_.Exception.Message)" }

    if ($Level -in @('ERROR', 'WARNING')) {
        Write-EventLogEntry -Level $Level -Message $Message
    }
}

function Write-EventLogEntry {
    [CmdletBinding()]
    param([string]$Level, [string]$Message)
    
    if (-not ($Global:Config -and $Global:Config.Logging.EnableEventLog)) {
        Write-Log -Level DEBUG -Message "Event logging is disabled in the configuration."
        return
    }

    try {
        if (-not (Get-EventLog -LogName Application -Source $Global:ScriptName -ErrorAction SilentlyContinue)) {
            # Event Log Source-Erstellung ist kritisch und sollte immer ausgeführt werden
            New-EventLog -LogName Application -Source $Global:ScriptName -ErrorAction Stop
            Write-Log -Level INFO -Message "Event Log Source '$($Global:ScriptName)' was registered successfully."
        }
        $typeMap = @{ ERROR = 'Error'; WARNING = 'Warning' }
        Write-EventLog -LogName Application -Source $Global:ScriptName -Message $Message -EventId 1000 -EntryType $typeMap[$Level] -ErrorAction Stop
    }
    catch { Write-Warning "Error writing to Windows Event Log: $($_.Exception.Message)" }
}

Export-ModuleMember -Function Write-Log, Write-EventLogEntry

# --- End of module --- v11.2.0 ; Regelwerk: v8.2.0 ---
