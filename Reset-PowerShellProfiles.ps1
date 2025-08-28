<#
.SYNOPSIS
    [DE] Setzt alle PowerShell-Profile auf einen Standard zurück, versioniert Vorlagen und verwaltet die Konfiguration über eine GUI.
    [EN] Resets all PowerShell profiles to a standard, versions templates, and manages the configuration via a GUI.
.DESCRIPTION
    [DE] Ein vollumfängliches Verwaltungsskript für PowerShell-Profile gemäss MUW-Regeln. Es erzwingt Administratorrechte,
         stellt die UTF-8-Kodierung sicher und bietet eine WPF-basierte GUI (-Setup) zur Konfiguration. Bei fehlender
         oder korrupter Konfiguration startet die GUI automatisch. Das Skript führt eine Versionskontrolle der Konfiguration
         durch, versioniert die Profil-Vorlagen, schreibt in das Windows Event Log und beinhaltet eine voll funktionsfähige
         Log-Archivierung sowie einen Mail-Versand.
    [EN] A comprehensive management script for PowerShell profiles according to MUW rules. It enforces administrator rights,
         ensures UTF-8 encoding, and provides a WPF-based GUI (-Setup) for configuration. The GUI starts automatically
         if the configuration is missing or corrupt. The script performs version control of the configuration, versions
         the profile templates, writes to the Windows Event Log, and includes fully functional log archiving and mail sending.
.PARAMETER Setup
    [DE] Startet die WPF-Konfigurations-GUI, um die Einstellungen zu bearbeiten.
    [EN] Starts the WPF configuration GUI to edit the settings.
.PARAMETER Versionscontrol
    [DE] Prüft die Konfigurationsdatei gegen die Skript-Version, zeigt Unterschiede an und aktualisiert sie.
    [EN] Checks the configuration file against the script version, displays differences, and updates it.
.PARAMETER ConfigFile
    [DE] Pfad zur JSON-Konfigurationsdatei. Standard: 'Config\Config-Reset-PowerShellProfiles.ps1.json' im Skriptverzeichnis.
    [EN] Path to the JSON configuration file. Default: 'Config\Config-Reset-PowerShellProfiles.ps1.json' in the script directory.
.EXAMPLE
    .\Reset-PowerShellProfiles.ps1
    [DE] Führt das Skript aus. Setzt die Profile zurück und fordert bei Bedarf Admin-Rechte an. Startet die GUI bei Erstkonfiguration.
    [EN] Executes the script. Resets the profiles and requests admin rights if necessary. Starts the GUI on first configuration.
.EXAMPLE
    .\Reset-PowerShellProfiles.ps1 -Setup
    [DE] Öffnet die Konfigurations-GUI, um die aktuellen Einstellungen zu ändern.
    [EN] Opens the configuration GUI to change the current settings.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.07.11
    Last modified:  2025.08.28
    old Version:    v08.00.14
    Version now:    v08.00.15
    MUW-Regelwerk:  v6.6.6
    Notes:          [DE] Finale Korrektur für XAML-Parsing-Fehler und -Setup Endlosschleife.
                    [EN] Final fix for XAML parsing error and -Setup infinite loop.
    Copyright:      © 2025 Flecki Garnreiter
.DISCLAIMER
    [DE] Die bereitgestellten Skripte und die zugehörige Dokumentation werden "wie besehen" ("as is")
    ohne ausdrückliche oder stillschweigende Gewährleistung jeglicher Art zur Verfügung gestellt.
    Insbesondere wird keinerlei Gewähr übernommen für die Marktgängigkeit, die Eignung für einen bestimmten Zweck
    oder die Nichtverletzung von Rechten Dritter.
    Es besteht keine Verpflichtung zur Wartung, Aktualisierung oder Unterstützung der Skripte. Jegliche Nutzung erfolgt auf eigenes Risiko.
    In keinem Fall haften Herr Flecki Garnreiter, sein Arbeitgeber oder die Mitwirkenden an der Erstellung,
    Entwicklung oder Verbreitung dieser Skripte für direkte, indirekte, zufällige, besondere oder Folgeschäden - einschließlich,
    aber nicht beschränkt auf entgangenen Gewinn, Betriebsunterbrechungen, Datenverlust oder sonstige wirtschaftliche Verluste -,
    selbst wenn sie auf die Möglichkeit solcher Schäden hingewiesen wurden.
    Durch die Nutzung der Skripte erklären Sie sich mit diesen Bedingungen einverstanden.

    [EN] The scripts and accompanying documentation are provided "as is," without warranty of any kind, either express or implied.
    Flecki Garnreiter and his employer disclaim all warranties, including but not limited to the implied warranties of merchantability,
    fitness for a particular purpose, and non-infringement.
    There is no obligation to provide maintenance, support, updates, or enhancements for the scripts.
    Use of these scripts is at your own risk. Under no circumstances shall Flecki Garnreiter, his employer, the authors,
    or any party involved in the creation, production, or distribution of the scripts be held liable for any damages whatever,
    including but not not limited to direct, indirect, incidental, consequential, or special damages
    (such as loss of profits, business interruption, or loss of business data), even if advised of the possibility of such damages.
    By using these scripts, you agree to be bound by the above terms.
#>
#requires -Version 5.1
#requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Switch]$Setup,
    [Switch]$Versionscontrol,
    [string]$ConfigFile
)

#region ####################### [1. Initialization & Self-Elevation] ##############################
$Global:ScriptName = $MyInvocation.MyCommand.Name
$Global:ScriptVersion = "v08.00.15"
$Global:RulebookVersion = "v6.6.6"
$Global:ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path

