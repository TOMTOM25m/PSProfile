#requires -Version 5.1

<#
.SYNOPSIS
    Server Configuration für CertWebService Mass Update

.DESCRIPTION
    Zentrale Konfiguration aller Server für das Hybrid-Update-System.
    Definiert alle Server, auf denen CertWebService installiert/aktualisiert werden soll.
    
.VERSION
    2.4.0

.RULEBOOK
    v10.1.0
#>

# Zentrale Server-Konfiguration
$Global:CertWebServiceServers = @{
    
    # Produktions-Server
    Production = @(
        "webserver01.meduniwien.ac.at",
        "webserver02.meduniwien.ac.at", 
        "webserver03.meduniwien.ac.at",
        "appserver01.meduniwien.ac.at",
        "appserver02.meduniwien.ac.at"
    )
    
    # Test-Server
    Testing = @(
        "testserver01.meduniwien.ac.at",
        "testserver02.meduniwien.ac.at",
        "devserver01.meduniwien.ac.at"
    )
    
    # Domain Controllers (falls benötigt)
    DomainControllers = @(
        "dc01.meduniwien.ac.at",
        "dc02.meduniwien.ac.at"
    )
    
    # Spezielle Server
    Special = @(
        "itscmgmt03.srv.meduniwien.ac.at",  # Network Share Server
        "monitoring01.meduniwien.ac.at",    # Monitoring Server
        "backup01.meduniwien.ac.at"         # Backup Server
    )
}

# Netzwerk-Konfiguration
$Global:NetworkConfiguration = @{
    
    # Haupt-Deployment-Share
    DeploymentShare = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
    
    # Backup-Deployment-Shares (falls Haupt-Share nicht verfügbar)
    BackupShares = @(
        "\\backup01.meduniwien.ac.at\CertWebService",
        "\\monitoring01.meduniwien.ac.at\Deployment\CertWebService"
    )
    
    # Standard-Ports
    HttpPort = 9080
    HttpsPort = 9443
    
    # Timeout-Einstellungen
    ConnectionTimeout = 30
    DeploymentTimeout = 300
    
    # Credentials (werden zur Laufzeit abgefragt)
    RequiresCredentials = $true
}

# Deployment-Strategie pro Server-Gruppe
$Global:DeploymentStrategy = @{
    
    # Produktions-Server: Vorsichtige Deployment-Strategie
    Production = @{
        Method = "Hybrid"           # PSRemoting -> Network -> Manual
        TestFirst = $true
        BackupBefore = $true
        MaxParallel = 2            # Nur 2 Server gleichzeitig
        RequireConfirmation = $true
    }
    
    # Test-Server: Aggressivere Deployment-Strategie  
    Testing = @{
        Method = "Hybrid"
        TestFirst = $false
        BackupBefore = $false
        MaxParallel = 5            # Alle gleichzeitig möglich
        RequireConfirmation = $false
    }
    
    # Domain Controllers: Sehr vorsichtig
    DomainControllers = @{
        Method = "ManualOnly"      # Nur manuelle Pakete erstellen
        TestFirst = $true
        BackupBefore = $true
        MaxParallel = 1            # Einzeln bearbeiten
        RequireConfirmation = $true
    }
    
    # Spezielle Server: Individual treatment
    Special = @{
        Method = "NetworkPreferred" # Network deployment bevorzugt
        TestFirst = $true
        BackupBefore = $true
        MaxParallel = 1
        RequireConfirmation = $true
    }
}

#region Helper Functions für Server-Management

function Get-ServersByGroup {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Production", "Testing", "DomainControllers", "Special", "All")]
        [string]$Group
    )
    
    if ($Group -eq "All") {
        $allServers = @()
        $allServers += $Global:CertWebServiceServers.Production
        $allServers += $Global:CertWebServiceServers.Testing
        $allServers += $Global:CertWebServiceServers.DomainControllers
        $allServers += $Global:CertWebServiceServers.Special
        return $allServers
    } else {
        return $Global:CertWebServiceServers.$Group
    }
}

function Get-DeploymentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName
    )
    
    # Bestimme Server-Gruppe
    foreach ($groupName in $Global:CertWebServiceServers.Keys) {
        if ($Global:CertWebServiceServers.$groupName -contains $ServerName) {
            return @{
                ServerName = $ServerName
                Group = $groupName
                Strategy = $Global:DeploymentStrategy.$groupName
                NetworkConfig = $Global:NetworkConfiguration
            }
        }
    }
    
    # Fallback für unbekannte Server
    return @{
        ServerName = $ServerName
        Group = "Unknown"
        Strategy = $Global:DeploymentStrategy.Production  # Sichere Standardeinstellung
        NetworkConfig = $Global:NetworkConfiguration
    }
}

