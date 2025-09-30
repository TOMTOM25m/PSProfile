#requires -Version 5.1

<#
.SYNOPSIS
    FL-Certificate Module - Certificate Management for Web Services
.DESCRIPTION
    Provides functions for creating and retrieving certificate data for web services.
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
    Creates a new self-signed certificate for HTTPS binding.
.DESCRIPTION
    Generates a self-signed SSL certificate with specified subject name and validity period
    for use with IIS HTTPS bindings. Compliant with Regelwerk v10.0.0 §14.
.PARAMETER SubjectName
    The subject name for the certificate (e.g., "localhost", "servername.domain.com").
.PARAMETER ValidityDays
    Number of days the certificate should be valid (default: 365).
.PARAMETER LogFunction
    A scriptblock for a logging function that conforms to Regelwerk v10.0.0 §5.
.EXAMPLE
    New-WebServiceCertificate -SubjectName "localhost" -ValidityDays 365 -LogFunction $LogBlock
#>
function New-WebServiceCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubjectName,
        
        [Parameter(Mandatory = $false)]
        [int]$ValidityDays = 365,

        [Parameter(Mandatory = $true)]
        [scriptblock]$LogFunction
    )
    
    begin {
        # Helper to invoke the provided logging function
        $Logger = { param($Message, $Level = 'INFO') & $LogFunction -Message $Message -Level $Level }
    }

    process {
        try {
            . $Logger "Creating self-signed certificate for subject: $SubjectName"

            $cert = New-SelfSignedCertificate -DnsName $SubjectName -CertStoreLocation "Cert:\LocalMachine\My" -NotAfter (Get-Date).AddDays($ValidityDays) -KeyUsage KeyEncipherment,DigitalSignature -KeyAlgorithm RSA -KeyLength 2048
            
            if (-not $cert) {
                throw "Certificate creation failed - no certificate object returned."
            }
            
            . $Logger "Self-signed certificate created successfully. Thumbprint: $($cert.Thumbprint)"

            return $cert
        }
        catch {
            . $Logger "Failed to create self-signed certificate: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}

<#
.SYNOPSIS
    Generates certificate data in JSON format for web service consumption.
.DESCRIPTION
    Extracts certificate information from the local machine certificate store and formats the data as JSON.
    Compliant with Regelwerk v10.0.0 §7.
.PARAMETER LogFunction
    A scriptblock for a logging function that conforms to Regelwerk v10.0.0 §5.
.EXAMPLE
    $certData = Get-CertificateWebData -LogFunction $LogBlock
#>
function Get-CertificateWebData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$LogFunction
    )
    
    begin {
        $Logger = { param($Message, $Level = 'INFO') & $LogFunction -Message $Message -Level $Level }
    }

    process {
        try {
            . $Logger "Extracting certificate data for web service."
            
            $certificates = Get-ChildItem -Path Cert:\LocalMachine\ -Recurse | Where-Object {
                (-not $_.PSIsContainer) -and
                ($_.Issuer -notlike 'CN=Microsoft*') -and
                ($_.Issuer -ne $_.Subject) -and
                ($_.NotAfter -gt (Get-Date))
            }
            
            $certificateData = foreach ($cert in $certificates) {
                @{
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
                    NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
                    DaysRemaining = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                    Thumbprint = $cert.Thumbprint
                    Store = $cert.PSParentPath -replace '.*\\', ''
                    HasPrivateKey = $cert.HasPrivateKey
                }
            }
            
            $result = @{
                GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                ServerName = $env:COMPUTERNAME
                CertificateCount = $certificateData.Count
                Certificates = $certificateData
            }
            
            . $Logger "Certificate data extraction completed. Found $($certificateData.Count) certificates."
            
            return $result
        }
        catch {
            . $Logger "Failed to extract certificate data: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function 'New-WebServiceCertificate', 'Get-CertificateWebData'