# --- Configuration Directory Management ---
$configDir = Join-Path $Global:ScriptDirectory 'Config'
if (-not (Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory | Out-Null
}

# One-time migration of .json files from root to /Config
$rootJsonFiles = Get-ChildItem -Path $Global:ScriptDirectory -Filter *.json -File
if ($rootJsonFiles) {
    Write-Host "[INFO] Migrating .json files to the 'Config' subfolder for better organization..." -ForegroundColor Cyan
    $rootJsonFiles | ForEach-Object {
        $destinationFile = Join-Path $configDir $_.Name
        Copy-Item -Path $_.FullName -Destination $destinationFile -Force
        if (Test-Path $destinationFile) {
            Remove-Item $_.FullName -Force
            Write-Host "  - Migrated '$($_.Name)' successfully."
        }
        else {
            Write-Warning "  - Failed to migrate '$($_.Name)'."
        }
    }
}

if ([string]::IsNullOrEmpty($ConfigFile)) {
    $ConfigFile = Join-Path -Path $configDir -ChildPath "Config-$($MyInvocation.MyCommand.Name).json"
}

$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
#endregion

#region ####################### [2. Core Functions (Config, Log, Mail, Archive)] ########################

function Get-DefaultConfig {
    # This function doesn't write logs because $Global:Config might not exist yet.
    return [PSCustomObject]@{ 
        Version           = $Global:ScriptVersion
        RulebookVersion   = $Global:RulebookVersion
        Language          = "de-DE"
        Environment       = "DEV"
        WhatIfMode        = $true
        TemplateVersions  = @{
            Profile    = "v23.0.1"
            ProfileX   = "v6.0.0"
            ProfileMOD = "v6.0.0"
        }
        TemplateFilePaths = @(
            (Join-Path $Global:ScriptDirectory 'Profile-template.ps1'),
            (Join-Path $Global:ScriptDirectory 'Profile-templateX.ps1'),
            (Join-Path $Global:ScriptDirectory 'Profile-templateMOD.ps1')
        )
        UNCPaths          = @{
            Logo = '\\itscmgmt03.srv.meduniwien.ac.at\iso\DEV\Images\Logo.ico'
        }
        Logging           = @{
            LogPath              = (Join-Path $Global:ScriptDirectory "LOG")
            ReportPath           = (Join-Path $Global:ScriptDirectory "Reports")
            LogoPath             = (Join-Path $Global:ScriptDirectory "Images\Logo.ico")
            EnableEventLog       = $true
            ArchiveLogs          = $true
            LogRetentionDays     = 30
            ArchiveRetentionDays = 90
            SevenZipPath         = "C:\Program Files\7-Zip\7z.exe"
        }
        Backup            = @{
            Enabled = $false
            Path    = ""
        }
        Mail              = @{
            Enabled    = $false
            SmtpServer = "smtpi.meduniwien.ac.at"
            SmtpPort   = 25
            UseSsl     = $false
            Sender     = "$($env:COMPUTERNAME)@meduniwien.ac.at"
            DevTo      = "Thomas.garnreiter@meduniwien.ac.at"
            ProdTo     = "win-admin@meduniwien.ac.at;another.admin@meduniwien.ac.at"
        }
        GitUpdate         = @{
            Enabled        = $false
            RepositoryUrl  = "https://your-git-server/user/powershell-profiles.git"
            Branch         = "main"
            LocalCachePath = (Join-Path $Global:ScriptDirectory "GitCache")
        }
    }
}

function Write-Log {
    param (
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")][string]$Level = "INFO",
        [switch]$NoHostWrite
    )
    $isDev = $Global:Config -and $Global:Config.Environment -eq "DEV"
    if ($Level -eq "DEBUG" -and -not $isDev) { return }

    $timestamp = Get-Date -Format "yyyy.MM.dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    if (-not $NoHostWrite) {
        $colorMap = @{ INFO = "White"; WARNING = "Yellow"; ERROR = "Red"; DEBUG = "Cyan" }
        Write-Host $logEntry -ForegroundColor $colorMap[$Level]
    }

    try {
        if ($Global:Config -and $Global:Config.Logging.LogPath) {
            $logPath = $Global:Config.Logging.LogPath
            if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
            
            $logFileBaseName = $Global:ScriptName -replace '\.ps1', ''
            $logFileName = if ($isDev) { "DEBUG_$($logFileBaseName)_$(Get-Date -Format 'yyyy-MM-dd').log" } else { "$($logFileBaseName)_$(Get-Date -Format 'yyyy-MM-dd').log" }
            $logFile = Join-Path $logPath $logFileName
            
            Add-Content -Path $logFile -Value $logEntry
        }
    }
    catch { Write-Warning "Could not write to log file. Reason: $($_.Exception.Message)" }

    if ($Level -in @('ERROR', 'WARNING')) {
        Write-EventLogEntry -Level $Level -Message $Message
    }
}

function Write-EventLogEntry {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Level, [string]$Message)
    
    if (-not ($Global:Config -and $Global:Config.Logging.EnableEventLog)) {
        Write-Log -Level DEBUG -Message "Event logging is disabled in the configuration."
        return
    }

    try {
        if (-not (Get-EventLog -LogName Application -Source $Global:ScriptName -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess("EventLog Source: $Global:ScriptName", "Create")) {
                New-EventLog -LogName Application -Source $Global:ScriptName -ErrorAction Stop
                Write-Log -Level INFO -Message "Event Log Source '$($Global:ScriptName)' was registered successfully."
            }
        }
        $typeMap = @{ ERROR = 'Error'; WARNING = 'Warning' }
        Write-EventLog -LogName Application -Source $Global:ScriptName -Message $Message -EventId 1000 -EntryType $typeMap[$Level] -ErrorAction Stop
    }
    catch { Write-Warning "Error writing to Windows Event Log: $($_.Exception.Message)" }
}

function Save-Config {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([PSCustomObject]$Config, [string]$Path, [switch]$NoHostWrite)

    if ($PSCmdlet.ShouldProcess($Path, "Save Configuration")) {
        try {
            Write-Log -Level DEBUG -Message "Saving configuration to '$Path'." -NoHostWrite:$NoHostWrite
            $Config.Version = $Global:ScriptVersion
            $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
            return $true
        }
        catch {
            Write-Log -Level ERROR -Message "Error saving configuration file: $($_.Exception.Message)" -NoHostWrite:$NoHostWrite
            return $false
        }
    }
    return $false
}

function Get-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    try {
        $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Log -Level WARNING -Message "Configuration file '$Path' is corrupt."
        return $null
    }
}

function Invoke-VersionControl {
    param([PSCustomObject]$LoadedConfig, [string]$ConfigPath)
    Write-Log -Level INFO -Message "Starting version control for configuration file..."
    $defaultConfig = Get-DefaultConfig
    $isUpdated = $false
    function Compare-AndUpdate($Reference, $Target) {
        $updated = $false
        foreach ($key in $Reference.PSObject.Properties.Name) {
            # Robustly check if the target object has a property with the same name as the key from the reference object.
            if (-not $Target.PSObject.Properties[$key]) {
                Write-Log -Level WARNING -Message "Missing property in configuration found. Adding '$key'."
                $Target | Add-Member -MemberType NoteProperty -Name $key -Value $Reference.$key
                $updated = $true
            }
            elseif (($Reference.$key -is [PSCustomObject]) -and ($Target.$key -is [PSCustomObject])) {
                # Recurse into nested objects
                if (Compare-AndUpdate -Reference $Reference.$key -Target $Target.$key) { $updated = $true }
            }
        }
        return $updated
    }
    if (Compare-AndUpdate -Reference $defaultConfig -Target $LoadedConfig) { $isUpdated = $true }
    if ($LoadedConfig.Version -ne $Global:ScriptVersion) {
        Write-Log -Level WARNING -Message "Version conflict! Script is $($Global:ScriptVersion), Config was $($LoadedConfig.Version). Configuration will be updated."
        $LoadedConfig.Version = $Global:ScriptVersion
        $isUpdated = $true
    }
    if ($LoadedConfig.RulebookVersion -ne $Global:RulebookVersion) {
        Write-Log -Level WARNING -Message "Rulebook version conflict! Script requires $($Global:RulebookVersion), Config has $($LoadedConfig.RulebookVersion). Updating."
        $LoadedConfig.RulebookVersion = $Global:RulebookVersion
        $isUpdated = $true
    }
    if ($isUpdated) {
        Write-Log -Level INFO -Message "Configuration file has been updated. Saving changes."
        Save-Config -Config $LoadedConfig -Path $ConfigPath
    }
    else { Write-Log -Level INFO -Message "Configuration is up to date." }
}

function Send-MailNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$Body
    )
    $mailSettings = $Global:Config.Mail
    if (-not $mailSettings.Enabled) {
        Write-Log -Level DEBUG -Message "Mail notifications are disabled."
        return
    }
    
    if ([string]::IsNullOrEmpty($mailSettings.SmtpServer)) {
        Write-Log -Level WARNING -Message "SMTP server is not configured. Email could not be sent."
        return
    }

    Write-Log -Level DEBUG -Message "Testing connection to SMTP server $($mailSettings.SmtpServer) on port $($mailSettings.SmtpPort)..."
    if (-not (Test-NetConnection -ComputerName $mailSettings.SmtpServer -Port $mailSettings.SmtpPort -WarningAction SilentlyContinue)) {
        Write-Log -Level WARNING -Message "SMTP server unreachable. Email could not be sent."
        return
    }
    
    $isDev = $Global:Config.Environment -eq "DEV"
    $recipientString = if ($isDev) { $mailSettings.DevTo } else { $mailSettings.ProdTo }
    $recipients = $recipientString -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) }

    if ([string]::IsNullOrEmpty($mailSettings.Sender) -or $recipients.Count -eq 0) {
        Write-Log -Level WARNING -Message "Sender or recipient(s) are not configured. Email could not be sent."
        return
    }

    $recipientLogString = $recipients -join ', '
    Write-Log -Level INFO -Message "Sending email notification to '$recipientLogString'"
    try {
        $smtpClient = New-Object System.Net.Mail.SmtpClient($mailSettings.SmtpServer, $mailSettings.SmtpPort)
        $smtpClient.EnableSsl = $mailSettings.UseSsl
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = $mailSettings.Sender
        $recipients | ForEach-Object { $mailMessage.To.Add($_) }
        $mailMessage.Subject = $Subject
        $mailMessage.Body = $Body
        
        $smtpClient.Send($mailMessage)
        Write-Log -Level INFO -Message "Email sent successfully."
    }
    catch { Write-Log -Level ERROR -Message "Error sending email: $($_.Exception.Message)" }
    finally {
        if ($smtpClient) { $smtpClient.Dispose() }
        if ($mailMessage) { $mailMessage.Dispose() }
    }
}

