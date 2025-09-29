# Certificate Web Service

**Version:** v2.2.0  
**Regelwerk:** v9.6.2  
**Author:** Flecki (Tom) Garnreiter  

## Overview

The Certificate Web Service provides a high-performance, web-based solution for certificate surveillance across multiple servers. Instead of connecting to each server individually via SSL/TLS, client machines can query this lightweight web service to get certificate information much faster.

## Features

- 🔒 **HTTPS Support** with automatic self-signed certificate generation
- 🌐 **IIS-based** web interface with modern responsive design
- 📊 **Real-time certificate dashboard** with expiration tracking
- 🔧 **REST API** for programmatic access (`/api/certificates.json`)
- 🛡️ **Windows Authentication** for secure access
- 📈 **Performance optimized** with caching and filtering
- 🎨 **Corporate Design** with customizable colors
- 📱 **Mobile-friendly** responsive interface

## Architecture

```
Client (Cert-Surveillance) ──HTTP/HTTPS──► Server (CertWebService) ──Local──► Certificate Store
                                                   │
                                                   ├─ IIS Website
                                                   ├─ JSON API
                                                   └─ HTML Dashboard
```

## Installation

### Prerequisites

- Windows Server 2012 R2+ or Windows 8.1+
- PowerShell 5.1+ (compatible with 5.1 and 7.x according to MUW-Regelwerk v9.6.2)
- Administrator privileges
- IIS features (automatically installed if missing)

### Deployment Steps

1. **Copy Project to Server**
   ```powershell
   # Copy entire CertWebService folder to target server
   Copy-Item "C:\Source\CertWebService" "C:\Script\CertWebService" -Recurse
   ```

2. **Run Installation**
   ```powershell
   cd "C:\Script\CertWebService"
   .\Setup.ps1
   
   # Or with custom settings
   .\Setup.ps1 -Port 8080 -SecurePort 8443
   ```

3. **Verify Installation**
   - HTTP: `http://servername:8080`
   - HTTPS: `https://servername:8443`
   - API: `https://servername:8443/api/certificates.json`

## Configuration

### Main Configuration (`Config\Config-CertWebService.json`)

```json
{
  "WebService": {
    "SiteName": "CertificateSurveillance",
    "HttpPort": 8080,
    "HttpsPort": 8443
  },
  "Certificate": {
    "ValidityDays": 365,
    "FilterMicrosoft": true,
    "FilterRootCerts": true
  },
  "Security": {
    "EnableWindowsAuth": true,
    "AllowedGroups": ["Domain Admins", "Administrators"]
  }
}
```

### Localization

- **English:** `Config\en-US.json`
- **German:** `Config\de-DE.json`

## Usage

### Manual Update

```powershell
.\Update.ps1

# Force update with cache bypass
.\Update.ps1 -Force -SkipCache
```

### Scheduled Updates

Create a Windows scheduled task to run updates automatically:

```powershell
# Create daily update task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Script\CertWebService\Update-CertificateWebService.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -TaskName "Certificate Web Service Update" -Action $action -Trigger $trigger -Principal $principal
```

### API Usage

#### Get All Certificates (JSON)

```powershell
$response = Invoke-RestMethod -Uri "https://servername:8443/api/certificates.json" -UseDefaultCredentials
Write-Host "Found $($response.CertificateCount) certificates"
```

#### Filter Expiring Certificates

```powershell
$certs = (Invoke-RestMethod -Uri "https://servername:8443/api/certificates.json" -UseDefaultCredentials).Certificates
$expiring = $certs | Where-Object { $_.DaysRemaining -le 30 }
```

## Integration with Cert-Surveillance

### Performance Comparison

| Method | Time per Server | 100 Servers | 1000 Servers |
|--------|----------------|-------------|--------------|
| Direct SSL | 2-5 seconds | 3-8 minutes | 30-80 minutes |
| Web Service | 0.1-0.3 seconds | 10-30 seconds | 1-5 minutes |

### Implementation Example

```powershell
# Instead of direct SSL connection:
# $cert = Get-RemoteCertificate -ServerName $server -Port 443

# Use web service API:
$certData = Invoke-RestMethod -Uri "https://$server:8443/api/certificates.json" -UseDefaultCredentials
$serverCerts = $certData.Certificates | Where-Object { $_.Subject -like "*$server*" }
```

## File Structure

