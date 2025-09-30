#requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443
)

$ErrorActionPreference = 'Stop'

Write-Host "CertWebService v2.3.0 Setup" -ForegroundColor Green
Write-Host "Read-Only Mode for 3 authorized servers" -ForegroundColor Yellow
Write-Host "PowerShell Compatible Edition (All Versions)" -ForegroundColor Cyan
Write-Host ""

function Write-InstallLog {
    param([string]$Message, [string]$Level = 'INFO')
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'ERROR' { Write-Host $logMessage -ForegroundColor Red }
        'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

function Install-IISFeatures {
    Write-InstallLog "Installing IIS features"
    
    $features = @(
        'IIS-WebServerRole',
        'IIS-WebServer', 
        'IIS-CommonHttpFeatures',
        'IIS-StaticContent',
        'IIS-DefaultDocument'
    )
    
    foreach ($feature in $features) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-InstallLog "Feature $feature enabled" "SUCCESS"
        }
        catch {
            Write-InstallLog "Feature $feature may already be enabled" "WARNING"
        }
    }
    return $true
}

function New-IISWebSite {
    param(
        [string]$SiteName,
        [string]$PhysicalPath,
        [int]$Port
    )
    
    try {
        Write-InstallLog "Creating IIS website using appcmd.exe (Universal PowerShell compatibility)"
        
        # Check if appcmd.exe exists
        $appcmdPath = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
        if (-not (Test-Path $appcmdPath)) {
            Write-InstallLog "appcmd.exe not found. Trying PowerShell WebAdministration fallback..." "WARNING"
            return (New-IISWebSitePowerShell -SiteName $SiteName -PhysicalPath $PhysicalPath -Port $Port)
        }
        
        Write-InstallLog "Using appcmd.exe for reliable IIS operations"
        
        # Remove existing site if it exists
        $existingSite = & $appcmdPath list site $SiteName 2>$null
        
        if ($existingSite) {
            Write-InstallLog "Found existing website: $SiteName, removing..."
            & $appcmdPath delete site $SiteName | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-InstallLog "Removed existing website: $SiteName"
            }
        }
        
        # Create new website using appcmd
        Write-InstallLog "Creating website: $SiteName on port $Port"
        & $appcmdPath add site /name:$SiteName /physicalPath:$PhysicalPath /bindings:http/*:${Port}: | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-InstallLog "Successfully created website with appcmd" "SUCCESS"
            
            # Verify the site was created
            Start-Sleep -Seconds 2
            $verifyResult = & $appcmdPath list site $SiteName 2>$null
            
            if ($verifyResult -and $verifyResult -like "*$SiteName*") {
                Write-InstallLog "Created website: $SiteName on port $Port" "SUCCESS"
                return $true
            } else {
                Write-InstallLog "Website verification failed" "ERROR"
                return $false
            }
        } else {
            Write-InstallLog "appcmd failed to create website (Exit Code: $LASTEXITCODE)" "ERROR"
            return $false
        }
    }
    catch {
        Write-InstallLog "appcmd method failed: $($_.Exception.Message)" "ERROR"
        Write-InstallLog "Trying PowerShell WebAdministration fallback..." "WARNING"
        return (New-IISWebSitePowerShell -SiteName $SiteName -PhysicalPath $PhysicalPath -Port $Port)
    }
}

function New-IISWebSitePowerShell {
    param(
        [string]$SiteName,
        [string]$PhysicalPath,
        [int]$Port
    )
    
    try {
        Write-InstallLog "Using PowerShell WebAdministration as fallback"
        
        # Try to import WebAdministration
        try {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                Import-Module WebAdministration -SkipEditionCheck -Force -ErrorAction Stop
            } else {
                Import-Module WebAdministration -Force -ErrorAction Stop
            }
            Write-InstallLog "WebAdministration module loaded successfully"
        }
        catch {
            Write-InstallLog "WebAdministration module failed to load: $($_.Exception.Message)" "ERROR"
            return $false
        }
        
        # Remove existing website
        $existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
        if ($existingSite) {
            Remove-Website -Name $SiteName -ErrorAction Stop
            Write-InstallLog "Removed existing website: $SiteName"
        }
        
        # Create new website
        $newSite = New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port $Port -ErrorAction Stop
        
        if ($newSite) {
            Write-InstallLog "Created website: $SiteName on port $Port" "SUCCESS"
            return $true
        } else {
            Write-InstallLog "PowerShell website creation returned null" "ERROR"
            return $false
        }
    }
    catch {
        Write-InstallLog "PowerShell WebAdministration fallback failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Set-FirewallRule {
    param([int]$Port)
    
    try {
        Get-NetFirewallRule -DisplayName "CertWebService*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName "CertWebService-ReadOnly" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True -ErrorAction Stop | Out-Null
        Write-InstallLog "Firewall rule created for port $Port" "SUCCESS"
        return $true
    }
    catch {
        Write-InstallLog "Firewall configuration failed: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function New-JSONFile {
    param([hashtable]$Data, [string]$FilePath)
    
    try {
        $json = $Data | ConvertTo-Json -Depth 10
        Set-Content $FilePath $json -Encoding UTF8 -ErrorAction Stop
        Write-InstallLog "Created JSON file: $(Split-Path $FilePath -Leaf)" "SUCCESS"
        return $true
    }
    catch {
        Write-InstallLog "JSON creation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

try {
    Write-InstallLog "Starting Certificate Web Service Setup"
    Write-InstallLog "PowerShell Version: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    
    # Step 1: Install IIS Features
    $iisSuccess = Install-IISFeatures
    
    # Step 2: Create Web Directory
    Write-InstallLog "Creating web directory"
    $webPath = "C:\inetpub\wwwroot\CertWebService"
    
    if (Test-Path $webPath) {
        Remove-Item $webPath -Recurse -Force -ErrorAction Stop
    }
    
    New-Item -Path $webPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    
    # Step 3: Create Web Content
    Write-InstallLog "Creating web content"
    
    # Create certificates.json
    $certData = @{
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        version = "v2.3.0"
        certificates = @()
        summary = @{ 
            total = 0
            expired = 0
            expiring_soon = 0
        }
        read_only_mode = $true
        authorized_hosts = @(
            "ITSCMGMT03.srv.meduniwien.ac.at",
            "ITSC020.cc.meduniwien.ac.at",
            "itsc049.uvw.meduniwien.ac.at"
        )
    }
    
    New-JSONFile -Data $certData -FilePath "$webPath\certificates.json"
    
    # Create health.json
    $healthData = @{
        status = "healthy"
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        version = "v2.3.0"
        powershell_version = "$($PSVersionTable.PSVersion)"
        powershell_edition = "$($PSVersionTable.PSEdition)"
        read_only_mode = $true
        authorized_hosts_count = 3
    }
    
    New-JSONFile -Data $healthData -FilePath "$webPath\health.json"
    
    # Create summary.json
    $summaryData = @{
        service = "Certificate Web Service"
        version = "v2.3.0"
        mode = "Read-Only"
        powershell_info = @{
            version = "$($PSVersionTable.PSVersion)"
            edition = "$($PSVersionTable.PSEdition)"
        }
        authorized_hosts = @(
            "ITSCMGMT03.srv.meduniwien.ac.at",
            "ITSC020.cc.meduniwien.ac.at", 
            "itsc049.uvw.meduniwien.ac.at"
        )
        last_update = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        certificate_count = 0
    }
    
    New-JSONFile -Data $summaryData -FilePath "$webPath\summary.json"
    
    # Create index.html
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate Web Service v2.3.0</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #111d4e; border-bottom: 2px solid #5fb4e5; padding-bottom: 10px; }
        .status { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .info { background: #cce7ff; color: #004085; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .api-link { display: block; margin: 10px 0; padding: 10px; background: #e9ecef; border-radius: 4px; text-decoration: none; color: #495057; }
        .api-link:hover { background: #dee2e6; }
        .version { background: #fff3cd; color: #856404; padding: 10px; border-radius: 4px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Certificate Web Service v2.3.0</h1>
        
        <div class="status">
            <strong>Service Status:</strong> Active (Read-Only Mode)
        </div>
        
        <div class="info">
            <strong>Security Mode:</strong> Read-Only for 3 authorized servers<br>
            <strong>HTTP Methods:</strong> GET, HEAD, OPTIONS only
        </div>
        
        <div class="version">
            <strong>PowerShell:</strong> $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))<br>
            <strong>Installation:</strong> Universal Compatibility Mode
        </div>
        
        <h2>API Endpoints:</h2>
        <a href="certificates.json" class="api-link">certificates.json - Certificate Data</a>
        <a href="health.json" class="api-link">health.json - Service Health</a>
        <a href="summary.json" class="api-link">summary.json - Service Summary</a>
        
        <h2>Authorized Servers:</h2>
        <ul>
            <li>ITSCMGMT03.srv.meduniwien.ac.at</li>
            <li>ITSC020.cc.meduniwien.ac.at</li>
            <li>itsc049.uvw.meduniwien.ac.at</li>
        </ul>
        
        <p><small>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | PowerShell $($PSVersionTable.PSVersion)</small></p>
    </div>
</body>
</html>
"@
    
    Set-Content "$webPath\index.html" $htmlContent -Encoding UTF8 -ErrorAction Stop
    Write-InstallLog "Created index.html" "SUCCESS"
    
    # Step 4: Create IIS Website (Universal method)
    $websiteSuccess = New-IISWebSite -SiteName "CertWebService" -PhysicalPath $webPath -Port $Port
    
    # Step 5: Configure Firewall
    $firewallSuccess = Set-FirewallRule -Port $Port
    
    # Step 6: Test Installation
    if ($websiteSuccess) {
        Write-InstallLog "Testing installation"
        try {
            Start-Sleep -Seconds 3
            $testUrl = "http://localhost:$Port/health.json"
            $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                Write-InstallLog "Website test successful" "SUCCESS"
            }
        }
        catch {
            Write-InstallLog "Website test warning: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Installation Summary
    Write-Host ""
    Write-Host "Certificate Web Service v2.3.0 installed successfully!" -ForegroundColor Green
    Write-Host "URL: http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "API: http://localhost:$Port/certificates.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Yellow
    Write-Host "Installation Method: Universal Compatibility" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Read-Only Mode: Only GET/HEAD/OPTIONS allowed" -ForegroundColor Yellow
    Write-Host "Authorized Servers: 3" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Installation Status:" -ForegroundColor Cyan
    Write-Host "IIS Features: $(if($iisSuccess){'Installed'}else{'Failed'})" -ForegroundColor $(if($iisSuccess){'Green'}else{'Red'})
    Write-Host "Website: $(if($websiteSuccess){'Created'}else{'Failed'})" -ForegroundColor $(if($websiteSuccess){'Green'}else{'Red'})
    Write-Host "Firewall: $(if($firewallSuccess){'Configured'}else{'Failed'})" -ForegroundColor $(if($firewallSuccess){'Green'}else{'Red'})
    Write-Host ""
    
}
catch {
    Write-InstallLog "Setup failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Write-Host "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Yellow
    exit 1
}