function Show-ServerInventory {
    Write-Host "🖥️ CertWebService Server Inventory" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    
    $totalServers = 0
    
    foreach ($group in $Global:CertWebServiceServers.Keys) {
        $servers = $Global:CertWebServiceServers.$group
        $totalServers += $servers.Count
        
        Write-Host "📂 $group ($($servers.Count) servers):" -ForegroundColor Yellow
        foreach ($server in $servers) {
            Write-Host "   🖥️ $server" -ForegroundColor White
        }
        Write-Host ""
    }
    
    Write-Host "📊 Total Servers: $totalServers" -ForegroundColor Cyan
    Write-Host "🌐 Deployment Share: $($Global:NetworkConfiguration.DeploymentShare)" -ForegroundColor Gray
    Write-Host ""
}

function Test-ServerListConnectivity {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ServerList,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    Write-Host "🔍 Testing connectivity to $($ServerList.Count) servers..." -ForegroundColor Yellow
    Write-Host ""
    
    $results = @()
    
    foreach ($server in $ServerList) {
        Write-Host "Testing $server..." -ForegroundColor Gray -NoNewline
        
        $result = @{
            ServerName = $server
            Ping = $false
            SMB = $false
            PSRemoting = $false
            Status = "Unknown"
        }
        
        try {
            # Ping test
            $result.Ping = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
            
            if ($result.Ping) {
                # SMB test
                try {
                    $result.SMB = Test-Path "\\$server\C$" -ErrorAction SilentlyContinue
                } catch { }
                
                # PSRemoting test (simplified)
                try {
                    if ($Credential) {
                        $testResult = Invoke-Command -ComputerName $server -Credential $Credential -ScriptBlock { "OK" } -ErrorAction SilentlyContinue
                    } else {
                        $testResult = Invoke-Command -ComputerName $server -ScriptBlock { "OK" } -ErrorAction SilentlyContinue
                    }
                    $result.PSRemoting = ($testResult -eq "OK")
                } catch { }
                
                # Determine status
                if ($result.PSRemoting) {
                    $result.Status = "PSRemoting"
                    Write-Host " ✅ PSRemoting" -ForegroundColor Green
                } elseif ($result.SMB) {
                    $result.Status = "Network"
                    Write-Host " 🌐 Network" -ForegroundColor Cyan
                } else {
                    $result.Status = "Limited"
                    Write-Host " ⚠️ Limited" -ForegroundColor Yellow
                }
            } else {
                $result.Status = "Unreachable"
                Write-Host " ❌ Unreachable" -ForegroundColor Red
            }
            
        } catch {
            $result.Status = "Error"
            Write-Host " ❌ Error" -ForegroundColor Red
        }
        
        $results += $result
    }
    
    Write-Host ""
    Write-Host "📊 Connectivity Summary:" -ForegroundColor Cyan
    $psRemotingCount = ($results | Where-Object { $_.Status -eq "PSRemoting" }).Count
    $networkCount = ($results | Where-Object { $_.Status -eq "Network" }).Count
    $limitedCount = ($results | Where-Object { $_.Status -eq "Limited" }).Count
    $unreachableCount = ($results | Where-Object { $_.Status -eq "Unreachable" }).Count
    
    Write-Host "   PSRemoting Available: $psRemotingCount" -ForegroundColor Green
    Write-Host "   Network Deployment: $networkCount" -ForegroundColor Cyan
    Write-Host "   Limited Access: $limitedCount" -ForegroundColor Yellow
    Write-Host "   Unreachable: $unreachableCount" -ForegroundColor Red
    Write-Host ""
    
    return $results
}

#endregion

#region Beispiel-Verwendung

function Show-UsageExamples {
    Write-Host "📖 USAGE EXAMPLES" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "1️⃣ Show all servers:" -ForegroundColor Yellow
    Write-Host "   Show-ServerInventory" -ForegroundColor White
    Write-Host ""
    
    Write-Host "2️⃣ Test connectivity to production servers:" -ForegroundColor Yellow
    Write-Host "   `$servers = Get-ServersByGroup -Group Production" -ForegroundColor White
    Write-Host "   Test-ServerListConnectivity -ServerList `$servers" -ForegroundColor White
    Write-Host ""
    
    Write-Host "3️⃣ Update all test servers:" -ForegroundColor Yellow
    Write-Host "   `$testServers = Get-ServersByGroup -Group Testing" -ForegroundColor White
    Write-Host "   .\Update-AllServers-Hybrid.ps1 -ServerList `$testServers -TestOnly" -ForegroundColor White
    Write-Host ""
    
    Write-Host "4️⃣ Update specific servers:" -ForegroundColor Yellow
    Write-Host "   `$specificServers = @('server01.domain.local', 'server02.domain.local')" -ForegroundColor White
    Write-Host "   .\Update-AllServers-Hybrid.ps1 -ServerList `$specificServers" -ForegroundColor White
    Write-Host ""
    
    Write-Host "5️⃣ Full production deployment:" -ForegroundColor Yellow
    Write-Host "   `$prodServers = Get-ServersByGroup -Group Production" -ForegroundColor White
    Write-Host "   .\Update-AllServers-Hybrid.ps1 -ServerList `$prodServers -GenerateReports" -ForegroundColor White
    Write-Host ""
}

#endregion

# Beim Import dieses Moduls zeige Inventory
if ($MyInvocation.InvocationName -ne ".") {
    Show-ServerInventory
    Show-UsageExamples
}
