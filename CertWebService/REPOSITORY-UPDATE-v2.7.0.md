# CertWebService Repository Update v2.7.0

## Dual Version Support - PowerShell 7.x UTF-8 Enhanced & PowerShell 5.1 ASCII Compatible

**Date:** 09.10.2025  
**Regelwerk:** v10.1.0 Compliant  
**Status:** Production Ready

### 🎯 **New Versions Available:**

#### **v2.6.0 - PowerShell 7.x UTF-8 Enhanced Edition**

- **File:** `CertWebService-PS7x-Enhanced.ps1`
- **Engine:** PowerShell 7.5.3
- **Encoding:** UTF-8 Enhanced with full Unicode support
- **Features:** Modern PowerShell features, optimal performance
- **Target:** Modern systems requiring UTF-8 support

#### **v2.7.0 - PowerShell 5.1 ASCII Compatible Edition** ⭐ **Recommended for Legacy**

- **File:** `CertWebService-PS51-ASCII.ps1`
- **Engine:** PowerShell 5.1.20348
- **Encoding:** ASCII (ISO-8859-1) - NO UTF-8 dependencies
- **Features:** Maximum compatibility, no emojis, pure ASCII
- **Target:** Legacy systems, maximum compatibility environments

### 🛠️ **Management Tools:**

#### **Dual Version Manager**

- **File:** `Dual-Version-Manager.ps1`
- **Purpose:** PowerShell-based version switching and management
- **Commands:**

  ```powershell
  .\Dual-Version-Manager.ps1 -Action "PS7x-UTF8"    # Switch to PS 7.x
  .\Dual-Version-Manager.ps1 -Action "PS51-ASCII"   # Switch to PS 5.1
  .\Dual-Version-Manager.ps1 -Action "Status"       # Check current status
  .\Dual-Version-Manager.ps1 -Action "Switch"       # Auto switch version
  ```

#### **Interactive Batch Switcher**

- **File:** `Switch-CertWebService.bat`
- **Purpose:** User-friendly interactive version switching
- **Usage:** Double-click to run interactive menu

#### **Repository Cleanup Tool**

- **File:** `Simple-Cleanup-CertWebService.ps1`
- **Purpose:** Professional server directory cleanup and consolidation
- **Features:** Archive old files, maintain core structure

### 📋 **Deployment Instructions:**

#### **1. Choose Your Version:**

- **UTF-8 Support needed?** → Use PowerShell 7.x Enhanced (v2.6.0)
- **Maximum Compatibility?** → Use PowerShell 5.1 ASCII (v2.7.0)

#### **2. Deploy to Server:**

```powershell
# Copy your chosen version to server
Copy-Item "CertWebService-PS7x-Enhanced.ps1" "C:\CertWebService\CertWebService.ps1" -Force
# OR
Copy-Item "CertWebService-PS51-ASCII.ps1" "C:\CertWebService\CertWebService.ps1" -Force

# Copy management tools
Copy-Item "Dual-Version-Manager.ps1" "C:\CertWebService\" -Force
Copy-Item "Switch-CertWebService.bat" "C:\CertWebService\" -Force
```

#### **3. Setup Service:**

```powershell
# For PS 7.x:
.\Dual-Version-Manager.ps1 -Action "PS7x-UTF8"

# For PS 5.1:
.\Dual-Version-Manager.ps1 -Action "PS51-ASCII"
```

### 🌐 **Service Access:**

- **URL:** `http://server:9080`
- **Management:** Windows Scheduled Task
- **Logs:** `C:\CertWebService\Logs\CertWebService.log`

### ✅ **Current Production Status:**

- **Server:** itscmgmt03.srv.meduniwien.ac.at
- **Active Version:** PowerShell 5.1 ASCII Compatible v2.7.0
- **Status:** ✅ Running and stable
- **Encoding Issues:** ✅ Resolved (ASCII-only)
- **Compatibility:** ✅ Maximum (legacy system support)

### 🔄 **Version History:**

- **v2.5.0:** Base version with encoding issues
- **v2.6.0:** PowerShell 7.x UTF-8 Enhanced
- **v2.7.0:** PowerShell 5.1 ASCII Compatible (current production)

### 📞 **Support:**

- Regelwerk v10.1.0 compliant
- Enterprise deployment ready
- Professional cleanup completed
- Dual version management available

---
**Repository updated:** 09.10.2025 14:35 CET  
**Deployment target:** Network share and production servers
