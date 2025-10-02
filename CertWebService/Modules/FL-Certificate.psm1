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
    v1.1.0
.RULEBOOK
    v10.0.2
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

<#
.SYNOPSIS
    Generates PowerShell-optimized certificate data in JSON format.
.DESCRIPTION
    Extracts certificate information and formats it in a PowerShell-friendly JSON structure
    with PascalCase properties, ISO 8601 dates, and enhanced metadata.
    Compliant with Regelwerk v10.0.0 §7.
.PARAMETER LogFunction
    A scriptblock for a logging function that conforms to Regelwerk v10.0.0 §5.
.EXAMPLE
    $certData = Get-PowerShellCertificateData -LogFunction $LogBlock
#>
function Get-PowerShellCertificateData {
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
            . $Logger "Extracting PowerShell-optimized certificate data for web service."
            
            # Get all certificates from all stores
            $allStores = @('My', 'Root', 'CA', 'AuthRoot', 'TrustedPeople', 'TrustedPublisher')
            $allCertificates = @()
            
            foreach ($storeName in $allStores) {
                try {
                    $storePath = "Cert:\LocalMachine\$storeName"
                    if (Test-Path $storePath) {
                        $storeCerts = Get-ChildItem -Path $storePath | Where-Object { -not $_.PSIsContainer }
                        foreach ($cert in $storeCerts) {
                            $allCertificates += [PSCustomObject]@{
                                Certificate = $cert
                                StoreName = $storeName
                            }
                        }
                    }
                } catch {
                    . $Logger "Warning: Could not access store $storeName - $($_.Exception.Message)" "WARN"
                }
            }
            
            . $Logger "Found $($allCertificates.Count) total certificates across all stores."
            
            # Process certificates with enhanced data
            $certificateData = foreach ($certObj in $allCertificates) {
                $cert = $certObj.Certificate
                $daysUntilExpiry = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                
                # Determine priority based on expiry
                $priority = if ($daysUntilExpiry -lt 0) { "EXPIRED" }
                           elseif ($daysUntilExpiry -le 7) { "URGENT" }
                           elseif ($daysUntilExpiry -le 30) { "WARNING" }
                           else { "OK" }
                
                # Get key algorithm info
                $keyAlgorithm = "Unknown"
                $keySize = 0
                $signatureAlgorithm = "Unknown"
                
                try {
                    if ($cert.PublicKey.Oid.FriendlyName) {
                        $keyAlgorithm = $cert.PublicKey.Oid.FriendlyName
                    }
                    if ($cert.PublicKey.Key.KeySize) {
                        $keySize = $cert.PublicKey.Key.KeySize
                    }
                    if ($cert.SignatureAlgorithm.FriendlyName) {
                        $signatureAlgorithm = $cert.SignatureAlgorithm.FriendlyName
                    }
                } catch {
                    # Ignore errors when accessing key properties
                }
                
                @{
                    Store = $certObj.StoreName
                    Subject = $cert.Subject
                    Issuer = $cert.Issuer
                    ExpiryDate = $cert.NotAfter.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    IssuedDate = $cert.NotBefore.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    DaysUntilExpiry = $daysUntilExpiry
                    Priority = $priority
                    Status = if ($cert.NotAfter -gt (Get-Date)) { "Valid" } else { "Expired" }
                    Serial = $cert.SerialNumber
                    Thumbprint = $cert.Thumbprint
                    KeyAlgorithm = $keyAlgorithm
                    KeySize = $keySize
                    SignatureAlgorithm = $signatureAlgorithm
                    HasPrivateKey = $cert.HasPrivateKey
                    IsSelfSigned = ($cert.Subject -eq $cert.Issuer)
                }
            }
            
            # Calculate statistics
            $stats = @{
                Valid = ($certificateData | Where-Object { $_.Status -eq "Valid" }).Count
                Expired = ($certificateData | Where-Object { $_.Priority -eq "EXPIRED" }).Count
                Urgent = ($certificateData | Where-Object { $_.Priority -eq "URGENT" }).Count
                Warning = ($certificateData | Where-Object { $_.Priority -eq "WARNING" }).Count
                OK = ($certificateData | Where-Object { $_.Priority -eq "OK" }).Count
                SelfSigned = ($certificateData | Where-Object { $_.IsSelfSigned -eq $true }).Count
                WithPrivateKey = ($certificateData | Where-Object { $_.HasPrivateKey -eq $true }).Count
            }
            
            $result = @{
                Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                Server = $env:COMPUTERNAME
                ApiVersion = "2.4.0-PowerShell"
                ScanVersion = "v2.4.0-PowerShell"
                TotalCount = $certificateData.Count
                Statistics = $stats
                Certificates = $certificateData
                Metadata = @{
                    PowerShellOptimized = $true
                    GeneratedBy = "CertWebService PowerShell Module"
                    FormatVersion = "1.0"
                    Description = "PowerShell-optimized certificate data with PascalCase properties and ISO 8601 dates"
                }
            }
            
            . $Logger "PowerShell certificate data extraction completed. Found $($certificateData.Count) certificates."
            . $Logger "Statistics: Valid=$($stats.Valid), Expired=$($stats.Expired), Urgent=$($stats.Urgent), Warning=$($stats.Warning), OK=$($stats.OK)"
            
            return $result
        }
        catch {
            . $Logger "Failed to extract PowerShell certificate data: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function 'New-WebServiceCertificate', 'Get-CertificateWebData', 'Get-PowerShellCertificateData'
