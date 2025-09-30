#requires -Version 5.1
<#
.SYNOPSIS
    Access Control Module for Certificate Web Service (Regelwerk v10.0.0)

.DESCRIPTION
    This module provides centralized access control functionality,
    including IP whitelist, FQDN validation, and firewall rule management.
    Fully compliant with Regelwerk v10.0.0 modular design principles (§10).

.NOTES
    Author:         Flecki (Tom) Garnreiter
    Version:        v2.3.0
    Regelwerk:      v10.0.0
    Dependencies:   FL-Logging.psm1, FL-Network.psm1
#>

#region Module Metadata (§1, §6)
$ModuleInfo = @{
    Name = "FL-AccessControl"
    Version = "v2.3.0"
    Author = "Flecki (Tom) Garnreiter"
    Regelwerk = "v10.0.0"
    Description = "Access Control and Security Management"
}

Export-ModuleMember -Function @(
    'Test-AccessControlPermission',
    'Install-AccessControlRules',
    'Update-AccessControlConfig',
    'Get-AccessControlStatus',
    'New-FirewallACLRules',
    'Remove-FirewallACLRules',
    'Test-RemoteHostAccess',
    'Test-HttpMethodAllowed',
    'Get-ReadOnlyStatus'
)
#endregion

#region Core Functions (§7, §10)

<#
.SYNOPSIS
    Tests if a remote host/IP is allowed access based on ACL configuration.
    
.PARAMETER RemoteAddress
    IP address or FQDN of the requesting client.
    
.PARAMETER Config
    Configuration object containing AccessControl settings.
    
.PARAMETER HttpMethod
    HTTP method being requested (GET, POST, etc.).
    
.PARAMETER LogFunction
    Optional logging function for audit trail.
#>
function Test-AccessControlPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RemoteAddress,
        
        [Parameter(Mandatory)]
        [PSObject]$Config,
        
        [string]$HttpMethod = "GET",
        
        [scriptblock]$LogFunction = { param($msg, $lvl) Write-Verbose $msg }
    )
    
    try {
        # Skip if ACL is disabled
        if (-not $Config.AccessControl.Enabled) {
            . $LogFunction "Access control disabled - allowing all connections" "DEBUG"
            return $true
        }
        
        # In whitelist mode with deny by default, we'll check explicitly
        
        # Check HTTP method restrictions (Read-Only Mode)
        if ($Config.AccessControl.ReadOnlyMode -and $Config.AccessControl.BlockedMethods -contains $HttpMethod.ToUpper()) {
            . $LogFunction "Access DENIED for $RemoteAddress - HTTP method $HttpMethod not allowed in read-only mode" "WARNING"
            return $false
        }
        
        # Check allowed hosts (FQDN) - case insensitive
        $normalizedRemoteAddress = $RemoteAddress.ToLower()
        $normalizedAllowedHosts = $Config.AccessControl.AllowedHosts | ForEach-Object { $_.ToLower() }
        
        if ($normalizedAllowedHosts -contains $normalizedRemoteAddress) {
            . $LogFunction "Access granted for FQDN: $RemoteAddress (Method: $HttpMethod)" "INFO"
            return $true
        }
        
        # Check allowed IP ranges
        foreach ($allowedRange in $Config.AccessControl.AllowedIPs) {
            if (Test-IPInRange -IPAddress $RemoteAddress -CIDRRange $allowedRange) {
                . $LogFunction "Access granted for IP: $RemoteAddress (range: $allowedRange, Method: $HttpMethod)" "INFO"
                return $true
            }
        }
        
        # Log denied access if logging enabled
        if ($Config.AccessControl.LogDenied) {
            . $LogFunction "Access DENIED for: $RemoteAddress (Method: $HttpMethod)" "WARNING"
        }
        
        return $false
        
    } catch {
        . $LogFunction "Error in access control check: $_" "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    Installs firewall rules based on ACL configuration.
    
.PARAMETER Config
    Configuration object containing firewall and ACL settings.
    
.PARAMETER HttpPort
    HTTP port to configure rules for.
    
.PARAMETER HttpsPort
    HTTPS port to configure rules for.
    
.PARAMETER LogFunction
    Optional logging function.
#>
function Install-AccessControlRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config,
        
        [Parameter(Mandatory)]
        [int]$HttpPort,
        
        [Parameter(Mandatory)]
        [int]$HttpsPort,
        
        [scriptblock]$LogFunction = { param($msg, $lvl) Write-Verbose $msg }
    )
    
    try {
        if (-not $Config.Firewall.EnableACLRules) {
            . $LogFunction "Firewall ACL rules disabled - skipping" "INFO"
            return
        }
        
        # Remove existing rules first
        Remove-FirewallACLRules -Config $Config -LogFunction $LogFunction
        
        # Create allow rules for specified ranges
        foreach ($range in $Config.Firewall.AllowedRemoteAddresses) {
            $ruleNameHttp = "$($Config.Firewall.RuleNamePrefix)-HTTP-Allow-$($range.Replace('/', '_').Replace('.', '_'))"
            $ruleNameHttps = "$($Config.Firewall.RuleNamePrefix)-HTTPS-Allow-$($range.Replace('/', '_').Replace('.', '_'))"
            
            # HTTP Rule
            New-NetFirewallRule -DisplayName $ruleNameHttp `
                               -Direction Inbound `
                               -Protocol TCP `
                               -LocalPort $HttpPort `
                               -RemoteAddress $range `
                               -Action Allow `
                               -Enabled True `
                               -ErrorAction SilentlyContinue
            
            # HTTPS Rule
            New-NetFirewallRule -DisplayName $ruleNameHttps `
                               -Direction Inbound `
                               -Protocol TCP `
                               -LocalPort $HttpsPort `
                               -RemoteAddress $range `
                               -Action Allow `
                               -Enabled True `
                               -ErrorAction SilentlyContinue
            
            . $LogFunction "Created firewall allow rules for range: $range" "INFO"
        }
        
        # Create block rule for all others if enabled
        if ($Config.Firewall.BlockAllOther) {
            $blockRuleHttp = "$($Config.Firewall.RuleNamePrefix)-HTTP-Block-Others"
            $blockRuleHttps = "$($Config.Firewall.RuleNamePrefix)-HTTPS-Block-Others"
            
            New-NetFirewallRule -DisplayName $blockRuleHttp `
                               -Direction Inbound `
                               -Protocol TCP `
                               -LocalPort $HttpPort `
                               -Action Block `
                               -Enabled True `
                               -ErrorAction SilentlyContinue
            
            New-NetFirewallRule -DisplayName $blockRuleHttps `
                               -Direction Inbound `
                               -Protocol TCP `
                               -LocalPort $HttpsPort `
                               -Action Block `
                               -Enabled True `
                               -ErrorAction SilentlyContinue
            
            . $LogFunction "Created firewall block rules for unauthorized access" "INFO"
        }
        
    } catch {
        . $LogFunction "Error creating firewall ACL rules: $_" "ERROR"
        throw
    }
}

