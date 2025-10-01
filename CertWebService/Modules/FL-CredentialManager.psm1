#requires -Version 5.1
<#
.SYNOPSIS
    Secure Credential Management Module for CertWebService
    
.DESCRIPTION
    Provides secure storage and retrieval of credentials using Windows DPAPI.
    Credentials are encrypted per-user and per-machine for maximum security.
    
.VERSION
    1.0.0
    
.REGELWERK
    v10.0.2
    
.AUTHOR
    GitHub Copilot & Thomas Garnreiter
    
.NOTES
    Uses Windows Data Protection API (DPAPI) for secure credential storage.
    Credentials can only be decrypted by the same user on the same machine.
#>

$Script:CredentialStorePath = "$env:ProgramData\CertWebService\Credentials"

<#
.SYNOPSIS
    Saves credentials securely using Windows DPAPI
    
.DESCRIPTION
    Encrypts and stores credentials in a secure file. The credentials can only
    be decrypted by the same user account on the same machine.
    
.PARAMETER Credential
    PSCredential object to store
    
.PARAMETER TargetName
    Unique identifier for this credential (e.g., "wsus.srv.meduniwien.ac.at")
    
.EXAMPLE
    $cred = Get-Credential
    Save-SecureCredential -Credential $cred -TargetName "wsus.srv.meduniwien.ac.at"
    
.RETURNS
    $true if successful, $false otherwise
#>
function Save-SecureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )
    
    try {
        # Ensure storage directory exists
        if (-not (Test-Path $Script:CredentialStorePath)) {
            New-Item -Path $Script:CredentialStorePath -ItemType Directory -Force | Out-Null
            
            # Set restrictive permissions (only SYSTEM and current user)
            $acl = Get-Acl $Script:CredentialStorePath
            $acl.SetAccessRuleProtection($true, $false) # Disable inheritance
            
            # Add SYSTEM
            $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            $acl.AddAccessRule($systemRule)
            
            # Add current user
            $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            $acl.AddAccessRule($userRule)
            
            Set-Acl -Path $Script:CredentialStorePath -AclObject $acl
            Write-Verbose "[OK] Created secure credential store: $Script:CredentialStorePath"
        }
        
        # Sanitize target name for filename
        $safeName = $TargetName -replace '[\\/:*?"<>|]', '_'
        $credFile = Join-Path $Script:CredentialStorePath "$safeName.cred"
        
        # Extract username and password
        $username = $Credential.UserName
        $password = $Credential.GetNetworkCredential().Password
        
        # Encrypt password using DPAPI
        $securePassword = $Credential.Password
        $encryptedPassword = $securePassword | ConvertFrom-SecureString
        
        # Create credential object
        $credentialData = @{
            Username = $username
            EncryptedPassword = $encryptedPassword
            TargetName = $TargetName
            CreatedDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            CreatedBy = "$env:USERDOMAIN\$env:USERNAME"
            MachineName = $env:COMPUTERNAME
        }
        
        # Save to file
        $credentialData | ConvertTo-Json | Out-File -FilePath $credFile -Encoding UTF8 -Force
        
        Write-Verbose "[OK] Credential saved securely: $credFile"
        return $true
    }
    catch {
        Write-Error "Failed to save credential: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Retrieves securely stored credentials
    
.DESCRIPTION
    Decrypts and retrieves credentials from secure storage. Can only decrypt
    credentials that were encrypted by the same user on the same machine.
    
.PARAMETER TargetName
    Unique identifier for the credential
    
.PARAMETER PromptIfNotFound
    If true, prompts user for credentials if not found in store
    
.EXAMPLE
    $cred = Get-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at"
    
.EXAMPLE
    $cred = Get-SecureCredential -TargetName "wsus" -PromptIfNotFound
    
.RETURNS
    PSCredential object or $null if not found
#>
function Get-SecureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$PromptIfNotFound,
        
        [Parameter(Mandatory = $false)]
        [string]$PromptMessage = "Enter credentials for $TargetName"
    )
    
    try {
        # Sanitize target name
        $safeName = $TargetName -replace '[\\/:*?"<>|]', '_'
        $credFile = Join-Path $Script:CredentialStorePath "$safeName.cred"
        
        if (-not (Test-Path $credFile)) {
            Write-Verbose "[INFO] No stored credential found for: $TargetName"
            
            if ($PromptIfNotFound) {
                Write-Host "[INFO] No stored credentials found for '$TargetName'" -ForegroundColor Yellow
                Write-Host "[INFO] Please enter credentials..." -ForegroundColor Cyan
                
                $cred = Get-Credential -Message $PromptMessage
                
                if ($cred) {
                    # Save for future use
                    $saved = Save-SecureCredential -Credential $cred -TargetName $TargetName
                    if ($saved) {
                        Write-Host "[OK] Credentials saved securely for future use" -ForegroundColor Green
                    }
                    return $cred
                }
            }
            
            return $null
        }
        
        # Load and decrypt
        $credentialData = Get-Content $credFile -Raw | ConvertFrom-Json
        
        # Decrypt password using DPAPI
        $securePassword = $credentialData.EncryptedPassword | ConvertTo-SecureString
        
        # Create PSCredential object
        $credential = New-Object System.Management.Automation.PSCredential(
            $credentialData.Username,
            $securePassword
        )
        
        Write-Verbose "[OK] Credential retrieved for: $TargetName"
        return $credential
    }
    catch {
        Write-Error "Failed to retrieve credential: $($_.Exception.Message)"
        
        if ($PromptIfNotFound) {
            Write-Host "[WARN] Failed to decrypt stored credential, requesting new credentials..." -ForegroundColor Yellow
            $cred = Get-Credential -Message $PromptMessage
            
            if ($cred) {
                $saved = Save-SecureCredential -Credential $cred -TargetName $TargetName
                if ($saved) {
                    Write-Host "[OK] New credentials saved" -ForegroundColor Green
                }
                return $cred
            }
        }
        
        return $null
    }
}