function Invoke-ArchiveMaintenance {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if (-not $Global:Config.Logging.ArchiveLogs) {
        Write-Log -Level INFO -Message "Log archiving is disabled."
        return
    }
    Write-Log -Level INFO -Message "Starting archive maintenance..."
    $logConf = $Global:Config.Logging
    $use7Zip = (Test-Path $logConf.SevenZipPath) -and ($logConf.SevenZipPath.EndsWith("7z.exe"))

    $cutoffDate = (Get-Date).AddDays(-$logConf.LogRetentionDays)
    $logsToArchive = Get-ChildItem -Path $logConf.LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    if ($logsToArchive) {
        $archiveName = "$($Global:ScriptName -replace '\.ps1', '')_$((Get-Date).AddMonths(-1).ToString('yyyy_MM')).zip"
        $archivePath = Join-Path $logConf.LogPath $archiveName
        Write-Log -Level INFO -Message "Archiving $($logsToArchive.Count) log files to '$archivePath'..."
        try {
            if ($PSCmdlet.ShouldProcess($archivePath, "Create Archive")) {
                if ($use7Zip) {
                    $filesString = $logsToArchive.FullName -join '" "'
                    Start-Process -FilePath $logConf.SevenZipPath -ArgumentList "a -tzip `"$archivePath`" `"$filesString`"" -Wait -NoNewWindow
                }
                else {
                    Compress-Archive -Path $logsToArchive.FullName -DestinationPath $archivePath -Update
                }
                $logsToArchive | Remove-Item -Force
            }
        }
        catch { Write-Log -Level ERROR -Message "Archiving failed: $($_.Exception.Message)" }
    }
    $archiveCutoffDate = (Get-Date).AddDays(-$logConf.ArchiveRetentionDays)
    Get-ChildItem -Path $logConf.LogPath -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $archiveCutoffDate } | ForEach-Object {
        Write-Log -Level INFO -Message "Deleting old archive: $($_.FullName)"
        if ($PSCmdlet.ShouldProcess($_.FullName, "Delete old archive")) {
            $_ | Remove-Item -Force
        }
    }
}

#endregion

