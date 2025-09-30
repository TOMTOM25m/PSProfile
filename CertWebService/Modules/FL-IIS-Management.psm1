#requires -Version 5.1

<#
.SYNOPSIS
    FL-IIS-Management Module - IIS Management for Web Services
.DESCRIPTION
    Provides functions for setting up and managing IIS websites and bindings.
    Compliant with Regelwerk v10.0.0.
.AUTHOR
    Flecki (Tom) Garnreiter
.VERSION
    v1.0.0
.RULEBOOK
    v10.0.0
#>

#----------------------------------------------------------[Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Sets up an IIS web service.
.DESCRIPTION
    Creates and configures an IIS website with HTTPS binding.
    Compliant with Regelwerk v10.0.0 §7 and §11.
.PARAMETER SiteName
    Name of the IIS website to create.
.PARAMETER SitePath
    Physical path for the website files.
.PARAMETER HttpPort
    HTTP port for the website.
.PARAMETER HttpsPort
    HTTPS port for the website.
.PARAMETER CertificateThumbprint
    SSL certificate thumbprint for HTTPS binding.
.PARAMETER LogFunction
    A scriptblock for a logging function that conforms to Regelwerk v10.0.0 §5.
.EXAMPLE
    Install-IISWebService -SiteName "CertSurveillance" -SitePath "C:\inetpub\wwwroot\certs" -HttpPort 8080 -HttpsPort 8443 -CertificateThumbprint "thumbprint" -LogFunction $LogBlock
#>
function Install-IISWebService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        
        [Parameter(Mandatory = $true)]
        [int]$HttpPort,

        [Parameter(Mandatory = $true)]
        [int]$HttpsPort,
        
        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory = $true)]
        [scriptblock]$LogFunction
    )
    
    begin {
        $Logger = { param($Message, $Level = 'INFO') & $LogFunction -Message $Message -Level $Level }
    }

    process {
        try {
            . $Logger "Starting IIS web service installation for $SiteName."
            
            Import-Module WebAdministration -Force

            if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
                . $Logger "Removing existing website: $SiteName"
                Remove-Website -Name $SiteName
            }
            
            . $Logger "Creating IIS website: $SiteName on HTTP port $HttpPort."
            New-Website -Name $SiteName -Port $HttpPort -PhysicalPath $SitePath | Out-Null
            
            . $Logger "Adding HTTPS binding on port $HttpsPort."
            New-WebBinding -Name $SiteName -Protocol https -Port $HttpsPort -SslFlags 0

            . $Logger "Binding SSL certificate using netsh."
            & netsh http delete sslcert ipport=0.0.0.0:$HttpsPort 2>$null
            $netshCmd = "http add sslcert ipport=0.0.0.0:$HttpsPort certhash=$CertificateThumbprint appid=`"{12345678-db90-4b66-8b01-88f7af2e36bf}`""
            & netsh $netshCmd.Split(' ')

            if ($LASTEXITCODE -ne 0) {
                . $Logger "NetSH SSL binding failed with exit code $LASTEXITCODE" -Level 'WARNING'
            }

            . $Logger "IIS web service installation completed successfully."
        }
        catch {
            . $Logger "Failed to install IIS web service: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function 'Install-IISWebService'
