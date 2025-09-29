# Configuration Management Module for Certificate Web Service (Regelwerk v9.6.2)
# Provides centralized configuration loading and management
# Compatible with PowerShell 5.1 and 7.x

function Get-WebServiceConfiguration {
    param(
        [string]$ConfigPath = "Config\Settings.json"
    )
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Verbose "Configuration loaded from: $ConfigPath"
        return $config
    } catch {
        throw "Failed to parse configuration file: $_"
    }
}

function Get-LocalizationData {
    param(
        [string]$Language = "English",
        [string]$ConfigDir = "Config"
    )
    
    $langFile = Join-Path $ConfigDir "$Language.json"
    
    if (-not (Test-Path $langFile)) {
        Write-Warning "Language file not found: $langFile. Using English defaults."
        $langFile = Join-Path $ConfigDir "English.json"
    }
    
    if (Test-Path $langFile) {
        try {
            $localization = Get-Content $langFile -Raw | ConvertFrom-Json
            Write-Verbose "Localization loaded: $Language"
            return $localization
        } catch {
            Write-Warning "Failed to parse language file: $_"
        }
    }
    
    # Return minimal English defaults if all else fails
    return @{
        WebService = @{
            Title = "Certificate Web Service"
            Description = "Certificate surveillance dashboard"
        }
        Messages = @{
            Loading = "Loading..."
            Error = "Error"
            NoData = "No data available"
        }
    }
}

function Test-ConfigurationIntegrity {
    param([object]$Config)
    
    $requiredSettings = @(
        'SiteName',
        'WebService.HttpPort',
        'WebService.HttpsPort'
    )
    
    $issues = @()
    
    foreach ($setting in $requiredSettings) {
        $parts = $setting -split '\.'
        $current = $Config
        
        foreach ($part in $parts) {
            if ($current -and $current.PSObject.Properties[$part]) {
                $current = $current.$part
            } else {
                $issues += "Missing configuration: $setting"
                break
            }
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Warning "Configuration issues found:"
        $issues | ForEach-Object { Write-Warning "  - $_" }
        return $false
    }
    
    return $true
}

function Update-ConfigurationVersion {
    param(
        [string]$ConfigPath,
        [string]$NewVersion,
        [string]$NewRegelwerk
    )
    
    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.ScriptVersion = $NewVersion
            $config.RulebookVersion = $NewRegelwerk
            $config | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8
            Write-Verbose "Configuration version updated to $NewVersion"
        } catch {
            Write-Warning "Failed to update configuration version: $_"
        }
    }
}

Export-ModuleMember -Function Get-WebServiceConfiguration, Get-LocalizationData, Test-ConfigurationIntegrity, Update-ConfigurationVersion