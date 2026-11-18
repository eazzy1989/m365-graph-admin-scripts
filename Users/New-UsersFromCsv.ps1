<#
.SYNOPSIS
    Legt neue Microsoft-365-Benutzer aus einer CSV-Datei an (Onboarding).

.DESCRIPTION
    Liest Vorname, Nachname, Abteilung, Position und optional eine Lizenz aus einer CSV
    und legt daraus Benutzer in Microsoft Entra ID an:
    - UPN nach dem Schema vorname.nachname@<Domain> (Umlaute werden ersetzt)
    - zufälliges Startpasswort, Änderung bei der ersten Anmeldung erzwungen
    - optional Zuweisung einer Lizenz (SkuPartNumber, z. B. ENTERPRISEPACK)
    Bereits vorhandene UPNs werden übersprungen.

    Unterstützt -WhatIf: zeigt an, was passieren würde, ohne etwas anzulegen.

.PARAMETER CsvPath
    Pfad zur CSV-Datei (Spalten: Vorname, Nachname, Abteilung, Position, Lizenz).

.PARAMETER Domain
    Domain für den UPN, z. B. contoso.onmicrosoft.com

.PARAMETER UsageLocation
    Nutzungsort (für Lizenzen erforderlich). Standard: DE

.EXAMPLE
    .\New-UsersFromCsv.ps1 -CsvPath ..\Beispiele\neue-benutzer.csv -Domain contoso.onmicrosoft.com -WhatIf

.EXAMPLE
    .\New-UsersFromCsv.ps1 -CsvPath .\onboarding.csv -Domain contoso.de

.NOTES
    Autor:     eazzy1989
    Benötigt:  Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement
    Scopes:    User.ReadWrite.All, Organization.Read.All
    Die Startpasswörter werden nur in der Konsole ausgegeben und sollten sicher übergeben werden.
#>
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$CsvPath,
    [Parameter(Mandatory)][string]$Domain,
    [string]$UsageLocation = 'DE'
)

function ConvertTo-UpnPart([string]$Text) {
    $t = $Text.Trim().ToLower()
    $t = $t -replace 'ä', 'ae' -replace 'ö', 'oe' -replace 'ü', 'ue' -replace 'ß', 'ss'
    $t = $t.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
    return ($t -replace '[^a-z0-9\-]', '')
}

function New-RandomPassword([int]$Length = 16) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!$%&*?'.ToCharArray()
    $bytes = [byte[]]::new($Length)
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    # Mindestens je ein Groß-, Kleinbuchstabe, Ziffer und Sonderzeichen voranstellen
    return 'Aa1!' + (-join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] }))
}

Connect-MgGraph -Scopes 'User.ReadWrite.All', 'Organization.Read.All' -NoWelcome

# Lizenzen einmal laden: SkuPartNumber -> SkuId
$skus = @{}
Get-MgSubscribedSku -All | ForEach-Object { $skus[$_.SkuPartNumber] = $_.SkuId }

$rows = Import-Csv -Path $CsvPath
$created = 0; $skipped = 0; $failed = 0
$results = @()

foreach ($row in $rows) {
    $first = $row.Vorname.Trim()
    $last  = $row.Nachname.Trim()
    $nick  = '{0}.{1}' -f (ConvertTo-UpnPart $first), (ConvertTo-UpnPart $last)
    $upn   = "$nick@$Domain"

    if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue) {
        Write-Host "[VORHANDEN]   $upn" -ForegroundColor Yellow
        $skipped++
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($upn, 'Benutzer anlegen')) { continue }

    try {
        $password = New-RandomPassword
        $user = New-MgUser `
            -DisplayName "$first $last" `
            -GivenName $first `
            -Surname $last `
            -UserPrincipalName $upn `
            -MailNickname $nick `
            -Department $row.Abteilung `
            -JobTitle $row.Position `
            -UsageLocation $UsageLocation `
            -AccountEnabled `
            -PasswordProfile @{ Password = $password; ForceChangePasswordNextSignIn = $true } `
            -ErrorAction Stop

        $license = $row.Lizenz
        if ($license) {
            if ($skus.ContainsKey($license)) {
                Set-MgUserLicense -UserId $user.Id -AddLicenses @(@{ SkuId = $skus[$license] }) -RemoveLicenses @() -ErrorAction Stop | Out-Null
            }
            else {
                Write-Warning "Lizenz '$license' gibt es im Tenant nicht – $upn wurde ohne Lizenz angelegt."
            }
        }

        Write-Host "[ANGELEGT]    $upn" -ForegroundColor Green
        $results += [PSCustomObject]@{ UPN = $upn; Startpasswort = $password; Lizenz = $license }
        $created++
    }
    catch {
        Write-Host "[FEHLER]      $upn – $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nAngelegt: $created   Übersprungen: $skipped   Fehler: $failed" -ForegroundColor Cyan

if ($results) {
    Write-Host "`nStartpasswörter (sicher weitergeben, nicht speichern):" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
}
