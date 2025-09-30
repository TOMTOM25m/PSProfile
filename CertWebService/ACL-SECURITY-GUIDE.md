# 🛡️ CertWebService v2.3.0 - Access Control & Security Features

## Übersicht
Das CertWebService wurde um umfassende Access Control Listen (ACL) und Firewall-Integration erweitert. Administratoren können nun genau steuern, welche Server/Workstations Zugriff auf den Service haben.

## 🔧 Konfiguration

### 1. Installationszeit-Konfiguration
Während der Installation können ACL-Regeln automatisch angewendet werden:

```powershell
.\Setup.ps1 -Port 8080 -SecurePort 8443
```

Die ACL-Einstellungen werden aus `Config-CertWebService.json` gelesen:

```json
{
  "AccessControl": {
    "Enabled": true,
    "AllowedHosts": [
      "itscmgmt01.srv.meduniwien.ac.at",
      "itscmgmt02.srv.meduniwien.ac.at", 
      "itscmgmt03.srv.meduniwien.ac.at"
    ],
    "AllowedIPs": [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16"
    ],
    "DenyByDefault": true,
    "WhitelistMode": true
  }
}
```

### 2. Laufzeit-Konfiguration über Setup GUI
Eine HTML-basierte Konfigurationsoberfläche ermöglicht:

- ✅ Hinzufügen/Entfernen erlaubter Hosts (FQDN)
- ✅ Verwalten erlaubter IP-Bereiche (CIDR)
- ✅ Ein-/Ausschalten der ACL-Funktionalität
- ✅ Firewall-Regeln verwalten
- ✅ Zugriffstests durchführen
- ✅ Monitoring von Zugriffsversuchen

**Aufruf der Setup GUI:**
```
https://servername:8443/setup.html
```

### 3. PowerShell-Konfiguration
Direkte Konfiguration über PowerShell:

```powershell
# ACL-Konfiguration abrufen
.\Setup-ACL-Config.ps1 -Action GetConfig

# Neue Hosts hinzufügen
$newConfig = @{
    AccessControl = @{
        AllowedHosts = @("server01.domain.com", "server02.domain.com")
        AllowedIPs = @("192.168.1.0/24")
    }
}
.\Setup-ACL-Config.ps1 -Action SetConfig -ConfigData ($newConfig | ConvertTo-Json)

# Zugriff testen
.\Setup-ACL-Config.ps1 -Action TestAccess -TestHost "192.168.1.100"
```

## 🔥 Firewall-Integration

### Automatische Regelerstellung
Bei aktivierter Firewall-Integration werden automatisch Regeln erstellt:

1. **Allow-Regeln** für jeden definierten IP-Bereich:
   - `CertSurveillance-HTTP-Allow-10_0_0_0_8`
   - `CertSurveillance-HTTPS-Allow-10_0_0_0_8`

2. **Block-Regel** für alle anderen Zugriffe:
   - `CertSurveillance-HTTP-Block-Others`
   - `CertSurveillance-HTTPS-Block-Others`

### Firewall-Konfiguration
```json
{
  "Firewall": {
    "EnableACLRules": true,
    "AllowedRemoteAddresses": [
      "10.0.0.0/8",
      "172.16.0.0/12", 
      "192.168.0.0/16"
    ],
    "BlockAllOther": true,
    "EnableLogging": true
  }
}
```

## 🎯 Sicherheitsfeatures

### Whitelist-Modus
- **Standard**: Nur explizit erlaubte Hosts/IPs haben Zugriff
- **Deny by Default**: Alle nicht gelisteten Zugriffe werden abgelehnt
- **Logging**: Blockierte Zugriffe werden protokolliert

### Host-Validierung
- **FQDN-Prüfung**: Vollständige Domainnamen werden validiert
- **IP-Bereich-Prüfung**: CIDR-Notation unterstützt (z.B. 192.168.1.0/24)
- **DNS-Auflösung**: Automatische Auflösung von Hostnamen zu IPs

