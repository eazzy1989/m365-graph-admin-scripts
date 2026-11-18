<#
.SYNOPSIS
    Listet alle Mitglieder privilegierter Rollen in Microsoft Entra ID auf.

.DESCRIPTION
    Liest alle aktivierten Verzeichnisrollen (z. B. Globaler Administrator, Exchange-Administrator)
    und deren Mitglieder aus. Hilfreich für regelmäßige Berechtigungsprüfungen
    (Least Privilege, „Wer ist eigentlich alles Global Admin?“).
    Das Skript ändert nichts, es erstellt nur einen Bericht.

.PARAMETER ExportPath
    Optionaler Pfad für einen CSV-Export.

.EXAMPLE
    .\Get-AdminRoleReport.ps1

.NOTES
    Autor:     eazzy1989
    Benötigt:  Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement
    Scopes:    RoleManagement.Read.Directory, Directory.Read.All
    Hinweis:   Erfasst aktive Rollenzuweisungen. Über PIM nur berechtigte (eligible) Zuweisungen
               erscheinen hier nicht.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement

[CmdletBinding()]
param(
    [string]$ExportPath
)

Connect-MgGraph -Scopes 'RoleManagement.Read.Directory', 'Directory.Read.All' -NoWelcome

$report = foreach ($role in Get-MgDirectoryRole -All) {
    foreach ($member in Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All) {
        $p = $member.AdditionalProperties
        [PSCustomObject]@{
            Rolle   = $role.DisplayName
            Name    = $p['displayName']
            Konto   = if ($p['userPrincipalName']) { $p['userPrincipalName'] } else { $p['appId'] }
            Typ     = ($p['@odata.type'] -replace '#microsoft.graph.', '')
        }
    }
}

$report = $report | Sort-Object Rolle, Name

Write-Host "`nRollenzuweisungen: $(@($report).Count)" -ForegroundColor Cyan
$report | Format-Table -AutoSize -GroupBy Rolle

$globalAdmins = @($report | Where-Object { $_.Rolle -eq 'Global Administrator' -and $_.Typ -eq 'user' })
$color = if ($globalAdmins.Count -gt 4) { 'Yellow' } else { 'Green' }
Write-Host "Globale Administratoren: $($globalAdmins.Count) (Empfehlung von Microsoft: weniger als 5)" -ForegroundColor $color

if ($ExportPath) {
    $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Host "Exportiert nach $ExportPath" -ForegroundColor Green
}
