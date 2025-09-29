#requires -Version 5.1
# Certificate Web Service Deployment Helper v1.0.3

[CmdletBinding()]
param(
    [string]$TargetPath = "C:\Deployment\CertWebService",
    [switch]$CreateZip
)

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    Write-Host "Certificate Web Service Deployment Helper" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    Write-Host "Preparing deployment package..." -ForegroundColor Cyan
    Write-Host "Source: $ScriptDirectory" -ForegroundColor Gray
    Write-Host "Target: $TargetPath" -ForegroundColor Gray
    
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
    
    # Create ZIP if requested
    if ($CreateZip) {
        $zipPath = "$TargetPath.zip"
        Write-Host "Creating ZIP package..." -ForegroundColor Yellow
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Compress-Archive -Path $TargetPath -DestinationPath $zipPath -Force
        Write-Host "ZIP created: $zipPath" -ForegroundColor Green
    }
    
    # Show instructions
    Write-Host ""
    Write-Host "Deployment Instructions:" -ForegroundColor Cyan
    Write-Host "1. Copy package to target server" -ForegroundColor White
    if ($CreateZip) {
        Write-Host "   Transfer: $zipPath" -ForegroundColor Gray
    } else {
        Write-Host "   Copy: $TargetPath" -ForegroundColor Gray
    }
    Write-Host "2. Extract to: C:\Script\CertWebService" -ForegroundColor White
    Write-Host "3. Run as Administrator:" -ForegroundColor White
    Write-Host "   .\Install-CertificateWebService.ps1" -ForegroundColor Gray
    Write-Host "4. Setup task scheduler:" -ForegroundColor White
    Write-Host "   .\Install-CertWebServiceTask.ps1" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Deployment package ready!" -ForegroundColor Green
}
catch {
    Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}