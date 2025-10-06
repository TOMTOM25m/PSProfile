#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Debug-ExcelHeaderContext.ps1 - Debuggt Excel Header Context Extraktion
.DESCRIPTION
    Testet die Extract-HeaderContext Funktion mit Debug-Output
.NOTES
    Version: 1.0.0
    Author: GitHub Copilot
    Date: 2025-10-06
#>

param(
    [string]$CertSurvPath = "C:\CertSurv"
)

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  DEBUG: EXCEL HEADER CONTEXT" -ForegroundColor Green  
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Import required modules
$modulePath = Join-Path $CertSurvPath "Modules\FL-DataProcessing.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Host "[ERROR] FL-DataProcessing.psm1 nicht gefunden: $modulePath" -ForegroundColor Red
    exit 1
}

try {
    Import-Module $modulePath -Force
    Write-Host "[OK] FL-DataProcessing.psm1 geladen" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Modul-Import fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load config
$configPath = Join-Path $CertSurvPath "Config\Config-Cert-Surveillance.json"
if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] Config nicht gefunden: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
Write-Host "[OK] Config geladen: $($config.ExcelFilePath)" -ForegroundColor Green

# Create temp log file
$logFile = Join-Path $env:TEMP "Debug-ExcelHeaders-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Write-Host "[INFO] Debug-Log: $logFile" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== TESTE EXCEL HEADER CONTEXT EXTRAKTION ===" -ForegroundColor Yellow

try {
    # Test Extract-HeaderContext directly
    $headerContext = Extract-HeaderContext -ExcelPath $config.ExcelFilePath -WorksheetName $config.ExcelWorksheet -HeaderRow 1 -Config $config -LogFile $logFile
    
    Write-Host ""
    Write-Host "HEADER CONTEXT RESULTATE:" -ForegroundColor Cyan
    Write-Host "  Anzahl Server im Context: $($headerContext.Count)" -ForegroundColor White
    
    if ($headerContext.Count -gt 0) {
        Write-Host ""
        Write-Host "BEISPIEL SERVER (erste 10):" -ForegroundColor Yellow
        
        $count = 0
        foreach ($serverName in $headerContext.Keys) {
            if ($count -ge 10) { break }
            
            $context = $headerContext[$serverName]
            $type = if ($context.IsDomain) { "Domain($($context.Domain))" } else { "Workgroup($($context.Subdomain))" }
            
            Write-Host "  $serverName -> $type" -ForegroundColor White
            $count++
        }
        
        # Domain/Workgroup Statistics
        $domainServers = ($headerContext.Values | Where-Object { $_.IsDomain }).Count
        $workgroupServers = $headerContext.Count - $domainServers
        
        Write-Host ""
        Write-Host "STATISTIKEN:" -ForegroundColor Yellow
        Write-Host "  Domain-Server: $domainServers" -ForegroundColor Green
        Write-Host "  Workgroup-Server: $workgroupServers" -ForegroundColor Yellow
        
        # Check specific problem servers
        Write-Host ""
        Write-Host "PROBLEM-SERVER CHECK:" -ForegroundColor Yellow
        $problemServers = @("proman", "uvwlex01", "na0fs1bkp", "M42MASTER", "M42DEPOT", "SIGNAGE01")
        
        foreach ($server in $problemServers) {
            if ($headerContext.ContainsKey($server)) {
                $context = $headerContext[$server]
                $type = if ($context.IsDomain) { "Domain($($context.Domain))" } else { "Workgroup($($context.Subdomain))" }
                Write-Host "  $server -> $type" -ForegroundColor Green
            } else {
                Write-Host "  $server -> NICHT GEFUNDEN!" -ForegroundColor Red
            }
        }
        
    } else {
        Write-Host "[ERROR] Kein Header Context extrahiert!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "[ERROR] Header Context Extraktion fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DEBUG LOG INHALT ===" -ForegroundColor Yellow
if (Test-Path $logFile) {
    Get-Content $logFile | Select-Object -Last 20 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] Debug-Log nicht erstellt" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Debug abgeschlossen. Log: $logFile" -ForegroundColor Green
Write-Host ""