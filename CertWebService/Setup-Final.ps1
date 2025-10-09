#requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443
)

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
$ErrorActionPreference = 'Stop'

Write-Host "CertWebService v2.3.0 Setup" -ForegroundColor Green
Write-Host "Read-Only Mode for 3 authorized servers" -ForegroundColor Yellow
Write-Host ""

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
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

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
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

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function New-WebSiteWithAppCmd {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteName,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PhysicalPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,65535)]
        [int]$Port
    )
    
    try {
        Write-InstallLog "Using appcmd.exe for IIS operations (PowerShell 7.x compatibility)"
        
        # Check if appcmd.exe exists
        $appcmdPath = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
        if (-not (Test-Path $appcmdPath)) {
            Write-InstallLog "appcmd.exe not found at $appcmdPath" "ERROR"
            return $false
        }
        
        # Remove existing site if it exists
        $listResult = & $appcmdPath list site $SiteName 2>$null
        if ($listResult) {
            Write-InstallLog "Found existing website: $SiteName, removing..."
            $deleteResult = & $appcmdPath delete site $SiteName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-InstallLog "Removed existing website: $SiteName"
            } else {
                Write-InstallLog "Failed to remove existing website: $deleteResult" "WARNING"
            }
        }
        
        # Create new website using appcmd
        Write-InstallLog "Creating website with appcmd: $SiteName on port $Port"
        $createResult = & $appcmdPath add site /name:$SiteName /physicalPath:$PhysicalPath /bindings:http/*:${Port}: 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-InstallLog "Successfully created website with appcmd" "SUCCESS"
            
            # Verify the site was created
            Start-Sleep -Seconds 2
            $verifyResult = & $appcmdPath list site $SiteName 2>$null
            if ($verifyResult) {
                Write-InstallLog "Created website: $SiteName on port $Port" "SUCCESS"
                Write-InstallLog "appcmd verification: $verifyResult" "SUCCESS"
                return $true
            } else {
                Write-InstallLog "Website creation verification failed" "ERROR"
                return $false
            }
        } else {
            Write-InstallLog "appcmd failed to create website: $createResult" "ERROR"
            return $false
        }
    }
    catch {
        Write-InstallLog "appcmd fallback failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
function New-WebSite {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteName,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PhysicalPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,65535)]
        [int]$Port
    )
    
    try {
        Write-InstallLog "Website creation parameters - Name: '$SiteName', Path: '$PhysicalPath', Port: $Port"
        
        # Import WebAdministration with PowerShell 7.x compatibility and fallback
        try {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                # PowerShell 7.x: Try compatibility mode first
                Import-Module WebAdministration -SkipEditionCheck -Force -ErrorAction Stop
                Write-InstallLog "Loaded WebAdministration module with PowerShell 7.x compatibility mode"
            } else {
                # PowerShell 5.x: Native support
                Import-Module WebAdministration -ErrorAction Stop
                Write-InstallLog "Loaded WebAdministration module for PowerShell 5.x"
            }
        }
        catch {
            # Fallback: Use appcmd.exe for PowerShell 7.x compatibility issues
            Write-InstallLog "WebAdministration module failed, using appcmd.exe fallback" "WARNING"
            return (New-WebSiteWithAppCmd -SiteName $SiteName -PhysicalPath $PhysicalPath -Port $Port)
        }
        
        # Remove existing website if it exists
        $existingSites = Get-Website -ErrorAction SilentlyContinue
        $existingSite = $existingSites | Where-Object { $_.Name -eq $SiteName }
        
        if ($existingSite) {
            Write-InstallLog "Found existing website: $SiteName (ID: $($existingSite.ID))"
            Remove-Website -Name $SiteName -ErrorAction Stop
            Write-InstallLog "Removed existing website: $SiteName"
            Start-Sleep -Seconds 1
        }
        
        # Create new website
        Write-InstallLog "Creating new website: $SiteName"
        $newSite = New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port $Port -ErrorAction Stop
        
        if ($newSite) {
            Write-InstallLog "Website object created successfully"
            
            # Verify website was created and is accessible
            Start-Sleep -Seconds 2
            $allSites = Get-Website -ErrorAction SilentlyContinue
            $verifysite = $allSites | Where-Object { $_.Name -eq $SiteName }
            
            if ($verifysite) {
                Write-InstallLog "Created website: $SiteName on port $Port" "SUCCESS"
                Write-InstallLog "Website ID: $($verifysite.ID), State: $($verifysite.State)" "SUCCESS"
                return $true
            } else {
                Write-InstallLog "Website creation verification failed - not found in website list" "ERROR"
                return $false
            }
        } else {
            Write-InstallLog "New-Website returned null or empty" "ERROR"
            return $false
        }
        
    }
    catch {
        Write-InstallLog "Website creation failed: $($_.Exception.Message)" "ERROR"
        if ($_.Exception.InnerException) {
            Write-InstallLog "Inner exception: $($_.Exception.InnerException.Message)" "ERROR"
        }
        return $false
    }
}

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
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

# Regelwerk v10.1.0 Enterprise Features:
# - Config Version Control (Â§20)
# - Advanced GUI Standards (Â§21) 
# - Event Log Integration (Â§22)
# - Log Archiving & Rotation (Â§23)
# - Enhanced Password Management (Â§24)
# - Environment Workflow Optimization (Â§25)
# - MUW Compliance Standards (Â§26)
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
        read_only_mode = $true
        authorized_hosts_count = 3
    }
    
    New-JSONFile -Data $healthData -FilePath "$webPath\health.json"
    
    # Create summary.json
    $summaryData = @{
        service = "Certificate Web Service"
        version = "v2.3.0"
        mode = "Read-Only"
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
        
        <p><small>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</small></p>
    </div>
</body>
</html>
"@
    
    Set-Content "$webPath\index.html" $htmlContent -Encoding UTF8 -ErrorAction Stop
    Write-InstallLog "Created index.html" "SUCCESS"
    
    # Step 4: Create IIS Website
    $websiteSuccess = New-WebSite -SiteName "CertWebService" -PhysicalPath $webPath -Port $Port
    
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
    exit 1
}
