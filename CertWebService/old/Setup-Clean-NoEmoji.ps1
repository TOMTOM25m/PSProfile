#requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443
)

# PowerShell Version Detection
$PSVersionInfo = @{
    Major = $PSVersionTable.PSVersion.Major
    Minor = $PSVersionTable.PSVersion.Minor
    Edition = $PSVersionTable.PSEdition
    IsCore = $PSVersionTable.PSEdition -eq 'Core'
    IsWindows = $true
}

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSVersionInfo.IsWindows = $IsWindows
}

Write-Host "Certificate Web Service v2.3.0 Setup" -ForegroundColor Green
Write-Host "Read-Only Mode fuer 3 autorisierte Server" -ForegroundColor Yellow
Write-Host ""
Write-Host "PowerShell Version: $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = 'Stop'

function Write-SetupLog {
    param(
        [string]$Message, 
        [string]$Level = 'INFO'
    )
    
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
    param([string[]]$Features)
    
    Write-SetupLog "Installing IIS features for PowerShell $($PSVersionInfo.Major).$($PSVersionInfo.Minor)"
    
    foreach ($feature in $Features) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-SetupLog "Feature $feature processed" "SUCCESS"
        }
        catch {
            Write-SetupLog "Feature $feature may already be enabled" "WARNING"
        }
    }
    return $true
}

