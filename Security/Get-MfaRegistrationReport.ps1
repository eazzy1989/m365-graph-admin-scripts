<#
.SYNOPSIS
    Zeigt, welche Benutzer noch keine Mehr-Faktor-Authentifizierung (MFA) registriert haben.

.DESCRIPTION
    Nutzt den Bericht „Registrierungsdetails der Authentifizierungsmethoden“ aus Microsoft Graph.
    Ausgegeben werden:
    - Anteil der Benutzer mit registrierter MFA
    - alle Benutzer ohne MFA – Administratoren werden besonders hervorgehoben
    - Verteilung der registrierten Methoden (Authenticator, Telefon, FIDO2 …)
    Das Skript ändert nichts, es erstellt nur einen Bericht.

.PARAMETER ExportPath
    Optionaler Pfad für einen CSV-Export.

.EXAMPLE
    .\Get-MfaRegistrationReport.ps1 -ExportPath .\mfa.csv

.NOTES
    Autor:     Ismail Yildiz
    Benötigt:  Microsoft.Graph.Authentication, Microsoft.Graph.Reports
    Scopes:    AuditLog.Read.All, UserAuthenticationMethod.Read.All
    Hinweis:   Der Bericht erfordert Microsoft Entra ID P1 oder P2.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Reports

[CmdletBinding()]
param(
    [string]$ExportPath
)

Connect-MgGraph -Scopes 'AuditLog.Read.All', 'UserAuthenticationMethod.Read.All' -NoWelcome

$details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
    Where-Object { $_.UserType -eq 'member' }

$total   = @($details).Count
$withMfa = @($details | Where-Object IsMfaRegistered).Count
$percent = if ($total) { [math]::Round($withMfa / $total * 100, 1) } else { 0 }

Write-Host "`nMFA registriert: $withMfa von $total Benutzern ($percent %)" -ForegroundColor Cyan

$missing = $details | Where-Object { -not $_.IsMfaRegistered } | Sort-Object { -not $_.IsAdmin }, UserPrincipalName

$admins = @($missing | Where-Object IsAdmin)
if ($admins) {
    Write-Host "`nACHTUNG: $($admins.Count) Administrator(en) ohne MFA" -ForegroundColor Red
    $admins | Select-Object UserDisplayName, UserPrincipalName | Format-Table -AutoSize
}

Write-Host "Benutzer ohne MFA: $(@($missing).Count)" -ForegroundColor Yellow
$missing | Select-Object UserDisplayName, UserPrincipalName, IsAdmin | Format-Table -AutoSize

Write-Host 'Registrierte Methoden' -ForegroundColor Cyan
$details | ForEach-Object { $_.MethodsRegistered } | Group-Object | Sort-Object Count -Descending |
    Select-Object @{ n = 'Methode'; e = { $_.Name } }, Count | Format-Table -AutoSize

if ($ExportPath) {
    $details | Select-Object UserDisplayName, UserPrincipalName, IsAdmin, IsMfaRegistered, IsMfaCapable,
        IsPasswordlessCapable, @{ n = 'Methoden'; e = { $_.MethodsRegistered -join ', ' } } |
        Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Host "Exportiert nach $ExportPath" -ForegroundColor Green
}
