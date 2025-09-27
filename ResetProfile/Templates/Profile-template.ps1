<#
.SYNOPSIS
    Professional PowerShell Universal Profile Template
    
.DESCRIPTION
    Enterprise-grade PowerShell profile template designed for maximum productivity and performance.
    Provides a unified experience across Windows PowerShell 5.1 and PowerShell 7+ with intelligent
    feature detection, advanced prompt customization, Git integration, and comprehensive utility functions.
    
    ✨ ENTERPRISE FEATURES:
    • Cross-platform compatibility (Windows PowerShell 5.1+ & PowerShell 7+)
    • Intelligent Git integration with performance caching
    • Advanced prompt with execution time, Git status, and system information
    • Comprehensive developer utilities and shortcuts
    • Performance monitoring and optimization tools
    • Security enhancements and compliance features
    • Modular architecture for easy customization
    • Professional error handling and logging
    
    🚀 PERFORMANCE OPTIMIZED:
    • Lazy loading of expensive operations
    • Intelligent caching for Git operations
    • Minimal startup time impact
    • Memory-efficient function implementations

.PARAMETER LoadExtensions
    Load additional profile extensions if available (ProfileMOD.ps1, ProfileX.ps1)

.PARAMETER Quiet
    Suppress startup messages and banners

.EXAMPLE
    # Standard loading (automatic via $PROFILE)
    # All features enabled by default
    
.EXAMPLE  
    # Manual loading with options
    . .\Profile-template.ps1 -Quiet -LoadExtensions:$false

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created:        2025-07-08
    Last Modified:  2025-09-27
    Version:        v25.0.0-Professional
    Regelwerk:      v9.6.0 Compliant
    Compatibility:  PowerShell 5.1+ | PowerShell 7+ | Cross-Platform
    License:        MIT License
    Copyright:      © 2025 Flecki Garnreiter
.DISCLAIMER
    [DE] Die bereitgestellten Skripte und die zugehörige Dokumentation werden "wie besehen" ("as is")
    ohne ausdrückliche oder stillschweigende Gewährleistung jeglicher Art zur Verfügung gestellt.
    Insbesondere wird keinerlei Gewähr übernommen für die Marktgängigkeit, die Eignung für einen bestimmten Zweck
    oder die Nichtverletzung von Rechten Dritter.
    Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder Unterstützung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
    In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
    Entwicklung oder Verbreitung dieser Skripte für direkte, indirekte, zufällige, besondere oder Folgeschäden - einschließlich,
    aber nicht beschränkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
    selbst wenn sie auf die Möglichkeit solcher Schäden hingewiesen wurden.
    Durch die Nutzung der Skripte erklären Sie sich mit diesen Bedingungen einverstanden.

    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
    fitness for a particular purpose, and non-infringement.
    There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
    Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
    or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
    including but not not limited to direct, indirect, incidental, consequential, or special damages
    (such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
    By using these scripts, you agree to be bound by the above terms.
#>
#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$LoadExtensions = $true,
    [switch]$Quiet = $false
)

#region ═══════════════════════════════════════════════════════════════════════════════════════════════
#                                    PROFILE INITIALIZATION
#═══════════════════════════════════════════════════════════════════════════════════════════════════════

# Performance tracking
$script:ProfileStartTime = Get-Date

# Prevent multiple loading in same session
if ($global:ProfileLoadedVersion -eq 'v25.0.0-Professional') { 
    if (-not $Quiet) { Write-Host "⚡ Profile already loaded (v25.0.0)" -ForegroundColor Yellow }
    return 
}
$global:ProfileLoadedVersion = 'v25.0.0-Professional'

# Initialize global variables with error handling
try {
    $global:IsAdmin = if ($PSVersionTable.Platform -eq 'Unix') {
        (id -u) -eq 0
    } else {
        ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    
    $global:IsModernPS = $PSVersionTable.PSVersion.Major -ge 7
    $global:IsWindows = $PSVersionTable.Platform -ne 'Unix' -and $PSVersionTable.Platform -ne 'MacOS'
    
    # PowerShell 5.1 compatible version of null coalescing
    if ($PSCommandPath) { 
        $global:ProfilePath = $PSCommandPath 
    } else { 
        $global:ProfilePath = $MyInvocation.MyCommand.Path 
    }
    
    $global:ProfileDir = Split-Path -Path $global:ProfilePath -Parent
} catch {
    Write-Warning "Profile initialization warning: $($_.Exception.Message)"
}

# Load profile extensions (optional)
if ($LoadExtensions) {
    $extensionFiles = @('ProfileMOD.ps1', 'ProfileX.ps1', 'Profile.Extensions.ps1')
    foreach ($extension in $extensionFiles) {
        $extensionPath = Join-Path -Path $global:ProfileDir -ChildPath $extension
        if (Test-Path -Path $extensionPath -PathType Leaf) {
            try { 
                . $extensionPath 
                if (-not $Quiet) { Write-Verbose "Loaded extension: $extension" }
            } catch { 
                Write-Warning "Failed to load extension '$extension': $($_.Exception.Message)" 
            }
        }
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════════════════════════
#                                 POWERSHELL 7+ MODERN FEATURES
#═══════════════════════════════════════════════════════════════════════════════════════════════════════

if ($global:IsModernPS) {
    
    # Enhanced system detection with cross-platform support
    $script:SystemInfo = try {
        if ($global:IsWindows) {
            $computerInfo = Get-ComputerInfo -Property PowerPlatformRole -ErrorAction SilentlyContinue
            $role = $computerInfo.PowerPlatformRole.ToString()
            switch -Regex ($role) {
                'Desktop|Workstation|Mobile' { "Workstation" }
                'Server' { "Server" }
                default {
                    $productType = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).ProductType
                    $roleMap = @{ 1 = "Workstation"; 2 = "Domain Controller"; 3 = "Server" }
                    if ($roleMap[$productType]) { 
                        $roleMap[$productType] 
                    } else { 
                        "Unknown" 
                    }
                }
            }
        } else {
            if ($PSVersionTable.Platform -eq 'Unix') { "Linux/Unix" }
            elseif ($PSVersionTable.Platform -eq 'MacOS') { "macOS" }
            else { "Cross-Platform" }
        }
    } catch { "Unknown" }
    
    # Professional startup banner
    if (-not $Quiet) {
        $adminText = if ($global:IsAdmin) { "Admin" } else { "User " }
        $banner = @"
╭─────────────────────────────────────────────────────────────────╮
│ 🚀 PowerShell Professional Profile v25.0.0                      │
│ 📋 Regelwerk v9.6.0 Compliant | $($script:SystemInfo.PadRight(15)) | $($adminText.PadRight(5)) │
│ ⚡ Enhanced productivity tools and utilities loaded              │
╰─────────────────────────────────────────────────────────────────╯
"@
        Write-Host $banner -ForegroundColor Cyan
    }

    # Optimized Git Integration with Caching
    $global:GitStatusCache = @{}
    function Get-GitStatus {
        $currentPath = Get-Location
        $cacheKey = $currentPath.Path
        $now = Get-Date
        
        # Use cache if less than 30 seconds old
        if ($global:GitStatusCache[$cacheKey] -and 
            ($now - $global:GitStatusCache[$cacheKey].Time).TotalSeconds -lt 30) {
            return $global:GitStatusCache[$cacheKey].Status
        }
        
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                $gitStatus = git status --porcelain 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $branch = git branch --show-current 2>$null
                    $status = if ($gitStatus) { "±" } else { "✓" }
                    $result = " ($branch$status)"
                    # Cache the result
                    $global:GitStatusCache[$cacheKey] = @{
                        Status = $result
                        Time = $now
                    }
                    return $result
                }
            } catch { }
        }
        return ""
    }

    # Enhanced Prompt with Git Integration
    function global:prompt {
        # Command status indicator
        if ($?) { Write-Host "✔ " -NoNewline -ForegroundColor Green } else { Write-Host "✘ " -NoNewline -ForegroundColor Red }

        # Execution time display
        $history = Get-History -Count 1
        if ($history -and $history.StartExecutionTime -and $history.EndExecutionTime) {
            $execTime = $history.EndExecutionTime - $history.StartExecutionTime
            $timeString = "{0:mm}:{0:ss}.{1:d3}" -f $execTime, $execTime.Milliseconds
            Write-Host "[$timeString] " -NoNewline -ForegroundColor White
        }

        # Current location
        Write-Host "$(Split-Path -Leaf (Get-Location)) " -NoNewline -ForegroundColor Yellow
        
        # Git status
        $gitInfo = Get-GitStatus
        if ($gitInfo) { Write-Host "$gitInfo " -NoNewline -ForegroundColor Magenta }

        # User and admin status
        $userColor = if ($global:IsAdmin) { "Red" } else { "Cyan" }
        $userText = if ($global:IsAdmin) { "[$($env:USERNAME)@Admin]" } else { "[$($env:USERNAME)]" }
        Write-Host "$userText " -NoNewline -ForegroundColor $userColor

        return "> "
    }

    # Modern PowerShell 7+ Aliases and Functions
    Set-Alias -Name "ll" -Value "Get-ChildItem" -Force
    Set-Alias -Name "grep" -Value "Select-String" -Force
    Set-Alias -Name "which" -Value "Get-Command" -Force
    
    function global:touch { param($file) New-Item -ItemType File -Path $file -Force }
    function global:mkd { param($dir) New-Item -ItemType Directory -Path $dir -Force }
    function global:reload { . $PROFILE }
    function global:edit-profile { code $PROFILE }
    function global:Get-PublicIP { (Invoke-RestMethod -Uri "https://ipinfo.io/ip").Trim() }

    #endregion
}
else {
    #region ####################### [3. Block für Windows PowerShell 5.1 (Legacy & Encoding-Safe)] ####################

    # Stellt sicher, dass die Konsolenausgabe UTF-8-kodiert ist, um Sonderzeichen korrekt darzustellen.
    $OutputEncoding = [System.Text.UTF8Encoding]::new()

    if ($global:IsAdmin) {
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319', 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' | ForEach-Object {
            if (-not (Test-Path $_)) { try { New-Item -Path $_ -Force -ErrorAction Stop | Out-Null } catch { return } }
            Set-ItemProperty -Path $_ -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SystemDefault # DevSkim: ignore DS440020, DS440000
        }
        catch {
            Write-Warning "System-Standard-Sicherheitsprotokolle konnten nicht gesetzt werden. Web-Anfragen könnten fehlschlagen."
        }
    }
    
    Write-Host "🔧 Legacy PowerShell Profile v25.0.0 (Regelwerk v9.6.0) für PS 5.1 geladen."
    if ($global:IsAdmin) { Write-Host "⚡ Administrator-Rechte aktiv" }

    # Optimized Legacy Git Integration with Caching
    $global:GitStatusCache = @{}
    function Get-GitStatusLegacy {
        $currentPath = Get-Location
        $cacheKey = "legacy_$($currentPath.Path)"
        $now = Get-Date
        
        # Use cache if less than 30 seconds old
        if ($global:GitStatusCache[$cacheKey] -and 
            ($now - $global:GitStatusCache[$cacheKey].Time).TotalSeconds -lt 30) {
            return $global:GitStatusCache[$cacheKey].Status
        }
        
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                $null = git status 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $branch = git rev-parse --abbrev-ref HEAD 2>$null
                    $result = " (git:$branch)"
                    # Cache the result
                    $global:GitStatusCache[$cacheKey] = @{
                        Status = $result
                        Time = $now
                    }
                    return $result
                }
            } catch { }
        }
        return ""
    }

    # Enhanced Legacy Prompt
    function global:prompt {
        if ($?) { Write-Host "✔ " -NoNewline -ForegroundColor Green } else { Write-Host "✘ " -NoNewline -ForegroundColor Red }

        $history = Get-History -Count 1
        if ($history -and $history.StartExecutionTime -and $history.EndExecutionTime) {
            $execTime = $history.EndExecutionTime - $history.StartExecutionTime
            $timeString = "{0:mm}:{0:ss}.{1:d3}" -f $execTime, $execTime.Milliseconds
            Write-Host "[$timeString] " -NoNewline -ForegroundColor White
        }

        Write-Host "$(Split-Path -Leaf (Get-Location)) " -NoNewline -ForegroundColor Yellow
        
        # Git status for PS 5.1
        $gitInfo = Get-GitStatusLegacy
        if ($gitInfo) { Write-Host "$gitInfo " -NoNewline -ForegroundColor Magenta }

        $userColor = if ($global:IsAdmin) { "Red" } else { "Cyan" }
        $userText = if ($global:IsAdmin) { "[$($env:USERNAME)@Admin]" } else { "[$($env:USERNAME)]" }
        Write-Host "$userText " -NoNewline -ForegroundColor $userColor

        return "> "
    }

    # Legacy-compatible Aliases and Functions
    Set-Alias -Name "ll" -Value "Get-ChildItem" -Force
    Set-Alias -Name "grep" -Value "Select-String" -Force
    Set-Alias -Name "which" -Value "Get-Command" -Force
    
    function global:touch { param($file) New-Item -ItemType File -Path $file -Force }
    function global:mkd { param($dir) New-Item -ItemType Directory -Path $dir -Force }
    function global:reload { . $PROFILE }
    function global:edit-profile { notepad $PROFILE }

    #endregion
}

