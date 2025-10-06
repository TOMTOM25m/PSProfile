# 🧹 REPOSITORY CLEANUP STRATEGY

## F:\DEV\repositories Aufräumung

### 📊 CURRENT STATUS (06.10.2025)

- **Total Items:** ~50+ files/folders scattered
- **Problem:** No clear organization, duplicate scripts, mixed purposes
- **Solution:** Systematic categorization and cleanup

---

## 🎯 CLEANUP PLAN

### 1️⃣ **PRESERVED REPOSITORIES** (Already organized)

✅ **CertSurv/** - Certificate Surveillance (well organized)
✅ **CertWebService/** - Web Service (recently cleaned up)
✅ **PSProfile/** - PowerShell Profile Management
✅ **EVASYS/** - EVASYS Integration
✅ **Useranlage/** - User Management
✅ **ResetProfile/** - Profile Reset Tools
✅ **DirectoryPermissionAudit/** - Permission Auditing
✅ **PSremotingAmServer/** - PowerShell Remoting Setup

### 2️⃣ **FILES TO ORGANIZE**

#### 📋 **Documentation Files** → `Documentation/`

- PowerShell-Regelwerk-Universal-v9.9.0.md
- PowerShell-Regelwerk-Universal-v10.0.0.md
- PowerShell-Regelwerk-Universal-v10.0.1.md
- PowerShell-Regelwerk-Universal-v10.0.2.md
- PowerShell-Regelwerk-Universal-v9.6.2.md
- GUI-Standards-Integration-Summary-v9.9.0.md
- GUI-Standards-Integration-Summary-v9.6.3.md
- Network-Share-Update-v10.0.2.md
- Network-Share-Sync-Report.md
- CertSurv-NetworkShare-Cleanup-Report.md
- QUICK-SERVER-TEST-CertWebService.md
- Deploy-To-NetworkShare-README.md
- CertSurv-ImportExcel-Deployment-Guide.md
- CertWebService-Mass-Update-DEPLOYMENT-COMPLETE.md
- CertWebService-Update-ANLEITUNG-NO-REMOTING.md

#### 🔧 **Utility Scripts** → `Scripts/Utilities/`

- Bulk-Update-Regelwerk.ps1
- Server-Management-CertWebService.ps1
- Debug-CertWebService.ps1
- Quick-Fix-CertWebService.ps1
- Quick-Fix-CertWebService-REPAIRED.ps1
- Quick-Fix-PS51.ps1
- Simple-Fix.ps1
- Deploy-To-NetworkShare.ps1
- Update-Both-Services.ps1
- Fix-Excel-BlockHeaders.ps1
- Update-Both-Services-Fixed.ps1
- Debug-ExcelHeaderContext.ps1

#### 📊 **CertSurv Related** → `Scripts/CertSurv/`

- Update-All-CertWebServices.ps1
- Update-All-CertWebServices-Simple.ps1
- Show-CertWebService-FQDNs.ps1
- Show-CertWebService-FQDNs-Simple.ps1
- Show-ONLY-CertWebService-Servers.ps1
- Update-REAL-CertWebServices.ps1
- Show-CertWebService-With-Domain-Context.ps1
- Update-CertWebServices-NO-REMOTING.ps1
- Update-CertSurv-Config-Fixed.ps1
- Update-CertSurv-Config-Clean.ps1
- Update-CertSurv-ImportExcel.ps1

#### 📦 **Modules** → `Modules/`

- FL-DataProcessing-NoExcelCOM.psm1
- Fix-FL-DataProcessing-ImportExcel.ps1

#### 🧪 **Test Scripts** → `Scripts/Testing/`

- Test-ImportExcel-Simple.ps1
- Install-ImportExcel-Solution.ps1

#### 📋 **Data Files** → `Data/`

- Serverliste2025.xlsx
- CertWebService_v1.1.0_ScheduledTask_2025-10-02-1201.zip

#### 🗂️ **Archive** → `archive/` (already exists, keep as is)

### 3️⃣ **DIRECTORIES TO CREATE**

```
F:\DEV\repositories\
├── [Existing Repos - Keep]
├── Documentation/           # All MD/TXT documentation
│   ├── Regelwerk/          # PowerShell-Regelwerk versions
│   ├── Deployment/         # Deployment guides & reports
│   └── Archive/            # Old documentation
├── Scripts/
│   ├── CertSurv/          # CertSurv management scripts
│   ├── Utilities/         # General utility scripts
│   ├── Testing/           # Test & validation scripts
│   └── Deployment/        # Deployment automation
├── Modules/               # Shared PowerShell modules
├── Data/                  # Excel files, configs, etc.
└── LOG/                   # Log files (already exists)
```

### 4️⃣ **CLEANUP ACTIONS**

1. **Create new directory structure**
2. **Move files to appropriate locations**
3. **Update cross-references in scripts**
4. **Create master README.md**
5. **Archive outdated files**
6. **Validate all paths still work**

---

## 🎯 **EXECUTION STRATEGY**

### Phase 1: Structure Creation

- Create Documentation/, Scripts/, Modules/, Data/ directories
- Create subdirectories

### Phase 2: File Movement

- Move files systematically by category
- Preserve git history where possible

### Phase 3: Reference Updates

- Update any hardcoded paths in scripts
- Test critical scripts still work

### Phase 4: Documentation

- Create master README.md
- Document new structure
- Create quick-reference guide

### Phase 5: Validation

- Test key workflows
- Verify network share deployments still work
- Update any external references

---

## ⚠️ **CAUTION ITEMS**

- **Network Share References:** Some scripts reference network shares
- **Cross-Repository Dependencies:** CertSurv ↔ CertWebService integration
- **LOG Directory:** Contains active log files
- **Git Integration:** Some folders are git repositories

---

## 🎯 **EXPECTED BENEFITS**

✅ **Clear Organization:** Logical grouping by purpose
✅ **Easier Navigation:** Find scripts faster
✅ **Better Maintenance:** Separate concerns
✅ **Reduced Duplication:** Identify duplicate scripts
✅ **Improved Documentation:** Centralized docs
✅ **Version Control:** Better tracking of changes
