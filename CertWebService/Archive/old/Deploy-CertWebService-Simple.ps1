#requires -Version 5.1

<#
.SYNOPSIS
    Certificate Web Service Deployment Helper
.DESCRIPTION
    Prepares deployment package for Certificate Web Service
.PARAMETER TargetPath
    Target deployment directory
.PARAMETER CreateZip
    Creates ZIP package
.EXAMPLE
    .\Deploy-CertWebService.ps1 -CreateZip
.VERSION
    v1.0.2
.RULEBOOK
    v9.3.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "C:\Deployment\CertWebService",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateZip
)

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptVersion = "v1.0.2"

function Show-DeploymentBanner {
    Write-Host ""
    Write-Host "Certificate Web Service Deployment Helper $ScriptVersion" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
}

try {
    Show-DeploymentBanner
    
    Write-Host "📦 Preparing deployment package..." -ForegroundColor Cyan
    Write-Host "   Source: $ScriptDirectory" -ForegroundColor Gray
    Write-Host "   Target: $TargetPath" -ForegroundColor Gray
    
    # Remove existing target
    if (Test-Path $TargetPath) {
        Write-Host "   🗑️ Removing existing directory..." -ForegroundColor Yellow
        Remove-Item $TargetPath -Recurse -Force
    }
    
    # Create target directory
    Write-Host "   📁 Creating target directory..." -ForegroundColor Yellow
    New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
    
    # Copy files
    Write-Host "   📋 Copying files..." -ForegroundColor Yellow
    
    $excludeItems = @('LOG', '.git', '.gitignore', '*.zip')
    
    Get-ChildItem -Path $ScriptDirectory -Recurse | ForEach-Object {
        $shouldExclude = $false
        $relativePath = $_.FullName.Substring($ScriptDirectory.Length + 1)
        
        foreach ($pattern in $excludeItems) {
            if ($relativePath -like "*$pattern*") {
                $shouldExclude = $true
                break
            }
        }
        
        # Exclude this deployment script itself
        if ($_.Name -eq "Deploy-CertWebService.ps1") {
            $shouldExclude = $true
        }
        
        if (-not $shouldExclude) {
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
    
    Write-Host "   [SUCCESS] Files copied successfully" -ForegroundColor Green
    
    # Create ZIP if requested
    if ($CreateZip) {
        $zipPath = "$TargetPath.zip"
        Write-Host "   📦 Creating ZIP package..." -ForegroundColor Yellow
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Compress-Archive -Path $TargetPath -DestinationPath $zipPath -Force
        Write-Host "   [SUCCESS] ZIP created: $zipPath" -ForegroundColor Green
    }
    
    # Show deployment instructions
    Write-Host ""
    Write-Host "📋 Deployment Instructions:" -ForegroundColor Cyan
    Write-Host "   1. Copy package to target server" -ForegroundColor White
    if ($CreateZip) {
        Write-Host "      Transfer: $zipPath" -ForegroundColor Gray
        Write-Host "      Extract to: C:\Scripts\CertWebService" -ForegroundColor Gray
    } else {
        Write-Host "      Copy: $TargetPath" -ForegroundColor Gray
        Write-Host "      To: C:\Scripts\CertWebService" -ForegroundColor Gray
    }
    Write-Host "   2. Run as Administrator on server:" -ForegroundColor White
    Write-Host "      cd C:\Scripts\CertWebService" -ForegroundColor Gray
    Write-Host "      .\Install-CertificateWebService.ps1" -ForegroundColor Gray
    Write-Host "   3. Setup scheduled task:" -ForegroundColor White
    Write-Host "      .\Install-CertWebServiceTask.ps1" -ForegroundColor Gray
    Write-Host "   4. Test installation:" -ForegroundColor White
    Write-Host "      https://servername:8443" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "[INFO] Package ready!" -ForegroundColor Green
    Write-Host "   Files: $(Get-ChildItem -Path $TargetPath -Recurse | Measure-Object).Count items" -ForegroundColor Gray
    if ($CreateZip) {
        $zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Write-Host "   ZIP size: $zipSize KB" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "[SUCCESS] Deployment package ready!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# End of Script - v1.0.2 - Regelwerk v9.3.0