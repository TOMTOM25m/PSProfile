# Security Configuration for CertWebService PowerShell System

## DevSkim Security Suppressions

Diese Datei dokumentiert die Sicherheits-Suppressions für das CertWebService PowerShell Mass Update System.

### Suppressed Rules

#### DS104456 - Use of restricted functions (Invoke-Command)

**Suppressed because:**

- `Invoke-Command` wird für legitime Remote-Administration in der Unternehmens-Umgebung verwendet
- Alle PSRemoting-Aufrufe verwenden korrekte Authentifizierung mit Admin-Credentials
- Läuft in kontrollierter Netzwerk-Umgebung (interne Server)
- Notwendig für automatisierte Server-Updates und Deployment

**Betroffene Funktionen:**

- Test-ServerConnectivity (Konnektivitäts-Tests)
- Deploy-ViaPSRemoting (Remote-Deployment)
- Server-Status-Validierung

#### DS137138 - HTTP-based URL without TLS

**Suppressed because:**

- HTTP-URLs werden nur für interne Netzwerk-Endpoints verwendet
- CertWebService Health-Endpoints laufen auf internen Servern
- Nicht für externe Netzwerke oder Internet-Zugriff bestimmt
- Teil der internen Monitoring-Infrastruktur

**Betroffene URLs:**

- `http://[SERVER]:9080/health.json` - CertWebService Health Check
- `http://[SERVER]:8080/health.json` - Alternative Port Testing
- Interne Test- und Monitoring-Endpoints

### Sicherheitsmaßnahmen

Obwohl diese Regeln unterdrückt sind, sind folgende Sicherheitsmaßnahmen implementiert:

1. **Authentifizierung:**
   - Alle Remote-Operationen erfordern Admin-Credentials
   - PSCredential-Objekte für sichere Passwort-Übertragung
   - Keine Hardcoded-Credentials im Code

2. **Netzwerk-Sicherheit:**
   - Alle HTTP-Endpoints sind nur im internen Netzwerk erreichbar
   - Firewall-Schutz verhindert externen Zugriff
   - VPN-geschützte Administratoren-Zugriffe

3. **Fehlerbehandlung:**
   - Umfassende Try-Catch-Blöcke
   - Sichere Fehler-Logging ohne Credential-Preisgabe
   - Timeout-Schutz für Remote-Operationen

4. **PowerShell-Sicherheit:**
   - Execution Policy Enforcement
   - Script-Signing wo möglich
   - Administrator-Rechte erforderlich (#Requires -RunAsAdministrator)

### Updates

- **2025-01-06**: Initial security configuration created
- **Version**: 1.0.0
- **Author**: Field Level Automation Team

### Review Schedule

Diese Sicherheitskonfiguration sollte quartalsweise überprüft werden:

- Q1 2025: März 2025
- Q2 2025: Juni 2025  
- Q3 2025: September 2025
- Q4 2025: Dezember 2025

### Contact

Bei Fragen zur Sicherheitskonfiguration:

- IT Security Team
- PowerShell Entwicklungs-Team
- Field Level Automation