### Monitoring & Logging
- **Zugriffs-Audit**: Alle Zugriffe werden protokolliert
- **Denied-Access-Log**: Blockierte Zugriffe mit Timestamp
- **Performance-Tracking**: Minimaler Overhead durch effiziente IP-Matching

## 📋 Verwendungsszenarien

### Szenario 1: Nur 3 Management-Server
```json
{
  "AccessControl": {
    "Enabled": true,
    "AllowedHosts": [
      "itscmgmt01.srv.meduniwien.ac.at",
      "itscmgmt02.srv.meduniwien.ac.at",
      "itscmgmt03.srv.meduniwien.ac.at"
    ],
    "AllowedIPs": [],
    "WhitelistMode": true
  }
}
```

### Szenario 2: Bestimmte IP-Bereiche + einzelne Server
```json
{
  "AccessControl": {
    "Enabled": true,
    "AllowedHosts": ["critical-server.domain.com"],
    "AllowedIPs": [
      "10.1.0.0/16",
      "192.168.100.0/24"
    ],
    "WhitelistMode": true
  }
}
```

### Szenario 3: Entwicklungsumgebung (offen)
```json
{
  "AccessControl": {
    "Enabled": false,
    "WhitelistMode": false
  }
}
```

## 🚀 Deployment

### Network Share Deployment
Die bereinigten Network Shares enthalten nur noch die essentiellen Dateien:

**CertWebService Share:**
- `Install.bat` - Enhanced installer mit ACL-Support
- `Setup.ps1` - Hauptinstallationsskript mit ACL-Integration
- `FL-AccessControl.psm1` - ACL-Modul
- `Setup-ACL-Config.ps1` - PowerShell-Backend für GUI
- `setup.html` - Web-GUI für Konfiguration
- `Config-CertWebService.json` - Konfigurationsdatei
- `ScanCertificates.ps1` - Daily certificate scanner
- `Setup-ScheduledTask-CertScan.ps1` - Scheduled task setup

**CertSurv Share:**
- `Main.ps1` - Hauptprogramm
- `Setup.ps1` - Installation
- `Config/` - Konfigurationsordner
- `Modules/` - PowerShell-Module

## 🔧 Administration

### ACL aktivieren/deaktivieren
```powershell
# Über PowerShell
.\Setup-ACL-Config.ps1 -Action SetConfig -ConfigData '{"AccessControl":{"Enabled":false}}'

# Über GUI
# Navigiere zu https://server:8443/setup.html -> Security Tab
```

### Firewall-Regeln verwalten
```powershell
# Regeln anwenden
.\Setup-ACL-Config.ps1 -Action ApplyFirewall

# Regeln entfernen
.\Setup-ACL-Config.ps1 -Action RemoveFirewall
```

### Status überprüfen
```powershell
.\Setup-ACL-Config.ps1 -Action GetStatus
```

## 🎛️ Web-GUI Features

Die Setup-GUI unter `/setup.html` bietet:

1. **Installation Tab**: Service installieren/entfernen
2. **Sicherheit & ACL Tab**: ACL-Konfiguration verwalten
3. **Firewall Tab**: Firewall-Regeln verwalten  
4. **Monitoring Tab**: Zugriffs-Logs einsehen
5. **Status Tab**: System-Status überwachen

## ✅ Compliance

- **Regelwerk v10.0.0** vollständig konform
- **Modular Design** (§10) - Alle ACL-Funktionen in eigenem Modul
- **Sicherheit** (§13) - Umfassende Zugriffskontrolle
- **Logging** (§12) - Vollständige Audit-Trails
- **Dokumentation** (§6) - Umfassende Dokumentation aller Features

---

**Version:** v2.3.0  
**Autor:** Flecki (Tom) Garnreiter  
**Regelwerk:** v10.0.0