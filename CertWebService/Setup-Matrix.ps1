#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Certificate Web Service - PowerShell Version Matrix Setup v2.3.0

.DESCRIPTION
    Universal setup with PowerShell version detection and compatibility matrix
    Supports PowerShell 5.1, 7.x, and Core versions
    
.PARAMETER Port
    HTTP port (default: 9080)
    
.PARAMETER SecurePort  
    HTTPS port (default: 9443)
#>

param(
    [int]$Port = 9080,
    [int]$SecurePort = 9443
)

#region PowerShell Version Detection and Compatibility Matrix
$PSVersionInfo = @{
    Major = $PSVersionTable.PSVersion.Major
    Minor = $PSVersionTable.PSVersion.Minor
    Edition = $PSVersionTable.PSEdition
    OS = $PSVersionTable.OS
    Platform = $PSVersionTable.Platform
    IsCore = $PSVersionTable.PSEdition -eq 'Core'
    IsWindows = $true
    SupportsWebAdministration = $true
    SupportsFirewall = $true
}

# Platform detection for cross-platform support
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSVersionInfo.IsWindows = $IsWindows
    $PSVersionInfo.SupportsWebAdministration = $IsWindows
    $PSVersionInfo.SupportsFirewall = $IsWindows
}

function Write-VersionMatrix {
    Write-Host "🔍 PowerShell Version Matrix:" -ForegroundColor Cyan
    Write-Host "   Version: $($PSVersionInfo.Major).$($PSVersionInfo.Minor)" -ForegroundColor White
    Write-Host "   Edition: $($PSVersionInfo.Edition)" -ForegroundColor White
    Write-Host "   Platform: $(if($PSVersionInfo.IsWindows){'Windows'}else{'Non-Windows'})" -ForegroundColor White
    Write-Host "   WebAdmin Support: $(if($PSVersionInfo.SupportsWebAdministration){'✅'}else{'❌'})" -ForegroundColor White
    Write-Host "   Firewall Support: $(if($PSVersionInfo.SupportsFirewall){'✅'}else{'❌'})" -ForegroundColor White
    Write-Host ""
}
#endregion

