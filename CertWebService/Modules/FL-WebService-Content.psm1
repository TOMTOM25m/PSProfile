#requires -Version 5.1

<#
.SYNOPSIS
    FL-WebService-Content Module - Content Generation for Web Services
.DESCRIPTION
    Provides functions for generating HTML an<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>[CERT] Certificate Surveillance - $($PowerShellCertificateData.Server)</title>   <title>[CERT] Certificate Surveillance - $($PowerShellCertificateData.Server)</title> content for web services.
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
            
            # Alle JSON-Endpunkte sind jetzt PowerShell-optimiert
            $powerShellData = Get-PowerShellCertificateData -CertificateData $CertificateData.Certificates
            $powerShellData | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding UTF8
            
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

<#
.SYNOPSIS
    Updates the web service with PowerShell-optimized certificate data.
.DESCRIPTION
    Generates both traditional and PowerShell-optimized JSON endpoints for certificate data.
    Creates /api/certificates.json (traditional) and /api/certificates-ps.json (PowerShell-optimized).
    Compliant with Regelwerk v10.0.0 §7.
.PARAMETER SitePath
    Physical path of the IIS website.
.PARAMETER CertificateData
    The traditional certificate data.
.PARAMETER PowerShellCertificateData
    The PowerShell-optimized certificate data.
.PARAMETER LogFunction
    A scriptblock for a logging function that conforms to Regelwerk v10.0.0 §5.
.EXAMPLE
    Update-PowerShellWebServiceContent -SitePath "C:\inetpub\wwwroot\certs" -CertificateData $certData -PowerShellCertificateData $psCertData -LogFunction $LogBlock
