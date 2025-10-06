#requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CertWebService Mass Update Launcher v2.4.0

.DESCRIPTION
    Zentraler Launcher für das Mass Update aller CertWebService-Installationen.
    Unterstützt verschiedene Deployment-Methoden und passt sich automatisch an
    die verfügbaren Verbindungstypen an.
    
.VERSION
    2.4.0

.RULEBOOK
    v10.0.0
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Production", "Testing", "DomainControllers", "Special", "All", "Custom")]
    [string]$ServerGroup = "Testing",
    
    [Parameter(Mandatory = $false)]
    [string[]]$CustomServers = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$TestConnectivityOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$Script:Version = "v2.4.0"
$Script:LauncherDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "🚀 CertWebService Mass Update Launcher" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   Version: $Script:Version" -ForegroundColor Gray
Write-Host "   Launch Time: $Script:LauncherDate" -ForegroundColor Gray
Write-Host ""

# Importiere Server-Konfiguration
$configPath = Join-Path $PSScriptRoot "Server-Configuration.ps1"
if (Test-Path $configPath) {
    Write-Host "📋 Loading server configuration..." -ForegroundColor Yellow
    . $configPath
    Write-Host "✅ Server configuration loaded" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "❌ Server configuration not found: $configPath" -ForegroundColor Red
    Write-Host "   Please ensure Server-Configuration.ps1 exists in the same directory." -ForegroundColor Yellow
    exit 1
}

# Bestimme Ziel-Server
$targetServers = @()

if ($ServerGroup -eq "Custom" -and $CustomServers.Count -gt 0) {
    $targetServers = $CustomServers
    Write-Host "🎯 Using custom server list ($($targetServers.Count) servers)" -ForegroundColor Cyan
} elseif ($ServerGroup -ne "Custom") {
    $targetServers = Get-ServersByGroup -Group $ServerGroup
    Write-Host "🎯 Using server group: $ServerGroup ($($targetServers.Count) servers)" -ForegroundColor Cyan
} else {
    Write-Host "❌ No servers specified. Use -ServerGroup or -CustomServers parameter." -ForegroundColor Red
    Write-Host ""
    Write-Host "Available server groups:" -ForegroundColor Yellow
    Write-Host "   Production, Testing, DomainControllers, Special, All" -ForegroundColor White
    Write-Host ""
    Write-Host "Example usage:" -ForegroundColor Yellow
    Write-Host "   .\Update-Launcher.ps1 -ServerGroup Testing" -ForegroundColor White
    Write-Host "   .\Update-Launcher.ps1 -ServerGroup Custom -CustomServers @('server1', 'server2')" -ForegroundColor White
    exit 1
}

Write-Host "📝 Target servers:" -ForegroundColor Yellow
foreach ($server in $targetServers) {
    Write-Host "   🖥️ $server" -ForegroundColor White
}
Write-Host ""

# Teste Connectivity falls gewünscht oder bei DryRun
if ($TestConnectivityOnly -or $DryRun) {
    Write-Host "🔍 Testing server connectivity..." -ForegroundColor Yellow
    
    # Hole Credentials für erweiterte Tests
    $testCredential = $null
    if (-not $TestConnectivityOnly) {
        Write-Host "🔐 Enter administrator credentials for connectivity testing:" -ForegroundColor Cyan
        $testCredential = Get-Credential -Message "Administrator credentials for server access"
    }
    
    $connectivityResults = Test-ServerListConnectivity -ServerList $targetServers -Credential $testCredential
    
    if ($TestConnectivityOnly) {
        Write-Host "🏁 Connectivity test completed. Exiting." -ForegroundColor Green
        exit 0
    }
}