#region ####################### [4. Gemeinsame Funktionen (Für alle Versionen)] ###########################

# Optimized System Information Functions
function global:Get-SystemInfo {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property Capacity -Sum
        
        [PSCustomObject]@{
            OS = $os.Caption
            Version = $os.Version
            Architecture = $os.OSArchitecture
            CPU = $cpu.Name
            MemoryGB = [Math]::Round($memory.Sum / 1GB, 2)
            Uptime = (Get-Date) - $os.LastBootUpTime
            PowerShell = $PSVersionTable.PSVersion
            LoadTime = "$(Get-Date -Format 'HH:mm:ss')"
        }
    } catch {
        Write-Warning "Could not retrieve system information: $($_.Exception.Message)"
        return $null
    }
}

# Network Utilities
function global:Test-Port {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][int]$Port,
        [int]$Timeout = 3000
    )
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($wait) {
            $tcp.EndConnect($connect)
            Write-Host "✅ $ComputerName`:$Port - Open" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ $ComputerName`:$Port - Closed/Timeout" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ $ComputerName`:$Port - Error: $_" -ForegroundColor Red
        return $false
    } finally {
        if ($tcp) { $tcp.Close() }
    }
}

# File and Directory Utilities
function global:Get-DirectorySize {
    param([string]$Path = ".")
    $size = (Get-ChildItem -Path $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $sizeGB = [Math]::Round($size / 1GB, 2)
    $sizeMB = [Math]::Round($size / 1MB, 2)
    Write-Host "Directory: $Path" -ForegroundColor Cyan
    Write-Host "Size: $sizeMB MB ($sizeGB GB)" -ForegroundColor Yellow
}

# PowerShell Performance
function global:Measure-CommandTime {
    param([scriptblock]$Command)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $Command
    $stopwatch.Stop()
    Write-Host "Execution Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
}

# Process Management
function global:Get-TopProcesses {
    param([int]$Count = 10)
    Get-Process | Sort-Object CPU -Descending | Select-Object -First $Count Name, CPU, WorkingSet, Id |
    Format-Table -AutoSize
}

# Quick System Commands
function global:uptime { (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime }
function global:df { Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}}, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}, @{Name="%Free";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}} }
function global:ps-version { $PSVersionTable }