<#
.SYNOPSIS
    Removes all ACL-related firewall rules.
#>
function Remove-FirewallACLRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config,
        
        [scriptblock]$LogFunction = { param($msg, $lvl) Write-Verbose $msg }
    )
    
    try {
        $existingRules = Get-NetFirewallRule -DisplayName "$($Config.Firewall.RuleNamePrefix)*" -ErrorAction SilentlyContinue
        
        foreach ($rule in $existingRules) {
            Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
            . $LogFunction "Removed firewall rule: $($rule.DisplayName)" "INFO"
        }
        
    } catch {
        . $LogFunction "Error removing firewall rules: $_" "WARNING"
    }
}

<#
.SYNOPSIS
    Tests if an IP address is within a CIDR range.
#>
function Test-IPInRange {
    [CmdletBinding()]
    param(
        [string]$IPAddress,
        [string]$CIDRRange
    )
    
    try {
        # Handle CIDR notation
        if ($CIDRRange -contains '/') {
            $network = $CIDRRange.Split('/')[0]
            $prefixLength = [int]$CIDRRange.Split('/')[1]
        } else {
            $network = $CIDRRange
            $prefixLength = 32
        }
        
        # Convert to IP objects
        $targetIP = [System.Net.IPAddress]::Parse($IPAddress)
        $networkIP = [System.Net.IPAddress]::Parse($network)
        
        # Calculate subnet mask
        $mask = [System.Net.IPAddress]::Parse(([System.Net.IPAddress]([System.UInt32]([System.UInt32]::MaxValue -shl (32 - $prefixLength)))).IPAddressToString)
        
        # Check if IP is in range
        $targetNetwork = [System.Net.IPAddress]::Parse(([System.Net.IPAddress]([System.UInt32]($targetIP.Address -band $mask.Address))).IPAddressToString)
        
        return $targetNetwork.Equals($networkIP)
        
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
    Updates ACL configuration and applies changes.
#>
function Update-AccessControlConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string[]]$AllowedHosts,
        [string[]]$AllowedIPs,
        [bool]$Enabled,
        
        [scriptblock]$LogFunction = { param($msg, $lvl) Write-Verbose $msg }
    )
    
    try {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        
        if ($PSBoundParameters.ContainsKey('AllowedHosts')) {
            $config.AccessControl.AllowedHosts = $AllowedHosts
        }
        
        if ($PSBoundParameters.ContainsKey('AllowedIPs')) {
            $config.AccessControl.AllowedIPs = $AllowedIPs
        }
        
        if ($PSBoundParameters.ContainsKey('Enabled')) {
            $config.AccessControl.Enabled = $Enabled
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        . $LogFunction "ACL configuration updated successfully" "INFO"
        
        return $config
        
    } catch {
        . $LogFunction "Error updating ACL configuration: $_" "ERROR"
        throw
    }
}

