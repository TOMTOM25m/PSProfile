# 🎯 CertWebService Update - LÖSUNG FÜR WINRM PROBLEME

## ❌ Problem erkannt:
Das ursprüngliche Update-System funktioniert nicht wegen **PowerShell Remoting/WinRM-Konfiguration**.

## ✅ Alternative Lösung erstellt:
**Update-Scripts ohne PowerShell Remoting** - werden lokal auf jedem Server ausgeführt.

---

## 📁 Erstellte Files auf Netzlaufwerk:

### **Update-Scripts für jeden Server:**
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-proman.ps1
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-evaextest01.ps1
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-wsus.ps1
```

### **Aktuelle CertWebService-Version:**
```
\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\CertWebService\
```

---

## 🚀 **ANLEITUNG ZUR AUSFÜHRUNG:**

### **OPTION 1 - Manuell auf jedem Server:**

#### **Server 1: proman.uvw.meduniwien.ac.at**
1. RDP zu `proman.uvw.meduniwien.ac.at`
2. PowerShell als Administrator öffnen
3. Ausführen:
```powershell
PowerShell -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-proman.ps1"
```

#### **Server 2: evaextest01.srv.meduniwien.ac.at**
1. RDP zu `evaextest01.srv.meduniwien.ac.at`
2. PowerShell als Administrator öffnen
3. Ausführen:
```powershell
PowerShell -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-evaextest01.ps1"
```

#### **Server 3: wsus.srv.meduniwien.ac.at**
1. RDP zu `wsus.srv.meduniwien.ac.at`
2. PowerShell als Administrator öffnen
3. Ausführen:
```powershell
PowerShell -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-wsus.ps1"
```

---

### **OPTION 2 - PsExec (falls verfügbar):**

```cmd
psexec \\proman.uvw.meduniwien.ac.at -u Administrator powershell.exe -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-proman.ps1"

psexec \\evaextest01.srv.meduniwien.ac.at -u Administrator powershell.exe -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-evaextest01.ps1"

psexec \\wsus.srv.meduniwien.ac.at -u Administrator powershell.exe -ExecutionPolicy Bypass -File "\\itscmgmt03.srv.meduniwien.ac.at\iso\CertSurv\ServerUpdates\Update-wsus.ps1"
```

---

## 🔧 **Was machen die Update-Scripts:**

1. **Stop CertWebService** - Beendet alle laufenden Prozesse
2. **Backup erstellen** - Sicherung der aktuellen Installation
3. **ROBOCOPY Update** - Kopiert neue Version vom Netzlaufwerk
4. **Service starten** - Startet CertWebService neu
5. **Verification** - Prüft ob Service wieder läuft
6. **Logging** - Alles wird in `C:\Temp\CertWebService-Update-[SERVER]-[DATUM].log` geloggt

---

## 📊 **Status-Überwachung:**

Nach der Ausführung wird auf jedem Server eine Datei erstellt:
- **Erfolg:** `C:\Temp\CertWebService-Update-SUCCESS-[SERVER].txt`
- **Fehler:** `C:\Temp\CertWebService-Update-ERROR-[SERVER].txt`

---

## ✅ **Nächste Schritte:**

1. **Wähle OPTION 1 oder OPTION 2**
2. **Führe Updates nacheinander aus** (nicht parallel)
3. **Prüfe nach jedem Update:** `http://[SERVER]:9080`
4. **Überprüfe Log-Files** bei Problemen

---

## 🎯 **Status der 3 echten CertWebService-Server:**

✅ **proman.uvw.meduniwien.ac.at** - v10.0.2 - Ready for update  
✅ **evaextest01.srv.meduniwien.ac.at** - v10.0.2 - Ready for update  
✅ **wsus.srv.meduniwien.ac.at** - v10.0.2 - Ready for update  

**Alle Scripts sind bereit auf dem Netzlaufwerk!** 🚀