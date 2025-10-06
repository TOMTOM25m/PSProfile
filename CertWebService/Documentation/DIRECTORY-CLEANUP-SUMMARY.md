# CertWebService v2.3.0 - Directory Structure (CLEANED)

## Network Location
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\
```

## 📁 Root Directory (Production Ready)
```
CertWebService/
├── 🚀 CertWebService-Installer.ps1    # Native PowerShell installer (3.9KB)
├── 🚀 Install.bat                     # Batch installer with UNC support (3.3KB)  
├── ⚙️ Setup-Simple.ps1                # Core installation script (9.8KB)
├── 📂 Config/                         # IIS configuration files
├── 📂 Documentation/                  # All documentation (ORGANIZED)
├── 📂 Modules/                        # Access control modules  
├── 📂 Scripts/                        # Utility scripts
├── 📂 WebFiles/                       # IIS web content
└── 📄 README.md                       # Quick start guide
```

## 📚 Documentation/ Directory
```
Documentation/
├── 📖 README.md                       # Original detailed README
├── 🔒 READ-ONLY-ACCESS-GUIDE.md       # Security configuration guide
├── 🛠️ UNC-PATH-INSTALLATION-GUIDE.md  # Installation troubleshooting
└── 📋 VERSION.ps1                     # Version information script
```

## 🧹 Cleanup Actions Performed:

### ✅ Removed:
- ❌ `Setup.ps1` (superseded by Setup-Simple.ps1)  
- ❌ `Install-PowerShell.ps1` (renamed to CertWebService-Installer.ps1)

### ✅ Organized:
- 📁 **Documentation/** - All guides and docs consolidated
- 📄 **README.md** - New quick-start guide in root
- 🏗️ **Clean Structure** - Only essential files in root

### ✅ Maintained:
- ⚙️ **Config/** - IIS configuration files
- 🔧 **Modules/** - Access control modules
- 📜 **Scripts/** - Utility scripts  
- 🌐 **WebFiles/** - IIS web content

## 🎯 Installation Commands:

### PowerShell (Recommended):
```powershell
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\CertWebService-Installer.ps1
```

### Batch:
```batch
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertWebService\Install.bat
```

## 📊 File Summary:
- **Total Files**: 8 (root) + 4 (documentation) = 12 files
- **Installation Scripts**: 2 methods (PowerShell + Batch)
- **Documentation**: 4 comprehensive guides
- **Support Directories**: 4 (Config, Modules, Scripts, WebFiles)

---
**Status: ✅ DIRECTORY CLEANED & ORGANIZED**  
**Ready for Production Deployment**