#Requires -Version 5.1

<#
.SYNOPSIS
    Show-PSRemotingWhitelist - Zeigt PSRemoting Whitelist-Konfiguration v1.0.0
    
.DESCRIPTION
    Zeigt die aktuelle PSRemoting-Konfiguration und die Whitelist der
    autorisierten Computer an.
    
.EXAMPLE
    .\Show-PSRemotingWhitelist.ps1
    
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v1.0.0
    Created on:     2025-10-07
    Regelwerk:      v10.0.3
#>

# ==========================================
# § 19 PowerShell Version Detection (MANDATORY)
# ==========================================
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

# ==========================================
# Whitelist Definition
# ==========================================
$AuthorizedComputers = @(
    "ITSC020.cc.meduniwien.ac.at",
    "itscmgmt03.srv.meduniwien.ac.at"
)

# ==========================================
# Display Functions
# ==========================================

function Get-WinRMStatus {
    try {
        $service = Get-Service -Name WinRM -ErrorAction Stop
        return @{
            Status = $service.Status
            StartType = $service.StartType
            Running = ($service.Status -eq 'Running')
        }
    } catch {
        return @{
            Status = "Not Found"
            StartType = "Unknown"
            Running = $false
        }
    }
}

function Get-TrustedHostsConfig {
    try {
        $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction Stop
        return $trustedHosts.Value
    } catch {
        return "NOT_CONFIGURED"
    }
}

function Get-FirewallRuleStatus {
    param([string]$RuleName)
    
    try {
        $rule = Get-NetFirewallRule -Name $RuleName -ErrorAction Stop
        return @{
            Exists = $true
            Enabled = $rule.Enabled
        }
    } catch {
        return @{
            Exists = $false
            Enabled = $false
        }
    }
}

function Test-WhitelistCompliance {
    $currentTrustedHosts = Get-TrustedHostsConfig
    
    if ($currentTrustedHosts -eq "NOT_CONFIGURED") {
        return @{
            Compliant = $false
            Reason = "TrustedHosts nicht konfiguriert"
        }
    }
    
    # Pruefe ob die Whitelist-Computer in TrustedHosts enthalten sind
    $separator = ","
    $trustedArray = $currentTrustedHosts -split $separator
    $compliant = $true
    $missing = @()
    
    foreach ($computer in $AuthorizedComputers) {
        $found = $false
        foreach ($trusted in $trustedArray) {
            if ($trusted.Trim() -eq $computer) {
                $found = $true
                break
            }
        }
        if (-not $found) {
            $compliant = $false
            $missing += $computer
        }
    }
    
    if ($compliant -and $trustedArray.Count -eq $AuthorizedComputers.Count) {
        return @{
            Compliant = $true
            Reason = "Whitelist korrekt konfiguriert"
        }
    } elseif ($compliant) {
        return @{
            Compliant = $false
            Reason = "Zusaetzliche Hosts in TrustedHosts (nicht nur Whitelist)"
        }
    } else {
        return @{
            Compliant = $false
            Reason = "Fehlende Whitelist-Computer: $($missing -join ', ')"
        }
    }
}

# ==========================================
# Main Display
# ==========================================

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  PSRemoting Whitelist-Konfiguration" -ForegroundColor Cyan
Write-Host "  Show-PSRemotingWhitelist v1.0.0" -ForegroundColor Cyan
Write-Host "  Regelwerk: v10.0.3" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# System-Info
Write-Host "SYSTEM-INFORMATIONEN:" -ForegroundColor Yellow
Write-Host "  Computer: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  PowerShell: $($PSVersion.ToString())" -ForegroundColor White
Write-Host ""

# Whitelist
Write-Host "🔒 AUTORISIERTE COMPUTER (WHITELIST):" -ForegroundColor Yellow
foreach ($computer in $AuthorizedComputers) {
    Write-Host "  ✓ $computer" -ForegroundColor Green
}
Write-Host ""

# WinRM Status
Write-Host "WINRM SERVICE STATUS:" -ForegroundColor Yellow
$winrmStatus = Get-WinRMStatus
if ($winrmStatus.Running) {
    Write-Host "  Status: $($winrmStatus.Status)" -ForegroundColor Green
    Write-Host "  StartType: $($winrmStatus.StartType)" -ForegroundColor Green
} else {
    Write-Host "  Status: $($winrmStatus.Status)" -ForegroundColor Red
    Write-Host "  StartType: $($winrmStatus.StartType)" -ForegroundColor Red
}
Write-Host ""

