<#!
.SYNOPSIS
    GUI zur Verwaltung der DirectoryPermissionAudit Einstellungen.
.DESCRIPTION
    Ermöglicht das Laden, Anpassen und Speichern der Settings-Datei (PSD1/JSON).
    Optional kann in eine JSON-Konfiguration exportiert werden.
#>
[CmdletBinding()]
param(
    [string]$SettingsPath = (Join-Path (Join-Path $PSScriptRoot '..') 'Config/DirectoryPermissionAudit.settings.psd1'),
    [string]$JsonConfigPath = (Join-Path (Join-Path $PSScriptRoot '..') 'Config/DirectoryPermissionAudit.settings.json')
)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Approved verb alternative to satisfy analyzer
function Get-DirectoryPermissionAuditSettingsObject {
    param([string]$Path)
    if (Test-Path $Path) {
        try { return Import-PowerShellDataFile -Path $Path } catch { [ordered]@{} }
    } else { [ordered]@{} }
}
function Set-SettingsObject {
    param([string]$Path,[hashtable]$Data)
    $contentLines = '@{'
    foreach ($k in $Data.Keys) { $v = $Data[$k]; if ($v -is [string]) { $contentLines += "    $k = '$v'" } else { $contentLines += "    $k = $v" } }
    $contentLines += '}'
    Set-Content -Path $Path -Value $contentLines -Encoding UTF8
}
function Export-SettingsJson {
    param([string]$Path,[hashtable]$Data)
    $Data | ConvertTo-Json | Set-Content -Path $Path -Encoding UTF8
}
$settings = Get-DirectoryPermissionAuditSettingsObject -Path $SettingsPath
if (-not $settings.Count) {
    $settings = [ordered]@{ DefaultOutputFormat='HTML'; DefaultDepth=0; IncludeInherited=$true; IncludeSystemAccounts=$false; Parallel=$false; Throttle=5; GroupInclude=@(); GroupExclude=@(); PruneEmpty=$false }
}
$form = New-Object Windows.Forms.Form
$form.Text = 'DirectoryPermissionAudit - Settings'
$form.Size = New-Object Drawing.Size(540,380)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $true

$labels = @('DefaultOutputFormat','DefaultDepth','IncludeInherited','IncludeSystemAccounts','Parallel','Throttle','GroupInclude','GroupExclude','PruneEmpty')
$y = 20
$controls = @{}
foreach ($name in $labels) {
    $lbl = New-Object Windows.Forms.Label
    $lbl.Text = $name
    $lbl.Location = New-Object Drawing.Point(20,$y+4)
    $lbl.AutoSize = $true
    $form.Controls.Add($lbl)

    if ($name -in 'IncludeInherited','IncludeSystemAccounts','Parallel','PruneEmpty') {
        $cb = New-Object Windows.Forms.CheckBox
        $cb.Location = New-Object Drawing.Point(200,$y)
        $cb.Width = 200
        $cb.Checked = [bool]$settings[$name]
        $controls[$name] = $cb
        $form.Controls.Add($cb)
    } elseif ($name -eq 'DefaultOutputFormat') {
        $combo = New-Object Windows.Forms.ComboBox
        $combo.Location = New-Object Drawing.Point(200,$y)
        $combo.Width = 250
        $combo.DropDownStyle = 'DropDownList'
        'Human','CSV','JSON','HTML','Excel' | ForEach-Object { [void]$combo.Items.Add($_) }
        $combo.SelectedItem = $settings[$name]
        $controls[$name] = $combo
        $form.Controls.Add($combo)
    } elseif ($name -in 'GroupInclude','GroupExclude') {
        $txt = New-Object Windows.Forms.TextBox
        $txt.Location = New-Object Drawing.Point(200,$y)
        $txt.Width = 250
        $txt.Text = ($settings[$name] -join ',')
        $controls[$name] = $txt
        $form.Controls.Add($txt)
    }
    else {
        $txt = New-Object Windows.Forms.TextBox
        $txt.Location = New-Object Drawing.Point(200,$y)
        $txt.Width = 250
        $txt.Text = [string]$settings[$name]
        $controls[$name] = $txt
        $form.Controls.Add($txt)
    }
    $y += 40
}
$btnSave = New-Object Windows.Forms.Button
$btnSave.Text = 'Speichern (PSD1)'
$btnSave.Location = New-Object Drawing.Point(20,$y+10)
$btnSave.Add_Click({
    $new = [ordered]@{}
    foreach ($k in $labels) {
        $ctrl = $controls[$k]
        switch ($k) {
            'IncludeInherited' { $new[$k] = $ctrl.Checked }
            'IncludeSystemAccounts' { $new[$k] = $ctrl.Checked }
            'Parallel' { $new[$k] = $ctrl.Checked }
            'DefaultDepth' { $new[$k] = [int]$ctrl.Text }
            'Throttle' { $new[$k] = [int]$ctrl.Text }
            'GroupInclude' { $new[$k] = ($ctrl.Text -split ',').Where({$_ -and $_.Trim()}) }
            'GroupExclude' { $new[$k] = ($ctrl.Text -split ',').Where({$_ -and $_.Trim()}) }
            'PruneEmpty' { $new[$k] = $ctrl.Checked }
            'DefaultOutputFormat' { $new[$k] = $ctrl.SelectedItem }
            default { $new[$k] = $ctrl.Text }
        }
    }
    Set-SettingsObject -Path $SettingsPath -Data $new
    [Windows.Forms.MessageBox]::Show("Gespeichert: $SettingsPath","OK") | Out-Null
})
$form.Controls.Add($btnSave)

$btnExport = New-Object Windows.Forms.Button
$btnExport.Text = 'Export als JSON'
$btnExport.Location = New-Object Drawing.Point(200,$y+10)
$btnExport.Add_Click({
    $jsonData = @{}
    foreach ($k in $labels) {
        $ctrl = $controls[$k]
        $jsonData[$k] = switch ($k) {
            'IncludeInherited' { $ctrl.Checked }
            'IncludeSystemAccounts' { $ctrl.Checked }
            'Parallel' { $ctrl.Checked }
            'DefaultDepth' { [int]$ctrl.Text }
            'Throttle' { [int]$ctrl.Text }
            'GroupInclude' { ($ctrl.Text -split ',').Where({$_ -and $_.Trim()}) }
            'GroupExclude' { ($ctrl.Text -split ',').Where({$_ -and $_.Trim()}) }
            'PruneEmpty' { $ctrl.Checked }
            'DefaultOutputFormat' { $ctrl.SelectedItem }
            default { $ctrl.Text }
        }
    }
    Export-SettingsJson -Path $JsonConfigPath -Data $jsonData
    [Windows.Forms.MessageBox]::Show("Exportiert: $JsonConfigPath","OK") | Out-Null
})
$form.Controls.Add($btnExport)

$btnClose = New-Object Windows.Forms.Button
$btnClose.Text = 'Schließen'
$btnClose.Location = New-Object Drawing.Point(380,$y+10)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

[void]$form.ShowDialog()
