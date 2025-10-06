<#!
.SYNOPSIS
    Bulk update all .ps1 / .psm1 files to PowerShell-Regelwerk Universal v10.0.2
.DESCRIPTION
    Scans repository (default: CertSurv folder root) and updates occurrences of legacy
    'Regelwerk v9.x.x' markers in script headers, region tags and comments to 'Regelwerk v10.0.2'.
    Adds standardized PowerShell version detection region if missing (optional).
.PARAMETER RootPath
    Root path to scan. Defaults to script location.
.PARAMETER DryRun
    If set, only reports planned changes.
.PARAMETER AddVersionRegionIfMissing
    If set, inserts a standardized version detection block at top (after #requires) when absent.
.EXAMPLE
    .\Bulk-Update-Regelwerk.ps1 -RootPath .
.EXAMPLE
    .\Bulk-Update-Regelwerk.ps1 -DryRun
.NOTES
    Regelwerk v10.0.2 Compliance Automation Helper.
#>
[CmdletBinding()]
param(
    [string]$RootPath = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [switch]$DryRun,
    [switch]$AddVersionRegionIfMissing
)

$TargetVersion = 'v10.0.2'
$PatternLegacy = 'Regelwerk v9\.[0-9]+\.[0-9]+'
$Files = Get-ChildItem -Path $RootPath -Recurse -Include *.ps1,*.psm1 -File | Where-Object { $_.FullName -notmatch '\\old\\' }

$stdVersionRegion = @(
    '#region PowerShell Version Detection (MANDATORY - Regelwerk v10.0.2)',
    '$PSVersion = $PSVersionTable.PSVersion',
    '$IsPS7Plus = $PSVersion.Major -ge 7',
    '$IsPS5 = $PSVersion.Major -eq 5',
    '$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1',
    'Write-Verbose "PowerShell Version: $($PSVersion.ToString())"',
    'Write-Verbose "Compatibility Mode: $(if($IsPS7Plus){''PS 7.x Enhanced''}elseif($IsPS51){''PS 5.1 Compatible''}else{''PS 5.x Standard''})"',
    '#endregion'
) -join [Environment]::NewLine

$results = @()
foreach ($file in $Files) {
    $content = Get-Content -Raw -Path $file.FullName
    $original = $content

    # Replace legacy Regelwerk version references
    $content = [regex]::Replace($content, $PatternLegacy, "Regelwerk $TargetVersion")

    # Standardize region tag if present with old version
    $content = [regex]::Replace($content, '#region PowerShell Version Detection \(MANDATORY - Regelwerk v10\.0\.2\)', '#region PowerShell Version Detection (MANDATORY - Regelwerk v10.0.2)')
    $content = [regex]::Replace($content, '#region PowerShell Version Detection \(MANDATORY - Regelwerk v9\.[0-9]+\.[0-9]+\)', '#region PowerShell Version Detection (MANDATORY - Regelwerk v10.0.2)')

    $addedRegion = $false
    if ($AddVersionRegionIfMissing -and $content -notmatch '#region PowerShell Version Detection') {
        # Find insertion point after any #Requires lines or initial comment block
        $lines = $content -split '\r?\n'
        $insertIndex = 0
        for ($i=0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^#Requires') { $insertIndex = $i + 1; continue }
            if ($lines[$i] -match '^<#$') { # skip comment header
                for ($j=$i+1; $j -lt $lines.Count; $j++) { if ($lines[$j] -match '^#>') { $insertIndex = $j + 1; break } }
            }
        }
        $lines = $lines[0..($insertIndex-1)] + $stdVersionRegion + $lines[$insertIndex..($lines.Count-1)]
        $content = ($lines -join [Environment]::NewLine)
        $addedRegion = $true
    }

    if ($content -ne $original) {
        if ($DryRun) {
            $results += [pscustomobject]@{ File=$file.FullName; Changed=$true; AddedRegion=$addedRegion }
        } else {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8
            $results += [pscustomobject]@{ File=$file.FullName; Changed=$true; AddedRegion=$addedRegion }
        }
    } else {
        $results += [pscustomobject]@{ File=$file.FullName; Changed=$false; AddedRegion=$false }
    }
}

Write-Host "Processed: $($results.Count) files" -ForegroundColor Cyan
Write-Host "Modified : $($results | Where-Object Changed | Measure-Object | Select-Object -ExpandProperty Count) files" -ForegroundColor Green
if ($DryRun) { Write-Host "(DryRun) No files written." -ForegroundColor Yellow }

# Summary table
$results | Sort-Object -Property Changed -Descending | Format-Table -AutoSize

# Detect remaining legacy tags
$remaining = Select-String -Path (Join-Path $RootPath '*') -Pattern $PatternLegacy -SimpleMatch -ErrorAction SilentlyContinue
if ($remaining) {
    Write-Warning "Remaining legacy Regelwerk references detected. Manual review recommended."
}
