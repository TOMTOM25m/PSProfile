# Network Share Update - PowerShell-Regelwerk v10.0.2

**Datum:** 30. September 2025  
**Update:** PowerShell-Regelwerk Universal v10.0.2  
**Network Share:** `\\itscmgmt03.srv.meduniwien.ac.at\iso`

---

## 📋 Update Summary

### ✅ **PowerShell-Regelwerk v10.0.2 Features**
- **§19**: PowerShell-Versionserkennung und Kompatibilitätsfunktionen (MANDATORY)
- **Universal Compatibility**: PowerShell 5.1/7.x mit intelligenten Hilfsfunktionen
- **Encoding Fix**: ASCII-kompatible Ausgaben für PowerShell 5.1
- **Null-Coalescing Alternativen**: Get-ConfigValueSafe() für universelle Kompatibilität

### 📁 **Aktualisierte Dateien im Network Share**

```
\\itscmgmt03.srv.meduniwien.ac.at\iso\
├── PowerShell-Regelwerk-Universal-v10.0.2.md      (23.3 KB) - NEUE VERSION
│
└── CertSurv\
    ├── Demo-PowerShell-Regelwerk-v10.0.2.ps1      (6.1 KB) - NEU
    ├── Test-PowerShell-Compatibility.ps1          (3.0 KB) - NEU
    ├── Setup-CertSurvGUI-CLEAN.ps1               (6.3 KB) - CLEAN VERSION
    ├── Test-WebService-PowerShell5.ps1           (6.9 KB) - Updated
    └── Test-WebService-Universal.ps1             (7.4 KB) - Updated
```

---

## 🚀 **Neue PowerShell-Kompatibilitätsfunktionen**

### **§19.1 - PowerShell Version Detection**
```powershell
# MANDATORY in allen Skripten
$PSVersion = $PSVersionTable.PSVersion
$IsPS7Plus = $PSVersion.Major -ge 7
$IsPS51 = $PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1
```

### **§19.2 - Universal Configuration Helper Functions**
```powershell
# Ersetzt null-coalescing Operatoren (??) 
function Get-ConfigValueSafe {
    param([object]$Config, [string]$PropertyName, [object]$DefaultValue)
    
    if ($Config -is [hashtable] -and $Config.ContainsKey($PropertyName)) {
        return $Config[$PropertyName]
    } elseif ($Config.PSObject.Properties.Name -contains $PropertyName) {
        return $Config.$PropertyName
    } else {
        return $DefaultValue
    }
}

# Verwendung:
$value = Get-ConfigValueSafe -Config $Config -PropertyName "ServerName" -DefaultValue "UNKNOWN"
```

### **§19.3 - Encoding-sichere Ausgaben**
```powershell
# PowerShell 5.1 kompatibel
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "✅ Success" -ForegroundColor Green
} else {
    Write-Host "[SUCCESS] Success" -ForegroundColor Green
}
```

---

## 📋 **Migration Guide für bestehende Skripte**

### **Schritt 1: Version Detection hinzufügen**
```powershell
#region PowerShell Version Detection (Regelwerk v10.0.2)
$IsPS7Plus = $PSVersionTable.PSVersion.Major -ge 7
$IsPS51 = $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersion.Minor -eq 1
#endregion
```

### **Schritt 2: Null-Coalescing Operatoren ersetzen**
```powershell
# Alt (nur PowerShell 7+):
$value = $Config.Property ?? $DefaultValue

# Neu (PowerShell 5.1+):
$value = Get-ConfigValueSafe -Config $Config -PropertyName "Property" -DefaultValue $DefaultValue
```

### **Schritt 3: Unicode-Zeichen korrigieren**
```powershell
# Alt (PowerShell 5.1 Problem):
Write-Host "✅ Done"

# Neu (PowerShell 5.1 kompatibel):
Write-Host "[SUCCESS] Done"
```

---

## 🎯 **Sofortige Maßnahmen erforderlich**

### **Für CertSurv-Administratoren:**
1. **PowerShell-Regelwerk v10.0.2 lesen** - Neue §19 Standards verstehen
2. **Demo-Script testen**: `Demo-PowerShell-Regelwerk-v10.0.2.ps1` ausführen
3. **Bestehende Skripte prüfen** auf null-coalescing Operatoren (`??`)
4. **Encoding-Probleme beheben** - Unicode-Zeichen durch ASCII ersetzen

### **Für Entwickler:**
1. **Get-ConfigValueSafe()** in allen neuen Skripten verwenden
2. **PowerShell Version Detection** in Skript-Header implementieren
3. **UTF-8 ohne BOM** für alle .ps1 Dateien sicherstellen
4. **Kompatibilitätstests** mit PowerShell 5.1 und 7.x durchführen

---

## 📞 **Support & Kontakt**

**Bei Fragen zu PowerShell-Regelwerk v10.0.2:**
- **Author:** Flecki (Tom) Garnreiter
- **Email:** thomas.garnreiter@meduniwien.ac.at
- **Network Share:** `\\itscmgmt03.srv.meduniwien.ac.at\iso`

**Test-Scripts verfügbar:**
- `Test-PowerShell-Compatibility.ps1` - Grundlegende Kompatibilitätstests
- `Demo-PowerShell-Regelwerk-v10.0.2.ps1` - Vollständige Funktionsdemonstration

---

**🎉 PowerShell-Regelwerk v10.0.2 ist jetzt im Network Share verfügbar!**