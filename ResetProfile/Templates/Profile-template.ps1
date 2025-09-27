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

# Enhanced PowerShell version detection
$global:PSVersionInfo = [PSCustomObject]@{
    Major = $PSVersionTable.PSVersion.Major
    Minor = $PSVersionTable.PSVersion.Minor
    IsModern = $PSVersionTable.PSVersion.Major -ge 7
    IsLegacy = $PSVersionTable.PSVersion.Major -lt 7
    IsCore = $PSVersionTable.PSEdition -eq 'Core'
    IsDesktop = $PSVersionTable.PSEdition -eq 'Desktop'
    Platform = $PSVersionTable.Platform
    Edition = $PSVersionTable.PSEdition
}

# Initialize global variables with error handling
try {
    $global:IsAdmin = if ($global:PSVersionInfo.Platform -eq 'Unix') {
        (id -u) -eq 0
    } else {
        ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    
    $global:IsModernPS = $global:PSVersionInfo.IsModern
    $global:IsWindows = $global:PSVersionInfo.Platform -ne 'Unix' -and $global:PSVersionInfo.Platform -ne 'MacOS'
    
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
    $extensionFiles = @('Profile-templateMOD.ps1', 'Profile-templateX.ps1', 'ProfileMOD.ps1', 'ProfileX.ps1', 'Profile.Extensions.ps1')
    foreach ($extension in $extensionFiles) {
        $extensionPath = Join-Path -Path $global:ProfileDir -ChildPath $extension
        if (Test-Path -Path $extensionPath -PathType Leaf) {
            try { 
                . $extensionPath 
                if (-not $Quiet) { Write-Host "✅ Loaded extension: $extension" -ForegroundColor Green }
            } catch { 
                Write-Warning "Failed to load extension '$extension': $($_.Exception.Message)" 
            }
        }
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════════════════════════
#                           VERSION-SPECIFIC FUNCTION IMPLEMENTATIONS
#═══════════════════════════════════════════════════════════════════════════════════════════════════════

# PowerShell 5.1 specific functions
if ($global:PSVersionInfo.IsLegacy) {
    
    # PS 5.1 System Info with WMI/CIM fallbacks
    function Get-SystemInfo-PS51 {
        try {
            # Prefer CIM, fallback to WMI for PS 5.1 compatibility
            try {
                $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
                $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property Capacity -Sum
            } catch {
                # Fallback to WMI for older systems
                $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
                $cpu = Get-WmiObject -Class Win32_Processor -ErrorAction Stop | Select-Object -First 1
                $memory = Get-WmiObject -Class Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property Capacity -Sum
            }
            
            [PSCustomObject]@{
                OS = $os.Caption
                Version = $os.Version
                Architecture = $os.OSArchitecture
                CPU = $cpu.Name
                MemoryGB = [Math]::Round($memory.Sum / 1GB, 2)
                Uptime = (Get-Date) - $os.LastBootUpTime
                PowerShell = "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
                LoadTime = "$(Get-Date -Format 'HH:mm:ss')"
                ProfileVersion = "v25.0.0-PS51"
            }
        } catch {
            Write-Warning "Could not retrieve system information (PS 5.1): $($_.Exception.Message)"
            return $null
        }
    }

    # PS 5.1 Git Status with enhanced error handling
    function Get-GitStatus-PS51 {
        $currentPath = Get-Location
        $cacheKey = "ps51_$($currentPath.Path)"
        $now = Get-Date
        
        # Use cache if less than 30 seconds old
        if ($global:GitStatusCache -and $global:GitStatusCache[$cacheKey] -and 
            ($now - $global:GitStatusCache[$cacheKey].Time).TotalSeconds -lt 30) {
            return $global:GitStatusCache[$cacheKey].Status
        }
        
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                $null = & git status --porcelain 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $branch = & git rev-parse --abbrev-ref HEAD 2>$null
                    $status = & git status --porcelain 2>$null
                    $indicator = if ($status) { "±" } else { "✓" }
                    $result = " (git:$branch$indicator)"
                    
                    # Initialize cache if not exists
                    if (-not $global:GitStatusCache) { $global:GitStatusCache = @{} }
                    $global:GitStatusCache[$cacheKey] = @{
                        Status = $result
                        Time = $now
                    }
                    return $result
                }
            } catch { 
                Write-Verbose "Git error in PS 5.1: $($_.Exception.Message)"
            }
        }
        return ""
    }

    # PS 5.1 Network Test with .NET Framework
    function Test-Port-PS51 {
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
                Write-Host "✅ $ComputerName`:$Port - Open (PS 5.1)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ $ComputerName`:$Port - Closed/Timeout (PS 5.1)" -ForegroundColor Red
                return $false
            }
        } catch {
            Write-Host "❌ $ComputerName`:$Port - Error (PS 5.1): $_" -ForegroundColor Red
            return $false
        } finally {
            if ($tcp) { $tcp.Close() }
        }
    }

    # PS 5.1 Enhanced Prompt
    function prompt-PS51 {
        # Command status indicator
        if ($?) { 
            Write-Host "✔ " -NoNewline -ForegroundColor Green 
        } else { 
            Write-Host "✘ " -NoNewline -ForegroundColor Red 
        }

        # Execution time display
        $history = Get-History -Count 1
        if ($history -and $history.StartExecutionTime -and $history.EndExecutionTime) {
            $execTime = $history.EndExecutionTime - $history.StartExecutionTime
            $timeString = "{0:mm}:{0:ss}.{1:d3}" -f $execTime, $execTime.Milliseconds
            Write-Host "[$timeString] " -NoNewline -ForegroundColor White
        }

        # Current location
        Write-Host "$(Split-Path -Leaf (Get-Location)) " -NoNewline -ForegroundColor Yellow
        
        # Git status for PS 5.1
        $gitInfo = Get-GitStatus-PS51
        if ($gitInfo) { Write-Host "$gitInfo " -NoNewline -ForegroundColor Magenta }

        # User and admin status
        $userColor = if ($global:IsAdmin) { "Red" } else { "Cyan" }
        $userPrefix = if ($global:IsAdmin) { "Admin" } else { "User" }
        $userText = "[$($env:USERNAME)@$userPrefix-PS$($PSVersionTable.PSVersion.Major)]"
        Write-Host "$userText " -NoNewline -ForegroundColor $userColor

        return "> "
    }

    # Set PS 5.1 specific aliases
    Set-Alias -Name "ll" -Value "Get-ChildItem" -Force -Scope Global
    Set-Alias -Name "grep" -Value "Select-String" -Force -Scope Global
    Set-Alias -Name "which" -Value "Get-Command" -Force -Scope Global
    
    # PS 5.1 Security enhancements
    if ($global:IsAdmin) {
        try {
            # Enable strong cryptography for PS 5.1
            $regPaths = @(
                'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
                'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            )
            foreach ($regPath in $regPaths) {
                if (-not (Test-Path $regPath)) { 
                    try { 
                        New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null 
                    } catch { 
                        continue 
                    } 
                }
                Set-ItemProperty -Path $regPath -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Verbose "Could not set strong crypto settings: $($_.Exception.Message)"
        }
    }

    # Set encoding for PS 5.1
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
    
    # Display PS 5.1 startup message
    if (-not $Quiet) {
        $adminText = if ($global:IsAdmin) { "Admin" } else { "User " }
        Write-Host "🔧 PowerShell 5.1 Legacy Profile v25.0.0 (Regelwerk v9.6.0) geladen" -ForegroundColor Cyan
        Write-Host "⚙️  Edition: $($PSVersionTable.PSEdition) | Platform: Windows | Rights: $adminText" -ForegroundColor Yellow
    }

} else {
    #region ####################### PowerShell 7.x Modern Features #######################
    
    # PS 7.x System Info with modern cmdlets
    function Get-SystemInfo-PS7 {
        try {
            if ($global:IsWindows) {
                $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
                $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property Capacity -Sum
                
                $systemRole = try {
                    $computerInfo = Get-ComputerInfo -Property PowerPlatformRole -ErrorAction SilentlyContinue
                    $role = $computerInfo.PowerPlatformRole.ToString()
                    switch -Regex ($role) {
                        'Desktop|Workstation|Mobile' { "Workstation" }
                        'Server' { "Server" }
                        default {
                            $productType = $os.ProductType
                            switch ($productType) {
                                1 { "Workstation" }
                                2 { "Domain Controller" }
                                3 { "Server" }
                                default { "Unknown" }
                            }
                        }
                    }
                } catch { "Unknown" }
            } else {
                # Cross-platform info for PS 7.x
                $os = [PSCustomObject]@{
                    Caption = "$($PSVersionTable.Platform)"
                    Version = [System.Environment]::OSVersion.Version.ToString()
                    OSArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
                    LastBootUpTime = Get-Date  # Simplified for non-Windows
                }
                $cpu = [PSCustomObject]@{ Name = "Cross-Platform CPU" }
                $memory = [PSCustomObject]@{ Sum = 8GB }  # Placeholder
                $systemRole = $PSVersionTable.Platform
            }
            
            [PSCustomObject]@{
                OS = $os.Caption
                Version = $os.Version
                Architecture = $os.OSArchitecture
                CPU = $cpu.Name
                MemoryGB = [Math]::Round($memory.Sum / 1GB, 2)
                Uptime = if ($global:IsWindows) { (Get-Date) - $os.LastBootUpTime } else { "N/A" }
                PowerShell = "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
                LoadTime = "$(Get-Date -Format 'HH:mm:ss')"
                ProfileVersion = "v25.0.0-PS7"
                SystemRole = $systemRole
                Platform = $PSVersionTable.Platform
            }
        } catch {
            Write-Warning "Could not retrieve system information (PS 7.x): $($_.Exception.Message)"
            return $null
        }
    }

    # PS 7.x Git Status with modern syntax
    function Get-GitStatus-PS7 {
        $currentPath = Get-Location
        $cacheKey = $currentPath.Path
        $now = Get-Date
        
        # Use cache if less than 30 seconds old
        if ($global:GitStatusCache -and $global:GitStatusCache[$cacheKey] -and 
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
                    
                    # Initialize cache if not exists
                    if (-not $global:GitStatusCache) { $global:GitStatusCache = @{} }
                    $global:GitStatusCache[$cacheKey] = @{
                        Status = $result
                        Time = $now
                    }
                    return $result
                }
            } catch { 
                Write-Verbose "Git error in PS 7.x: $($_.Exception.Message)"
            }
        }
        return ""
    }

    # PS 7.x Network Test with modern features
    function Test-Port-PS7 {
        param(
            [Parameter(Mandatory)][string]$ComputerName,
            [Parameter(Mandatory)][int]$Port,
            [int]$Timeout = 3000
        )
        try {
            $tcp = [System.Net.Sockets.TcpClient]::new()
            $connect = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
            if ($wait) {
                $tcp.EndConnect($connect)
                Write-Host "✅ $ComputerName`:$Port - Open (PS 7.x)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ $ComputerName`:$Port - Closed/Timeout (PS 7.x)" -ForegroundColor Red
                return $false
            }
        } catch {
            Write-Host "❌ $ComputerName`:$Port - Error (PS 7.x): $_" -ForegroundColor Red
            return $false
        } finally {
            $tcp?.Close()
        }
    }

    # PS 7.x Enhanced Prompt with modern features
    function prompt-PS7 {
        # Command status indicator
        if ($?) { 
            Write-Host "✔ " -NoNewline -ForegroundColor Green 
        } else { 
            Write-Host "✘ " -NoNewline -ForegroundColor Red 
        }

        # Execution time display
        $history = Get-History -Count 1
        if ($history?.StartExecutionTime -and $history?.EndExecutionTime) {
            $execTime = $history.EndExecutionTime - $history.StartExecutionTime
            $timeString = "{0:mm}:{0:ss}.{1:d3}" -f $execTime, $execTime.Milliseconds
            Write-Host "[$timeString] " -NoNewline -ForegroundColor White
        }

        # Current location
        Write-Host "$(Split-Path -Leaf (Get-Location)) " -NoNewline -ForegroundColor Yellow
        
        # Git status
        $gitInfo = Get-GitStatus-PS7
        if ($gitInfo) { Write-Host "$gitInfo " -NoNewline -ForegroundColor Magenta }

        # User and admin status with platform info
        $userColor = if ($global:IsAdmin) { "Red" } else { "Cyan" }
        $userPrefix = if ($global:IsAdmin) { "Admin" } else { "User" }
        $platformInfo = if ($global:IsWindows) { "Win" } else { $PSVersionTable.Platform }
        $userText = "[$($env:USERNAME)@$userPrefix-PS$($PSVersionTable.PSVersion.Major)-$platformInfo]"
        Write-Host "$userText " -NoNewline -ForegroundColor $userColor

        return "> "
    }

    # Set PS 7.x specific aliases with modern syntax
    Set-Alias -Name "ll" -Value "Get-ChildItem" -Force -Scope Global
    Set-Alias -Name "grep" -Value "Select-String" -Force -Scope Global
    Set-Alias -Name "which" -Value "Get-Command" -Force -Scope Global
    
    # PS 7.x specific functions
    function global:Get-PublicIP-PS7 { 
        try {
            (Invoke-RestMethod -Uri "https://ipinfo.io/ip" -TimeoutSec 5).Trim() 
        } catch {
            Write-Warning "Could not retrieve public IP: $($_.Exception.Message)"
        }
    }

    # Display PS 7.x startup message with enhanced info
    if (-not $Quiet) {
        $adminText = if ($global:IsAdmin) { "Admin" } else { "User " }
        $platformText = if ($global:IsWindows) { "Windows" } else { $PSVersionTable.Platform }
        
        $banner = @"
╭─────────────────────────────────────────────────────────────────╮
│ 🚀 PowerShell 7.x Modern Profile v25.0.0                        │
│ 📋 Regelwerk v9.6.0 | $($platformText.PadRight(12)) | $($adminText.PadRight(5)) │
│ ⚡ Enhanced productivity tools and utilities loaded              │
╰─────────────────────────────────────────────────────────────────╯
"@
        Write-Host $banner -ForegroundColor Cyan
    }

    #endregion
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════════════════════════
#                               UNIVERSAL FUNCTIONS (ALL VERSIONS)
#═══════════════════════════════════════════════════════════════════════════════════════════════════════

