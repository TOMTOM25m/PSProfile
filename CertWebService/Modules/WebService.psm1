# Core Web Service Functions for Certificate Web Service (Regelwerk v9.6.2)
# Provides main functionality for certificate processing and web service management
# Compatible with PowerShell 5.1 and 7.x

function Get-CertificateStoreData {
    param(
        [array]$StoreNames = @('My', 'Root', 'CA', 'Trust'),
        [hashtable]$Filters = @{}
    )
    
    $certificates = @()
    
    foreach ($storeName in $StoreNames) {
        try {
            Write-Verbose "Processing certificate store: $storeName"
            $store = Get-ChildItem -Path "Cert:\LocalMachine\$storeName" -ErrorAction SilentlyContinue
            
            foreach ($cert in $store) {
                # Apply filters
                $includeCert = $true
                
                if ($Filters.FilterMicrosoft -and ($cert.Subject -match "Microsoft|Windows" -or $cert.Issuer -match "Microsoft")) {
                    $includeCert = $false
                }
                
                if ($Filters.FilterRootCerts -and $storeName -eq "Root") {
                    $includeCert = $false
                }
                
                if ($includeCert) {
                    $daysRemaining = ($cert.NotAfter - (Get-Date)).Days
                    
                    $certInfo = [PSCustomObject]@{
                        Subject = $cert.Subject
                        Issuer = $cert.Issuer
                        NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss')
                        NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
                        DaysRemaining = $daysRemaining
                        Thumbprint = $cert.Thumbprint
                        Store = $storeName
                        HasPrivateKey = $cert.HasPrivateKey
                        KeyLength = $cert.PublicKey.Key.KeySize
                        Status = if ($daysRemaining -le 0) { "Expired" } elseif ($daysRemaining -le 30) { "Expiring" } else { "Valid" }
                        StatusClass = if ($daysRemaining -le 0) { "danger" } elseif ($daysRemaining -le 30) { "warning" } else { "success" }
                    }
                    
                    $certificates += $certInfo
                }
            }
        } catch {
            Write-Warning "Error accessing certificate store $storeName: $($_.Exception.Message)"
        }
    }
    
    Write-Verbose "Retrieved $($certificates.Count) certificates"
    return $certificates
}

function New-WebServiceSummary {
    param([array]$Certificates)
    
    $summary = @{
        Total = $Certificates.Count
        Valid = ($Certificates | Where-Object { $_.Status -eq "Valid" }).Count
        Expiring = ($Certificates | Where-Object { $_.Status -eq "Expiring" }).Count
        Expired = ($Certificates | Where-Object { $_.Status -eq "Expired" }).Count
        LastUpdate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Server = $env:COMPUTERNAME
    }
    
    # Add percentage calculations
    if ($summary.Total -gt 0) {
        $summary.ValidPercent = [math]::Round(($summary.Valid / $summary.Total) * 100, 1)
        $summary.ExpiringPercent = [math]::Round(($summary.Expiring / $summary.Total) * 100, 1)
        $summary.ExpiredPercent = [math]::Round(($summary.Expired / $summary.Total) * 100, 1)
    } else {
        $summary.ValidPercent = 0
        $summary.ExpiringPercent = 0  
        $summary.ExpiredPercent = 0
    }
    
    return $summary
}

function Test-WebServiceHealth {
    param(
        [string]$SiteName,
        [int]$HttpPort = 8080,
        [int]$HttpsPort = 8443
    )
    
    $health = @{
        IISStatus = "Unknown"
        HttpAccessible = $false
        HttpsAccessible = $false
        OverallStatus = "Unknown"
        LastCheck = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    
    try {
        # Check IIS site status
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
        
        if ($site) {
            $health.IISStatus = $site.State
        } else {
            $health.IISStatus = "NotFound"
        }
        
        # Test HTTP connectivity
        try {
            $httpResponse = Invoke-WebRequest -Uri "http://localhost:$HttpPort" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $health.HttpAccessible = ($httpResponse.StatusCode -eq 200)
        } catch {
            $health.HttpAccessible = $false
        }
        
        # Test HTTPS connectivity
        try {
            $httpsResponse = Invoke-WebRequest -Uri "https://localhost:$HttpsPort" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $health.HttpsAccessible = ($httpsResponse.StatusCode -eq 200)
        } catch {
            $health.HttpsAccessible = $false
        }
        
        # Determine overall status
        if ($health.IISStatus -eq "Started" -and ($health.HttpAccessible -or $health.HttpsAccessible)) {
            $health.OverallStatus = "Healthy"
        } elseif ($health.IISStatus -eq "Started") {
            $health.OverallStatus = "Warning"
        } else {
            $health.OverallStatus = "Critical"
        }
        
    } catch {
        $health.OverallStatus = "Error"
        Write-Warning "Health check failed: $($_.Exception.Message)"
    }
    
    return $health
}

function Export-CertificateData {
    param(
        [array]$Certificates,
        [string]$OutputPath,
        [string]$Format = "JSON"
    )
    
    switch ($Format.ToUpper()) {
        "JSON" {
            $data = @{
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Server = $env:COMPUTERNAME
                CertificateCount = $Certificates.Count
                Certificates = $Certificates
                Summary = New-WebServiceSummary -Certificates $Certificates
            }
            
            $data | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8
        }
        "CSV" {
            $Certificates | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        }
        "XML" {
            $Certificates | Export-Clixml -Path $OutputPath -Encoding UTF8
        }
        default {
            throw "Unsupported export format: $Format"
        }
    }
    
    Write-Verbose "Certificate data exported to: $OutputPath ($Format)"
}

function Start-CertificateWebService {
    param(
        [string]$SiteName,
        [int]$TimeoutSeconds = 30
    )
    
    try {
        Import-Module WebAdministration -Force
        
        $site = Get-Website -Name $SiteName -ErrorAction Stop
        
        if ($site.State -ne "Started") {
            Start-Website -Name $SiteName
            
            # Wait for startup
            $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
            while ((Get-Date) -lt $timeout) {
                $site = Get-Website -Name $SiteName
                if ($site.State -eq "Started") {
                    Write-Verbose "Website '$SiteName' started successfully"
                    return $true
                }
                Start-Sleep -Seconds 2
            }
            
            Write-Warning "Website '$SiteName' failed to start within $TimeoutSeconds seconds"
            return $false
        } else {
            Write-Verbose "Website '$SiteName' is already running"
            return $true
        }
    } catch {
        Write-Error "Failed to start website '$SiteName': $_"
        return $false
    }
}

function Stop-CertificateWebService {
    param([string]$SiteName)
    
    try {
        Import-Module WebAdministration -Force
        
        $site = Get-Website -Name $SiteName -ErrorAction Stop
        
        if ($site.State -eq "Started") {
            Stop-Website -Name $SiteName
            Write-Verbose "Website '$SiteName' stopped successfully"
            return $true
        } else {
            Write-Verbose "Website '$SiteName' is not running"
            return $true
        }
    } catch {
        Write-Error "Failed to stop website '$SiteName': $_"
        return $false
    }
}

Export-ModuleMember -Function Get-CertificateStoreData, New-WebServiceSummary, Test-WebServiceHealth, Export-CertificateData, Start-CertificateWebService, Stop-CertificateWebService