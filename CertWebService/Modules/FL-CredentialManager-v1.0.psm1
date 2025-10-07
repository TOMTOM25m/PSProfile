#requires -Version 5.1

<#
.SYNOPSIS
    FL Credential Manager v1.0.0

.DESCRIPTION
    Credential Management für Windows Credential Manager (PasswordVault)
    mit PowerShell 5.1 und 7.x Unterstützung.

.VERSION
    1.0.0

.RULEBOOK
    v10.0.2

.AUTHOR
    IT-Services

.NOTES
    Verwendet Windows Credential Manager für sichere Passwort-Speicherung.
#>

#region PowerShell Version Detection (MANDATORY - Regelwerk v10.0.2)
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS5 = $PSVersion.Major -eq 5
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1

Write-Verbose "FL-CredentialManager v1.0.0 | PowerShell: $($PSVersion.ToString())"
#endregion

#region Functions

function Save-StoredCredential {
    <#
    .SYNOPSIS
        Speichert Credentials im Windows Credential Manager
    
    .PARAMETER Target
        Target-Name (z.B. "ITSCMGMT03" oder "CertSurv-Admin")
    
    .PARAMETER Username
        Benutzername
    
    .PARAMETER Password
        Passwort (SecureString oder String)
    
    .PARAMETER Credential
        PSCredential Objekt
    
    .EXAMPLE
        Save-StoredCredential -Target "ITSCMGMT03" -Username "itscmgmt03\Administrator" -Password $securePass
    
    .EXAMPLE
        $cred = Get-Credential
        Save-StoredCredential -Target "ITSCMGMT03" -Credential $cred
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [object]$Password,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        # Wenn Credential-Objekt übergeben wurde
        if ($Credential) {
            $Username = $Credential.UserName
            $Password = $Credential.Password
        }
        
        # Passwort als SecureString sicherstellen
        if ($Password -is [string]) {
            $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        } elseif ($Password -is [System.Security.SecureString]) {
            $securePassword = $Password
        } else {
            throw "Password must be String or SecureString"
        }
        
        # Credential speichern mit cmdkey.exe (Windows Credential Manager)
        $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        )
        
        # cmdkey.exe zum Speichern verwenden
        $process = Start-Process -FilePath "cmdkey.exe" -ArgumentList "/generic:$Target /user:$Username /pass:$passwordPlain" -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Verbose "[OK] Credential saved: $Target ($Username)"
            return $true
        } else {
            Write-Warning "[ERROR] Failed to save credential: Exit Code $($process.ExitCode)"
            return $false
        }
        
    } catch {
        Write-Warning "[ERROR] Save-StoredCredential failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-StoredCredential {
    <#
    .SYNOPSIS
        Lädt Credentials aus Windows Credential Manager
    
    .PARAMETER Target
        Target-Name (z.B. "ITSCMGMT03")
    
    .PARAMETER Username
        Optional: Benutzername (falls mehrere für Target gespeichert)
    
    .EXAMPLE
        $cred = Get-StoredCredential -Target "ITSCMGMT03"
        if ($cred) {
            Invoke-Command -ComputerName Server01 -Credential $cred -ScriptBlock { whoami }
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [string]$Username
    )
    
    try {
        # cmdkey.exe zum Auslesen verwenden
        $output = & cmdkey.exe /list:$Target 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "[INFO] No credential found for: $Target"
            return $null
        }
        
        # Benutzername aus Output extrahieren
        $userLine = $output | Where-Object { $_ -match 'User:' } | Select-Object -First 1
        
        if ($userLine -match 'User:\s*(.+)$') {
            $storedUsername = $matches[1].Trim()
            
            # Wenn Username angegeben wurde, prüfen ob es übereinstimmt
            if ($Username -and $storedUsername -ne $Username) {
                Write-Verbose "[INFO] Username mismatch: Stored='$storedUsername', Requested='$Username'"
                return $null
            }
            
            # Passwort-Prompt mit gespeichertem Username
            Write-Verbose "[OK] Credential found: $Target ($storedUsername)"
            
            # Passwort aus Credential Manager über PowerShell-API holen
            try {
                # Windows.Security.Credentials.PasswordVault verwenden (Windows 10+)
                Add-Type -AssemblyName System.Runtime.WindowsRuntime
                
                $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
                    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
                })[0]
                
                function Await($WinRtTask, $ResultType) {
                    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
                    $netTask = $asTask.Invoke($null, @($WinRtTask))
                    $netTask.Wait(-1) | Out-Null
                    $netTask.Result
                }
                
                [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType=WindowsRuntime]
                $vault = New-Object Windows.Security.Credentials.PasswordVault
                
                $credential = $vault.Retrieve($Target, $storedUsername)
                $credential.RetrievePassword()
                
                $password = $credential.Password
                $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
                
                $psCredential = New-Object System.Management.Automation.PSCredential($storedUsername, $securePassword)
                
                return $psCredential
                
            } catch {
                Write-Verbose "[WARN] PasswordVault failed, falling back to manual entry: $($_.Exception.Message)"
                
                # Fallback: Benutzer nach Passwort fragen
                Write-Host "[INFO] Credential found but password retrieval failed" -ForegroundColor Yellow
                Write-Host "  Target: $Target" -ForegroundColor Gray
                Write-Host "  Username: $storedUsername" -ForegroundColor Gray
                Write-Host ""
                
                $cred = Get-Credential -UserName $storedUsername -Message "Enter password for $storedUsername @ $Target"
                return $cred
            }
            
        } else {
            Write-Verbose "[INFO] Could not parse username from cmdkey output"
            return $null
        }
        
    } catch {
        Write-Warning "[ERROR] Get-StoredCredential failed: $($_.Exception.Message)"
        return $null
    }
}

