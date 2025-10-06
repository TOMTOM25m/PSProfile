Certificate WebService Deployment Package v2.1.0
====================================================

🆕 REGELWERK v9.5.0 COMPLIANT VERSION WITH ROBOCOPY DEPLOYMENT

INSTALLATION INSTRUCTIONS:

1. Copy this folder to the target server (or run from network share)
2. Run as Administrator: Install.bat (RECOMMENDED)
3. Test with: Test.ps1

REQUIREMENTS:
- Windows Server 2012 R2+
- PowerShell 5.1+
- Administrator privileges

NEW in v2.1.0:
+ Regelwerk v9.5.0 Compliance
+ Robocopy Integration with Local Execution
+ Automatic Scheduled Task Creation
+ Enhanced Error Handling & Path Management
+ PowerShell Version Detection
+ Daily Certificate Scan Automation

API ENDPOINTS (after installation):
- http://[SERVER]:9080/certificates.json
- http://[SERVER]:9080/health.json
- http://[SERVER]:9080/summary.json

PORTS:
- 9080 (HTTP)
- 9443 (HTTPS)

AUTOMATIC UPDATES:
- Daily at 6:00 (configurable via Setup-ScheduledTask-CertScan.ps1)
- Manual: C:\inetpub\CertWebService\ScanCertificates.ps1
- Automatic setup during installation

FILES IN THIS PACKAGE:
- Setup.ps1                          : Unified setup script with ALL features (RECOMMENDED)
- Install.bat                        : Robocopy-based installer with local execution
- Test.ps1                           : Comprehensive testing script with port detection
- Setup-ScheduledTask-CertScan.ps1   : Daily certificate scan task setup
- VERSION.txt                        : Package version information
- README.txt                         : This file

RECOMMENDED INSTALLATION:
Use Install.bat for full Regelwerk v9.5.0 compliance with robocopy deployment

NEW FEATURES:
+ Local execution (files copied to C:\Temp\CertWebService-Install)
+ Automatic cleanup after installation
+ Integrated scheduled task setup

INSTALLATION PROCESS:
1. IIS features are installed automatically
2. WebService directory created: C:\inetpub\CertWebService
3. IIS site "CertWebService" created on ports 9080/9443
4. Firewall rules added for ports 9080 and 9443
5. Scheduled task created for automatic certificate updates
6. Initial certificate scan performed

INTEGRATION WITH CERTIFICATE SURVEILLANCE:
The Certificate Surveillance System will automatically detect 
and use the WebService API for fast certificate retrieval.

TROUBLESHOOTING:
- Check IIS: Get-Service W3SVC
- Check site: Get-IISSite -Name "CertWebService"  
- Check firewall: Test-NetConnection localhost -Port 9080
- Manual update: C:\inetpub\CertWebService\Update-CertificateData.ps1

SUPPORT:
- IT Systems Management
- Server: itscmgmt03.srv.meduniwien.ac.at

VERSION: v2.1.0
BUILD DATE: 2025-09-24
AUTHOR: Flecki (Tom) Garnreiter