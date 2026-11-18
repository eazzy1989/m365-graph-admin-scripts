# Microsoft 365 Admin-Skripte mit Microsoft Graph

PowerShell-Skripte für typische Aufgaben in der Microsoft-365-Administration – Berichte zu Lizenzen, Benutzern, Geräten und Sicherheit sowie ein Onboarding per CSV. Alle Skripte nutzen das offizielle **Microsoft Graph PowerShell SDK** und fordern nur die Berechtigungen an, die sie wirklich brauchen.

Entstanden als Praxisprojekt zu meiner Zertifizierung **Microsoft 365 Certified: Endpoint Administrator Associate (MD-102)**.

## Überblick

| Bereich | Skript | Zweck | ändert etwas? |
|---|---|---|---|
| Reports | `Get-M365LicenseReport.ps1` | gekaufte, verbrauchte und freie Lizenzen je SKU | nein |
| Users | `Get-InactiveUsers.ps1` | Konten ohne Anmeldung seit X Tagen – Kandidaten für Deaktivierung und Lizenzrückgabe | nein |
| Users | `New-UsersFromCsv.ps1` | Onboarding: Benutzer aus CSV anlegen, Startpasswort, Lizenz zuweisen | **ja** – mit `-WhatIf` testbar |
| Intune | `Get-IntuneComplianceReport.ps1` | nicht konforme, unverschlüsselte und lange nicht synchronisierte Geräte | nein |
| Security | `Get-MfaRegistrationReport.ps1` | Benutzer ohne MFA, Administratoren hervorgehoben | nein |
| Security | `Get-AdminRoleReport.ps1` | Mitglieder privilegierter Rollen (z. B. Anzahl Global Admins) | nein |

Jedes Skript hat eine eingebaute Hilfe:

```powershell
Get-Help .\Users\New-UsersFromCsv.ps1 -Full
```

## Voraussetzungen

- PowerShell 7 (empfohlen) oder Windows PowerShell 5.1
- Microsoft Graph PowerShell SDK:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

- Ein Konto mit passender Admin-Rolle (z. B. Global Reader für die Berichte, User Administrator für das Onboarding)
- Für `Get-InactiveUsers.ps1` und `Get-MfaRegistrationReport.ps1`: Microsoft Entra ID P1/P2 (z. B. in Microsoft 365 E3/E5 oder Business Premium enthalten)

Beim ersten Aufruf öffnet sich die Microsoft-Anmeldung und fragt die benötigten Berechtigungen (Scopes) ab.

## Beispiele

```powershell
# Lizenzübersicht mit CSV-Export
.\Reports\Get-M365LicenseReport.ps1 -ExportPath .\lizenzen.csv

# Wer hat sich seit 60 Tagen nicht angemeldet?
.\Users\Get-InactiveUsers.ps1 -Days 60

# Onboarding erst simulieren, dann ausführen
.\Users\New-UsersFromCsv.ps1 -CsvPath .\Beispiele\neue-benutzer.csv -Domain contoso.onmicrosoft.com -WhatIf
.\Users\New-UsersFromCsv.ps1 -CsvPath .\Beispiele\neue-benutzer.csv -Domain contoso.onmicrosoft.com

# Intune: Geräte ohne Sync seit 14 Tagen
.\Intune\Get-IntuneComplianceReport.ps1 -StaleDays 14
```

## Sicherheit

- Alle Berichtsskripte arbeiten **nur lesend**.
- Das Onboarding-Skript unterstützt `-WhatIf` und `-Confirm`, überspringt vorhandene Konten und erzwingt die Passwortänderung bei der ersten Anmeldung.
- Startpasswörter werden nur in der Konsole angezeigt, nicht gespeichert.
- Im Repo stehen keine Tenant-IDs, Domains oder Zugangsdaten – die Anmeldung läuft interaktiv über `Connect-MgGraph`.

## Lizenz

[MIT](LICENSE)