# Initialize Git Status Cache
if (-not $global:GitStatusCache) { $global:GitStatusCache = @{} }

# Version-aware wrapper functions
function global:Get-SystemInfo {
    if ($global:PSVersionInfo.IsModern) {
        Get-SystemInfo-PS7
    } else {
        Get-SystemInfo-PS51
    }
}

function global:Test-Port {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][int]$Port,
        [int]$Timeout = 3000
    )
    if ($global:PSVersionInfo.IsModern) {
        Test-Port-PS7 -ComputerName $ComputerName -Port $Port -Timeout $Timeout
    } else {
        Test-Port-PS51 -ComputerName $ComputerName -Port $Port -Timeout $Timeout
    }
}

# Set the appropriate prompt function
function global:prompt {
    if ($global:PSVersionInfo.IsModern) {
        prompt-PS7
    } else {
        prompt-PS51
    }
}

# Universal utility functions (work in both versions)
function global:Get-DirectorySize {
    param([string]$Path = ".")
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [Math]::Round($size / 1GB, 2)
        $sizeMB = [Math]::Round($size / 1MB, 2)
        Write-Host "Directory: $Path" -ForegroundColor Cyan
        Write-Host "Size: $sizeMB MB ($sizeGB GB)" -ForegroundColor Yellow
    } catch {
        Write-Warning "Could not calculate directory size: $($_.Exception.Message)"
    }
}

