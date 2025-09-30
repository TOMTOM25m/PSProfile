using namespace System.Net
using namespace System.Windows.Forms

#Requires -Version 5
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Directory Permission Audit Tool - Analyzes folder permissions and user access rights

.DESCRIPTION
    Provides comprehensive reporting of directory access permissions including group memberships 
    and user account information for enhanced security auditing and compliance.
    Supports interactive folder selection and detailed permission reporting.

.OUTPUTS
    CSV or text report of folder permissions structure with user access rights

.NOTES
    Version:    v2.3.0
    Author:     Thomas Garnreiter 
    Creation:   2022-01-12
    Modified:   2025-09-29
    Regelwerk:  v9.6.2
    Repository: DirectoryPermissionAudit

.EXAMPLE
    .\FolderPermissionReport.ps1
    Launches the tool in interactive mode with folder browser dialog

.EXAMPLE
    .\FolderPermissionReport.ps1 -Path "D:\SharedFolders" -OutputFormat "CSV" -OutputPath "C:\Reports"
    Analyzes permissions for the specified path and generates a CSV report in the specified folder

.DISCLAIMER
    This script is provided AS IS without warranty of any kind. The entire risk arising out of
    the use or performance of the script remains with you.
#>
<#
.SYNOPSIS
  Directory Permission Audit Tool (Wrapper Script)
.DESCRIPTION
  Wrapper lädt das Modul und ruft den modulbasierten Einstieg auf. Bewahrt Rückwärtskompatibilität.
#>
[CmdletBinding()]param(
  [Parameter(Position=0)][string]$Path,
  [int]$Depth = 0,
  [ValidateSet('CSV','JSON','Human')][string]$OutputFormat = 'Human',
  [string]$OutputPath,
  [switch]$IncludeInherited,
  [switch]$IncludeSystemAccounts,
  [switch]$Interactive,
  [switch]$NoLogo
)
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$moduleRoot = Join-Path $ScriptDirectory 'Modules'
$manifest   = Join-Path $moduleRoot 'DirectoryPermissionAudit.psd1'
if (-not (Test-Path $manifest)) {
    # Fallback: development layout
    $devManifest = Join-Path $ScriptDirectory 'DirectoryPermissionAudit.psd1'
    if (Test-Path $devManifest) { $manifest = $devManifest } else { Write-Error "Module manifest not found: $manifest"; exit 1 }
}
try { Import-Module $manifest -Force -ErrorAction Stop } catch { Write-Error "Failed to import module manifest: $($_.Exception.Message)"; exit 1 }
Start-DirectoryPermissionAudit -Path $Path -Depth $Depth -OutputFormat $OutputFormat -OutputPath $OutputPath -IncludeInherited:$IncludeInherited.IsPresent -IncludeSystemAccounts:$IncludeSystemAccounts.IsPresent -Interactive:$Interactive.IsPresent -NoLogo:$NoLogo.IsPresent
# zgXAulwZ1XlLEVmoNW85dNAUTy/MBbDwD3tcN5C1SX07hdl1J8bM7tUarCMR8C+e
# OY1oaOATUJPukm7I/BnrE20bqXN7gpII0seLXVOZs0aNenzlOyVXxJS43mnKgVTH
# AO2Rm3i2ZLFKqSDkAt39X2ec3UZbw+SX/URXQQ==
# SIG # End signature block