# TrustedHosts
Write-Host "TRUSTEDHOSTS KONFIGURATION:" -ForegroundColor Yellow
$trustedHosts = Get-TrustedHostsConfig
if ($trustedHosts -ne "NOT_CONFIGURED") {
    $separator = ","
    $trustedArray = $trustedHosts -split $separator
    foreach ($hostItem in $trustedArray) {
        $hostTrimmed = $hostItem.Trim()
        if ($AuthorizedComputers -contains $hostTrimmed) {
            Write-Host "  [SUCCESS] $hostTrimmed" -ForegroundColor Green
        } else {
            Write-Host "  [WARNING] $hostTrimmed" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  <nicht konfiguriert>" -ForegroundColor Red
}
Write-Host ""

# Compliance Check
Write-Host "WHITELIST COMPLIANCE:" -ForegroundColor Yellow
$compliance = Test-WhitelistCompliance
if ($compliance.Compliant) {
    Write-Host "  ✓ COMPLIANT" -ForegroundColor Green
    Write-Host "  $($compliance.Reason)" -ForegroundColor Gray
} else {
    Write-Host "  ✗ NOT COMPLIANT" -ForegroundColor Red
    Write-Host "  $($compliance.Reason)" -ForegroundColor Yellow
}
Write-Host ""

# Firewall-Regeln
Write-Host "FIREWALL-REGELN:" -ForegroundColor Yellow
$httpRule = Get-FirewallRuleStatus -RuleName "WINRM-HTTP-In-TCP"
$httpsRule = Get-FirewallRuleStatus -RuleName "WINRM-HTTPS-In-TCP"

if ($httpRule.Exists) {
    $status = if ($httpRule.Enabled) { "✓ Enabled" } else { "⚠ Disabled" }
    $color = if ($httpRule.Enabled) { "Green" } else { "Yellow" }
    Write-Host "  HTTP (5985): $status" -ForegroundColor $color
} else {
    Write-Host "  HTTP (5985): ✗ Not configured" -ForegroundColor Red
}

if ($httpsRule.Exists) {
    $status = if ($httpsRule.Enabled) { "✓ Enabled" } else { "⚠ Disabled" }
    $color = if ($httpsRule.Enabled) { "Green" } else { "Yellow" }
    Write-Host "  HTTPS (5986): $status" -ForegroundColor $color
} else {
    Write-Host "  HTTPS (5986): Not configured" -ForegroundColor Gray
}
Write-Host ""

# WinRM Listener
Write-Host "WINRM LISTENER:" -ForegroundColor Yellow
try {
    $listeners = Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate -ErrorAction Stop
    foreach ($listener in $listeners) {
        Write-Host "  Transport: $($listener.Transport) | Port: $($listener.Port) | Address: $($listener.Address)" -ForegroundColor White
    }
} catch {
    Write-Host "  <keine Listener konfiguriert>" -ForegroundColor Red
}
Write-Host ""

# Empfehlungen
Write-Host "=====================================================================" -ForegroundColor Cyan
if (-not $compliance.Compliant -or -not $winrmStatus.Running) {
    Write-Host "EMPFOHLENE AKTION:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Führe Configure-PSRemoting.ps1 aus, um die Whitelist zu konfigurieren:" -ForegroundColor White
    Write-Host "  .\Configure-PSRemoting.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Dies konfiguriert automatisch:" -ForegroundColor Gray
    Write-Host "  - WinRM Service" -ForegroundColor Gray
    Write-Host "  - PSRemoting" -ForegroundColor Gray
    Write-Host "  - TrustedHosts Whitelist" -ForegroundColor Gray
    Write-Host "  - Firewall-Regeln" -ForegroundColor Gray
} else {
    Write-Host "✓ SYSTEM KORREKT KONFIGURIERT" -ForegroundColor Green
    Write-Host ""
    Write-Host "PSRemoting ist aktiv und auf die Whitelist beschränkt." -ForegroundColor White
    Write-Host "Nur ITSC020 und itscmgmt03 dürfen zugreifen." -ForegroundColor White
}
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
