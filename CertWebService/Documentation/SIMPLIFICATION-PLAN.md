# CertWebService - Vereinfachte Struktur

## 📋 **Vereinfachungsplan**

### **Aktuelle Probleme:**
- 20+ Scripts (viele redundant)
- Verwirrende Namen (Install-CertificateWebService vs Install-CertWebService-Safe)
- Mehrfache Deployment-Scripts
- Zu komplex für einfache Web-Service-Installation

### **Neue minimale Struktur:**
```
CertWebService/
├── Setup.ps1                    # Einziges Setup-Script (ersetzt alle Install-*)
├── Update.ps1                   # Einziges Update-Script 
├── Remove.ps1                   # Saubere Deinstallation
├── VERSION.ps1                  # Zentrale Versionsverwaltung
├── README.md                    # Vereinfachte Dokumentation
├── Config/
│   ├── Settings.json           # Einzige Konfigurationsdatei
│   ├── German.json            # Deutsche Übersetzung
│   └── English.json           # Englische Übersetzung
├── Modules/
│   ├── WebService.psm1        # Kern-Funktionen
│   ├── Configuration.psm1     # Konfiguration
│   └── Logging.psm1           # Logging
└── WebFiles/
    ├── index.html             # Web-Interface
    ├── api.json              # API-Daten
    └── styles.css            # Styling
```

### **Entfernte Scripts:**
- ❌ Deploy-CertWebService-Simple.ps1
- ❌ Deploy-CertWebService.ps1  
- ❌ Deploy-Simple.ps1
- ❌ Distribute-CertWebService.ps1
- ❌ Install-CertificateWebService-Clean.ps1
- ❌ Install-CertificateWebService.ps1
- ❌ Install-CertWebService-Safe.ps1
- ❌ Install-CertWebServiceTask-Clean.ps1
- ❌ Install-CertWebServiceTask.ps1
- ❌ Install.bat
- ❌ Manage-CertWebServiceTask.ps1
- ❌ Setup-CertWebService-System.ps1
- ❌ Setup-ScheduledTask-CertScan.ps1
- ❌ Update-CertificateWebService.ps1
- ❌ VERSION.txt
- ❌ README.txt
- ❌ DEPLOYMENT-README.md

### **3 Haupt-Scripts:**
1. **Setup.ps1** - Komplette Installation und Konfiguration
2. **Update.ps1** - Service-Updates und Wartung  
3. **Remove.ps1** - Saubere Deinstallation