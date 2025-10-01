# PowerShell Version-Specific Scripts

This directory contains deployment scripts optimized for specific PowerShell versions.

## 📁 Directory Structure

```
PowerShell-Versions/
├── Deploy-CertWebService-PS5.ps1     # PowerShell 5.1 compatible server deployment
├── Deploy-CertWebService-PS7.ps1     # PowerShell 7+ server deployment  
├── Deploy-FromExcel-PS5.ps1          # PowerShell 5.1 Excel-based deployment
├── Deploy-FromExcel-PS7.ps1          # PowerShell 7+ Excel-based deployment
└── README.md                         # This file
```

## 🚀 Usage

### Option 1: Direct Script Execution
```powershell
# PowerShell 5.1
.\PowerShell-Versions\Deploy-CertWebService-PS5.ps1

# PowerShell 7+
.\PowerShell-Versions\Deploy-CertWebService-PS7.ps1

# Excel-based deployment
.\PowerShell-Versions\Deploy-FromExcel-PS5.ps1
.\PowerShell-Versions\Deploy-FromExcel-PS7.ps1
```

### Option 2: Global Launcher (Recommended)
```powershell
# Auto-detect PowerShell version and launch appropriate script
.\Deploy-Launcher.ps1 -Mode Server
.\Deploy-Launcher.ps1 -Mode Excel

# Force specific PowerShell version
.\Deploy-Launcher.ps1 -Mode Server -ForcePS5
.\Deploy-Launcher.ps1 -Mode Excel -ForcePS7

# Show available scripts
.\Deploy-Launcher.ps1 -ShowScripts
```

## 📋 Script Differences

### PowerShell 5.1 Scripts
- ✅ ASCII output (no emojis)
- ✅ Compatible with Windows PowerShell 5.1
- ✅ Uses traditional cmdlets and syntax
- ✅ Optimized for older Windows Server environments

### PowerShell 7+ Scripts  
- 🎨 Enhanced Unicode output with emojis
- ⚡ Improved performance and parallel processing
- 🔧 Modern PowerShell Core features
- 🌐 Cross-platform compatibility

## 🔧 Path Configuration

All scripts automatically detect the parent directory structure:
- `$ScriptDir` points to the main CertWebService directory
- Module paths are resolved relative to parent directory
- Configuration files are accessed from `../Config/`
- CrossUse modules loaded from `../CertSurv/Modules/`

## 🌐 Global Access

The deployment configuration in `Config/Config-CertWebService.json` includes:

```json
{
  "Deployment": {
    "PowerShellVersionsPath": "PowerShell-Versions",
    "PS5ScriptPath": "PowerShell-Versions\\Deploy-CertWebService-PS5.ps1",
    "PS7ScriptPath": "PowerShell-Versions\\Deploy-CertWebService-PS7.ps1",
    "ExcelPS5ScriptPath": "PowerShell-Versions\\Deploy-FromExcel-PS5.ps1",
    "ExcelPS7ScriptPath": "PowerShell-Versions\\Deploy-FromExcel-PS7.ps1",
    "GlobalAccess": true,
    "Description": "PowerShell version-specific deployment scripts organized in subfolder"
  }
}
```

## 🔗 CrossUse Integration

All scripts maintain compatibility with the CrossUse architecture:
- FL-FastServerProcessing module loaded from CertSurv
- Automatic update detection capabilities
- Parallel processing for improved performance
- Shared credential management system

## 📊 Performance Benefits

- **Organization**: Clean separation of PowerShell versions
- **Maintenance**: Easier to maintain version-specific features
- **Compatibility**: No conflicts between PowerShell versions
- **Flexibility**: Choose the right tool for your environment

## 🎯 Recommended Usage

1. **ITSC020 Workstation**: Use PowerShell 7+ scripts for modern features
2. **Legacy Servers**: Use PowerShell 5.1 scripts for compatibility
3. **Mixed Environments**: Use Deploy-Launcher.ps1 for automatic detection
4. **Excel Deployments**: Choose based on your PowerShell version

## 🚨 Important Notes

- All scripts have been updated to reference parent directory paths
- Configuration files remain in the main Config/ directory
- Module dependencies are resolved correctly
- CrossUse functionality is preserved across all versions