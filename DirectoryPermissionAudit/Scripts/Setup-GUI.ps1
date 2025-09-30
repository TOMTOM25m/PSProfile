<#!
.SYNOPSIS
    WPF-GUI zur Verwaltung der DirectoryPermissionAudit Einstellungen (MUW-Regelwerk v9.6.2 konform).
.DESCRIPTION
    Enterprise WPF-GUI mit Tab-basierter Organisation zur Verwaltung der Settings-Datei (PSD1/JSON).
    Vollständige Datenanzeige, MUW-Regelwerk v9.6.2 konforme Farben und Struktur.
.NOTES
    Author: Flecki (Tom) Garnreiter
    Version: 2.3.0
    MUW-Regelwerk: v9.6.2
    GUI-Type: WPF (Enterprise Standard)
#>
[CmdletBinding()]
param(
    [string]$SettingsPath = (Join-Path (Join-Path $PSScriptRoot '..') 'Config/DirectoryPermissionAudit.settings.psd1'),
    [string]$JsonConfigPath = (Join-Path (Join-Path $PSScriptRoot '..') 'Config/DirectoryPermissionAudit.settings.json')
)

# MUW-Regelwerk v9.6.2: WPF assemblies (Enterprise Standard)
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# MUW-Regelwerk v9.6.2 Enterprise Farbschema
$Colors = @{
    Primary = "#003366"        # MedUni Wien Corporate Blue
    Success = "#008000"        # Success Green
    Warning = "#FFD700"        # Warning Gold
    Info = "#00FFFF"          # Information Cyan
    Background = "#F5F5F5"     # Light Gray Background
    CardBackground = "#FFFFFF" # White Card Background
    Text = "#000000"          # Black Text
    Border = "#CCCCCC"        # Light Border Gray
}

# MUW-Regelwerk v9.6.2: Helper Functions (Enterprise Standard)
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

# Settings laden oder Defaults erstellen
$settings = Get-DirectoryPermissionAuditSettingsObject -Path $SettingsPath
if (-not $settings.Count) {
    $settings = [ordered]@{ DefaultOutputFormat='HTML'; DefaultDepth=0; IncludeInherited=$true; IncludeSystemAccounts=$false; Parallel=$false; Throttle=5; GroupInclude=@(); GroupExclude=@(); PruneEmpty=$false }
}

