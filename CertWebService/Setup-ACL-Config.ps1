#requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ACL Configuration Management Tool for CertWebService (Regelwerk v10.0.0)

.DESCRIPTION
    PowerShell backend for the Setup GUI to manage Access Control Lists,
    firewall rules, and security configurations. Provides web API endpoints
    for the HTML configuration interface.

.NOTES
    Author:         Flecki (Tom) Garnreiter  
    Version:        v2.3.0
    Regelwerk:      v10.0.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('GetConfig', 'SetConfig', 'TestAccess', 'GetStatus', 'ApplyFirewall', 'RemoveFirewall')]
    [string]$Action,
    
    [string]$ConfigData,
    [string]$TestHost,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "Config\Config-CertWebService.json")
)

#region Module Import and Initialization
$ErrorActionPreference = 'Stop'

try {
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-Logging.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-Config.psm1') -Force  
    Import-Module (Join-Path $PSScriptRoot 'Modules\FL-AccessControl.psm1') -Force
    
    $LogPath = Join-Path $PSScriptRoot "LOG\ACL-Config_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $LogBlock = { param($Message, $Level = 'INFO') Write-Log -Message $Message -Level $Level -LogPath $LogPath }
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}
#endregion

#region Action Handlers

switch ($Action) {
    'GetConfig' {
        try {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            $result = @{
                Success = $true
                Data = @{
                    AccessControl = $config.AccessControl
                    Firewall = $config.Firewall
                    Status = Get-AccessControlStatus -Config $config
                }
            }
            $result | ConvertTo-Json -Depth 10
        } catch {
            @{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json
        }
    }
    
    'SetConfig' {
        try {
            if (-not $ConfigData) {
                throw "ConfigData parameter required"
            }
            
            $newConfig = $ConfigData | ConvertFrom-Json
            $currentConfig = Get-Content $ConfigPath | ConvertFrom-Json
            
            # Update AccessControl section
            if ($newConfig.AccessControl) {
                $currentConfig.AccessControl = $newConfig.AccessControl
            }
            
            # Update Firewall section
            if ($newConfig.Firewall) {
                $currentConfig.Firewall = $newConfig.Firewall
            }
            
            # Save updated configuration
            $currentConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            
            . $LogBlock "ACL configuration updated via Setup GUI" "INFO"
            
            @{ Success = $true; Message = "Configuration saved successfully" } | ConvertTo-Json
            
        } catch {
            . $LogBlock "Error updating ACL configuration: $_" "ERROR"
            @{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json
        }
    }
    
    'TestAccess' {
        try {
            if (-not $TestHost) {
                throw "TestHost parameter required"
            }
            
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            $result = Test-RemoteHostAccess -RemoteHost $TestHost -Port $config.WebService.HttpPort -Config $config -LogFunction $LogBlock
            
            @{ Success = $true; Data = $result } | ConvertTo-Json -Depth 5
            
        } catch {
            @{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json
        }
    }
    
    'GetStatus' {
        try {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            
            # Get service status
            $website = Get-Website -Name $config.WebService.SiteName -ErrorAction SilentlyContinue
            $serviceRunning = $website -and $website.State -eq 'Started'
            
            # Get firewall rules
            $firewallRules = Get-NetFirewallRule -DisplayName "$($config.Firewall.RuleNamePrefix)*" -ErrorAction SilentlyContinue
            
            # Get access control status
            $aclStatus = Get-AccessControlStatus -Config $config
            
            $status = @{
                Service = @{
                    Running = $serviceRunning
                    SiteName = $config.WebService.SiteName
                    HttpPort = $config.WebService.HttpPort
                    HttpsPort = $config.WebService.HttpsPort
                }
                AccessControl = $aclStatus
                Firewall = @{
                    RulesCount = $firewallRules.Count
                    Rules = $firewallRules | Select-Object DisplayName, Enabled, Direction, Action | ConvertTo-Json -Depth 2 | ConvertFrom-Json
                }
            }
            
            @{ Success = $true; Data = $status } | ConvertTo-Json -Depth 10
            
        } catch {
            @{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json
        }
    }
    
    'ApplyFirewall' {
        try {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            
            Install-AccessControlRules -Config $config -HttpPort $config.WebService.HttpPort -HttpsPort $config.WebService.HttpsPort -LogFunction $LogBlock
            
            . $LogBlock "Firewall rules applied via Setup GUI" "INFO"
            
            @{ Success = $true; Message = "Firewall rules applied successfully" } | ConvertTo-Json
            
        } catch {
            . $LogBlock "Error applying firewall rules: $_" "ERROR"
            @{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json
        }
    }
    
    'RemoveFirewall' {
        try {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            
            Remove-FirewallACLRules -Config $config -LogFunction $LogBlock
            
            . $LogBlock "Firewall rules removed via Setup GUI" "INFO"
            
            @{ Success = $true; Message = "Firewall rules removed successfully" } | ConvertTo-Json
            
        } catch {
            . $LogBlock "Error removing firewall rules: $_" "ERROR"
            @{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json
        }
    }
}

#endregion