#requires -Version 5.1

<#
.SYNOPSIS
    FL-Config Module - Configuration management for Certificate Web Service
.DESCRIPTION
    Provides functions for loading and managing JSON configuration files
    for the Certificate Web Service installation and operation.
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

$ModuleName = "FL-Config"
$ModuleVersion = "v1.0.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

Function Get-ScriptConfiguration {
    <#
    .SYNOPSIS
        Loads script configuration and localization for Certificate Web Service
    .DESCRIPTION
        Reads the JSON configuration file and language settings for the
        Certificate Web Service installation and operation.
    .PARAMETER ScriptDirectory
        The root directory of the script containing the Config folder
    .EXAMPLE
        $config = Get-ScriptConfiguration -ScriptDirectory "C:\Scripts\CertWebService"
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptDirectory
    )

    $configPath = Join-Path -Path $ScriptDirectory -ChildPath "Config"
    $configFile = Join-Path -Path $configPath -ChildPath "Config-CertWebService.json"

    if (-not (Test-Path $configFile)) {
        Write-Warning "Configuration file not found at '$configFile', using defaults"
        
        # Return default configuration if file doesn't exist
        return @{
            Config = @{
                Language = "en-US"
                WebService = @{
                    SiteName = "CertificateSurveillance"
                    SitePath = "C:\inetpub\wwwroot\CertificateSurveillance"
                    HttpPort = 8080
                    HttpsPort = 8443
                    SubjectName = $env:COMPUTERNAME
                }
                Certificate = @{
                    ValidityDays = 365
                    FilterMicrosoft = $true
                    FilterRootCerts = $true
                    FilterTestCerts = $true
                }
                Logging = @{
                    LogLevel = "INFO"
                    EnableEventLog = $true
                }
            }
            Localization = @{
                InstallationStarted = "Certificate Web Service installation started"
                InstallationCompleted = "Installation completed successfully"
                CertificateCreated = "Self-signed certificate created"
                WebServiceInstalled = "IIS web service installed"
                ContentUpdated = "Certificate content updated"
            }
        }
    }

    try {
        $config = Get-Content -Path $configFile | ConvertFrom-Json
        
        # Load language file if it exists
        $langFile = Join-Path -Path $configPath -ChildPath "$($config.Language).json"
        $localization = @{}
        
        if (Test-Path $langFile) {
            $localization = Get-Content -Path $langFile | ConvertFrom-Json
        }
        else {
            Write-Warning "Language file not found for '$($config.Language)' at '$langFile'"
        }

        return @{
            Config = $config
            Localization = $localization
        }
    }
    catch {
        throw "Failed to load configuration: $($_.Exception.Message)"
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function Get-ScriptConfiguration

Write-Verbose "FL-Config module v$ModuleVersion loaded successfully"

# --- End of module --- v1.0.0 ; Regelwerk: v9.3.0 ---