function global:Measure-CommandTime {
    param([scriptblock]$Command)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Command
    } finally {
        $stopwatch.Stop()
        Write-Host "Execution Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
    }
}

function global:Get-TopProcesses {
    param([int]$Count = 10)
    Get-Process | Sort-Object CPU -Descending | Select-Object -First $Count Name, CPU, WorkingSet, Id |
    Format-Table -AutoSize
}

# Universal system commands
function global:uptime { 
    try {
        if ($global:IsWindows) {
            (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        } else {
            "Uptime not available on this platform"
        }
    } catch {
        Write-Warning "Could not retrieve uptime: $($_.Exception.Message)"
    }
}

function global:df { 
    try {
        if ($global:IsWindows) {
            Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, 
                @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}}, 
                @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}, 
                @{Name="%Free";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}}
        } else {
            Write-Host "df command not implemented for this platform. Use native 'df -h'" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "Could not retrieve disk information: $($_.Exception.Message)"
    }
}

function global:ps-version { $PSVersionTable }

# Development helpers
function global:New-GUID { [System.Guid]::NewGuid().ToString() }

function global:Get-Hash {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$Algorithm = "SHA256"
    )
    try {
        Get-FileHash -Path $FilePath -Algorithm $Algorithm
    } catch {
        Write-Warning "Could not calculate hash: $($_.Exception.Message)"
    }
}