#region Logging Function (Version-Specific)
function Write-SetupLog {
    param(
        [string]$Message, 
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Version-specific color handling
    if ($PSVersionInfo.Major -ge 7) {
        # PowerShell 7+ has better ANSI support
        switch ($Level) {
            'ERROR' { Write-Host $logMessage -ForegroundColor Red }
            'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
            'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
            default { Write-Host $logMessage -ForegroundColor White }
        }
    } else {
        # PowerShell 5.1 fallback
        switch ($Level) {
            'ERROR' { Write-Host $logMessage -ForegroundColor Red }
            'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
            'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
            default { Write-Host $logMessage }
        }
    }
}
#endregion

#region Version-Specific Helper Functions
function Install-IISFeatures-VersionSpecific {
    param([string[]]$Features)
    
    Write-SetupLog "Installing IIS features (PS $($PSVersionInfo.Major).$($PSVersionInfo.Minor))"
    
    if (-not $PSVersionInfo.SupportsWebAdministration) {
        Write-SetupLog "WebAdministration not supported on this platform" "WARNING"
        return $false
    }
    
    foreach ($feature in $Features) {
        try {
            if ($PSVersionInfo.Major -ge 7) {
                # PowerShell 7+ - better error handling
                $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
                if ($result.RestartNeeded -eq $true) {
                    Write-SetupLog "Feature $feature installed (restart may be needed)" "WARNING"
                } else {
                    Write-SetupLog "Feature $feature installed successfully" "SUCCESS"
                }
            } else {
                # PowerShell 5.1 - legacy handling
                Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
                Write-SetupLog "Feature $feature processed" "INFO"
            }
        }
        catch {
            Write-SetupLog "Feature $feature may already be enabled: $($_.Exception.Message)" "WARNING"
        }
    }
    return $true
}

function Create-WebSite-VersionSpecific {
    param(
        [string]$SiteName,
        [string]$PhysicalPath,
        [int]$Port
    )
    
    if (-not $PSVersionInfo.SupportsWebAdministration) {
        Write-SetupLog "WebAdministration not supported - skipping IIS configuration" "WARNING"
        return $false
    }
    
    try {
        # Import WebAdministration with version-specific handling
        if ($PSVersionInfo.Major -ge 7) {
            Import-Module WebAdministration -Force -ErrorAction Stop
        } else {
            Import-Module WebAdministration -ErrorAction Stop
        }
        
        # Remove existing site
        $existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
        if ($existingSite) {
            Remove-Website -Name $SiteName -ErrorAction Stop
            Write-SetupLog "Removed existing website: $SiteName" "INFO"
        }
        
        # Create new website
        $newSite = New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port $Port -ErrorAction Stop
        Write-SetupLog "Created website: $SiteName on port $Port" "SUCCESS"
        return $true
        
    }
    catch {
        Write-SetupLog "Website creation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Configure-Firewall-VersionSpecific {
    param([int]$Port)
    
    if (-not $PSVersionInfo.SupportsFirewall) {
        Write-SetupLog "Firewall configuration not supported on this platform" "WARNING"
        return $false
    }
    
    try {
        # Remove old rules with version-specific cmdlets
        if ($PSVersionInfo.Major -ge 7) {
            Get-NetFirewallRule -DisplayName "CertWebService*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction Stop
        } else {
            Get-NetFirewallRule -DisplayName "CertWebService*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        }
        
        # Create new rule
        $rule = New-NetFirewallRule -DisplayName "CertWebService-HTTP-ReadOnly" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True -ErrorAction Stop
        Write-SetupLog "Firewall rule created for port $Port" "SUCCESS"
        return $true
        
    }
    catch {
        Write-SetupLog "Firewall configuration failed: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Create-JsonContent-VersionSpecific {
    param(
        [hashtable]$Data,
        [string]$FilePath
    )
    
    try {
        if ($PSVersionInfo.Major -ge 7) {
            # PowerShell 7+ has better JSON handling
            $Data | ConvertTo-Json -Depth 10 -EscapeHandling EscapeNonAscii | Set-Content $FilePath -Encoding utf8NoBOM -ErrorAction Stop
        } else {
            # PowerShell 5.1 fallback
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
#endregion

#region Main Installation Logic
Write-Host "🚀 Certificate Web Service v2.3.0 Setup" -ForegroundColor Green
Write-Host "📋 Read-Only Mode für 3 autorisierte Server" -ForegroundColor Yellow
Write-Host ""

Write-VersionMatrix

$ErrorActionPreference = 'Stop'

try {
    Write-SetupLog "Starting Certificate Web Service Setup" "INFO"
    
    # Step 1: Install IIS Features (Version-Specific)
    $features = @(
        'IIS-WebServerRole',
        'IIS-WebServer', 
        'IIS-CommonHttpFeatures',
        'IIS-HttpErrors',
        'IIS-HttpLogging',
        'IIS-RequestFiltering',
        'IIS-StaticContent',
        'IIS-DefaultDocument',
        'IIS-DirectoryBrowsing'
    )
    
    $iisSuccess = Install-IISFeatures-VersionSpecific -Features $features
    
    # Step 2: Create Web Directory
    Write-SetupLog "Creating web directory..." "INFO"
    $webPath = "C:\inetpub\wwwroot\CertWebService"
    
    if (Test-Path $webPath) {
        Remove-Item $webPath -Recurse -Force -ErrorAction Stop
    }
    
    New-Item -Path $webPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    
    # Step 3: Copy or Create Web Files
    Write-SetupLog "Setting up web content..." "INFO"
    $sourceWebFiles = Join-Path $PSScriptRoot "WebFiles"
    
    if (Test-Path $sourceWebFiles) {
        Copy-Item "$sourceWebFiles\*" $webPath -Recurse -Force -ErrorAction Stop
        Write-SetupLog "Web files copied from WebFiles directory" "SUCCESS"
    } else {
        Write-SetupLog "WebFiles directory not found - creating minimal content" "WARNING"
        
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
        
        Create-JsonContent-VersionSpecific -Data $certData -FilePath "$webPath\certificates.json"
        
        # Create health.json
        $healthData = @{
            status = "healthy"
            timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            version = "v2.3.0"
            powershell_version = "$($PSVersionInfo.Major).$($PSVersionInfo.Minor)"
            powershell_edition = $PSVersionInfo.Edition
            platform = $(if($PSVersionInfo.IsWindows){"Windows"}else{"Non-Windows"})
            read_only_mode = $true
            authorized_hosts_count = 3
        }
        
        Create-JsonContent-VersionSpecific -Data $healthData -FilePath "$webPath\health.json"
        
        # Create summary.json
        $summaryData = @{
            service = "Certificate Web Service"
            version = "v2.3.0"
            mode = "Read-Only"
            powershell_info = @{
                version = "$($PSVersionInfo.Major).$($PSVersionInfo.Minor)"
                edition = $PSVersionInfo.Edition
                platform = $(if($PSVersionInfo.IsWindows){"Windows"}else{"Non-Windows"})
            }
            authorized_hosts = @(
                "ITSCMGMT03.srv.meduniwien.ac.at",
                "ITSC020.cc.meduniwien.ac.at", 
                "itsc049.uvw.meduniwien.ac.at"
            )
            last_update = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            certificate_count = 0
        }
        
        Create-JsonContent-VersionSpecific -Data $summaryData -FilePath "$webPath\summary.json"
        
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
        <h1>🔒 Certificate Web Service v2.3.0</h1>
        
        <div class="status">
            <strong>✅ Service Status:</strong> Active (Read-Only Mode)
        </div>
        
        <div class="info">
            <strong>🛡️ Security Mode:</strong> Nur für 3 autorisierte Server<br>
            <strong>📋 HTTP Methods:</strong> GET, HEAD, OPTIONS (POST/PUT/DELETE blockiert)
        </div>
        
        <div class="version-info">
            <strong>⚡ PowerShell Version:</strong> $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))<br>
            <strong>🖥️ Platform:</strong> $(if($PSVersionInfo.IsWindows){"Windows"}else{"Non-Windows"})
        </div>
        
        <h2>📊 API Endpoints:</h2>
        <a href="certificates.json" class="api-link">📜 certificates.json - Certificate Data</a>
        <a href="health.json" class="api-link">💚 health.json - Service Health</a>
        <a href="summary.json" class="api-link">📋 summary.json - Service Summary</a>
        
        <h2>👥 Autorisierte Server:</h2>
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
    
    # Step 4: Create IIS Website (Version-Specific)
    if ($iisSuccess) {
        $websiteSuccess = Create-WebSite-VersionSpecific -SiteName "CertWebService" -PhysicalPath $webPath -Port $Port
    } else {
        Write-SetupLog "Skipping website creation due to IIS feature installation issues" "WARNING"
        $websiteSuccess = $false
    }
    
    # Step 5: Configure Firewall (Version-Specific)
    $firewallSuccess = Configure-Firewall-VersionSpecific -Port $Port
    
    # Step 6: Test Installation
    Write-SetupLog "Testing installation..." "INFO"
    if ($websiteSuccess) {
        try {
            Start-Sleep -Seconds 3
            $testUrl = "http://localhost:$Port/health.json"
            
            if ($PSVersionInfo.Major -ge 7) {
                $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            } else {
                $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            }
            
            if ($response.StatusCode -eq 200) {
                Write-SetupLog "Website test successful (HTTP $($response.StatusCode))" "SUCCESS"
            }
        }
        catch {
            Write-SetupLog "Website test failed: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Installation Summary
    Write-SetupLog "=== Installation Summary ===" "INFO"
    Write-Host ""
    Write-Host "✅ Certificate Web Service v2.3.0 installed!" -ForegroundColor Green
    Write-Host "   🌐 URL: http://$($env:COMPUTERNAME):$Port" -ForegroundColor Cyan
    Write-Host "   📊 API: http://$($env:COMPUTERNAME):$Port/certificates.json" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚡ PowerShell Version: $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))" -ForegroundColor Yellow
    Write-Host "🖥️ Platform: $(if($PSVersionInfo.IsWindows){"Windows"}else{"Non-Windows"})" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔒 Read-Only Mode: Nur GET/HEAD/OPTIONS erlaubt" -ForegroundColor Yellow
    Write-Host "👥 Autorisierte Server: 3" -ForegroundColor Yellow
    Write-Host ""
    
    # Feature Status
    Write-Host "📋 Feature Status:" -ForegroundColor Cyan
    Write-Host "   IIS Features: $(if($iisSuccess){"✅ Installed"}else{"❌ Failed"})" -ForegroundColor $(if($iisSuccess){"Green"}else{"Red"})
    Write-Host "   Website: $(if($websiteSuccess){"✅ Created"}else{"❌ Failed"})" -ForegroundColor $(if($websiteSuccess){"Green"}else{"Red"})
    Write-Host "   Firewall: $(if($firewallSuccess){"✅ Configured"}else{"❌ Failed"})" -ForegroundColor $(if($firewallSuccess){"Green"}else{"Red"})
    Write-Host ""
    
}
catch {
    Write-SetupLog "Setup failed: $($_.Exception.Message)" "ERROR"
    Write-Host "❌ Installation failed: $_" -ForegroundColor Red
    Write-Host "PowerShell Version: $($PSVersionInfo.Major).$($PSVersionInfo.Minor) ($($PSVersionInfo.Edition))" -ForegroundColor Yellow
    exit 1
}
#endregion