# CertWebService v2.3.0 Installation Guide
## UNC Path Support Solutions

### Problem: UNC Path Limitations
```
Error: "UNC paths are not supported. Defaulting to Windows directory."
```
**Root Cause**: Windows CMD.EXE cannot execute batch files directly from UNC paths (network shares).

### Solution 1: Enhanced Batch Installer (Install.bat) ✅

**Features:**
- Automatically copies files to `%TEMP%\CertWebService-Install`
- Executes from local temp directory (bypasses UNC limitation)
- Cleans up temporary files after installation
- Full error handling and status reporting

**Usage:**
```batch
# Run as Administrator from any location:
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Install.bat
```

**Process Flow:**
1. Creates temporary directory: `C:\Users\%USERNAME%\AppData\Local\Temp\CertWebService-Install`
2. Copies `Setup-Simple.ps1` to temp directory
3. Executes PowerShell script from local path
4. Cleans up temporary files
5. Reports installation status

### Solution 2: Native PowerShell Installer (CertWebService-Installer.ps1) ✅

**Advantages:**
- **Native UNC Support**: PowerShell handles UNC paths natively
- **No File Copying**: Executes directly from network location
- **Enhanced UI**: Colored output and better formatting
- **Parameter Support**: Custom port configuration
- **Fixed Website Creation**: Resolved IIS binding issues

**Usage:**
```powershell
# Method 1: Right-click PowerShell -> Run as Administrator
Set-Location "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService"
.\CertWebService-Installer.ps1

# Method 2: Direct execution with full path
powershell.exe -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\CertWebService-Installer.ps1"

# Method 3: Custom port
.\CertWebService-Installer.ps1 -Port 8080
```

### Deployment Status:

```
Network Location: \\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\

✅ Install.bat - Enhanced batch installer with UNC path handling
✅ CertWebService-Installer.ps1 - Native PowerShell installer (FIXED website creation)
✅ Setup-Simple.ps1 - Core installation script (FIXED IIS binding bug)
✅ WebFiles/ - IIS web content
✅ Modules/ - Access control modules
✅ Config/ - IIS configuration
```

### Installation Methods Comparison:

| Method | UNC Support | User Experience | Bug Fixes | Admin Required |
|--------|-------------|-----------------|-----------|----------------|
| **Install.bat** | ✅ (via temp copy) | Good | Enhanced error handling | Yes |
| **CertWebService-Installer.ps1** | ✅ (native) | Excellent | Fixed IIS website creation | Yes |

### Recommended Usage:

#### For IT Administrators:
```powershell
# Preferred method - Native PowerShell (FIXED)
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\CertWebService-Installer.ps1
```

#### For Automated Deployment:
```batch
# Batch method for scripts/automation
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Install.bat
```

### Installation Verification:

After successful installation, verify:

```powershell
# Check IIS Website
Get-Website -Name "CertWebService"

# Test API Endpoints
Invoke-WebRequest http://localhost:9080/health.json
Invoke-WebRequest http://localhost:9080/certificates.json

# Verify Firewall Rule
Get-NetFirewallRule -DisplayName "CertWebService*"

# Check Web Directory
Get-ChildItem "C:\inetpub\wwwroot\CertWebService"
```

### Expected Output:
```
✅ IIS Features: Installed
✅ Website: CertWebService on port 9080
✅ Firewall: Rule created
✅ API Endpoints: certificates.json, health.json, summary.json
✅ Read-Only Mode: Active for 3 authorized servers
```

### Troubleshooting:

#### If installation fails:
1. **Check Administrator Privileges**: Both methods require "Run as Administrator"
2. **Verify PowerShell Version**: Requires PowerShell 5.1 or later
3. **Check Network Access**: Ensure network share is accessible
4. **IIS Availability**: Windows Server/Pro editions with IIS features

#### Common Issues:
- **"UNC paths not supported"**: Use Install-PowerShell.ps1 instead
- **"Access Denied"**: Run as Administrator
- **"Script execution disabled"**: Use `-ExecutionPolicy Bypass`

### Security Notes:

Both installation methods implement:
- ✅ **Read-Only Mode** enforcement
- ✅ **3-Server Authorization** limit
- ✅ **HTTP Method Filtering** (GET/HEAD/OPTIONS only)
- ✅ **Firewall Integration**
- ✅ **IIS Security Headers**