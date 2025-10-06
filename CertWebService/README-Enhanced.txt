Certificate WebService v2.3.0 - Enhanced Network Deployment
==========================================================

🚀 ENHANCED FEATURES (with Scheduled Task Support):
✅ Automatic Certificate Scanning via Scheduled Task
✅ Daily certificate data updates (06:00)
✅ Network Share Deployment Strategy
✅ Automatic IIS Configuration
✅ JSON API Endpoints
✅ Modern HTML Dashboard
✅ CertSurv Integration Ready
✅ PowerShell 5.1/7.x Compatible

INSTALLATION:
=============
1. Run as Administrator: Install.bat
2. Test: Test.ps1
3. Access: http://SERVER:9080/

ENHANCED FEATURES:
==================
✅ Automatic daily certificate discovery
✅ Scheduled task runs at 06:00 daily
✅ Certificate data automatically updated
✅ Log files in C:\inetpub\CertWebService\Logs\
✅ Health monitoring with scan status

API ENDPOINTS:
==============
- GET /certificates.json (Updated daily via scheduled task)
- GET /health.json (Real-time health and scan status)
- GET /summary.json (Certificate statistics)

INTEGRATION:
============
Works seamlessly with Certificate Surveillance System (CertSurv):
- CertSurv collects data via API endpoints
- Automatic certificate discovery keeps data fresh
- Scheduled tasks ensure regular updates
- Enterprise monitoring ready

FILES INCLUDED:
===============
- Install.bat (Enhanced installer with scheduled task)
- Setup.ps1 (Main installation script)
- Setup-ScheduledTask-CertScan.ps1 (Task scheduler setup)
- ScanCertificates.ps1 (Daily certificate scan script)
- Test.ps1 (Installation testing)
- README.txt (This file)
- VERSION.txt (Version information)

SCHEDULED TASK DETAILS:
=======================
Task Name: CertWebService-DailyCertScan
Schedule: Daily at 06:00
User: SYSTEM account
Action: Scans local certificate stores and updates JSON files
Logs: C:\inetpub\CertWebService\Logs\CertScan_YYYY-MM-DD.log

TROUBLESHOOTING:
================
❌ Installation fails:
   - Ensure Administrator privileges
   - Check PowerShell execution policy
   - Verify IIS is available

❌ Scheduled task fails:
   - Check C:\inetpub\CertWebService\Logs\ for details
   - Verify SYSTEM account has access to certificate stores
   - Ensure ScanCertificates.ps1 exists in site directory

❌ API endpoints not responding:
   - Check Windows Firewall rules
   - Verify IIS site is running
   - Test with: Test.ps1

VERSION: v2.3.0 (Enhanced)
BUILD: $(Get-Date -Format 'yyyy-MM-dd')
COMPLIANCE: Regelwerk v10.0.0
FEATURES: Network Deployment + Scheduled Tasks