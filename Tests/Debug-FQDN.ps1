# Quick FQDN Debug Test
# Purpose: Test why FQDN construction is not working
# Author: Certificate Surveillance System
# Date: September 9, 2025

param(
    [string]$ExcelPath = "f:\DEV\repositories\test-single-server.xlsx"
)

# Import required modules
$ModulePath = "f:\DEV\repositories\CertSurv\Modules"
Import-Module "$ModulePath\FL-Config.psm1" -Force
Import-Module "$ModulePath\FL-NetworkOperations.psm1" -Force

Write-Host "=== FQDN Debug Test ===" -ForegroundColor Green

# Load config
$Config = Get-Configuration -ConfigPath "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
Write-Host "Main Domain: $($Config.MainDomain)" -ForegroundColor Yellow
Write-Host "FQDN Column: $($Config.Excel.FqdnColumnName)" -ForegroundColor Yellow
Write-Host "Server Column: $($Config.Excel.ServerNameColumnName)" -ForegroundColor Yellow

# Open Excel
try {
    $ExcelApp = New-Object -ComObject Excel.Application
    $ExcelApp.Visible = $false
    $ExcelApp.DisplayAlerts = $false
    
    $Workbook = $ExcelApp.Workbooks.Open($ExcelPath)
    $Worksheet = $Workbook.ActiveSheet
    
    Write-Host "`nChecking first 5 data rows..." -ForegroundColor Cyan
    
    for ($row = 2; $row -le 6; $row++) {
        $serverName = $Worksheet.Cells.Item($row, $Config.Excel.ServerNameColumn).Value2
        $existingFqdn = $Worksheet.Cells.Item($row, $Config.Excel.FqdnColumn).Value2
        
        if ($serverName) {
            Write-Host "`n[ROW $row] Server: '$serverName'" -ForegroundColor White
            Write-Host "  Existing FQDN: '$existingFqdn'" -ForegroundColor Gray
            
            # Test our logic
            $cleanName = Format-ServerName -ServerName $serverName
            $currentSubdomain = ""  # Simulate empty subdomain
            $workgroupSubdomain = if ([string]::IsNullOrWhiteSpace($currentSubdomain)) { "SRV" } else { $currentSubdomain }
            
            Write-Host "  Clean Name: '$cleanName'" -ForegroundColor Gray
            Write-Host "  Current Subdomain: '$currentSubdomain'" -ForegroundColor Gray
            Write-Host "  Workgroup Subdomain: '$workgroupSubdomain'" -ForegroundColor Gray
            
            # Test FQDN construction logic
            if ($existingFqdn -and -not [string]::IsNullOrWhiteSpace($existingFqdn)) {
                Write-Host "  [EXISTING] Using existing FQDN: '$existingFqdn'" -ForegroundColor Red
                
                # Check if it needs SRV subdomain
                if ($existingFqdn -match "^([^.]+)\.($([regex]::Escape($Config.MainDomain)))$") {
                    $newFqdn = Build-IntelligentFQDN -ServerName $cleanName -Subdomain $workgroupSubdomain -MainDomain $Config.MainDomain
                    Write-Host "  [REBUILD] Should be rebuilt to: '$newFqdn'" -ForegroundColor Yellow
                } else {
                    Write-Host "  [KEEP] Already has subdomain, keeping: '$existingFqdn'" -ForegroundColor Green
                }
            } else {
                $newFqdn = Build-IntelligentFQDN -ServerName $cleanName -Subdomain $workgroupSubdomain -MainDomain $Config.MainDomain
                Write-Host "  [NEW] Building new FQDN: '$newFqdn'" -ForegroundColor Green
            }
        }
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($Workbook) { $Workbook.Close($false) }
    if ($ExcelApp) { $ExcelApp.Quit() }
}

Write-Host "`n=== Debug Complete ===" -ForegroundColor Green