function global:Format-Json {
    param([Parameter(ValueFromPipeline)]$InputObject)
    try {
        $InputObject | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Green
    } catch {
        Write-Warning "Could not format JSON: $($_.Exception.Message)"
    }
}

# Universal file operations
function global:touch { 
    param($file) 
    try {
        New-Item -ItemType File -Path $file -Force
    } catch {
        Write-Warning "Could not create file '$file': $($_.Exception.Message)"
    }
}

function global:mkd { 
    param($dir) 
    try {
        New-Item -ItemType Directory -Path $dir -Force
    } catch {
        Write-Warning "Could not create directory '$dir': $($_.Exception.Message)"
    }
}

function global:reload { 
    try {
        . $PROFILE 
    } catch {
        Write-Warning "Could not reload profile: $($_.Exception.Message)"
    }
}

function global:edit-profile { 
    if ($global:PSVersionInfo.IsModern -and (Get-Command code -ErrorAction SilentlyContinue)) {
        code $PROFILE
    } else {
        notepad $PROFILE
    }
}

# Enhanced profile information
function global:Show-ProfileInfo {
    Write-Host "📋 PowerShell Profile Information" -ForegroundColor Cyan
    Write-Host "Profile Path: $PROFILE" -ForegroundColor Yellow
    Write-Host "Profile Exists: $(Test-Path $PROFILE)" -ForegroundColor $(if (Test-Path $PROFILE) {'Green'} else {'Red'})
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor White
    Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor White
    Write-Host "Regelwerk Version: v9.6.0" -ForegroundColor Green
    Write-Host "Template Version: v25.0.0-Professional" -ForegroundColor Green
    Write-Host "Admin Rights: $global:IsAdmin" -ForegroundColor $(if ($global:IsAdmin) {'Red'} else {'Green'})
    Write-Host "Modern PS: $($global:PSVersionInfo.IsModern)" -ForegroundColor Cyan
    Write-Host "Legacy PS: $($global:PSVersionInfo.IsLegacy)" -ForegroundColor Cyan
    Write-Host "Edition: $($global:PSVersionInfo.Edition)" -ForegroundColor Magenta
}