#region ####################### [3. GUI (WPF)] ######################################################
function Show-MuwSetupGui {
    param(
        [PSCustomObject]$InitialConfig
    )
    Write-Progress -Activity "Initializing GUI" -Status "Please wait..."
    Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

    # --- External Localization ---
    $configDir = Join-Path $Global:ScriptDirectory 'Config'
    $lang = if ($InitialConfig.Language -in @('de-DE', 'en-US')) { $InitialConfig.Language } else { 'en-US' }
    $langFilePath = Join-Path $configDir "$lang.json"
    if (-not (Test-Path $langFilePath)) {
        Write-Log -Level ERROR -Message "Localization file '$langFilePath' not found. Aborting GUI."
        return $false
    }
    $T = Get-Content -Path $langFilePath | ConvertFrom-Json

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="SetupWindow" Height="580" Width="600" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#F0F0F0">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        
        <TabControl Grid.Row="0" Background="White">
            <TabControl.Resources>
                <Style TargetType="TabItem">
                    <Setter Property="Padding" Value="10,5"/>
                    <Setter Property="Background" Value="LightGray"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="TabItem">
                                <Border Name="Border" BorderThickness="1,1,1,0" BorderBrush="Gainsboro" CornerRadius="4,4,0,0" Margin="2,0">
                                    <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="10,2"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter TargetName="Border" Property="Background" Value="#111d4e" />
                                        <Setter Property="Foreground" Value="White"/>
                                    </Trigger>
                                    <Trigger Property="IsSelected" Value="False">
                                        <Setter TargetName="Border" Property="Background" Value="LightGray" />
                                        <Setter Property="Foreground" Value="Black"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
            </TabControl.Resources>

            <TabItem Name="TabGeneral">
                <StackPanel Margin="15">
                    <Label Name="LblLanguage"/>
                    <ComboBox Name="LangComboBox" SelectedIndex="0">
                        <ComboBoxItem Content="Deutsch (de-DE)"/>
                        <ComboBoxItem Content="English (en-US)"/>
                    </ComboBox>
                    <Label Name="LblEnvironment" Margin="0,10,0,0"/>
                    <ComboBox Name="EnvComboBox" SelectedIndex="0">
                        <ComboBoxItem Content="DEV"/>
                        <ComboBoxItem Content="PROD"/>
                    </ComboBox>
                    <TextBlock Name="HelpEnv" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,2,0,0"/>
                    <CheckBox Name="WhatIfCheckBox" Margin="0,15,0,0"/>
                    <TextBlock Name="HelpWhatIf" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,2,0,0"/>
                    <CheckBox Name="ArchiveCheckBox" Margin="0,15,0,0"/>
                    <CheckBox Name="EventLogCheckBox" Margin="0,10,0,0"/>
                </StackPanel>
            </TabItem>
            
            <TabItem Name="TabPaths">
                 <StackPanel Margin="15">
                    <GroupBox Name="GrpLoggingPaths">
                        <StackPanel Margin="10">
                            <Label Name="LblLogDir"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                                <TextBox Name="LogPathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                                <Button Name="BrowseLogPath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                            </Grid>
                            <Label Name="LblReportDir" Margin="0,10,0,0"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                                <TextBox Name="ReportPathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                                <Button Name="BrowseReportPath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                            </Grid>
                        </StackPanel>
                    </GroupBox>
                    <GroupBox Name="GrpTemplatePaths" Margin="0,10,0,0">
                        <StackPanel Margin="10">
                            <Label Name="LblStdTemplate"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                                <TextBox Name="TemplatePathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                                <Button Name="BrowseTemplatePath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                            </Grid>
                            <Label Name="LblTemplateX" Margin="0,10,0,0"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                                <TextBox Name="TemplateXPathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                                <Button Name="BrowseTemplateXPath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                            </Grid>
                            <Label Name="LblTemplateMOD" Margin="0,10,0,0"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                                <TextBox Name="TemplateMODPathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                                <Button Name="BrowseTemplateMODPath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                            </Grid>
                        </StackPanel>
                    </GroupBox>
                 </StackPanel>
            </TabItem>

            <TabItem Name="TabBackup">
                 <StackPanel Margin="15">
                    <CheckBox Name="BackupCheckBox"/>
                    <Label Name="LblBackupPath" Margin="0,10,0,0"/>
                    <Grid>
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                        <TextBox Name="BackupPathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                        <Button Name="BrowseBackupPath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                    </Grid>
                 </StackPanel>
            </TabItem>

            <TabItem Name="TabMail">
                 <StackPanel Margin="15">
                    <CheckBox Name="MailCheckBox"/>
                    <Label Name="LblSmtpServer" Margin="0,10,0,0"/>
                    <TextBox Name="SmtpServerTextBox"/>
                    <Label Name="LblSender" Margin="0,10,0,0"/>
                    <TextBox Name="SenderTextBox"/>
                    <Label Name="LblDevRecipient" Margin="0,10,0,0"/>
                    <TextBox Name="DevToTextBox"/>
                    <Label Name="LblProdRecipient" Margin="0,10,0,0"/>
                    <TextBox Name="ProdToTextBox"/>
                    <TextBlock Name="HelpMailProd" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,2,0,0"/>
                 </StackPanel>
            </TabItem>

            <TabItem Name="TabUpdate">
                 <StackPanel Margin="15">
                    <CheckBox Name="GitUpdateCheckBox"/>
                    <TextBlock Name="HelpGitUpdate" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,2,0,10"/>
                    <Label Name="LblGitRepoUrl" Margin="0,10,0,0"/>
                    <TextBox Name="GitRepoUrlTextBox"/>
                    <Label Name="LblGitBranch" Margin="0,10,0,0"/>
                    <TextBox Name="GitBranchTextBox"/>
                    <Label Name="LblGitCachePath" Margin="0,10,0,0"/>
                    <Grid>
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
                        <TextBox Name="GitCachePathTextBox" Grid.Column="0" VerticalContentAlignment="Center"/>
                        <Button Name="BrowseGitCachePath" Grid.Column="1" Margin="5,0,0,0" Width="30"/>
                    </Grid>
                 </StackPanel>
            </TabItem>

        </TabControl>

        <Grid Grid.Row="1" Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <Button Name="CancelButton" Width="80" Margin="0,0,5,0" IsCancel="True" Grid.Column="0" HorizontalAlignment="Left"/>
            <StackPanel Orientation="Horizontal" Grid.Column="2" HorizontalAlignment="Right">
                <Button Name="ApplyButton" Width="80" Margin="5,0,0,0"/>
                <Button Name="OkButton" Width="80" Margin="5,0,0,0" IsDefault="True"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
    # Using a try-catch block for robust XAML parsing
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    $controls = @{}
    $window.FindName("OkButton") -and ($controls.OkButton = $window.FindName("OkButton"))
    $window.FindName("ApplyButton") -and ($controls.ApplyButton = $window.FindName("ApplyButton"))
    $window.FindName("CancelButton") -and ($controls.CancelButton = $window.FindName("CancelButton"))
    $window.FindName("LangComboBox") -and ($controls.LangComboBox = $window.FindName("LangComboBox"))
    $window.FindName("EnvComboBox") -and ($controls.EnvComboBox = $window.FindName("EnvComboBox"))
    $window.FindName("WhatIfCheckBox") -and ($controls.WhatIfCheckBox = $window.FindName("WhatIfCheckBox"))
    $window.FindName("LogPathTextBox") -and ($controls.LogPathTextBox = $window.FindName("LogPathTextBox"))
    $window.FindName("ReportPathTextBox") -and ($controls.ReportPathTextBox = $window.FindName("ReportPathTextBox"))
    $window.FindName("BrowseLogPath") -and ($controls.BrowseLogPath = $window.FindName("BrowseLogPath"))
    $window.FindName("BrowseReportPath") -and ($controls.BrowseReportPath = $window.FindName("BrowseReportPath"))
    $window.FindName("ArchiveCheckBox") -and ($controls.ArchiveCheckBox = $window.FindName("ArchiveCheckBox"))
    $window.FindName("EventLogCheckBox") -and ($controls.EventLogCheckBox = $window.FindName("EventLogCheckBox"))
    $window.FindName("BackupCheckBox") -and ($controls.BackupCheckBox = $window.FindName("BackupCheckBox"))
    $window.FindName("BackupPathTextBox") -and ($controls.BackupPathTextBox = $window.FindName("BackupPathTextBox"))
    $window.FindName("BrowseBackupPath") -and ($controls.BrowseBackupPath = $window.FindName("BrowseBackupPath"))
    $window.FindName("MailCheckBox") -and ($controls.MailCheckBox = $window.FindName("MailCheckBox"))
    $window.FindName("SmtpServerTextBox") -and ($controls.SmtpServerTextBox = $window.FindName("SmtpServerTextBox"))
    $window.FindName("SenderTextBox") -and ($controls.SenderTextBox = $window.FindName("SenderTextBox"))
    $window.FindName("DevToTextBox") -and ($controls.DevToTextBox = $window.FindName("DevToTextBox"))
    $window.FindName("ProdToTextBox") -and ($controls.ProdToTextBox = $window.FindName("ProdToTextBox"))
    $window.FindName("TemplatePathTextBox") -and ($controls.TemplatePathTextBox = $window.FindName("TemplatePathTextBox"))
    $window.FindName("BrowseTemplatePath") -and ($controls.BrowseTemplatePath = $window.FindName("BrowseTemplatePath"))
    $window.FindName("TemplateXPathTextBox") -and ($controls.TemplateXPathTextBox = $window.FindName("TemplateXPathTextBox"))
    $window.FindName("BrowseTemplateXPath") -and ($controls.BrowseTemplateXPath = $window.FindName("BrowseTemplateXPath"))
    $window.FindName("TemplateMODPathTextBox") -and ($controls.TemplateMODPathTextBox = $window.FindName("TemplateMODPathTextBox"))
    $window.FindName("BrowseTemplateMODPath") -and ($controls.BrowseTemplateMODPath = $window.FindName("BrowseTemplateMODPath"))
    $window.FindName("GitUpdateCheckBox") -and ($controls.GitUpdateCheckBox = $window.FindName("GitUpdateCheckBox"))
    $window.FindName("GitRepoUrlTextBox") -and ($controls.GitRepoUrlTextBox = $window.FindName("GitRepoUrlTextBox"))
    $window.FindName("GitBranchTextBox") -and ($controls.GitBranchTextBox = $window.FindName("GitBranchTextBox"))
    $window.FindName("GitCachePathTextBox") -and ($controls.GitCachePathTextBox = $window.FindName("GitCachePathTextBox"))
    $window.FindName("BrowseGitCachePath") -and ($controls.BrowseGitCachePath = $window.FindName("BrowseGitCachePath"))

    # Find static controls for localization
    $window.FindName("SetupWindow") -and ($controls.SetupWindow = $window.FindName("SetupWindow"))
    $window.FindName("TabGeneral") -and ($controls.TabGeneral = $window.FindName("TabGeneral") )
    $window.FindName("LblLanguage") -and ($controls.LblLanguage = $window.FindName("LblLanguage"))
    $window.FindName("LblEnvironment") -and ($controls.LblEnvironment = $window.FindName("LblEnvironment"))
    $window.FindName("HelpEnv") -and ($controls.HelpEnv = $window.FindName("HelpEnv"))
    $window.FindName("HelpWhatIf") -and ($controls.HelpWhatIf = $window.FindName("HelpWhatIf"))
    $window.FindName("TabPaths") -and ($controls.TabPaths = $window.FindName("TabPaths"))
    $window.FindName("GrpLoggingPaths") -and ($controls.GrpLoggingPaths = $window.FindName("GrpLoggingPaths"))
    $window.FindName("LblLogDir") -and ($controls.LblLogDir = $window.FindName("LblLogDir"))
    $window.FindName("LblReportDir") -and ($controls.LblReportDir = $window.FindName("LblReportDir"))
    $window.FindName("GrpTemplatePaths") -and ($controls.GrpTemplatePaths = $window.FindName("GrpTemplatePaths"))
    $window.FindName("LblStdTemplate") -and ($controls.LblStdTemplate = $window.FindName("LblStdTemplate"))
    $window.FindName("LblTemplateX") -and ($controls.LblTemplateX = $window.FindName("LblTemplateX"))
    $window.FindName("LblTemplateMOD") -and ($controls.LblTemplateMOD = $window.FindName("LblTemplateMOD"))
    $window.FindName("TabBackup") -and ($controls.TabBackup = $window.FindName("TabBackup"))
    $window.FindName("LblBackupPath") -and ($controls.LblBackupPath = $window.FindName("LblBackupPath"))
    $window.FindName("TabMail") -and ($controls.TabMail = $window.FindName("TabMail"))
    $window.FindName("LblSmtpServer") -and ($controls.LblSmtpServer = $window.FindName("LblSmtpServer"))
    $window.FindName("LblSender") -and ($controls.LblSender = $window.FindName("LblSender"))
    $window.FindName("LblDevRecipient") -and ($controls.LblDevRecipient = $window.FindName("LblDevRecipient"))
    $window.FindName("LblProdRecipient") -and ($controls.LblProdRecipient = $window.FindName("LblProdRecipient"))
    $window.FindName("HelpMailProd") -and ($controls.HelpMailProd = $window.FindName("HelpMailProd"))
    $window.FindName("TabUpdate") -and ($controls.TabUpdate = $window.FindName("TabUpdate"))
    $window.FindName("HelpGitUpdate") -and ($controls.HelpGitUpdate = $window.FindName("HelpGitUpdate"))
    $window.FindName("LblGitRepoUrl") -and ($controls.LblGitRepoUrl = $window.FindName("LblGitRepoUrl"))
    $window.FindName("LblGitBranch") -and ($controls.LblGitBranch = $window.FindName("LblGitBranch"))
    $window.FindName("LblGitCachePath") -and ($controls.LblGitCachePath = $window.FindName("LblGitCachePath"))

    $populateUI = {
        param($config)
        $controls.LangComboBox.SelectedIndex = if ($config.Language -eq 'de-DE') { 0 } else { 1 }
        $controls.EnvComboBox.SelectedIndex = if ($config.Environment -eq 'DEV') { 0 } else { 1 }
        $controls.WhatIfCheckBox.IsChecked = $config.WhatIfMode
    $controls.LogPathTextBox.Text = $config.Logging.LogPath
    $controls.ReportPathTextBox.Text = $config.Logging.ReportPath
    $controls.ArchiveCheckBox.IsChecked = $config.Logging.ArchiveLogs
    $controls.EventLogCheckBox.IsChecked = $config.Logging.EnableEventLog
        $controls.BackupCheckBox.IsChecked = $config.Backup.Enabled
        $controls.BackupPathTextBox.Text = $config.Backup.Path
        $controls.MailCheckBox.IsChecked = $config.Mail.Enabled
        $controls.SmtpServerTextBox.Text = $config.Mail.SmtpServer
        $controls.SenderTextBox.Text = $config.Mail.Sender
        $controls.DevToTextBox.Text = $config.Mail.DevTo
        $controls.ProdToTextBox.Text = $config.Mail.ProdTo
        if ($config.TemplateFilePaths.Count -ge 3) {
            $controls.TemplatePathTextBox.Text = $config.TemplateFilePaths[0]
            $controls.TemplateXPathTextBox.Text = $config.TemplateFilePaths[1]
            $controls.TemplateMODPathTextBox.Text = $config.TemplateFilePaths[2]
        }
        $controls.GitUpdateCheckBox.IsChecked = $config.GitUpdate.Enabled
        $controls.GitRepoUrlTextBox.Text = $config.GitUpdate.RepositoryUrl
        $controls.GitBranchTextBox.Text = $config.GitUpdate.Branch
        $controls.GitCachePathTextBox.Text = $config.GitUpdate.LocalCachePath
        # Populate static text from localization object $T
        $controls.SetupWindow.Title = "SetupGUI $($Global:ScriptName) - $($Global:ScriptVersion)"
        $controls.TabGeneral.Header = $T.TabGeneral
        $controls.LblLanguage.Content = $T.LblLanguage
        $controls.LblEnvironment.Content = $T.LblEnvironment
        $controls.HelpEnv.Text = $T.HelpEnv
        $controls.WhatIfCheckBox.Content = $T.WhatIfLabel
        $controls.HelpWhatIf.Text = $T.HelpWhatIf
        $controls.TabPaths.Header = $T.TabPaths
        $controls.GrpLoggingPaths.Header = $T.GrpLoggingPaths
        $controls.LblLogDir.Content = $T.LblLogDir
        $controls.BrowseLogPath.Content = $T.BtnBrowse
        $controls.LblReportDir.Content = $T.LblReportDir
        $controls.BrowseReportPath.Content = $T.BtnBrowse
        $controls.GrpTemplatePaths.Header = $T.GrpTemplatePaths
        $controls.LblStdTemplate.Content = $T.LblStdTemplate
        $controls.BrowseTemplatePath.Content = $T.BtnBrowse
        $controls.LblTemplateX.Content = $T.LblTemplateX
        $controls.BrowseTemplateXPath.Content = $T.BtnBrowse
        $controls.LblTemplateMOD.Content = $T.LblTemplateMOD
        $controls.BrowseTemplateMODPath.Content = $T.BtnBrowse
        $controls.ArchiveCheckBox.Content = $T.ChkArchive
        $controls.EventLogCheckBox.Content = $T.ChkEventLog
        $controls.TabBackup.Header = $T.TabBackup
        $controls.BackupCheckBox.Content = $T.ChkBackupEnabled
        $controls.LblBackupPath.Content = $T.LblBackupPath
        $controls.BrowseBackupPath.Content = $T.BtnBrowse
        $controls.TabMail.Header = $T.TabMail
        $controls.MailCheckBox.Content = $T.ChkMailEnabled
        $controls.LblSmtpServer.Content = $T.LblSmtpServer
        $controls.LblSender.Content = $T.LblSender
        $controls.LblDevRecipient.Content = $T.LblDevRecipient
        $controls.LblProdRecipient.Content = $T.LblProdRecipient
        $controls.HelpMailProd.Text = $T.HelpMailProd
        $controls.TabUpdate.Header = $T.TabUpdate
        $controls.GitUpdateCheckBox.Content = $T.ChkGitUpdateEnabled
        $controls.HelpGitUpdate.Text = $T.HelpGitUpdate
        $controls.LblGitRepoUrl.Content = $T.LblGitRepoUrl
        $controls.LblGitBranch.Content = $T.LblGitBranch
        $controls.LblGitCachePath.Content = $T.LblGitCachePath
        $controls.BrowseGitCachePath.Content = $T.BtnBrowse
        $controls.CancelButton.Content = $T.BtnCancel
        $controls.ApplyButton.Content = $T.BtnApply
        $controls.OkButton.Content = $T.BtnOK
    }
    $collectUI = {
        $newConfig = $InitialConfig.psobject.copy()
        $newConfig.Language = if ($controls.LangComboBox.SelectedIndex -eq 0) { 'de-DE' } else { 'en-US' }
        $newConfig.Environment = $controls.EnvComboBox.SelectedItem.Content
        $newConfig.WhatIfMode = $controls.WhatIfCheckBox.IsChecked
    $newConfig.Logging.LogPath = $controls.LogPathTextBox.Text
    $newConfig.Logging.ReportPath = $controls.ReportPathTextBox.Text
    $newConfig.Logging.ArchiveLogs = $controls.ArchiveCheckBox.IsChecked
    $newConfig.Logging.EnableEventLog = $controls.EventLogCheckBox.IsChecked
        $newConfig.Backup.Enabled = $controls.BackupCheckBox.IsChecked
        $newConfig.Backup.Path = $controls.BackupPathTextBox.Text
        $newConfig.Mail.Enabled = $controls.MailCheckBox.IsChecked
        $newConfig.Mail.SmtpServer = $controls.SmtpServerTextBox.Text
        $newConfig.Mail.Sender = $controls.SenderTextBox.Text
        $newConfig.Mail.DevTo = $controls.DevToTextBox.Text
        $newConfig.Mail.ProdTo = $controls.ProdToTextBox.Text
        $newConfig.TemplateFilePaths[0] = $controls.TemplatePathTextBox.Text
        $newConfig.TemplateFilePaths[1] = $controls.TemplateXPathTextBox.Text
        $newConfig.TemplateFilePaths[2] = $controls.TemplateMODPathTextBox.Text
        $newConfig.GitUpdate.Enabled = $controls.GitUpdateCheckBox.IsChecked
        $newConfig.GitUpdate.RepositoryUrl = $controls.GitRepoUrlTextBox.Text
        $newConfig.GitUpdate.Branch = $controls.GitBranchTextBox.Text
        $newConfig.GitUpdate.LocalCachePath = $controls.GitCachePathTextBox.Text
        return $newConfig
    }
    $browseFolder = {
        param($initialDir)
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.SelectedPath = $initialDir
        if ($dialog.ShowDialog() -eq 'OK') { return $dialog.SelectedPath }
        return $initialDir
    }
    $browseFile = {
        param($initialDir, $filter)
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.InitialDirectory = $initialDir
        $dialog.Filter = $filter
        if ($dialog.ShowDialog() -eq 'OK') { return $dialog.FileName }
        return ''
    }

    # --- Event Handlers ---
    $controls.OkButton.add_Click({ $window.DialogResult = $true; $window.Close() })
    $controls.ApplyButton.add_Click({
            $newConfig = . $collectUI
            if (Save-Config -Config $newConfig -Path $ConfigFile -NoHostWrite) {
                $Global:Config = $newConfig
                $script:InitialConfig = $newConfig
                Write-Log -Level INFO -Message "Configuration applied successfully." -NoHostWrite
            }
        })
    $controls.BrowseLogPath.add_Click({ $controls.LogPathTextBox.Text = . $browseFolder $controls.LogPathTextBox.Text })
    $controls.BrowseReportPath.add_Click({ $controls.ReportPathTextBox.Text = . $browseFolder $controls.ReportPathTextBox.Text })
    $controls.BrowseBackupPath.add_Click({ $controls.BackupPathTextBox.Text = . $browseFolder $controls.BackupPathTextBox.Text })
    $controls.BrowseTemplatePath.add_Click({ 
        $newPath = . $browseFile (Split-Path $controls.TemplatePathTextBox.Text -Parent) "PowerShell Scripts (*.ps1)|*.ps1|All files (*.*)|*.*"
        if ($newPath) { $controls.TemplatePathTextBox.Text = $newPath }
    })
    $controls.BrowseTemplateXPath.add_Click({
        $newPath = . $browseFile (Split-Path $controls.TemplateXPathTextBox.Text -Parent) "PowerShell Scripts (*.ps1)|*.ps1|All files (*.*)|*.*"
        if ($newPath) { $controls.TemplateXPathTextBox.Text = $newPath }
    })
    $controls.BrowseTemplateMODPath.add_Click({
        $newPath = . $browseFile (Split-Path $controls.TemplateMODPathTextBox.Text -Parent) "PowerShell Scripts (*.ps1)|*.ps1|All files (*.*)|*.*"
        if ($newPath) { $controls.TemplateMODPathTextBox.Text = $newPath }
    })
    $controls.BrowseGitCachePath.add_Click({ $controls.GitCachePathTextBox.Text = . $browseFolder $controls.GitCachePathTextBox.Text })
    
    # --- Populate UI ---
    . $populateUI $InitialConfig

    # --- Wire up change events AFTER population to prevent loops ---
    # Create a flag to ignore the initial selection change event that occurs during UI population
    $script:isInitializing = $true
    
    $langChangeAction = {
        # Skip handler during initialization
        if ($script:isInitializing) { return }
        
        $msgBoxResult = [System.Windows.MessageBox]::Show($T.RestartMessage, $T.RestartTitle, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($msgBoxResult -eq 'Yes') {
            $currentConfig = . $collectUI
            Save-Config -Config $currentConfig -Path $ConfigFile -NoHostWrite
            $window.Tag = "Restart"
            $window.Close()
        } else {
            # Revert the selection if user clicks No
            $controls.LangComboBox.remove_SelectionChanged($langChangeAction)
            $controls.LangComboBox.SelectedIndex = if ($InitialConfig.Language -eq 'de-DE') { 0 } else { 1 }
            $controls.LangComboBox.add_SelectionChanged($langChangeAction)
        }
    }
    $controls.LangComboBox.add_SelectionChanged($langChangeAction)
    
    # Set the flag to false after initialization is complete
    $script:isInitializing = $false

    # --- Show Window ---
    $result = $window.ShowDialog()

    if ($window.Tag -eq "Restart") {
        return "Restart"
    }

    if ($result) {
        $Global:Config = . $collectUI
        Save-Config -Config $Global:Config -Path $ConfigFile
        return $true
    }

    return $false
}
#endregion

#region ####################### [4. Helper & Maintenance Functions] ##############################

function Initialize-LocalizationFiles {
    param(
        [string]$ConfigDirectory
    )
    $deFile = Join-Path $ConfigDirectory 'de-DE.json'
    $enFile = Join-Path $ConfigDirectory 'en-US.json'

    # Always overwrite to ensure the files are correct and up-to-date with the script version.
    Write-Log -Level DEBUG "Ensuring default German localization file is up-to-date."
    @'
{
  "TabGeneral": "Allgemein",
  "LblLanguage": "Sprache",
  "LblEnvironment": "Umgebung",
  "WhatIfLabel": "Simulationsmodus ausführen (WhatIf)",
  "HelpEnv": "DEV für Debugging und Simulation, PROD für den produktiven Einsatz.",
  "HelpWhatIf": "Simuliert nur Aktionen im DEV-Modus, ohne Änderungen vorzunehmen.",
  "TabPaths": "Pfade / Logging",
  "GrpLoggingPaths": "Protokollierungs-Pfade",
  "GrpTemplatePaths": "Vorlagen-Pfade",
  "LblStdTemplate": "Standard-Profil (profile.ps1)",
  "LblTemplateX": "Erweitertes Profil (profileX.ps1)",
  "LblTemplateMOD": "Modernes Profil (ProfileMOD.ps1)",
  "LblLogDir": "Log-Verzeichnis",
  "LblReportDir": "Report-Verzeichnis",
  "ChkArchive": "Log-Archivierung aktivieren",
  "ChkEventLog": "Windows Event Log aktivieren",
  "TabBackup": "Backup",
  "ChkBackupEnabled": "Backup aktivieren",
  "LblBackupPath": "Backup-Pfad",
  "TabMail": "E-Mail",
  "ChkMailEnabled": "Mail-Benachrichtigung aktivieren",
  "LblSmtpServer": "SMTP-Server",
  "LblSender": "Absender",
  "LblDevRecipient": "Empfänger (DEV)",
  "LblProdRecipient": "Empfänger (PROD)",
  "HelpMailProd": "Mehrere Empfänger mit Semikolon (;) trennen.",
  "BtnOK": "OK",
  "BtnApply": "Anwenden",
  "BtnCancel": "Abbrechen",
  "BtnBrowse": " ... ",
  "RestartTitle": "Sprachwechsel",
  "RestartMessage": "Um die Sprache zu ändern, muss das Konfigurationsfenster neu gestartet werden. Aktuelle Änderungen speichern und neu starten?",
  "TabUpdate": "Update",
  "ChkGitUpdateEnabled": "Automatische Updates via Git aktivieren",
  "HelpGitUpdate": "Wenn aktiviert, werden die Profil-Vorlagen vor der Ausführung aus dem angegebenen Git-Repository geklont/aktualisiert. Git muss auf dem System installiert sein.",
  "LblGitRepoUrl": "Repository URL",
  "LblGitBranch": "Branch",
  "LblGitCachePath": "Lokaler Cache-Pfad"
}
'@ | Set-Content -Path $deFile -Encoding UTF8

    Write-Log -Level DEBUG "Ensuring default English localization file is up-to-date."
    @'
{
  "TabGeneral": "General",
  "LblLanguage": "Language",
  "LblEnvironment": "Environment",
  "WhatIfLabel": "Run in Simulation Mode (WhatIf)",
  "HelpEnv": "DEV for debugging and simulation, PROD for productive use.",
  "HelpWhatIf": "Only simulates actions in DEV mode without making changes.",
  "TabPaths": "Paths / Logging",
  "GrpLoggingPaths": "Logging Paths",
  "GrpTemplatePaths": "Template Paths",
  "LblStdTemplate": "Standard Profile (profile.ps1)",
  "LblTemplateX": "Extended Profile (profileX.ps1)",
  "LblTemplateMOD": "Modern Profile (ProfileMOD.ps1)",
  "LblLogDir": "Log Directory",
  "LblReportDir": "Report Directory",
  "ChkArchive": "Enable Log Archiving",
  "ChkEventLog": "Enable Windows Event Log",
  "TabBackup": "Backup",
  "ChkBackupEnabled": "Enable Backup",
  "LblBackupPath": "Backup Path",
  "TabMail": "E-Mail",
  "ChkMailEnabled": "Enable Mail Notification",
  "LblSmtpServer": "SMTP Server",
  "LblSender": "Sender",
  "LblDevRecipient": "Recipient (DEV)",
  "LblProdRecipient": "Recipient (PROD)",
  "HelpMailProd": "Separate multiple recipients with a semicolon (;).",
  "BtnOK": "OK",
  "BtnApply": "Apply",
  "BtnCancel": "Cancel",
  "BtnBrowse": " ... ",
  "RestartTitle": "Language Change",
  "RestartMessage": "To apply the language change, the configuration window must be restarted. Save current changes and restart?",
  "TabUpdate": "Update",
  "ChkGitUpdateEnabled": "Enable automatic updates via Git",
  "HelpGitUpdate": "If enabled, the profile templates will be cloned/updated from the specified Git repository before execution. Git must be installed on the system.",
  "LblGitRepoUrl": "Repository URL",
  "LblGitBranch": "Branch",
  "LblGitCachePath": "Local Cache Path"
}
'@ | Set-Content -Path $enFile -Encoding UTF8
}

function Initialize-LocalAssets {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    $logoPath = $Global:Config.Logging.LogoPath
    $logoUncPath = $Global:Config.UNCPaths.Logo

    if (-not (Test-Path $logoPath) -and (Test-Path $logoUncPath)) {
        Write-Log -Level INFO -Message "Local logo not found. Attempting to copy from UNC path: $logoUncPath"
        $localImageDir = Split-Path $logoPath -Parent
        if (-not (Test-Path $localImageDir)) {
            if ($PSCmdlet.ShouldProcess($localImageDir, "Create Image Directory")) {
                New-Item -Path $localImageDir -ItemType Directory | Out-Null
            }
        }
        if ($PSCmdlet.ShouldProcess($logoPath, "Copy Logo from UNC")) {
            try {
                Copy-Item -Path $logoUncPath -Destination $logoPath -Force -ErrorAction Stop
                Write-Log -Level INFO -Message "Logo successfully copied to $logoPath"
            }
            catch {
                Write-Log -Level WARNING -Message "Could not copy logo from UNC path: $($_.Exception.Message)"
            }
        }
    }
}

function Get-AllProfilePaths {
    Write-Log -Level DEBUG -Message "Querying all four potential profile paths."
    $profileProperties = 'CurrentUserCurrentHost', 'CurrentUserAllHosts', 'AllUsersCurrentHost', 'AllUsersAllHosts'
    return $profileProperties.ForEach({ try { $PROFILE.$_ } catch {} }) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Select-Object -Unique
}

function Get-SystemwideProfilePath {
    Write-Log -Level DEBUG -Message "Determining system-wide profile path for this PowerShell edition."
    if ($IsCoreCLR) {
        # PowerShell 7+
        return Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\profile.ps1'
    }
    else {
        # Windows PowerShell 5.1
        return Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\profile.ps1'
    }
}

function Set-TemplateVersion {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$FilePath, [string]$NewVersion, [string]$OldVersion)
    if ($PSCmdlet.ShouldProcess($FilePath, "Set Version to $NewVersion")) {
        try {
            $content = Get-Content -Path $FilePath -Raw
            $content = $content -replace "(old Version:\s*v)[\d\.]+", "`$1$OldVersion"
            $content = $content -replace "(Version now:\s*v)[\d\.]+", "`$1$($NewVersion.TrimStart('v'))"
            $content = $content -replace "(End of Script now: v)[\d\.]+", "`$1$($NewVersion.TrimStart('v'))"
            $content = $content -replace "(; old: v)[\d\.]+", "`$1$OldVersion"
            
            $encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'UTF8BOM' } else { 'UTF8' }
            Set-Content -Path $FilePath -Value $content -Encoding $encoding -Force
            Write-Log -Level DEBUG -Message "Version for '$FilePath' was set to '$NewVersion' using encoding '$($encoding)'."
        }
        catch { Write-Log -Level ERROR -Message "Error versioning file '$FilePath': $($_.Exception.Message)" }
    }
}