<#
.SYNOPSIS
    Removes stored credentials
    
.PARAMETER TargetName
    Unique identifier for the credential to remove
    
.EXAMPLE
    Remove-SecureCredential -TargetName "wsus.srv.meduniwien.ac.at"
    
.RETURNS
    $true if successful, $false otherwise
#>
function Remove-SecureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )
    
    try {
        $safeName = $TargetName -replace '[\\/:*?"<>|]', '_'
        $credFile = Join-Path $Script:CredentialStorePath "$safeName.cred"
        
        if (Test-Path $credFile) {
            Remove-Item $credFile -Force
            Write-Verbose "[OK] Credential removed: $TargetName"
            return $true
        }
        else {
            Write-Verbose "[INFO] No credential found to remove: $TargetName"
            return $false
        }
    }
    catch {
        Write-Error "Failed to remove credential: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Lists all stored credentials
    
.EXAMPLE
    Get-StoredCredentials
    
.RETURNS
    Array of credential information objects
#>
function Get-StoredCredentials {
    [CmdletBinding()]
    param()
    
    try {
        if (-not (Test-Path $Script:CredentialStorePath)) {
            Write-Verbose "[INFO] No credential store found"
            return @()
        }
        
        $credFiles = Get-ChildItem -Path $Script:CredentialStorePath -Filter "*.cred"
        
        $credentials = @()
        foreach ($file in $credFiles) {
            try {
                $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $credentials += [PSCustomObject]@{
                    TargetName = $data.TargetName
                    Username = $data.Username
                    CreatedDate = $data.CreatedDate
                    CreatedBy = $data.CreatedBy
                    MachineName = $data.MachineName
                    FilePath = $file.FullName
                }
            }
            catch {
                Write-Warning "Failed to read credential file: $($file.Name)"
            }
        }
        
        return $credentials
    }
    catch {
        Write-Error "Failed to list credentials: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
    Tests if a credential exists and is valid
    
.PARAMETER TargetName
    Unique identifier for the credential
    
.EXAMPLE
    if (Test-SecureCredential -TargetName "wsus") { ... }
    
.RETURNS
    $true if credential exists and can be decrypted, $false otherwise
#>
function Test-SecureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )
    
    try {
        $cred = Get-SecureCredential -TargetName $TargetName -ErrorAction SilentlyContinue
        return ($null -ne $cred)
    }
    catch {
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Save-SecureCredential',
    'Get-SecureCredential',
    'Remove-SecureCredential',
    'Get-StoredCredentials',
    'Test-SecureCredential'
)