function Remove-StoredCredential {
    <#
    .SYNOPSIS
        Entfernt Credentials aus Windows Credential Manager
    
    .PARAMETER Target
        Target-Name (z.B. "ITSCMGMT03")
    
    .EXAMPLE
        Remove-StoredCredential -Target "ITSCMGMT03"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target
    )
    
    try {
        $process = Start-Process -FilePath "cmdkey.exe" -ArgumentList "/delete:$Target" -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Verbose "[OK] Credential removed: $Target"
            return $true
        } else {
            Write-Warning "[WARN] Failed to remove credential: Exit Code $($process.ExitCode)"
            return $false
        }
        
    } catch {
        Write-Warning "[ERROR] Remove-StoredCredential failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-OrPromptCredential {
    <#
    .SYNOPSIS
        Intelligente Credential-Beschaffung mit 3-Stufen-Strategie
    
    .DESCRIPTION
        1. Versucht Default-Admin-Passwort (aus Config/Environment)
        2. Prüft Passwort-Vault für spezifischen Server
        3. Fragt Benutzer und speichert für späteren Gebrauch
    
    .PARAMETER Target
        Target-Name (Server/Computer-Name)
    
    .PARAMETER Username
        Optional: Vorgeschlagener Username
    
    .PARAMETER Message
        Optional: Credential-Prompt Message
    
    .PARAMETER DefaultPassword
        Optional: Default-Passwort zum Testen
    
    .PARAMETER DefaultPasswordEnvVar
        Optional: Environment-Variable mit Default-Passwort
    
    .PARAMETER AutoSave
        Speichert neue Credentials automatisch (ohne Frage)
    
    .EXAMPLE
        $cred = Get-OrPromptCredential -Target "ITSCMGMT03" -Username "itscmgmt03\Administrator" -DefaultPasswordEnvVar "ADMIN_DEFAULT_PASSWORD" -AutoSave
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$DefaultPassword,
        
        [Parameter(Mandatory = $false)]
        [string]$DefaultPasswordEnvVar = "ADMIN_DEFAULT_PASSWORD",
        
        [Parameter(Mandatory = $false)]
        [switch]$AutoSave
    )
    
    Write-Verbose "[START] Get-OrPromptCredential for: $Target"
    
    # STUFE 1: Default-Admin-Passwort versuchen
    if (-not $DefaultPassword -and $DefaultPasswordEnvVar) {
        $DefaultPassword = [Environment]::GetEnvironmentVariable($DefaultPasswordEnvVar, 'User')
        
        if (-not $DefaultPassword) {
            $DefaultPassword = [Environment]::GetEnvironmentVariable($DefaultPasswordEnvVar, 'Machine')
        }
    }
    
    if ($DefaultPassword -and $Username) {
        Write-Verbose "[STUFE 1] Trying default admin password..."
        
        try {
            $securePassword = ConvertTo-SecureString -String $DefaultPassword -AsPlainText -Force
            $defaultCred = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
            
            # Test: Versuche kurzen Remote-Test (wenn Server erreichbar)
            Write-Verbose "[TEST] Testing default credential..."
            
            # Einfacher Test ohne Invoke-Command (nur Credential erstellt)
            Write-Verbose "[OK] Default credential created for testing"
            
            # Credential zurückgeben für Test durch Aufrufer
            return $defaultCred
            
        } catch {
            Write-Verbose "[STUFE 1] Default password failed: $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "[STUFE 1] No default password configured"
    }
    
    # STUFE 2: Passwort-Vault prüfen
    Write-Verbose "[STUFE 2] Checking password vault..."
    
    $cred = Get-StoredCredential -Target $Target -Username $Username
    
    if ($cred) {
        Write-Verbose "[OK] Using stored credential from vault for: $Target"
        Write-Host "[OK] Using stored credentials for $Target" -ForegroundColor Green
        return $cred
    }
    
    Write-Verbose "[STUFE 2] No credential found in vault"
    
    # STUFE 3: Benutzer fragen
    Write-Verbose "[STUFE 3] Prompting user for credentials..."
    
    Write-Host ""
    Write-Host "[INFO] No credential available for: $Target" -ForegroundColor Yellow
    Write-Host "  Tried: Default password, Password vault" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $Message) {
        $Message = "Enter Administrator credentials for $Target"
    }
    
    if (-not $Username) {
        $cred = Get-Credential -Message $Message
    } else {
        $cred = Get-Credential -UserName $Username -Message $Message
    }
    
    if (-not $cred) {
        Write-Warning "[ERROR] No credential provided"
        return $null
    }
    
    # Speichern für späteren Gebrauch
    $shouldSave = $false
    
    if ($AutoSave) {
        $shouldSave = $true
        Write-Host "[INFO] Auto-saving credential to vault..." -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] Save credential for future use? (Y/N)" -ForegroundColor Yellow -NoNewline
        $save = Read-Host " "
        $shouldSave = ($save -eq "Y" -or $save -eq "y")
    }
    
    if ($shouldSave) {
        $saved = Save-StoredCredential -Target $Target -Credential $cred
        
        if ($saved) {
            Write-Host "[OK] Credential saved to Windows Credential Manager" -ForegroundColor Green
            Write-Host "  Next time: Automatic load from vault" -ForegroundColor Gray
        } else {
            Write-Host "[WARN] Failed to save credential" -ForegroundColor Yellow
        }
    }
    
    return $cred
}

