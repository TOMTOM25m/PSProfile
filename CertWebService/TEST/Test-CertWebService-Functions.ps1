# Certificate WebService Dual-Endpoint Test v1.4.3
# Tests both localhost and FQDN endpoints with dynamic port detection
# Author: Flecki (Tom) Garnreiter

Write-Host "Certificate WebService Dual-Endpoint Test v1.4.3" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Auto-detect FQDN
try {
    $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($domain -and $domain -ne "WORKGROUP") {
        $fqdn = "$env:COMPUTERNAME.$domain"
    } else {
        $fqdn = "$env:COMPUTERNAME.WORKGROUP"
    }
    Write-Host "[INFO] Auto-detected FQDN: $fqdn" -ForegroundColor Yellow
} catch {
    $fqdn = $env:COMPUTERNAME
    Write-Host "[WARNING] Could not detect FQDN, using: $fqdn" -ForegroundColor Yellow
}

# Dynamic port detection
Write-Host "[DETECTION] Scanning for active WebService..."
$testPorts = @(9081, 9080, 9082, 9443, 9444)
$workingPort = $null

foreach ($port in $testPorts) {
    try {
        $testUrl = "http://localhost:$port/health.json"
        $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $workingPort = $port
            Write-Host "[SUCCESS] WebService detected on port $port" -ForegroundColor Green
            break
        }
    } catch {
        # Continue to next port
    }
}

if (-not $workingPort) {
    Write-Host "[ERROR] No active WebService found on any port" -ForegroundColor Red
    Write-Host "[INFO] Tested ports: $($testPorts -join ', ')" -ForegroundColor Yellow
    Write-Host "[SUGGESTION] Run .\Install-WebService.bat first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[TESTING] Testing endpoints on port $workingPort..."
Write-Host ""

# Test results
$results = @()

# Test 1: Local Health Check
Write-Host "[TEST] LOCAL HEALTH: http://localhost:$workingPort/health.json"
try {
    $response = Invoke-WebRequest -Uri "http://localhost:$workingPort/health.json" -UseBasicParsing -ErrorAction Stop
    Write-Host "  [✓] SUCCESS - Status: $($response.StatusCode)" -ForegroundColor Green
    $results += "LOCAL HEALTH: SUCCESS"
} catch {
    Write-Host "  [-] FAILED - $($_.Exception.Message)" -ForegroundColor Red
    $results += "LOCAL HEALTH: FAILED"
}

# Test 2: Local Certificates
Write-Host "[TEST] LOCAL CERTIFICATES: http://localhost:$workingPort/certificates.json"
try {
    $response = Invoke-WebRequest -Uri "http://localhost:$workingPort/certificates.json" -UseBasicParsing -ErrorAction Stop
    $content = $response.Content | ConvertFrom-Json
    $certCount = if ($content -is [array]) { $content.Count } else { 1 }
    Write-Host "  [✓] SUCCESS - $certCount certificates found ($([math]::Round($response.RawContentLength/1MB, 2)) MB)" -ForegroundColor Green
    $results += "LOCAL CERTIFICATES: SUCCESS ($certCount certs)"
} catch {
    Write-Host "  [-] FAILED - $($_.Exception.Message)" -ForegroundColor Red
    $results += "LOCAL CERTIFICATES: FAILED"
}

# Test 3: Remote Health Check
Write-Host "[TEST] REMOTE HEALTH: http://${fqdn}:${workingPort}/health.json"
try {
    $response = Invoke-WebRequest -Uri "http://${fqdn}:${workingPort}/health.json" -UseBasicParsing -ErrorAction Stop
    Write-Host "  [✓] SUCCESS - Status: $($response.StatusCode)" -ForegroundColor Green
    $results += "REMOTE HEALTH: SUCCESS"
} catch {
    Write-Host "  [-] FAILED - $($_.Exception.Message)" -ForegroundColor Red
    $results += "REMOTE HEALTH: FAILED"
}

# Test 4: Remote Certificates  
Write-Host "[TEST] REMOTE CERTIFICATES: http://${fqdn}:${workingPort}/certificates.json"
try {
    $response = Invoke-WebRequest -Uri "http://${fqdn}:${workingPort}/certificates.json" -UseBasicParsing -ErrorAction Stop
    $content = $response.Content | ConvertFrom-Json
    $certCount = if ($content -is [array]) { $content.Count } else { 1 }
    Write-Host "  [✓] SUCCESS - $certCount certificates found ($([math]::Round($response.RawContentLength/1MB, 2)) MB)" -ForegroundColor Green
    $results += "REMOTE CERTIFICATES: SUCCESS ($certCount certs)"
} catch {
    Write-Host "  [-] FAILED - $($_.Exception.Message)" -ForegroundColor Red
    $results += "REMOTE CERTIFICATES: FAILED"
}

# Test Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$successCount = ($results | Where-Object { $_ -like "*SUCCESS*" }).Count
$totalTests = $results.Count

Write-Host "[RESULTS] $successCount of $totalTests endpoints successful" -ForegroundColor $(if ($successCount -eq $totalTests) { "Green" } else { "Yellow" })

if ($successCount -eq $totalTests) {
    Write-Host "[STATUS] All tests passed - WebService is fully operational!" -ForegroundColor Green
} elseif ($successCount -gt 0) {
    Write-Host "[STATUS] Partial success - check network connectivity for remote access" -ForegroundColor Yellow
} else {
    Write-Host "[STATUS] All tests failed - check installation" -ForegroundColor Red
}

Write-Host ""
Write-Host "[ACTIVE ENDPOINTS] Working endpoints on port ${workingPort}:" -ForegroundColor Cyan
Write-Host "  LOCAL:  http://localhost:${workingPort}/certificates.json" -ForegroundColor White
Write-Host "  REMOTE: http://${fqdn}:${workingPort}/certificates.json" -ForegroundColor White
Write-Host "  HEALTH: http://localhost:${workingPort}/health.json" -ForegroundColor White
Write-Host ""

Write-Host "[USAGE] For Certificate Surveillance System:" -ForegroundColor Yellow
Write-Host "  Use: http://${fqdn}:${workingPort}/certificates.json" -ForegroundColor White
Write-Host ""

if ($successCount -lt $totalTests) {
    Write-Host "[TROUBLESHOOTING] If tests failed, check:" -ForegroundColor Yellow
    Write-Host "1. IIS is running: Get-Service W3SVC" -ForegroundColor White
    Write-Host "2. Site is started: Get-IISSite -Name CertWebService" -ForegroundColor White
    Write-Host "3. Firewall allows port $workingPort" -ForegroundColor White
    Write-Host "4. Network connectivity for remote access" -ForegroundColor White
}