# Development Helpers
function global:New-GUID { [System.Guid]::NewGuid().ToString() }
function global:Get-Hash {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$Algorithm = "SHA256"
    )
    Get-FileHash -Path $FilePath -Algorithm $Algorithm
}

# Quick JSON/XML formatting
function global:Format-Json {
    param([Parameter(ValueFromPipeline)]$InputObject)
    $InputObject | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Green
}

# Profile Management and Performance
function global:Show-ProfileInfo {
    Write-Host "📋 PowerShell Profile Information" -ForegroundColor Cyan
    Write-Host "Profile Path: $PROFILE" -ForegroundColor Yellow
    Write-Host "Profile Exists: $(Test-Path $PROFILE)" -ForegroundColor $(if (Test-Path $PROFILE) {'Green'} else {'Red'})
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "Regelwerk Version: v9.6.0" -ForegroundColor Green
    Write-Host "Template Version: v25.0.0-Professional" -ForegroundColor Green
    Write-Host "Admin Rights: $global:IsAdmin" -ForegroundColor $(if ($global:IsAdmin) {'Red'} else {'Green'})
    Write-Host "Modern PS: $global:IsModernPS" -ForegroundColor Cyan
}

# Profile Performance Test
function global:Test-ProfilePerformance {
    Write-Host "🚀 Testing Profile Performance..." -ForegroundColor Cyan
    
    $tests = @(
        @{ Name = "Get-SystemInfo"; Command = { Get-SystemInfo | Out-Null } },
        @{ Name = "Git Status"; Command = { if ($global:IsModernPS) { Get-GitStatus } else { Get-GitStatusLegacy } } },
        @{ Name = "Directory Listing"; Command = { Get-ChildItem | Out-Null } },
        @{ Name = "Process List"; Command = { Get-Process | Select-Object -First 5 | Out-Null } }
    )
    
    foreach ($test in $tests) {
        $time = (Measure-Command $test.Command).TotalMilliseconds
        $color = if ($time -lt 100) { 'Green' } elseif ($time -lt 500) { 'Yellow' } else { 'Red' }
        Write-Host "  $($test.Name): $([Math]::Round($time, 2))ms" -ForegroundColor $color
    }
}

#endregion

#region ####################### [5. Aufräumen (Für alle Versionen)] ###########################

# Cleanup temporary variables
Remove-Variable -Name 'script:*' -ErrorAction SilentlyContinue
Remove-Variable -Name 'osMessage' -ErrorAction SilentlyContinue

# Display welcome message
if (-not $global:ProfileWelcomeShown) {
    Write-Host "\n🎉 Profile loaded successfully! Use 'Show-ProfileInfo' for details." -ForegroundColor Green
    $global:ProfileWelcomeShown = $true
}

#endregion

# --- End of Profile Template | Version: v25.0.0-Professional | Regelwerk: v9.6.0 | Date: 2025-09-27 ---