<#
.SYNOPSIS
    Gets current access control status and statistics.
#>
function Get-AccessControlStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config
    )
    
    $status = @{
        Enabled = $config.AccessControl.Enabled
        WhitelistMode = $config.AccessControl.WhitelistMode
        AllowedHostsCount = $config.AccessControl.AllowedHosts.Count
        AllowedIPRangesCount = $config.AccessControl.AllowedIPs.Count
        FirewallRulesEnabled = $config.Firewall.EnableACLRules
        DenyByDefault = $config.AccessControl.DenyByDefault
        LogDeniedAccess = $config.AccessControl.LogDenied
    }
    
    return $status
}

<#
.SYNOPSIS
    Tests remote host connectivity and access permissions.
#>
function Test-RemoteHostAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RemoteHost,
        
        [Parameter(Mandatory)]
        [int]$Port,
        
        [Parameter(Mandatory)]
        [PSObject]$Config,
        
        [scriptblock]$LogFunction = { param($msg, $lvl) Write-Verbose $msg }
    )
    
    $result = @{
        RemoteHost = $RemoteHost
        Port = $Port
        ACLAllowed = $false
        NetworkReachable = $false
        DNSResolvable = $false
        ResolvedIP = $null
    }
    
    try {
        # Test DNS resolution
        try {
            $resolvedIP = [System.Net.Dns]::GetHostAddresses($RemoteHost)[0].IPAddressToString
            $result.DNSResolvable = $true
            $result.ResolvedIP = $resolvedIP
            . $LogFunction "DNS resolved $RemoteHost to $resolvedIP" "DEBUG"
        } catch {
            . $LogFunction "DNS resolution failed for $RemoteHost" "WARNING"
        }
        
        # Test network connectivity
        if ($result.ResolvedIP) {
            $tcpTest = Test-NetConnection -ComputerName $RemoteHost -Port $Port -InformationLevel Quiet
            $result.NetworkReachable = $tcpTest
        }
        
        # Test ACL permission
        $result.ACLAllowed = Test-AccessControlPermission -RemoteAddress $RemoteHost -Config $Config -LogFunction $LogFunction
        
        if ($result.ResolvedIP) {
            $ipAllowed = Test-AccessControlPermission -RemoteAddress $result.ResolvedIP -Config $Config -LogFunction $LogFunction
            $result.ACLAllowed = $result.ACLAllowed -or $ipAllowed
        }
        
    } catch {
        . $LogFunction "Error testing remote host access: $_" "ERROR"
    }
    
    return $result
}

<#
.SYNOPSIS
    Tests if an HTTP method is allowed based on read-only configuration.
#>
function Test-HttpMethodAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HttpMethod,
        
        [Parameter(Mandatory)]
        [PSObject]$Config
    )
    
    if (-not $Config.AccessControl.ReadOnlyMode) {
        return $true
    }
    
    $method = $HttpMethod.ToUpper()
    
    # Check if method is explicitly blocked
    if ($Config.AccessControl.BlockedMethods -contains $method) {
        return $false
    }
    
    # Check if method is explicitly allowed
    if ($Config.AccessControl.AllowedMethods -contains $method) {
        return $true
    }
    
    # Default deny if not in allowed list
    return $false
}

<#
.SYNOPSIS
    Gets read-only mode status and configuration.
#>
function Get-ReadOnlyStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config
    )
    
    return @{
        ReadOnlyMode = $Config.AccessControl.ReadOnlyMode
        AllowedMethods = $Config.AccessControl.AllowedMethods
        BlockedMethods = $Config.AccessControl.BlockedMethods
        AllowedHostsCount = $Config.AccessControl.AllowedHosts.Count
        AllowedHosts = $Config.AccessControl.AllowedHosts
    }
}

#endregion

#region Module Initialization (§6)
. { Write-Verbose "FL-AccessControl module loaded (Regelwerk v10.0.0)" } 2>$null
#endregion