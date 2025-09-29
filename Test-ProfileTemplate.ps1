# PowerShell Profile Template Test Script
Write-Host "=== PowerShell Profile Template Functionality Test ===" -ForegroundColor Cyan

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Write-Host "Testing profile loading..." -ForegroundColor Yellow
    
    # Test basic syntax by loading the profile
    $profilePath = ".\ResetProfile\Templates\Profile-template.ps1"
    if (-not (Test-Path $profilePath)) {
        Write-Error "Profile template not found at: $profilePath"
        exit 1
    }
    
    # Parse the script for syntax errors
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$errors)
    
    if ($errors.Count -gt 0) {
        Write-Host "Syntax Errors Found:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }
    } else {
        Write-Host " Syntax validation passed" -ForegroundColor Green
    }
    
    # Test performance of loading
    $loadTime = Measure-Command { 
        . $profilePath 2>$null
    }
    
    Write-Host " Profile loaded in $($loadTime.TotalMilliseconds)ms" -ForegroundColor Green
    
    # Test functions if they were loaded
    $functions = @("Get-SystemInfo", "Test-Port", "Get-DirectorySize", "Show-ProfileInfo")
    foreach ($func in $functions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host " Function '$func' loaded successfully" -ForegroundColor Green
        } else {
            Write-Host " Function '$func' not loaded" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host " Error testing profile: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    $stopwatch.Stop()
    Write-Host "Total test time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
}
