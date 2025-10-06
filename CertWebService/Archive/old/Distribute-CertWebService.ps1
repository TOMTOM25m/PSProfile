#requires -Version 5.1
# Certificate Web Service Distribution Helper v1.0.0

[CmdletBinding()]
param(
    [string]$TargetPath = "C:\Deployment\CertWebService",
    [string]$DistributionPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertDeployment",
    [switch]$CreateZip = $true
)

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    Write-Host "Certificate Web Service Distribution Helper" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
    
    Write-Host "Preparing deployment package for distribution..." -ForegroundColor Cyan
    Write-Host "Source: $ScriptDirectory" -ForegroundColor Gray
    Write-Host "Target: $TargetPath" -ForegroundColor Gray
    Write-Host "Distribution: $DistributionPath" -ForegroundColor Gray
    
    # Remove existing target
    if (Test-Path $TargetPath) {
        Write-Host "Removing existing directory..." -ForegroundColor Yellow
        Remove-Item $TargetPath -Recurse -Force
    }
    
    # Create target directory
    Write-Host "Creating target directory..." -ForegroundColor Yellow
    New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
    
    # Copy files (exclude logs and git)
    Write-Host "Copying files..." -ForegroundColor Yellow
    
    Get-ChildItem -Path $ScriptDirectory -Recurse | ForEach-Object {
        $shouldCopy = $true
        $relativePath = $_.FullName.Substring($ScriptDirectory.Length + 1)
        
        # Skip LOG directory
        if ($relativePath -like "LOG*") { $shouldCopy = $false }
        # Skip git files
        if ($relativePath -like ".git*") { $shouldCopy = $false }
        # Skip ZIP files
        if ($relativePath -like "*.zip") { $shouldCopy = $false }
        # Skip deployment scripts
        if ($_.Name -like "Deploy-*") { $shouldCopy = $false }
        
        if ($shouldCopy) {
            $targetFile = Join-Path $TargetPath $relativePath
            $targetDir = Split-Path $targetFile -Parent
            
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            
            Copy-Item $_.FullName $targetFile -Force
        }
    }
    
    # Create empty LOG directory
    New-Item -Path (Join-Path $TargetPath "LOG") -ItemType Directory -Force | Out-Null
    
    Write-Host "Files copied successfully" -ForegroundColor Green
    
    # Create ZIP package
    if ($CreateZip) {
        $zipPath = "$TargetPath.zip"
        Write-Host "Creating ZIP package..." -ForegroundColor Yellow
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Compress-Archive -Path $TargetPath -DestinationPath $zipPath -Force
        Write-Host "ZIP created: $zipPath" -ForegroundColor Green
        
        # Test distribution path accessibility
        Write-Host "Testing distribution path access..." -ForegroundColor Yellow
        if (Test-Path $DistributionPath) {
            Write-Host "Distribution path accessible" -ForegroundColor Green
            
            # Copy to distribution location
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
            $distributionZip = Join-Path $DistributionPath "CertWebService_$timestamp.zip"
            
            Write-Host "Copying to distribution location..." -ForegroundColor Yellow
            Copy-Item $zipPath $distributionZip -Force
            Write-Host "Distribution package created: $distributionZip" -ForegroundColor Green
            
            # Also create a "latest" version
            $latestZip = Join-Path $DistributionPath "CertWebService_Latest.zip"
            Copy-Item $zipPath $latestZip -Force
            Write-Host "Latest package updated: $latestZip" -ForegroundColor Green
            
            # Copy deployment README
            $deploymentReadme = Join-Path $ScriptDirectory "DEPLOYMENT-README.md"
            if (Test-Path $deploymentReadme) {
                $targetReadme = Join-Path $DistributionPath "README.md"
                Copy-Item $deploymentReadme $targetReadme -Force
                Write-Host "Deployment guide updated: $targetReadme" -ForegroundColor Green
            }
            
        } else {
            Write-Host "Warning: Distribution path not accessible!" -ForegroundColor Red
            Write-Host "Please manually copy: $zipPath" -ForegroundColor Yellow
            Write-Host "To: $DistributionPath" -ForegroundColor Yellow
        }
    }
    
    # Show deployment instructions
    Write-Host ""
    Write-Host "Distribution Instructions:" -ForegroundColor Cyan
    Write-Host "1. Package is ready on distribution server:" -ForegroundColor White
    Write-Host "   $DistributionPath\CertWebService_Latest.zip" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. On each target server, run as Administrator:" -ForegroundColor White
    Write-Host "   # Download and extract" -ForegroundColor Gray
    Write-Host "   Copy-Item '$DistributionPath\CertWebService_Latest.zip' 'C:\Temp\' -Force" -ForegroundColor Gray
    Write-Host "   Expand-Archive 'C:\Temp\CertWebService_Latest.zip' 'C:\Script\' -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   # Install WebService" -ForegroundColor Gray
    Write-Host "   cd 'C:\Script\CertWebService'" -ForegroundColor Gray
    Write-Host "   .\Install-CertificateWebService.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   # Setup daily updates" -ForegroundColor Gray
    Write-Host "   .\Install-CertWebServiceTask.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Test installation:" -ForegroundColor White
    Write-Host "   https://servername:8443" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Automated Deployment Script:" -ForegroundColor Cyan
    Write-Host "For multiple servers, use this PowerShell script:" -ForegroundColor Gray
    Write-Host ""
    $deployScript = @"
# Multi-Server Deployment Script
`$servers = @('server1', 'server2', 'server3')
`$distributionZip = '$DistributionPath\CertWebService_Latest.zip'

foreach (`$server in `$servers) {
    Write-Host "Deploying to `$server..." -ForegroundColor Cyan
    
    # Copy ZIP to server
    Copy-Item `$distributionZip "\\`$server\C`$\Temp\" -Force
    
    # Remote installation
    Invoke-Command -ComputerName `$server -ScriptBlock {
        # Extract
        Expand-Archive 'C:\Temp\CertWebService_Latest.zip' 'C:\Script\' -Force
        
        # Install
        Set-Location 'C:\Script\CertWebService'
        .\Install-CertificateWebService.ps1
        .\Install-CertWebServiceTask.ps1
    }
    
    Write-Host "Deployment to `$server completed" -ForegroundColor Green
}
"@
    
    Write-Host $deployScript -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Distribution package ready for enterprise deployment!" -ForegroundColor Green
}
catch {
    Write-Host "Distribution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}