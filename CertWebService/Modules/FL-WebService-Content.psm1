#requires -Version 5.1

<#
.SYNOPSIS
    FL-WebService-Content Module - Content Generation for Web Services
.DESCRIPTION
    Provides functions for generating HTML and JSON content for web services.
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
    Updates the web service with current certificate data.
.DESCRIPTION
    Regenerates the HTML and JSON files for the certificate web service.
    Compliant with Regelwerk v10.0.0 §7.
.PARAMETER SitePath
    Physical path of the IIS website.
.PARAMETER CertificateData
    The certificate data to be published.
.PARAMETER LogFunction
    A scriptblock for a logging function that conforms to Regelwerk v10.0.0 §5.
.EXAMPLE
    Update-WebServiceContent -SitePath "C:\inetpub\wwwroot\certs" -CertificateData $certData -LogFunction $LogBlock
#>
function Update-WebServiceContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CertificateData,

        [Parameter(Mandatory = $true)]
        [scriptblock]$LogFunction
    )
    
    begin {
        $Logger = { param($Message, $Level = 'INFO') & $LogFunction -Message $Message -Level $Level }
    }

    process {
        try {
            . $Logger "Updating certificate web service content."
            
            $jsonPath = Join-Path $SitePath "api\certificates.json"
            $apiDir = Split-Path $jsonPath -Parent
            if (-not (Test-Path $apiDir)) {
                New-Item -Path $apiDir -ItemType Directory -Force | Out-Null
            }
            
            $CertificateData | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
            
            $htmlContent = @"
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <title>Certificate Surveillance - $($env:COMPUTERNAME)</title>
</head>
<body>
    <h1>Certificate Surveillance Dashboard</h1>
    <p>Server: <strong>$($env:COMPUTERNAME)</strong> | Generated: <strong>$($CertificateData.GeneratedAt)</strong></p>
    <p>Total Certificates: <strong>$($CertificateData.CertificateCount)</strong></p>
    <table>
        <thead>
            <tr>
                <th>Subject</th>
                <th>Days Remaining</th>
                <th>Expires</th>
                <th>Issuer</th>
            </tr>
        </thead>
        <tbody>
"@
            foreach ($cert in ($CertificateData.Certificates | Sort-Object DaysRemaining)) {
                $htmlContent += @"
                <tr>
                    <td>$($cert.Subject)</td>
                    <td>$($cert.DaysRemaining)</td>
                    <td>$($cert.NotAfter)</td>
                    <td>$($cert.Issuer)</td>
                </tr>
"@
            }
            $htmlContent += "</tbody></table></body></html>"
            
            $htmlPath = Join-Path $SitePath "index.html"
            $htmlContent | Set-Content -Path $htmlPath -Encoding UTF8
            
            . $Logger "Web service content updated successfully."
        }
        catch {
            . $Logger "Failed to update web service content: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function 'Update-WebServiceContent'
