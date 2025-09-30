# 🔒 CertWebService v2.3.0 - Read-Only Access Control

## ✅ Autorisierte Server (Nur lesender Zugriff)

Das CertWebService ist jetzt auf **Read-Only Modus** konfiguriert und erlaubt nur den folgenden 3 Servern Zugriff:

### 📋 Autorisierte Hosts:
1. **ITSCMGMT03.srv.meduniwien.ac.at**
2. **ITSC020.cc.meduniwien.ac.at** 
3. **itsc049.uvw.meduniwien.ac.at**

## 🛡️ Sicherheitseinstellungen

### Read-Only Modus aktiviert:
- ✅ **Erlaubte HTTP-Methods**: GET, HEAD, OPTIONS
- ❌ **Blockierte HTTP-Methods**: POST, PUT, DELETE, PATCH
- ✅ **Whitelist-Modus**: Nur die 3 definierten Server
- ❌ **IP-Bereiche**: Deaktiviert für maximale Sicherheit
- ✅ **Logging**: Alle Zugriffe werden protokolliert

### IIS Web.config Konfiguration:
```xml
<rewrite>
    <rules>
        <!-- Block POST, PUT, DELETE, PATCH methods -->
        <rule name="BlockWriteMethods" stopProcessing="true">
            <match url=".*" />
            <conditions>
                <add input="{REQUEST_METHOD}" pattern="POST|PUT|DELETE|PATCH" />
            </conditions>
            <action type="CustomResponse" statusCode="405" statusReason="Method Not Allowed" />
        </rule>
    </rules>
</rewrite>
```

### Security Headers:
- `X-Read-Only-Mode: true`
- `X-Allowed-Methods: GET, HEAD, OPTIONS`
- `X-Authorized-Hosts: ITSCMGMT03.srv.meduniwien.ac.at, ITSC020.cc.meduniwien.ac.at, itsc049.uvw.meduniwien.ac.at`

## 🔧 Konfiguration

### JSON-Konfiguration:
```json
{
  "AccessControl": {
    "Enabled": true,
    "AllowedHosts": [
      "ITSCMGMT03.srv.meduniwien.ac.at",
      "ITSC020.cc.meduniwien.ac.at", 
      "itsc049.uvw.meduniwien.ac.at"
    ],
    "AllowedIPs": [],
    "ReadOnlyMode": true,
    "BlockedMethods": ["POST", "PUT", "DELETE", "PATCH"],
    "AllowedMethods": ["GET", "HEAD", "OPTIONS"],
    "WhitelistMode": true,
    "DenyByDefault": true
  }
}
```

## 📊 Verfügbare API-Endpoints (Read-Only):

### 1. Certificate Data (JSON)
```
GET https://server:8443/certificates.json
```

### 2. Health Status
```
GET https://server:8443/health.json
```

### 3. Certificate Summary
```
GET https://server:8443/summary.json
```

### 4. Web Dashboard
```
GET https://server:8443/index.html
```

### 5. Setup Interface (für Administratoren)
```
GET https://server:8443/setup.html
```

## 🚫 Blockierte Aktionen

Alle folgenden Aktionen werden mit **HTTP 405 Method Not Allowed** abgelehnt:
- POST-Requests (Datenübertragung)
- PUT-Requests (Datenänderung)
- DELETE-Requests (Datenlöschung)
- PATCH-Requests (Partial Updates)

## 🔍 Zugriffskontrolle

### Erlaubte Zugriffe:
- ✅ **ITSCMGMT03.srv.meduniwien.ac.at** → GET/HEAD/OPTIONS
- ✅ **ITSC020.cc.meduniwien.ac.at** → GET/HEAD/OPTIONS
- ✅ **itsc049.uvw.meduniwien.ac.at** → GET/HEAD/OPTIONS

### Blockierte Zugriffe:
- ❌ Alle anderen Server/IPs
- ❌ Alle schreibenden HTTP-Methods
- ❌ Anonyme Zugriffe
- ❌ IP-basierte Zugriffe (nur FQDN erlaubt)

## 🚀 Installation

Die Installation erfolgt über das enhanced `Install.bat`:

```batch
Install.bat
```

Das Script:
1. Installiert IIS mit Read-Only Web.config
2. Konfiguriert Firewall-Regeln für die 3 Server
3. Erstellt SSL-Zertifikat
4. Aktiviert ACL mit Read-Only Modus
5. Startet Scheduled Task für tägliche Zertifikatsuche

## 📈 Monitoring

### Setup GUI Dashboard:
- **URL**: `https://server:8443/setup.html`
- **Features**: Echtzeit-Status, Zugriffs-Logs, ACL-Verwaltung

### PowerShell-Monitoring:
```powershell
# Status abrufen
.\Setup-ACL-Config.ps1 -Action GetStatus

# Zugriff testen  
.\Setup-ACL-Config.ps1 -Action TestAccess -TestHost "ITSC020.cc.meduniwien.ac.at"
```

## ⚡ Compliance

- **Regelwerk v10.0.0**: ✅ Vollständig konform
- **Security-by-Design**: ✅ Read-Only Default
- **Zero-Trust**: ✅ Nur explizit autorisierte Hosts
- **Audit-Trail**: ✅ Vollständige Protokollierung
- **Minimal Attack Surface**: ✅ Nur 3 HTTP-Methods erlaubt

---

**Version:** v2.3.0  
**Security Mode:** Read-Only  
**Authorized Hosts:** 3  
**Date:** 30.09.2025