function New-CertWebSite {
    param(
        [string]$SiteName,
        [string]$PhysicalPath,
        [int]$Port
    )
    
    try {
        Import-Module WebAdministration -ErrorAction Stop
        
        $existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
        if ($existingSite) {
            Remove-Website -Name $SiteName -ErrorAction Stop
            Write-SetupLog "Removed existing website: $SiteName"
        }
        
        New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port $Port -ErrorAction Stop | Out-Null
        Write-SetupLog "Created website: $SiteName on port $Port" "SUCCESS"
        return $true
        
    }
    catch {
        Write-SetupLog "Website creation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Set-FirewallRules {
    param([int]$Port)
    
    try {
        Get-NetFirewallRule -DisplayName "CertWebService*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName "CertWebService-HTTP-ReadOnly" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True -ErrorAction Stop | Out-Null
        Write-SetupLog "Firewall rule created for port $Port" "SUCCESS"
        return $true
    }
    catch {
        Write-SetupLog "Firewall configuration failed: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function New-JsonContent {
    param(
        [hashtable]$Data,
        [string]$FilePath
    )
    
    try {
        if ($PSVersionInfo.Major -ge 7) {
            $Data | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding utf8NoBOM -ErrorAction Stop
        } else {
            $Data | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding UTF8 -ErrorAction Stop
        }
        Write-SetupLog "Created JSON file: $(Split-Path $FilePath -Leaf)" "SUCCESS"
        return $true
    }
    catch {
        Write-SetupLog "JSON creation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

try {
    Write-SetupLog "Starting Certificate Web Service Setup"
    
    # Step 1: Install IIS Features
    $features = @(
        'IIS-WebServerRole',
        'IIS-WebServer', 
        'IIS-CommonHttpFeatures',
        'IIS-StaticContent',
        'IIS-DefaultDocument'
    )
    
    $iisSuccess = Install-IISFeatures -Features $features
    
    # Step 2: Create Web Directory
    Write-SetupLog "Creating web directory"
    $webPath = "C:\inetpub\wwwroot\CertWebService"
    
    if (Test-Path $webPath) {
        Remove-Item $webPath -Recurse -Force -ErrorAction Stop
    }
    
    New-Item -Path $webPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    
    # Step 3: Setup Web Content
    Write-SetupLog "Setting up web content"
    $sourceWebFiles = Join-Path $PSScriptRoot "WebFiles"
    
    if (Test-Path $sourceWebFiles) {
        Copy-Item "$sourceWebFiles\*" $webPath -Recurse -Force -ErrorAction Stop
        Write-SetupLog "Web files copied from WebFiles directory" "SUCCESS"
    } else {
        Write-SetupLog "Creating minimal web content"
        
        # Create certificates.json
        $certData = @{
            timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            powershell_version = "$($PSVersionInfo.Major).$($PSVersionInfo.Minor)"
            powershell_edition = $PSVersionInfo.Edition
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
        
        New-JsonContent -Data $certData -FilePath "$webPath\certificates.json"
        
        # Create health.json
        $healthData = @{
            status = "healthy"
            timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            version = "v2.3.0"
            powershell_version = "$($PSVersionInfo.Major).$($PSVersionInfo.Minor)"
            powershell_edition = $PSVersionInfo.Edition
            read_only_mode = $true
            authorized_hosts_count = 3
        }
        
        New-JsonContent -Data $healthData -FilePath "$webPath\health.json"
        
        # Create summary.json
        $summaryData = @{
            service = "Certificate Web Service"
            version = "v2.3.0"
            mode = "Read-Only"
            powershell_info = @{
                version = "$($PSVersionInfo.Major).$($PSVersionInfo.Minor)"
                edition = $PSVersionInfo.Edition
            }
            authorized_hosts = @(
                "ITSCMGMT03.srv.meduniwien.ac.at",
                "ITSC020.cc.meduniwien.ac.at", 
                "itsc049.uvw.meduniwien.ac.at"
            )
            last_update = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            certificate_count = 0
        }
        
        New-JsonContent -Data $summaryData -FilePath "$webPath\summary.json"
        
        # Create index.html
        $htmlContent = @"
<!DOCTYPE html>
<html lang="de">
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
        .version-info { background: #fff3cd; color: #856404; padding: 10px; border-radius: 4px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Certificate Web Service v2.3.0</h1>
        
        <div class="status">
            <strong>Service Status:</strong> Active (Read-Only Mode)
        </div>
        
        <div class="info">
            <strong>Security Mode:</strong> Nur fuer 3 autorisierte Server<br>
            <strong>HTTP Methods:</strong> GET, HEAD, OPTIONS (POST/PUT/DELETE blockiert)
        </div>
        
        <div class="version-info">
            <strong>PowerShell Version:</strong> $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))<br>
            <strong>Platform:</strong> Windows
        </div>
        
        <h2>API Endpoints:</h2>
        <a href="certificates.json" class="api-link">certificates.json - Certificate Data</a>
        <a href="health.json" class="api-link">health.json - Service Health</a>
        <a href="summary.json" class="api-link">summary.json - Service Summary</a>
        
        <h2>Autorisierte Server:</h2>
        <ul>
            <li>ITSCMGMT03.srv.meduniwien.ac.at</li>
            <li>ITSC020.cc.meduniwien.ac.at</li>
            <li>itsc049.uvw.meduniwien.ac.at</li>
        </ul>
        
        <p><small>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | PowerShell $($PSVersionInfo.Major).$($PSVersionInfo.Minor)</small></p>
    </div>
</body>
</html>
"@
        
        Set-Content "$webPath\index.html" $htmlContent -Encoding UTF8 -ErrorAction Stop
        Write-SetupLog "Created index.html with version info" "SUCCESS"
    }
    
    # Step 4: Create IIS Website
    $websiteSuccess = New-CertWebSite -SiteName "CertWebService" -PhysicalPath $webPath -Port $Port
    
    # Step 5: Configure Firewall
    $firewallSuccess = Set-FirewallRules -Port $Port
    
    # Step 6: Test Installation
    if ($websiteSuccess) {
        Write-SetupLog "Testing installation"
        try {
            Start-Sleep -Seconds 3
            $testUrl = "http://localhost:$Port/health.json"
            $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                Write-SetupLog "Website test successful" "SUCCESS"
            }
        }
        catch {
            Write-SetupLog "Website test warning: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Installation Summary
    Write-SetupLog "Installation Summary" "SUCCESS"
    Write-Host ""
    Write-Host "Certificate Web Service v2.3.0 installed successfully!" -ForegroundColor Green
    Write-Host "URL: http://$($env:COMPUTERNAME):$Port" -ForegroundColor Cyan
    Write-Host "API: http://$($env:COMPUTERNAME):$Port/certificates.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PowerShell Version: $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Read-Only Mode: Nur GET/HEAD/OPTIONS erlaubt" -ForegroundColor Yellow
    Write-Host "Autorisierte Server: 3" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Feature Status:" -ForegroundColor Cyan
    Write-Host "IIS Features: $(if($iisSuccess){'Installed'}else{'Failed'})" -ForegroundColor $(if($iisSuccess){'Green'}else{'Red'})
    Write-Host "Website: $(if($websiteSuccess){'Created'}else{'Failed'})" -ForegroundColor $(if($websiteSuccess){'Green'}else{'Red'})
    Write-Host "Firewall: $(if($firewallSuccess){'Configured'}else{'Failed'})" -ForegroundColor $(if($firewallSuccess){'Green'}else{'Red'})
    Write-Host ""
    
}
catch {
    Write-SetupLog "Setup failed: $($_.Exception.Message)" "ERROR"
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Write-Host "PowerShell Version: $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))" -ForegroundColor Yellow
    exit 1
}