function Set-DefaultAdminPassword {
    <#
    .SYNOPSIS
        Setzt Default-Admin-Passwort als Environment-Variable
    
    .PARAMETER Password
        Passwort (SecureString oder String)
    
    .PARAMETER Scope
        User oder Machine (Standard: User)
    
    .EXAMPLE
        Set-DefaultAdminPassword -Password "YourDefaultPassword"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Password,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User'
    )
    
    try {
        # Passwort als String sicherstellen
        if ($Password -is [System.Security.SecureString]) {
            $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            )
        } else {
            $passwordPlain = $Password
        }
        
        # Als Environment-Variable speichern
        [Environment]::SetEnvironmentVariable('ADMIN_DEFAULT_PASSWORD', $passwordPlain, $Scope)
        
        Write-Host "[OK] Default admin password saved (Scope: $Scope)" -ForegroundColor Green
        Write-Host "  Environment Variable: ADMIN_DEFAULT_PASSWORD" -ForegroundColor Gray
        Write-Host "  Note: This will be tried first for all admin credentials" -ForegroundColor Yellow
        
        return $true
        
    } catch {
        Write-Warning "[ERROR] Failed to set default password: $($_.Exception.Message)"
        return $false
    }
}

function Remove-DefaultAdminPassword {
    <#
    .SYNOPSIS
        Entfernt Default-Admin-Passwort
    
    .PARAMETER Scope
        User oder Machine (Standard: User)
    
    .EXAMPLE
        Remove-DefaultAdminPassword
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User'
    )
    
    try {
        [Environment]::SetEnvironmentVariable('ADMIN_DEFAULT_PASSWORD', $null, $Scope)
        Write-Host "[OK] Default admin password removed (Scope: $Scope)" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "[ERROR] Failed to remove default password: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Export
Export-ModuleMember -Function @(
    'Save-StoredCredential',
    'Get-StoredCredential',
    'Remove-StoredCredential',
    'Get-OrPromptCredential',
    'Set-DefaultAdminPassword',
    'Remove-DefaultAdminPassword'
)
#endregion
