# PowerShell Execution Policy Problem - SOLUTIONS

## Problem:
```
File cannot be loaded. The file is not digitally signed. 
You cannot run this script on the current system.
```

## Root Cause:
PowerShell Execution Policy blocks unsigned scripts from network locations (UNC paths).

## SOLUTION OPTIONS:

### Option 1: Bypass Execution Policy (Recommended)
```powershell
# Method 1: Direct bypass for single execution
powershell.exe -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\CertWebService-Installer.ps1"

# Method 2: Set bypass for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\CertWebService-Installer.ps1

# Method 3: Direct execution with bypass
& {Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; .\CertWebService-Installer.ps1}
```

### Option 2: Copy to Local Drive First
```powershell
# Copy files to local temp directory
$tempDir = "$env:TEMP\CertWebService"
New-Item -Path $tempDir -ItemType Directory -Force
Copy-Item "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\*" $tempDir -Recurse -Force

# Run from local directory (usually allowed)
cd $tempDir
.\CertWebService-Installer.ps1
```

### Option 3: Use Batch Installer (No Execution Policy)
```batch
# Batch files are not affected by PowerShell execution policy
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Install.bat
```

### Option 4: Direct PowerShell Execution
```powershell
# Execute script content directly
$scriptContent = Get-Content "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Setup-Simple.ps1" -Raw
Invoke-Expression $scriptContent
```

## IMMEDIATE SOLUTIONS:

### Quick Fix 1: PowerShell with Bypass
```powershell
powershell.exe -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\CertWebService-Installer.ps1"
```

### Quick Fix 2: Use Batch Installer
```batch
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Install.bat
```

### Quick Fix 3: Process-Level Bypass
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\CertWebService-Installer.ps1
```

## Security Notes:

- **Bypass is Safe**: Only affects current PowerShell session
- **Network Scripts**: UNC paths have stricter security policies
- **Batch Alternative**: Install.bat bypasses PowerShell restrictions entirely
- **Temporary**: No permanent system changes required

## Current System Status:
```
Execution Policy: Restricted for network scripts
Recommended Solution: Use Batch installer or PowerShell with -ExecutionPolicy Bypass
```

---
**QUICK START: Run Install.bat (No execution policy issues)**