function Invoke-GitUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $gitConfig = $Global:Config.GitUpdate
    if (-not $gitConfig.Enabled) {
        Write-Log -Level INFO -Message "Git update feature is disabled."
        return $null
    }

    Write-Log -Level INFO -Message "Starting Git update for profile templates..."

    $gitPath = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $gitPath) {
        throw "Git is not installed or not in the system's PATH. Cannot perform Git update."
    }
    Write-Log -Level DEBUG -Message "Found git.exe at: $($gitPath.Source)"

    $cachePath = $gitConfig.LocalCachePath
    if (-not (Test-Path $cachePath)) {
        if ($PSCmdlet.ShouldProcess($cachePath, "Create Git cache directory")) {
            New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
        }
    }

    $repoDir = Join-Path $cachePath "repository"

    if (-not (Test-Path (Join-Path $repoDir ".git"))) {
        Write-Log -Level INFO -Message "Local repository not found. Cloning from $($gitConfig.RepositoryUrl)..."
        $cloneArgs = "clone --branch $($gitConfig.Branch) --single-branch `"$($gitConfig.RepositoryUrl)`" `"$repoDir`""
        if ($PSCmdlet.ShouldProcess($gitConfig.RepositoryUrl, "Clone Repository")) {
            $process = Start-Process -FilePath $gitPath.Source -ArgumentList $cloneArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($process.ExitCode -ne 0) { throw "Git clone failed with exit code $($process.ExitCode)." }
            Write-Log -Level INFO -Message "Repository cloned successfully."
        }
    }
    else {
        Write-Log -Level INFO -Message "Local repository found. Fetching updates..."
        if ($PSCmdlet.ShouldProcess($repoDir, "Update Repository (git fetch & reset)")) {
            $fetchArgs = "-C `"$repoDir`" fetch origin"
            $resetArgs = "-C `"$repoDir`" reset --hard origin/$($gitConfig.Branch)"
            & $gitPath.Source $fetchArgs.Split(' ') | Out-Null
            & $gitPath.Source $resetArgs.Split(' ') | Out-Null
            Write-Log -Level INFO -Message "Repository updated successfully to latest version from branch '$($gitConfig.Branch)'."
        }
    }
    return $repoDir
}

