#requires -Version 5.1
#Requires -RunAsAdministrator

Write-Host "🧪 Certificate WebService Test Suite v2.3.0" -ForegroundColor Cyan
Write-Host ""

$server = $env:COMPUTERNAME
$port = 9080

Write-Host "Testing server: $server on port $port" -ForegroundColor Gray
Write-Host ""

$tests = @(
    @{Name="Dashboard"; Url="http://$server`:$port/"; Expected="Certificate WebService"},
    @{Name="Health"; Url="http://$server`:$port/health.json"; Expected="healthy"},
    @{Name="Certificates"; Url="http://$server`:$port/certificates.json"; Expected="timestamp"}
)

$passed = 0
$total = $tests.Count

foreach ($test in $tests) {
    Write-Host "Testing $($test.Name)..." -ForegroundColor Yellow -NoNewline
    
    try {
        $response = Invoke-WebRequest -Uri $test.Url -UseBasicParsing -TimeoutSec 10
        
        if ($response.StatusCode -eq 200) {
            if ($test.Expected -and $response.Content -like "*$($test.Expected)*") {
                Write-Host " ✅ PASS" -ForegroundColor Green
                $passed++
            } elseif (-not $test.Expected) {
                Write-Host " ✅ PASS" -ForegroundColor Green
                $passed++
            } else {
                Write-Host " ⚠️ CONTENT MISMATCH" -ForegroundColor Yellow
            }
        } else {
            Write-Host " ❌ HTTP $($response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host " ❌ FAIL: $($_.Exception.Message.Split('.')[0])" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📊 Test Results:" -ForegroundColor Cyan
Write-Host "   Passed: $passed/$total" -ForegroundColor $(if($passed -eq $total){"Green"}else{"Yellow"})

if ($passed -eq $total) {
    Write-Host ""
    Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "   Certificate WebService is operational" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 Access URLs:" -ForegroundColor Cyan
    Write-Host "   Dashboard: http://$server`:$port/" -ForegroundColor White
    Write-Host "   API: http://$server`:$port/certificates.json" -ForegroundColor White
    Write-Host "   Health: http://$server`:$port/health.json" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "Some tests failed!" -ForegroundColor Yellow
    Write-Host "   Check installation and try again" -ForegroundColor White
    Write-Host ""
    exit 1
}