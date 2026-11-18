<#
.SYNOPSIS
    Übersicht über alle Microsoft-365-Lizenzen im Tenant.

.DESCRIPTION
    Liest alle abonnierten Lizenzen (SKUs) per Microsoft Graph aus und zeigt
    pro Lizenz die gekauften, verbrauchten und freien Einheiten an.
    Lizenzen mit wenigen freien Einheiten werden farblich hervorgehoben.

.PARAMETER WarnFree
    Ab dieser Anzahl freier Lizenzen (oder weniger) wird die Zeile gelb markiert. Standard: 2

.PARAMETER ExportPath
    Optionaler Pfad für einen CSV-Export.

.EXAMPLE
    .\Get-M365LicenseReport.ps1

.EXAMPLE
    .\Get-M365LicenseReport.ps1 -WarnFree 5 -ExportPath .\lizenzen.csv

.NOTES
    Autor:     Ismail Yildiz
    Benötigt:  Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement
    Scopes:    Organization.Read.All
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement

[CmdletBinding()]
param(
    [int]$WarnFree = 2,
    [string]$ExportPath
)

Connect-MgGraph -Scopes 'Organization.Read.All' -NoWelcome

$report = Get-MgSubscribedSku -All | ForEach-Object {
    $enabled  = [int]$_.PrepaidUnits.Enabled
    $consumed = [int]$_.ConsumedUnits
    [PSCustomObject]@{
        Lizenz     = $_.SkuPartNumber
        Gekauft    = $enabled
        Verbraucht = $consumed
        Frei       = $enabled - $consumed
        Status     = $_.CapabilityStatus
        SkuId      = $_.SkuId
    }
} | Sort-Object Lizenz

Write-Host ''
Write-Host ('{0,-40} {1,8} {2,11} {3,6}' -f 'Lizenz', 'Gekauft', 'Verbraucht', 'Frei') -ForegroundColor Cyan
Write-Host ('-' * 70) -ForegroundColor DarkGray

foreach ($row in $report) {
    $color = if ($row.Frei -lt 0) { 'Red' } elseif ($row.Frei -le $WarnFree) { 'Yellow' } else { 'White' }
    Write-Host ('{0,-40} {1,8} {2,11} {3,6}' -f $row.Lizenz, $row.Gekauft, $row.Verbraucht, $row.Frei) -ForegroundColor $color
}

if ($ExportPath) {
    $report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    Write-Host "`nExportiert nach $ExportPath" -ForegroundColor Green
}
