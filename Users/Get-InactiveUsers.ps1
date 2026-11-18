<#
.SYNOPSIS
    Findet aktive Benutzerkonten, die sich seit X Tagen nicht angemeldet haben.

.DESCRIPTION
    Liest alle Mitglieder-Konten (keine Gäste) mit ihrer letzten Anmeldung aus.
    Konten ohne Anmeldung innerhalb des Zeitraums oder ganz ohne Anmeldung werden
    aufgelistet – typische Kandidaten für Deaktivierung oder Lizenzrückgabe.
    Das Skript ändert nichts, es erstellt nur einen Bericht.

.PARAMETER Days
    Zeitraum in Tagen. Standard: 90

.PARAMETER ExportPath
    Optionaler Pfad für einen CSV-Export.

.EXAMPLE
    .\Get-InactiveUsers.ps1 -Days 60 -ExportPath .\inaktiv.csv

.NOTES
    Autor:     eazzy1989
    Benötigt:  Microsoft.Graph.Authentication, Microsoft.Graph.Users
    Scopes:    User.Read.All, AuditLog.Read.All
    Hinweis:   Die Anmeldeinformationen (signInActivity) erfordern Microsoft Entra ID P1 oder P2.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users

[CmdletBinding()]
param(
    [int]$Days = 90,
    [string]$ExportPath
)

Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays(-$Days)

# signInActivity lässt sich nicht mit jedem Filter kombinieren – daher clientseitig filtern
$users = Get-MgUser -All `
    -Property 'DisplayName,UserPrincipalName,CreatedDateTime,SignInActivity,AssignedLicenses,AccountEnabled,UserType' |
    Where-Object { $_.AccountEnabled -and $_.UserType -eq 'Member' }

$report = foreach ($u in $users) {
    $last = $u.SignInActivity.LastSignInDateTime

    if (-not $last -or $last -lt $cutoff) {
        [PSCustomObject]@{
            Name           = $u.DisplayName
            UPN            = $u.UserPrincipalName
            LetzteAnmeldung = if ($last) { $last.ToString('yyyy-MM-dd') } else { 'nie' }
            TageInaktiv    = if ($last) { [int]((Get-Date) - $last).TotalDays } else { $null }
            Lizenziert     = [bool]$u.AssignedLicenses.Count
            Angelegt       = $u.CreatedDateTime.ToString('yyyy-MM-dd')
        }
    }
}

$report = $report | Sort-Object { if ($_.TageInaktiv) { $_.TageInaktiv } else { [int]::MaxValue } } -Descending

Write-Host "`nInaktive Konten (keine Anmeldung seit $Days Tagen): $(@($report).Count)" -ForegroundColor Cyan
Write-Host "davon lizenziert: $(@($report | Where-Object Lizenziert).Count)`n" -ForegroundColor Yellow
$report | Format-Table -AutoSize

if ($ExportPath) {
    $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Host "Exportiert nach $ExportPath" -ForegroundColor Green
}
