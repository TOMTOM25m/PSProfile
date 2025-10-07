<#
.SYNOPSIS
    Simple Credential Setup v1.0.0
    
.DESCRIPTION
    Einfaches Setup für Domain-Credentials
#>

param([switch]$Setup, [switch]$Test)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CREDENTIAL SETUP v1.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$credPath = "$PSScriptRoot\Credentials"
if (-not (Test-Path $credPath)) {
    New-Item -Path $credPath -ItemType Directory -Force | Out-Null
}

$domains = @{
    "UVW" = @{
        Name = "UVW Domain"
        Servers = @("UVWmgmt01", "UVW-FINANZ01", "UVWDC001")
        CredFile = "$credPath\UVW-Cred.xml"
    }
}

if ($Setup) {
    Write-Host "Setting up domain credentials..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($key in $domains.Keys) {
        $domain = $domains[$key]
        
        Write-Host "[$key] $($domain.Name)" -ForegroundColor Cyan
        Write-Host "Servers: $($domain.Servers -join ', ')" -ForegroundColor Gray
        Write-Host ""
        
        $setup = Read-Host "Setup credentials for $key? (y/N)"
        if ($setup -eq 'y') {
            $username = Read-Host "Username (e.g., UVW\administrator)"
            $cred = Get-Credential -UserName $username -Message "Password for $username"
            
            if ($cred) {
                $cred | Export-CliXml -Path $domain.CredFile
                Write-Host "✓ Credentials saved for $key" -ForegroundColor Green
            } else {
                Write-Host "✗ No credentials provided" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
    Write-Host "Setup completed!" -ForegroundColor Green
    exit 0
}

if ($Test) {
    Write-Host "Testing credentials..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($key in $domains.Keys) {
        $domain = $domains[$key]
        
        Write-Host "Testing $key..." -ForegroundColor Cyan
        
        if (Test-Path $domain.CredFile) {
            try {
                $cred = Import-CliXml -Path $domain.CredFile
                Write-Host "✓ Loaded: $($cred.UserName)" -ForegroundColor Green
                
                # Test connection to first server
                $testServer = "$($domain.Servers[0]).uvw.meduniwien.ac.at"
                $testResult = Test-WSMan -ComputerName $testServer -Credential $cred -ErrorAction SilentlyContinue
                
                if ($testResult) {
                    Write-Host "✓ Connection test passed" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Connection test failed" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "✗ Failed to load credentials" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠ No credentials stored" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    exit 0
}

# Default: Show status
Write-Host "Current status:" -ForegroundColor Yellow
Write-Host ""

foreach ($key in $domains.Keys) {
    $domain = $domains[$key]
    
    Write-Host "[$key] $($domain.Name)" -ForegroundColor Cyan
    if (Test-Path $domain.CredFile) {
        try {
            $cred = Import-CliXml -Path $domain.CredFile
            Write-Host "Status: ✓ Configured ($($cred.UserName))" -ForegroundColor Green
        } catch {
            Write-Host "Status: ✗ Corrupted" -ForegroundColor Red
        }
    } else {
        Write-Host "Status: ⚠ Not configured" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  -Setup : Configure credentials" -ForegroundColor White
Write-Host "  -Test  : Test stored credentials" -ForegroundColor White