#endregion

#region ####################### [5. Script Main Body] ##############################

# Central definition for template versions to improve maintainability
$targetTemplateVersions = @{
    Profile    = "v23.0.1"
    ProfileX   = "v6.0.0"
    ProfileMOD = "v6.0.0"
}

# --- Handle dedicated operational modes first ---
if ($Setup.IsPresent) {    
    do {
        $restartGui = $false
        $Global:Config = Get-Config -Path $ConfigFile
        
        if ($null -eq $Global:Config) {
            Write-Log -Level WARNING -Message "Configuration file not found or corrupt. Using default values for GUI."
            $Global:Config = Get-DefaultConfig
        }
        
        # Ensure the config object is complete before passing it to the GUI. This prevents errors if the config file is from an older version.
        Invoke-VersionControl -LoadedConfig $Global:Config -Path $ConfigFile

        Initialize-LocalizationFiles -ConfigDirectory $configDir
        $guiResult = Show-MuwSetupGui -InitialConfig $Global:Config
        
        if ($guiResult -eq 'Restart') {
            Write-Log -Level INFO -Message "Restarting GUI to apply language change..."
            $restartGui = $true
        }
    } while ($restartGui)

    Write-Log -Level INFO -Message "Configuration finished. Script will exit."
    return # Use return to exit the script but not the host shell
}

