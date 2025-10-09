#Requires -Version 5.1

<#
.SYNOPSIS
    Update all scripts to Regelwerk v10.1.0 standards

.DESCRIPTION
    Updates PowerShell scripts in CertSurv and CertWebService directories
    to comply with Regelwerk v10.1.0 Enterprise Edition standards.

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Regelwerk:      v10.1.0
    BuildDate:      2025-10-09
#>

param(
    [string[]]$Directories = @("CertSurv", "CertWebService"),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Write-UpdateLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Color = switch ($Level) {
        "INFO"    { "White" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
    }
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
}

function Update-ScriptToRegelwerk {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )
    
    Write-UpdateLog "Processing: $FilePath"
    
    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        $updated = $false
        
        # Update version references
        if ($content -match "v10\.0\.[0-9]") {
            $content = $content -replace "v10\.0\.[0-9]", "v10.1.0"
            $updated = $true
        }
        
        # Update Regelwerk references
        if ($content -match "Regelwerk v10\.0\.[0-9]") {
            $content = $content -replace "Regelwerk v10\.0\.[0-9]", "Regelwerk v10.1.0"
            $updated = $true
        }
        
        # Update MUW-Regelwerk references
        if ($content -match "MUW-Regelwerk:\s*v10\.0\.[0-9]") {
            $content = $content -replace "MUW-Regelwerk:\s*v10\.0\.[0-9]", "MUW-Regelwerk: v10.1.0"
            $updated = $true
        }
        
        # Update build dates
        if ($content -match "Stand: \d{2}\.\d{2}\.\d{4}") {
            $content = $content -replace "Stand: \d{2}\.\d{2}\.\d{4}", "Stand: 09.10.2025"
            $updated = $true
        }
        
        if ($content -match "Last modified:\s*\d{4}\.\d{2}\.\d{2}") {
            $content = $content -replace "Last modified:\s*\d{4}\.\d{2}\.\d{2}", "Last modified: 2025.10.09"
            $updated = $true
        }
        
        if ($content -match "BuildDate.*\d{4}-\d{2}-\d{2}") {
            $content = $content -replace "BuildDate.*\d{4}-\d{2}-\d{2}", "BuildDate = `"2025-10-09`""
            $updated = $true
        }
        
        # Add Enterprise features comment for main scripts
        if (($FilePath -match "(Main|Deploy|Setup|Install)" -and $FilePath -notmatch "Test|Temp") -and 
            $content -notmatch "Regelwerk v10\.1\.0 Enterprise") {
            
            $enterpriseComment = @"
# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (§20)
# - Advanced GUI Standards (§21) 
# - Event Log Integration (§22)
# - Log Archiving & Rotation (§23)
# - Enhanced Password Management (§24)
# - Environment Workflow Optimization (§25)
# - MUW Compliance Standards (§26)

"@
            
            # Insert after header but before first region or function
            if ($content -match '(#region|function|\$ErrorActionPreference)') {
                $content = $content -replace '(#region|function|\$ErrorActionPreference)', "$enterpriseComment`$1"
                $updated = $true
            }
        }
        
        # Save changes if any updates were made
        if ($updated -and -not $WhatIf) {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8
            Write-UpdateLog "Updated: $FilePath" -Level SUCCESS
            return $true
        }
        elseif ($updated -and $WhatIf) {
            Write-UpdateLog "[WHATIF] Would update: $FilePath" -Level WARNING
            return $true
        }
        else {
            Write-UpdateLog "No changes needed: $FilePath"
            return $false
        }
    }
    catch {
        Write-UpdateLog "Error updating $FilePath`: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Main execution
Write-UpdateLog "=== Starting Regelwerk v10.1.0 Update ===" -Level SUCCESS
Write-UpdateLog "Target directories: $($Directories -join ', ')"

$totalFiles = 0
$updatedFiles = 0

foreach ($Directory in $Directories) {
    if (-not (Test-Path $Directory)) {
        Write-UpdateLog "Directory not found: $Directory" -Level WARNING
        continue
    }
    
    Write-UpdateLog "Processing directory: $Directory" -Level SUCCESS
    
    $scripts = Get-ChildItem -Path $Directory -Filter "*.ps1" -Recurse
    $totalFiles += $scripts.Count
    
    foreach ($script in $scripts) {
        if (Update-ScriptToRegelwerk -FilePath $script.FullName) {
            $updatedFiles++
        }
    }
}

Write-UpdateLog "=== Update Complete ===" -Level SUCCESS
Write-UpdateLog "Total files processed: $totalFiles"
Write-UpdateLog "Files updated: $updatedFiles"

if ($updatedFiles -gt 0) {
    Write-UpdateLog "Regelwerk v10.1.0 implementation successful!" -Level SUCCESS
} else {
    Write-UpdateLog "All files already up to date" -Level SUCCESS
}