# MUW-Regelwerk v9.6.2: WPF XAML Enterprise GUI Definition
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DirectoryPermissionAudit - Settings Manager (MUW-Regelwerk v9.6.2)"
        Height="600" Width="800"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        Background="$($Colors.Background)">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header mit MUW Corporate Design -->
        <Border Grid.Row="0" Background="$($Colors.Primary)" Padding="15">
            <StackPanel>
                <TextBlock Text="DirectoryPermissionAudit" FontSize="24" FontWeight="Bold" Foreground="White"/>
                <TextBlock Text="Settings Manager - MUW-Regelwerk v9.6.2 Enterprise Edition" FontSize="12" Foreground="White" Opacity="0.8"/>
            </StackPanel>
        </Border>
        
        <!-- Tab Control für organisierte Darstellung -->
        <TabControl Grid.Row="1" Margin="10" Background="$($Colors.CardBackground)">
            <!-- Tab 1: Basis-Einstellungen -->
            <TabItem Header="📊 Basis-Einstellungen" FontSize="14">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="20">
                        <GroupBox Header="Ausgabe-Konfiguration" Margin="0,0,0,15" Padding="10" BorderBrush="$($Colors.Border)">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="200"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                
                                <TextBlock Grid.Row="0" Grid.Column="0" Text="Standard-Ausgabeformat:" VerticalAlignment="Center" Margin="0,0,0,10"/>
                                <ComboBox Grid.Row="0" Grid.Column="1" Name="ComboOutputFormat" Height="25" Margin="0,0,0,10">
                                    <ComboBoxItem Content="Human"/>
                                    <ComboBoxItem Content="CSV"/>
                                    <ComboBoxItem Content="JSON"/>
                                    <ComboBoxItem Content="HTML"/>
                                    <ComboBoxItem Content="Excel"/>
                                </ComboBox>
                                
                                <TextBlock Grid.Row="1" Grid.Column="0" Text="Standard-Verzeichnistiefe:" VerticalAlignment="Center"/>
                                <TextBox Grid.Row="1" Grid.Column="1" Name="TextDepth" Height="25"/>
                            </Grid>
                        </GroupBox>
                        
                        <GroupBox Header="Verarbeitungs-Optionen" Margin="0,0,0,15" Padding="10" BorderBrush="$($Colors.Border)">
                            <StackPanel>
                                <CheckBox Name="CheckIncludeInherited" Content="Geerbte Berechtigungen einschließen" Margin="0,5"/>
                                <CheckBox Name="CheckIncludeSystemAccounts" Content="Systemkonten einschließen" Margin="0,5"/>
                                <CheckBox Name="CheckParallel" Content="Parallele Verarbeitung aktivieren" Margin="0,5"/>
                                <CheckBox Name="CheckPruneEmpty" Content="Leere Ordner nach Filterung entfernen" Margin="0,5"/>
                            </StackPanel>
                        </GroupBox>
                        
                        <GroupBox Header="Performance-Einstellungen" Padding="10" BorderBrush="$($Colors.Border)">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="200"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                
                                <TextBlock Text="Parallelitäts-Limit:" VerticalAlignment="Center"/>
                                <TextBox Grid.Column="1" Name="TextThrottle" Height="25"/>
                            </Grid>
                        </GroupBox>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
            
            <!-- Tab 2: Filter-Einstellungen -->
            <TabItem Header="🔍 Filter &amp; Auswahl" FontSize="14">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="20">
                        <GroupBox Header="Gruppen-Filter (Wildcards unterstützt)" Margin="0,0,0,15" Padding="10" BorderBrush="$($Colors.Border)">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="100"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="100"/>
                                </Grid.RowDefinitions>
                                
                                <TextBlock Grid.Row="0" Text="Nur diese Gruppen einschließen (kommagetrennt):" Margin="0,0,0,5"/>
                                <TextBox Grid.Row="1" Name="TextGroupInclude" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>
                                
                                <TextBlock Grid.Row="2" Text="Diese Gruppen ausschließen (kommagetrennt):" Margin="0,15,0,5"/>
                                <TextBox Grid.Row="3" Name="TextGroupExclude" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>
                            </Grid>
                        </GroupBox>
                        
                        <GroupBox Header="Filter-Hilfe" Padding="10" BorderBrush="$($Colors.Info)" BorderThickness="2">
                            <TextBlock TextWrapping="Wrap" Foreground="$($Colors.Primary)">
                                <Run Text="Beispiele für Wildcards:"/>
                                <LineBreak/>
                                <Run Text="• *Admin* - Alle Gruppen mit 'Admin' im Namen"/>
                                <LineBreak/>
                                <Run Text="• vz_* - Alle Gruppen die mit 'vz_' beginnen"/>
                                <LineBreak/>
                                <Run Text="• *_R, *_W, *_D - Mehrere Patterns kommagetrennt"/>
                                <LineBreak/>
                                <LineBreak/>
                                <Run Text="Filter-Reihenfolge: 1. Include → 2. Exclude → 3. PruneEmpty"/>
                            </TextBlock>
                        </GroupBox>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
            
            <!-- Tab 3: System-Informationen -->
            <TabItem Header="ℹ️ System &amp; Status" FontSize="14">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="20">
                        <GroupBox Header="Aktuelle Konfiguration" Margin="0,0,0,15" Padding="10" BorderBrush="$($Colors.Border)">
                            <TextBlock Name="TextCurrentConfig" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" Background="#F8F8F8" Padding="10"/>
                        </GroupBox>
                        
                        <GroupBox Header="System-Informationen" Margin="0,0,0,15" Padding="10" BorderBrush="$($Colors.Border)">
                            <TextBlock Name="TextSystemInfo" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" Background="#F8F8F8" Padding="10"/>
                        </GroupBox>
                        
                        <GroupBox Header="Pfad-Informationen" Padding="10" BorderBrush="$($Colors.Border)">
                            <TextBlock Name="TextPathInfo" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" Background="#F8F8F8" Padding="10"/>
                        </GroupBox>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>
        
        <!-- Footer mit Action Buttons -->
        <Border Grid.Row="2" Background="$($Colors.Background)" Padding="15" BorderBrush="$($Colors.Border)" BorderThickness="0,1,0,0">
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button Name="ButtonSave" Content="💾 Speichern (PSD1)" Width="150" Height="35" Margin="0,0,10,0" 
                        Background="$($Colors.Success)" Foreground="White" FontWeight="Bold"/>
                <Button Name="ButtonExport" Content="📤 Export (JSON)" Width="150" Height="35" Margin="0,0,10,0"
                        Background="$($Colors.Info)" Foreground="Black" FontWeight="Bold"/>
                <Button Name="ButtonClose" Content="❌ Schließen" Width="100" Height="35"
                        Background="$($Colors.Warning)" Foreground="Black" FontWeight="Bold"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