#>
function Update-PowerShellWebServiceContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CertificateData,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$PowerShellCertificateData,

        [Parameter(Mandatory = $true)]
        [scriptblock]$LogFunction
    )
    
    begin {
        $Logger = { param($Message, $Level = 'INFO') & $LogFunction -Message $Message -Level $Level }
    }

    process {
        try {
            . $Logger "Updating PowerShell-optimized certificate web service content."
            
            # Ensure API directory exists
            $apiDir = Join-Path $SitePath "api"
            if (-not (Test-Path $apiDir)) {
                New-Item -Path $apiDir -ItemType Directory -Force | Out-Null
            }
            
            # Alle JSON-Endpunkte verwenden PowerShell-optimiertes Format
            $jsonPath = Join-Path $apiDir "certificates.json"
            [System.IO.File]::WriteAllText($jsonPath, ($PowerShellCertificateData | ConvertTo-Json -Depth 4 -Compress:$false), [System.Text.Encoding]::UTF8)
            . $Logger "Updated PowerShell-optimized certificates.json endpoint."
            
            # PowerShell-optimized JSON endpoint (NEW!)
            $psJsonPath = Join-Path $apiDir "certificates-ps.json"
            # Use clean JSON conversion without BOM
            $jsonContent = $PowerShellCertificateData | ConvertTo-Json -Depth 4 -Compress:$false
            [System.IO.File]::WriteAllText($psJsonPath, $jsonContent, [System.Text.Encoding]::UTF8)
            . $Logger "Updated PowerShell-optimized certificates-ps.json endpoint."
            
            # Enhanced HTML dashboard
            $htmlContent = @"
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate Surveillance - $($PowerShellCertificateData.Server)</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        .stats { display: flex; gap: 15px; margin: 20px 0; flex-wrap: wrap; }
        .stat-card { background: #ecf0f1; padding: 15px; border-radius: 6px; text-align: center; min-width: 120px; }
        .stat-number { font-size: 24px; font-weight: bold; color: #2980b9; }
        .stat-label { font-size: 12px; color: #7f8c8d; text-transform: uppercase; }
        .urgent { background-color: #e74c3c; color: white; }
        .warning { background-color: #f39c12; color: white; }
        .ok { background-color: #27ae60; color: white; }
        .expired { background-color: #c0392b; color: white; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #34495e; color: white; }
        tr:hover { background-color: #f8f9fa; }
        .priority-urgent { color: #e74c3c; font-weight: bold; }
        .priority-warning { color: #f39c12; font-weight: bold; }
        .priority-ok { color: #27ae60; }
        .priority-expired { color: #c0392b; font-weight: bold; }
        .api-links { margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-radius: 6px; }
        .api-link { display: inline-block; margin: 5px 10px 5px 0; padding: 8px 12px; background-color: #3498db; color: white; text-decoration: none; border-radius: 4px; font-size: 14px; }
        .api-link:hover { background-color: #2980b9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>[CERT] Certificate Surveillance Dashboard</h1>
        
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
            <div>
                <strong>Server:</strong> $($PowerShellCertificateData.Server)<br>
                <strong>Generated:</strong> $($PowerShellCertificateData.Timestamp)<br>
                <strong>API Version:</strong> $($PowerShellCertificateData.ApiVersion)
            </div>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number">$($PowerShellCertificateData.TotalCount)</div>
                <div class="stat-label">Total Certificates</div>
            </div>
            <div class="stat-card ok">
                <div class="stat-number">$($PowerShellCertificateData.Statistics.OK)</div>
                <div class="stat-label">OK</div>
            </div>
            <div class="stat-card warning">
                <div class="stat-number">$($PowerShellCertificateData.Statistics.Warning)</div>
                <div class="stat-label">Warning</div>
            </div>
            <div class="stat-card urgent">
                <div class="stat-number">$($PowerShellCertificateData.Statistics.Urgent)</div>
                <div class="stat-label">Urgent</div>
            </div>
            <div class="stat-card expired">
                <div class="stat-number">$($PowerShellCertificateData.Statistics.Expired)</div>
                <div class="stat-label">Expired</div>
            </div>
        </div>
        
        <div class="api-links">
            <strong>[API] API Endpoints:</strong><br>
            <a href="/api/certificates.json" class="api-link">Traditional JSON</a>
            <a href="/api/certificates-ps.json" class="api-link">PowerShell-Optimized JSON</a>
            <a href="/health.json" class="api-link">Health Check</a>
        </div>
        
        <table>
            <thead>
                <tr>
                    <th>Subject</th>
                    <th>Priority</th>
                    <th>Days Until Expiry</th>
                    <th>Expires</th>
                    <th>Store</th>
                    <th>Key Algorithm</th>
                </tr>
            </thead>
            <tbody>
"@
            
            # Sort certificates by priority (most critical first)
            $sortedCerts = $PowerShellCertificateData.Certificates | Sort-Object @{
                Expression = { 
                    switch ($_.Priority) {
                        'EXPIRED' { 0 }
                        'URGENT' { 1 }
                        'WARNING' { 2 }
                        'OK' { 3 }
                        default { 4 }
                    }
                }
            }, DaysUntilExpiry
            
            foreach ($cert in $sortedCerts) {
                $priorityClass = "priority-" + $cert.Priority.ToLower()
                $expiryDate = [DateTime]::Parse($cert.ExpiryDate).ToString('yyyy-MM-dd')
                $keyInfo = if ($cert.KeySize -gt 0) { "$($cert.KeyAlgorithm) $($cert.KeySize)" } else { $cert.KeyAlgorithm }
                
                $htmlContent += @"
                <tr>
                    <td>$($cert.Subject)</td>
                    <td class="$priorityClass">$($cert.Priority)</td>
                    <td class="$priorityClass">$($cert.DaysUntilExpiry)</td>
                    <td>$expiryDate</td>
                    <td>$($cert.Store)</td>
                    <td>$keyInfo</td>
                </tr>
"@
            }
            
            $htmlContent += @"
            </tbody>
        </table>
        
        <div style="margin-top: 30px; text-align: center; color: #7f8c8d; font-size: 12px;">
            CertWebService v$($PowerShellCertificateData.ApiVersion) | PowerShell-Optimized Certificate Surveillance (Regelwerk v10.0.2)
        </div>
    </div>
</body>
</html>
"@
            
            $htmlPath = Join-Path $SitePath "index.html"
            $htmlContent | Set-Content -Path $htmlPath -Encoding UTF8
            
            . $Logger "PowerShell-optimized web service content updated successfully."
            . $Logger "Available endpoints: /api/certificates.json (traditional), /api/certificates-ps.json (PowerShell-optimized)"
        }
        catch {
            . $Logger "Failed to update PowerShell web service content: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}

#----------------------------------------------------------[Module Exports]--------------------------------------------------------

Export-ModuleMember -Function 'Update-WebServiceContent', 'Update-PowerShellWebServiceContent'

Export-ModuleMember -Function 'Update-WebServiceContent'