if ($Versionscontrol.IsPresent) {
    $Global:Config = Get-Config -Path $ConfigFile
    if ($null -ne $Global:Config) {
        Invoke-VersionControl -LoadedConfig $Global:Config -Path $ConfigFile
        Write-Log -Level INFO -Message "Version control check finished. Script will exit."
    }
    else {
        Write-Log -Level WARNING -Message "Configuration file not found. Cannot perform version control."
    }
    return
}


# --- Main execution logic ---
$oldVersion = $Global:ScriptVersion
$emailSubject, $emailBody = $null, $null

try {
    $Global:Config = Get-Config -Path $ConfigFile
    if ($null -eq $Global:Config) {
        throw "Configuration file `"$ConfigFile`" not found or corrupt. Please run the script with the -Setup parameter first."
    }
    
    # --- Environment and WhatIf Setup ---
    if ($Global:Config.Environment -eq "DEV") {
        $VerbosePreference = 'Continue'
        $DebugPreference = 'Continue'
        if ($Global:Config.WhatIfMode) {
            $WhatIfPreference = $true
            Write-Log -Level WARNING -Message "SCRIPT IS RUNNING IN SIMULATION (WhatIf) MODE. NO CHANGES WILL BE MADE."
        }
    }
    else {
        # PROD
        $VerbosePreference = 'SilentlyContinue'
        $DebugPreference = 'SilentlyContinue'
        $WhatIfPreference = $false
    }
    
    Write-Log -Level INFO -Message "--- Script started: $Global:ScriptName $Global:ScriptVersion ---"
    
    Initialize-LocalAssets

    # --- Handle Template Source (Git or Local) ---
    if ($Global:Config.GitUpdate.Enabled) {
        $templateSourcePath = Invoke-GitUpdate
        if ($null -eq $templateSourcePath) {
            throw "Git update was enabled but failed to retrieve templates."
        }
        # Overwrite template paths to use the Git cache
        $Global:Config.TemplateFilePaths = @(
            (Join-Path $templateSourcePath 'Profile-template.ps1'),
            (Join-Path $templateSourcePath 'Profile-templateX.ps1'),
            (Join-Path $templateSourcePath 'Profile-templateMOD.ps1')
        )
        Write-Log -Level INFO -Message "Using template files from Git cache: $templateSourcePath"
    }

    @($Global:Config.Logging.LogPath, $Global:Config.Logging.ReportPath, $Global:Config.Backup.Path) | ForEach-Object {
        if ($_ -and -not (Test-Path -Path $_ -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($_, "Create Directory")) {
                New-Item -ItemType Directory -Path $_ -Force -ErrorAction Stop | Out-Null
            }
        }
    }
    $Global:Config.TemplateFilePaths | ForEach-Object {
        if (-not (Test-Path $_)) { throw "Template file '$_' not found. Please check configuration or Git repository." }
    }
    Write-Log -Level DEBUG -Message 'All template files found.'

    Write-Log -Level INFO -Message 'Deleting existing PowerShell profiles...'
    Get-AllProfilePaths | ForEach-Object {
        if (Test-Path $_) {
            if ($PSCmdlet.ShouldProcess($_, "Delete Profile")) {
                try { Remove-Item $_ -Force -ErrorAction Stop; Write-Log -Level INFO -Message "  - Deleted: $_" }
                catch { Write-Log -Level WARNING -Message "Error deleting '$_': $($_.Exception.Message)" }
            }
        }
    }

    Write-Log -Level INFO -Message 'Creating new profiles from templates...'
    $systemwideProfilePath = Get-SystemwideProfilePath
    $systemwideProfileDir = Split-Path $systemwideProfilePath -Parent
    if (-not (Test-Path $systemwideProfileDir)) { 
        if ($PSCmdlet.ShouldProcess($systemwideProfileDir, "Create Directory")) {
            New-Item -ItemType Directory -Path $systemwideProfileDir -Force | Out-Null 
        }
    }

    foreach ($templatePath in $Global:Config.TemplateFilePaths) {
        $templateLeaf = Split-Path -Path $templatePath -Leaf
        $destinationPath, $versionToSet, $oldTemplateVersion = $null, $null, "v0.0.0"
        switch -Wildcard ($templateLeaf) {
            '*-template.ps1' { 
                $destinationPath = $systemwideProfilePath
                $oldTemplateVersion = $Global:Config.TemplateVersions.Profile
                $versionToSet = $Global:Config.TemplateVersions.Profile = $targetTemplateVersions.Profile
            }
            '*-templateX.ps1' { 
                $destinationPath = Join-Path $systemwideProfileDir 'profileX.ps1'
                $oldTemplateVersion = $Global:Config.TemplateVersions.ProfileX
                $versionToSet = $Global:Config.TemplateVersions.ProfileX = $targetTemplateVersions.ProfileX
            }
            '*-templateMOD.ps1' { 
                $destinationPath = Join-Path $systemwideProfileDir 'ProfileMOD.ps1'
                $oldTemplateVersion = $Global:Config.TemplateVersions.ProfileMOD
                $versionToSet = $Global:Config.TemplateVersions.ProfileMOD = $targetTemplateVersions.ProfileMOD
            }
        }
        if ($PSCmdlet.ShouldProcess($destinationPath, "Create Profile from $templateLeaf")) {
            try {
                Copy-Item -Path $templatePath -Destination $destinationPath -Force -ErrorAction Stop
                Write-Log -Level INFO -Message "  - Created: $destinationPath"
                Set-TemplateVersion -FilePath $destinationPath -NewVersion $versionToSet -OldVersion $oldTemplateVersion
            }
            catch { Write-Log -Level ERROR -Message "Error creating '$destinationPath': $($_.Exception.Message)" }
        }
    }

    Write-Log -Level INFO -Message 'PowerShell profiles have been reset successfully.'
    $emailSubject = "SUCCESS: Profile-Reset on $($env:COMPUTERNAME)"
    $emailBody = "Script '$($Global:ScriptName)' ($($Global:ScriptVersion)) finished successfully on $($env:COMPUTERNAME) at $(Get-Date)."
}
catch {
    $errorMessage = "Critical Error: $($_.Exception.Message)"
    Write-Log -Level ERROR -Message $errorMessage
    $emailSubject = "FAILURE: Profile-Reset on $($env:COMPUTERNAME)"
    $emailBody = "Script '$($Global:ScriptName)' ($($Global:ScriptVersion)) failed on $($env:COMPUTERNAME) at $(Get-Date).`n`nError:`n$($_.Exception.Message)"
}
finally {
    if ($Global:Config) {
        if ($emailSubject) { Send-MailNotification -Subject $emailSubject -Body $emailBody }
        Invoke-ArchiveMaintenance
        Save-Config -Config $Global:Config -Path $ConfigFile | Out-Null
    }
    Write-Log -Level INFO -Message "--- Script finished: $Global:ScriptName. ---"
}
#endregion


# --- End of Script old: v08.00.14 ; now: v08.00.15 ; Regelwerk: v6.6.6 ---