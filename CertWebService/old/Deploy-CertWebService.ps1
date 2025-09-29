#requires -Version 5.1

<#
.SYNOPSIS
    Certificate Web Service Deployment Helper
.DESCRIPTION
    Assists with copying and deploying the Certificate Web Service to remote servers.
    This script helps prepare the deployment package and provides deployment instructions.
.PARAMETER TargetPath
    Local path where deployment package should be created
.PARAMETER CreateZip
    Creates a ZIP package for easy transfer
.EXAMPLE
    .\Deploy-CertWebService.ps1 -TargetPath "C:\Deployment" -CreateZip
.AUTHOR
    System Administrator
.VERSION
    v1.0.0
.RULEBOOK
    v9.3.0
#>

#----------------------------------------------------------[Parameters]----------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "C:\Deployment\CertWebService",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateZip
)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$Global:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:ScriptVersion = "v1.0.0"

#----------------------------------------------------------[Functions]----------------------------------------------------------

function Show-DeploymentBanner {
    $banner = @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                Certificate Web Service Deployment Helper                    ║
║                                                                              ║
║  Prepares deployment package for Certificate Web Service installation       ║
║  Version: $Global:ScriptVersion                                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Green
}

#----------------------------------------------------------[Main Execution]----------------------------------------------------------

try {
    Show-DeploymentBanner
    
    Write-Host "📦 Preparing Certificate Web Service deployment package..." -ForegroundColor Cyan
    Write-Host "   Source: $Global:ScriptDirectory" -ForegroundColor Gray
    Write-Host "   Target: $TargetPath" -ForegroundColor Gray
    
    # Create target directory
    if (Test-Path $TargetPath) {
        Write-Host "   🗑️ Removing existing deployment directory..." -ForegroundColor Yellow
        Remove-Item $TargetPath -Recurse -Force
    }
    
    Write-Host "   📁 Creating deployment directory..." -ForegroundColor Yellow
    New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
    
    # Copy files (exclude logs and git files)
    Write-Host "   📋 Copying project files..." -ForegroundColor Yellow
    
    $excludePatterns = @('LOG', '.git', '.gitignore', '*.zip', 'Deploy-CertWebService.ps1')
    
    Get-ChildItem -Path $Global:ScriptDirectory -Recurse | ForEach-Object {
        $shouldExclude = $false
        $relativePath = $_.FullName.Substring($Global:ScriptDirectory.Length + 1)
        
        foreach ($pattern in $excludePatterns) {
            if ($relativePath -like "*$pattern*") {
                $shouldExclude = $true
                break
            }
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
    
    # Create ZIP package if requested
    if ($CreateZip) {
        $zipPath = "$TargetPath.zip"
        Write-Host "   📦 Creating ZIP package..." -ForegroundColor Yellow
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Compress-Archive -Path $TargetPath -DestinationPath $zipPath -Force
        Write-Host "   [SUCCESS] ZIP package created: $zipPath" -ForegroundColor Green
    }
    
    # Display deployment instructions
    Write-Host "`n📋 Deployment Instructions:" -ForegroundColor Cyan
    Write-Host "   1. Copy the deployment package to target server(s)" -ForegroundColor White
    if ($CreateZip) {
        Write-Host "      • Transfer: $zipPath" -ForegroundColor Gray
        Write-Host "      • Extract to: C:\Scripts\CertWebService" -ForegroundColor Gray
    } else {
        Write-Host "      • Copy folder: $TargetPath" -ForegroundColor Gray
        Write-Host "      • To server: C:\Scripts\CertWebService" -ForegroundColor Gray
    }
    Write-Host "   2. Open PowerShell as Administrator on target server" -ForegroundColor White
    Write-Host "   3. Navigate to: C:\Scripts\CertWebService" -ForegroundColor White
    Write-Host "   4. Run: .\Install-CertificateWebService.ps1" -ForegroundColor White
    Write-Host "   5. Test access via browser or API" -ForegroundColor White
    
    Write-Host "`n Package Contents:" -ForegroundColor Cyan
    Get-ChildItem -Path $TargetPath -Recurse | ForEach-Object {
        if ($_.PSIsContainer) {
            Write-Host "   📁 $($_.Name)/" -ForegroundColor Yellow
        } else {
            Write-Host "   📄 $($_.Name)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n[SUCCESS] Deployment package prepared successfully!" -ForegroundColor Green
    Write-Host "   Ready to deploy to servers for enhanced certificate surveillance performance." -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Deployment preparation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# --- End of Script --- old: v1.0.0 ; now: v1.0.0 ; Regelwerk: v9.3.0 ---