# XAML parsen und Window erstellen
try {
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
} catch {
    Write-Error "XAML parsing failed: $($_.Exception.Message)"
    return
}
# WPF Controls finden und konfigurieren
$ComboOutputFormat = $window.FindName('ComboOutputFormat')
$TextDepth = $window.FindName('TextDepth')
$CheckIncludeInherited = $window.FindName('CheckIncludeInherited')
$CheckIncludeSystemAccounts = $window.FindName('CheckIncludeSystemAccounts')
$CheckParallel = $window.FindName('CheckParallel')
$CheckPruneEmpty = $window.FindName('CheckPruneEmpty')
$TextThrottle = $window.FindName('TextThrottle')
$TextGroupInclude = $window.FindName('TextGroupInclude')
$TextGroupExclude = $window.FindName('TextGroupExclude')
$TextCurrentConfig = $window.FindName('TextCurrentConfig')
$TextSystemInfo = $window.FindName('TextSystemInfo')
$TextPathInfo = $window.FindName('TextPathInfo')
$ButtonSave = $window.FindName('ButtonSave')
$ButtonExport = $window.FindName('ButtonExport')
$ButtonClose = $window.FindName('ButtonClose')

# Settings in GUI laden
$ComboOutputFormat.SelectedItem = $ComboOutputFormat.Items | Where-Object { $_.Content -eq $settings.DefaultOutputFormat }
$TextDepth.Text = [string]$settings.DefaultDepth
$CheckIncludeInherited.IsChecked = [bool]$settings.IncludeInherited
$CheckIncludeSystemAccounts.IsChecked = [bool]$settings.IncludeSystemAccounts
$CheckParallel.IsChecked = [bool]$settings.Parallel
$CheckPruneEmpty.IsChecked = [bool]$settings.PruneEmpty
$TextThrottle.Text = [string]$settings.Throttle
$TextGroupInclude.Text = ($settings.GroupInclude -join ', ')
$TextGroupExclude.Text = ($settings.GroupExclude -join ', ')

# System-Informationen anzeigen
$systemInfo = @"
PowerShell Version: $($PSVersionTable.PSVersion.ToString())
Host: $($env:COMPUTERNAME)
User: $($env:USERNAME)
OS: $([System.Environment]::OSVersion.VersionString)
.NET Version: $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)
Execution Policy: $(Get-ExecutionPolicy)
Current Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
$TextSystemInfo.Text = $systemInfo

# Pfad-Informationen
$pathInfo = @"
Settings Path: $SettingsPath
JSON Export Path: $JsonConfigPath
Script Directory: $PSScriptRoot
Module Root: $(Join-Path $PSScriptRoot '..\Modules')
Config Directory: $(Join-Path $PSScriptRoot '..\Config')
LOG Directory: $(Join-Path $PSScriptRoot '..\LOG')
"@
$TextPathInfo.Text = $pathInfo

# Aktuelle Konfiguration als JSON anzeigen
$TextCurrentConfig.Text = ($settings | ConvertTo-Json -Depth 5)

# Event Handlers für Buttons
$ButtonSave.Add_Click({
    try {
        $newSettings = [ordered]@{
            DefaultOutputFormat = $ComboOutputFormat.SelectedItem.Content
            DefaultDepth = [int]$TextDepth.Text
            IncludeInherited = $CheckIncludeInherited.IsChecked
            IncludeSystemAccounts = $CheckIncludeSystemAccounts.IsChecked
            Parallel = $CheckParallel.IsChecked
            Throttle = [int]$TextThrottle.Text
            GroupInclude = ($TextGroupInclude.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            GroupExclude = ($TextGroupExclude.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            PruneEmpty = $CheckPruneEmpty.IsChecked
        }
        
        Set-SettingsObject -Path $SettingsPath -Data $newSettings
        
        # Aktuelle Konfiguration aktualisieren
        $TextCurrentConfig.Text = ($newSettings | ConvertTo-Json -Depth 5)
        
        [System.Windows.MessageBox]::Show("Einstellungen erfolgreich gespeichert:`n$SettingsPath", "Speichern erfolgreich", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Fehler beim Speichern: $($_.Exception.Message)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$ButtonExport.Add_Click({
    try {
        $jsonData = [ordered]@{
            DefaultOutputFormat = $ComboOutputFormat.SelectedItem.Content
            DefaultDepth = [int]$TextDepth.Text
            IncludeInherited = $CheckIncludeInherited.IsChecked
            IncludeSystemAccounts = $CheckIncludeSystemAccounts.IsChecked
            Parallel = $CheckParallel.IsChecked
            Throttle = [int]$TextThrottle.Text
            GroupInclude = ($TextGroupInclude.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            GroupExclude = ($TextGroupExclude.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            PruneEmpty = $CheckPruneEmpty.IsChecked
        }
        
        Export-SettingsJson -Path $JsonConfigPath -Data $jsonData
        [System.Windows.MessageBox]::Show("Konfiguration erfolgreich exportiert:`n$JsonConfigPath", "Export erfolgreich", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Fehler beim Export: $($_.Exception.Message)", "Fehler", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$ButtonClose.Add_Click({
    $window.Close()
})

# GUI anzeigen
[void]$window.ShowDialog()