# Bestätige Deployment falls nicht Force
if (-not $Force -and -not $DryRun) {
    Write-Host "⚠️ DEPLOYMENT CONFIRMATION REQUIRED" -ForegroundColor Yellow
    Write-Host "====================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You are about to update CertWebService on the following servers:" -ForegroundColor White
    Write-Host "   Server Group: $ServerGroup" -ForegroundColor Cyan
    Write-Host "   Server Count: $($targetServers.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($server in $targetServers) {
        Write-Host "   🖥️ $server" -ForegroundColor Gray
    }
    Write-Host ""
    
    $confirmation = Read-Host "Continue with deployment? (yes/no)"
    if ($confirmation -notlike "y*" -and $confirmation -notlike "yes") {
        Write-Host "🛑 Deployment cancelled by user." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# Vorbereitung für Deployment
Write-Host "🎯 Preparing for deployment..." -ForegroundColor Cyan

# Prüfe ob Deployment-Package verfügbar ist
$networkSharePath = $Global:NetworkConfiguration.DeploymentShare
Write-Host "📦 Checking deployment package at: $networkSharePath" -ForegroundColor Yellow

if (-not (Test-Path $networkSharePath)) {
    Write-Host "❌ Deployment package not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUTION STEPS:" -ForegroundColor Yellow
    Write-Host "1. Create the deployment package:" -ForegroundColor White
    Write-Host "   .\Deploy-NetworkPackage.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Or run the package creator:" -ForegroundColor White
    Write-Host "   .\Create-NetworkDeployment.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Then run this launcher again:" -ForegroundColor White
    Write-Host "   .\Update-Launcher.ps1 -ServerGroup $ServerGroup" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}
Write-Host "✅ Deployment package verified" -ForegroundColor Green

# Dry Run Modus
if ($DryRun) {
    Write-Host "🧪 DRY RUN MODE - No actual changes will be made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The following actions WOULD be performed:" -ForegroundColor Cyan
    Write-Host "1. Load administrator credentials" -ForegroundColor White
    Write-Host "2. Test connectivity to all $($targetServers.Count) servers" -ForegroundColor White
    Write-Host "3. Determine optimal deployment method for each server" -ForegroundColor White
    Write-Host "4. Execute hybrid deployment (PSRemoting/Network/Manual)" -ForegroundColor White
    Write-Host "5. Generate deployment reports" -ForegroundColor White
    Write-Host "6. Provide manual installation packages where needed" -ForegroundColor White
    Write-Host ""
    Write-Host "To execute the actual deployment:" -ForegroundColor Yellow
    Write-Host "   .\Update-Launcher.ps1 -ServerGroup $ServerGroup -Force" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

# Starte tatsächliches Deployment
Write-Host "🚀 Starting CertWebService mass update..." -ForegroundColor Green
Write-Host ""

try {
    # Führe Hybrid-Update aus
    $hybridUpdatePath = Join-Path $PSScriptRoot "Update-AllServers-Hybrid.ps1"
    
    if (-not (Test-Path $hybridUpdatePath)) {
        throw "Hybrid update script not found: $hybridUpdatePath"
    }
    
    # Parameter für Hybrid-Update
    $hybridParams = @{
        ServerList = $targetServers
        NetworkSharePath = $networkSharePath
        GenerateReports = $true
        TimeoutSeconds = $Global:NetworkConfiguration.DeploymentTimeout
    }
    
    Write-Host "▶️ Executing hybrid update with the following parameters:" -ForegroundColor Cyan
    Write-Host "   Servers: $($targetServers.Count)" -ForegroundColor Gray
    Write-Host "   Network Share: $networkSharePath" -ForegroundColor Gray
    Write-Host "   Reports: Enabled" -ForegroundColor Gray
    Write-Host "   Timeout: $($Global:NetworkConfiguration.DeploymentTimeout) seconds" -ForegroundColor Gray
    Write-Host ""
    
    # Führe Hybrid-Update-Skript aus
    & $hybridUpdatePath @hybridParams
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "🎉 Mass update process completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
        Write-Host "1. Review the deployment summary above" -ForegroundColor White
        Write-Host "2. Complete any manual installations identified" -ForegroundColor White
        Write-Host "3. Test the WebService endpoints on all servers:" -ForegroundColor White
        Write-Host "   http://[SERVER]:9080/health.json" -ForegroundColor Gray
        Write-Host "4. Update Certificate Surveillance (CertSurv) configuration" -ForegroundColor White
        Write-Host "5. Run end-to-end integration test" -ForegroundColor White
        Write-Host ""
        
        # Integration mit CertSurv hinweisen
        Write-Host "🔗 INTEGRATION WITH CERTSURV:" -ForegroundColor Yellow
        Write-Host "After completing the updates, update your CertSurv configuration:" -ForegroundColor White
        Write-Host "1. Edit the CertSurv server list to include updated endpoints" -ForegroundColor Gray
        Write-Host "2. Run a test collection to verify API connectivity" -ForegroundColor Gray
        Write-Host "3. Schedule regular certificate surveillance runs" -ForegroundColor Gray
        Write-Host ""
        
    } else {
        Write-Host "⚠️ Mass update completed with some issues. Check the summary above." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Mass update process failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. Ensure you have Administrator privileges" -ForegroundColor White
    Write-Host "2. Check network connectivity to the deployment share" -ForegroundColor White
    Write-Host "3. Verify server list and credentials" -ForegroundColor White
    Write-Host "4. Review PowerShell execution policy" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "🏁 Launcher completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan