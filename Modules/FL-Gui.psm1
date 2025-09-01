<#
.SYNOPSIS
    [EN] Module for displaying the WPF configuration GUI.
    [DE] Modul zur Anzeige der WPF-Konfigurations-GUI.
.DESCRIPTION
    [EN] This module contains the functions to build and display the graphical user interface for script configuration.
    [DE] Dieses Modul enthält die Funktionen zum Erstellen und Anzeigen der grafischen Benutzeroberfläche für die Skriptkonfiguration.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.08.29
    Version:        v09.04.00
    MUW-Regelwerk:  v7.3.0
    Copyright:      © 2025 Flecki Garnreiter
#>

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
        Write-Log -Level INFO -Message "Localization file '$langFilePath' not found. Creating it now."
        Initialize-LocalizationFiles -ConfigDirectory $configDir
    }
    $T = Get-Content -Path $langFilePath | ConvertFrom-Json

    # Version check for the language file
    $expectedVersion = $Global:Config.LanguageFileVersions[$lang]
    if ($null -eq $T.Version -or $T.Version -ne $expectedVersion) {
        Write-Log -Level WARNING -Message "Language file '$lang' is outdated or corrupt (Version: $($T.Version), Expected: $expectedVersion). Regenerating."
        Initialize-LocalizationFiles -ConfigDirectory $configDir
        $T = Get-Content -Path $langFilePath | ConvertFrom-Json
    }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="SetupWindow" Height="650" Width="700" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
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
                            <TextBlock Name="HelpLoggingPaths" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,0,0,10"/>
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
                            <TextBlock Name="HelpTemplatePaths" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,0,0,10"/>
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
                    <TextBlock Name="HelpBackup" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,0,0,10"/>
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
                    <TextBlock Name="HelpMail" Foreground="Gray" FontStyle="Italic" TextWrapping="Wrap" Margin="0,0,0,10"/>
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
    $window.FindName("HelpLoggingPaths") -and ($controls.HelpLoggingPaths = $window.FindName("HelpLoggingPaths"))
    $window.FindName("LblLogDir") -and ($controls.LblLogDir = $window.FindName("LblLogDir"))
    $window.FindName("LblReportDir") -and ($controls.LblReportDir = $window.FindName("LblReportDir"))
    $window.FindName("GrpTemplatePaths") -and ($controls.GrpTemplatePaths = $window.FindName("GrpTemplatePaths"))
    $window.FindName("HelpTemplatePaths") -and ($controls.HelpTemplatePaths = $window.FindName("HelpTemplatePaths"))
    $window.FindName("LblStdTemplate") -and ($controls.LblStdTemplate = $window.FindName("LblStdTemplate"))
    $window.FindName("LblTemplateX") -and ($controls.LblTemplateX = $window.FindName("LblTemplateX"))
    $window.FindName("LblTemplateMOD") -and ($controls.LblTemplateMOD = $window.FindName("LblTemplateMOD"))
    $window.FindName("TabBackup") -and ($controls.TabBackup = $window.FindName("TabBackup"))
    $window.FindName("HelpBackup") -and ($controls.HelpBackup = $window.FindName("HelpBackup"))
    $window.FindName("LblBackupPath") -and ($controls.LblBackupPath = $window.FindName("LblBackupPath"))
    $window.FindName("TabMail") -and ($controls.TabMail = $window.FindName("TabMail"))
    $window.FindName("HelpMail") -and ($controls.HelpMail = $window.FindName("HelpMail"))
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
        $controls.HelpLoggingPaths.Text = $T.HelpLoggingPaths
        $controls.LblLogDir.Content = $T.LblLogDir
        $controls.BrowseLogPath.Content = $T.BtnBrowse
        $controls.LblReportDir.Content = $T.LblReportDir
        $controls.BrowseReportPath.Content = $T.BtnBrowse
        $controls.GrpTemplatePaths.Header = $T.GrpTemplatePaths
        $controls.HelpTemplatePaths.Text = $T.HelpTemplatePaths
        $controls.LblStdTemplate.Content = $T.LblStdTemplate
        $controls.BrowseTemplatePath.Content = $T.BtnBrowse
        $controls.LblTemplateX.Content = $T.LblTemplateX
        $controls.BrowseTemplateXPath.Content = $T.BtnBrowse
        $controls.LblTemplateMOD.Content = $T.LblTemplateMOD
        $controls.BrowseTemplateMODPath.Content = $T.BtnBrowse
        $controls.ArchiveCheckBox.Content = $T.ChkArchive
        $controls.EventLogCheckBox.Content = $T.ChkEventLog
        $controls.TabBackup.Header = $T.TabBackup
        $controls.HelpBackup.Text = $T.HelpBackup
        $controls.BackupCheckBox.Content = $T.ChkBackupEnabled
        $controls.LblBackupPath.Content = $T.LblBackupPath
        $controls.BrowseBackupPath.Content = $T.BtnBrowse
        $controls.TabMail.Header = $T.TabMail
        $controls.HelpMail.Text = $T.HelpMail
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
    
    # Define the change action first
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
    # Add the handler BEFORE populating
    $controls.LangComboBox.add_SelectionChanged($langChangeAction)

    # Set flag to true to prevent the event from firing during population
    $script:isInitializing = $true

    # --- Populate UI ---
    . $populateUI $InitialConfig

    # Set flag to false after population so user changes are handled
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

function Initialize-LocalizationFiles {
    param(
        [string]$ConfigDirectory
    )
    $deFile = Join-Path $ConfigDirectory 'de-DE.json'
    $enFile = Join-Path $ConfigDirectory 'en-US.json'

    # Always overwrite to ensure the files are correct and up-to-date with the script version.
    Write-Log -Level DEBUG "Ensuring default German localization file is up-to-date."
    $deVersion = $Global:Config.LanguageFileVersions['de-DE']
    @"
{
  "Version": "$deVersion",
  "TabGeneral": "Allgemein",
  "LblLanguage": "Sprache",
  "LblEnvironment": "Umgebung",
  "WhatIfLabel": "Simulationsmodus ausführen (WhatIf)",
  "HelpEnv": "DEV für Debugging und Simulation, PROD für den produktiven Einsatz.",
  "HelpWhatIf": "Simuliert nur Aktionen im DEV-Modus, ohne Änderungen vorzunehmen.",
  "TabPaths": "Pfade / Logging",
  "GrpLoggingPaths": "Protokollierungs-Pfade",
  "HelpLoggingPaths": "Definiert die Speicherorte für Log- und Report-Dateien.",
  "GrpTemplatePaths": "Vorlagen-Pfade",
  "HelpTemplatePaths": "Pfade zu den PowerShell-Profilvorlagen, die verwendet werden sollen.",
  "LblStdTemplate": "Standard-Profil (profile.ps1)",
  "LblTemplateX": "Erweitertes Profil (profileX.ps1)",
  "LblTemplateMOD": "Modernes Profil (ProfileMOD.ps1)",
  "LblLogDir": "Log-Verzeichnis",
  "LblReportDir": "Report-Verzeichnis",
  "ChkArchive": "Log-Archivierung aktivieren",
  "ChkEventLog": "Windows Event Log aktivieren",
  "TabBackup": "Backup",
  "HelpBackup": "Aktiviert und konfiguriert automatische Backups der Profile.",
  "ChkBackupEnabled": "Backup aktivieren",
  "LblBackupPath": "Backup-Pfad",
  "TabMail": "E-Mail",
  "HelpMail": "Konfiguriert die E-Mail-Benachrichtigungen für den Skriptstatus.",
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
    $enVersion = $Global:Config.LanguageFileVersions['en-US']
    @"
{
  "Version": "$enVersion",
  "TabGeneral": "General",
  "LblLanguage": "Language",
  "LblEnvironment": "Environment",
  "WhatIfLabel": "Run in Simulation Mode (WhatIf)",
  "HelpEnv": "DEV for debugging and simulation, PROD for productive use.",
  "HelpWhatIf": "Only simulates actions in DEV mode without making changes.",
  "TabPaths": "Paths / Logging",
  "GrpLoggingPaths": "Logging Paths",
  "HelpLoggingPaths": "Defines the storage locations for log and report files.",
  "GrpTemplatePaths": "Template Paths",
  "HelpTemplatePaths": "Paths to the PowerShell profile templates to be used.",
  "LblStdTemplate": "Standard Profile (profile.ps1)",
  "LblTemplateX": "Extended Profile (profileX.ps1)",
  "LblTemplateMOD": "Modern Profile (ProfileMOD.ps1)",
  "LblLogDir": "Log Directory",
  "LblReportDir": "Report Directory",
  "ChkArchive": "Enable Log Archiving",
  "ChkEventLog": "Enable Windows Event Log",
  "TabBackup": "Backup",
  "HelpBackup": "Enables and configures automatic backups of the profiles.",
  "ChkBackupEnabled": "Enable Backup",
  "LblBackupPath": "Backup Path",
  "TabMail": "E-Mail",
  "HelpMail": "Configures the e-mail notifications for the script status.",
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

Export-ModuleMember -Function Show-MuwSetupGui, Initialize-LocalizationFiles

# --- End of module --- v09.04.00 ; Regelwerk: v7.3.0 ---