```
CertWebService/
├── Install-CertificateWebService.ps1    # Main installation script
├── Update-CertificateWebService.ps1     # Content update script
├── README.md                            # This documentation
├── Config/
│   ├── Config-CertWebService.json       # Main configuration
│   ├── en-US.json                       # English localization
│   └── de-DE.json                       # German localization
├── Modules/
│   ├── FL-Config.psm1                   # Configuration management
│   ├── FL-Logging.psm1                  # Logging functions
│   └── FL-WebService.psm1               # Core web service functions
└── LOG/                                 # Log files directory
```

## Security Considerations

### Self-Signed Certificate

- Automatically added to **Trusted Root Certification Authorities**
- Valid for 365 days (configurable)
- Subject name matches server hostname

### Authentication

- **Windows Authentication** enabled by default
- **Anonymous Authentication** disabled
- Configurable allowed groups in `Config-CertWebService.json`

### Firewall

- Automatic firewall rules creation for HTTP/HTTPS ports
- Rules named: `CertSurveillance HTTP (8080)` and `CertSurveillance HTTPS (8443)`

## Troubleshooting

### Common Issues

1. **IIS Features Missing**
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All
   ```

2. **Certificate Binding Failed**
   ```powershell
   # Check existing certificates
   Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*$env:COMPUTERNAME*" }
   ```

3. **Firewall Blocking Access**
   ```powershell
   # Check firewall rules
   Get-NetFirewallRule -DisplayName "*CertSurveillance*"
   ```

4. **Authentication Issues**
   ```powershell
   # Test with PowerShell
   Invoke-RestMethod -Uri "https://servername:8443/api/certificates.json" -UseDefaultCredentials
   ```

### Log Files

- Installation: `LOG\DEV_Install-CertWebService_yyyy-MM-dd.log`
- Updates: `LOG\DEV_Update-CertWebService_yyyy-MM-dd.log`
- Windows Event Log: Application → CertificateWebService

## Performance Tuning

### Cache Settings

```json
{
  "Performance": {
    "CacheEnabled": true,
    "CacheDurationMinutes": 15,
    "MaxCertificatesPerPage": 100
  }
}
```

### Update Frequency

- **Development:** Every 15 minutes
- **Production:** Every 60 minutes  
- **Critical environments:** Every 5 minutes

## Scheduled Updates

### Automatic Task Scheduler Setup

The web service includes automatic daily updates via Windows Task Scheduler at 17:00 (5:00 PM).

#### Install Scheduled Task

```powershell
# Install daily update task
.\Install-CertWebServiceTask.ps1

# Preview what would be done
.\Install-CertWebServiceTask.ps1 -WhatIf
```

#### Manage Scheduled Task

```powershell
# Check task status
.\Manage-CertWebServiceTask.ps1 -Action Status

# Start task manually
.\Manage-CertWebServiceTask.ps1 -Action Start

# Enable/disable task
.\Manage-CertWebServiceTask.ps1 -Action Enable
.\Manage-CertWebServiceTask.ps1 -Action Disable

# View task history
.\Manage-CertWebServiceTask.ps1 -Action History

# Remove task
.\Manage-CertWebServiceTask.ps1 -Action Remove
```

#### Task Configuration

- **Task Name:** `CertWebService-DailyUpdate`
- **Schedule:** Daily at 17:00 (5:00 PM)
- **User:** SYSTEM (highest privileges)
- **Script:** `Update-CertificateWebService.ps1`
- **Logging:** `LOG\TASK_Update-CertWebService_yyyy-MM-dd.log`

#### Manual Updates

```powershell
# Manual update (respects cache)
.\Update-CertificateWebService.ps1

# Force update (ignores cache)
.\Update-CertificateWebService.ps1 -Force
```

## Maintenance

### Regular Tasks

1. **Monitor log files** for errors
2. **Check certificate expiration** (web service's own certificate)
3. **Review scheduled task status** daily
4. **Update cache settings** as needed
5. **Review security settings** periodically

### Certificate Renewal

The web service's own SSL certificate expires after 365 days. To renew:

```powershell
# Re-run installation to create new certificate
.\Install-CertificateWebService.ps1
```

## Support

For technical support or feature requests, contact the System Administrator or refer to the MUW-Regelwerk v9.3.0 documentation.

---

## Support

For technical support or feature requests, contact the development team or refer to the MUW-Regelwerk v9.6.2 documentation.

**© 2025 Flecki (Tom) Garnreiter | MIT License | MUW-Regelwerk v9.6.2**