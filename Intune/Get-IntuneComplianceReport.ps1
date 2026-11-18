<#
.SYNOPSIS
    Bericht über den Compliance-Status aller Intune-verwalteten Geräte.

.DESCRIPTION
    Liest alle von Intune verwalteten Geräte aus und zeigt:
    - eine Zusammenfassung nach Compliance-Status und Betriebssystem
    - alle nicht konformen Geräte
    - alle Geräte, die sich seit X Tagen nicht mehr synchronisiert haben
    Das Skript ändert nichts, es erstellt nur einen Bericht.

.PARAMETER StaleDays
    Geräte ohne Synchronisierung seit so vielen Tagen gelten als veraltet. Standard: 30

.PARAMETER ExportPath
    Optionaler Pfad für einen CSV-Export aller Geräte.

.EXAMPLE
    .\Get-IntuneComplianceReport.ps1 -StaleDays 14 -ExportPath .\geraete.csv

.NOTES
    Autor:     eazzy1989
    Benötigt:  Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement
    Scopes:    DeviceManagementManagedDevices.Read.All
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

[CmdletBinding()]
param(
    [int]$StaleDays = 30,
    [string]$ExportPath
)

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$cutoff = (Get-Date).AddDays(-$StaleDays)

$devices = Get-MgDeviceManagementManagedDevice -All | ForEach-Object {
    [PSCustomObject]@{
        Geraet        = $_.DeviceName
        Benutzer      = $_.UserPrincipalName
        OS            = $_.OperatingSystem
        Version       = $_.OsVersion
        Compliance    = $_.ComplianceState
        LetzterSync   = $_.LastSyncDateTime
        Verschluesselt = $_.IsEncrypted
        Veraltet      = $_.LastSyncDateTime -lt $cutoff
    }
}

Write-Host "`nGeräte gesamt: $(@($devices).Count)" -ForegroundColor Cyan

Write-Host "`nNach Compliance-Status" -ForegroundColor Cyan
$devices | Group-Object Compliance | Sort-Object Count -Descending |
    Select-Object @{ n = 'Status'; e = { $_.Name } }, Count | Format-Table -AutoSize

Write-Host 'Nach Betriebssystem' -ForegroundColor Cyan
$devices | Group-Object OS | Sort-Object Count -Descending |
    Select-Object @{ n = 'OS'; e = { $_.Name } }, Count | Format-Table -AutoSize

$noncompliant = $devices | Where-Object { $_.Compliance -eq 'noncompliant' }
Write-Host "Nicht konform: $(@($noncompliant).Count)" -ForegroundColor Red
$noncompliant | Select-Object Geraet, Benutzer, OS, Version, LetzterSync | Format-Table -AutoSize

$stale = $devices | Where-Object Veraltet | Sort-Object LetzterSync
Write-Host "Kein Sync seit $StaleDays Tagen: $(@($stale).Count)" -ForegroundColor Yellow
$stale | Select-Object Geraet, Benutzer, OS, LetzterSync | Format-Table -AutoSize

$unencrypted = $devices | Where-Object { $_.Verschluesselt -eq $false }
Write-Host "Nicht verschlüsselt: $(@($unencrypted).Count)" -ForegroundColor Yellow

if ($ExportPath) {
    $devices | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Host "`nExportiert nach $ExportPath" -ForegroundColor Green
}