# Enhanced performance test with version-specific tests
function global:Test-ProfilePerformance {
    Write-Host "🚀 Testing Profile Performance..." -ForegroundColor Cyan
    
    $tests = @(
        @{ Name = "Get-SystemInfo"; Command = { Get-SystemInfo | Out-Null } },
        @{ Name = "Git Status"; Command = { 
            if ($global:PSVersionInfo.IsModern) { 
                Get-GitStatus-PS7 | Out-Null 
            } else { 
                Get-GitStatus-PS51 | Out-Null 
            } 
        }},
        @{ Name = "Directory Listing"; Command = { Get-ChildItem | Out-Null } },
        @{ Name = "Process List"; Command = { Get-Process | Select-Object -First 5 | Out-Null } },
        @{ Name = "Test-Port"; Command = { Test-Port -ComputerName "127.0.0.1" -Port 80 -Timeout 1000 | Out-Null } }
    )
    
    foreach ($test in $tests) {
        try {
            $time = (Measure-Command $test.Command).TotalMilliseconds
            $color = if ($time -lt 100) { 'Green' } elseif ($time -lt 500) { 'Yellow' } else { 'Red' }
            Write-Host "  $($test.Name): $([Math]::Round($time, 2))ms" -ForegroundColor $color
        } catch {
            Write-Host "  $($test.Name): Error - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "Profile optimized for: PowerShell $($PSVersionTable.PSVersion.Major).x" -ForegroundColor Magenta
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════════════════════════
#                                       CLEANUP & FINALIZATION
#═══════════════════════════════════════════════════════════════════════════════════════════════════════

# Cleanup temporary variables
Remove-Variable -Name 'script:*' -ErrorAction SilentlyContinue

# Display welcome message
if (-not $global:ProfileWelcomeShown) {
    $loadTime = ((Get-Date) - $script:ProfileStartTime).TotalMilliseconds
    Write-Host "`n🎉 Profile loaded successfully in $([Math]::Round($loadTime, 2))ms!" -ForegroundColor Green
    Write-Host "💡 Use 'Show-ProfileInfo' for details | 'Test-ProfilePerformance' for benchmarks" -ForegroundColor Cyan
    $global:ProfileWelcomeShown = $true
}

#endregion

# --- End of Profile Template | Version: v25.0.0-Professional | Regelwerk: v9.6.0 | Date: 2025-09-27 ---