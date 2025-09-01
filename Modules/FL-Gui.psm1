<#
.SYNOPSIS
    [DE] Enthält alle Funktionen zur Erstellung und Verwaltung der WPF-Konfigurations-GUI.
    [EN] Contains all functions for creating and managing the WPF configuration GUI.
.DESCRIPTION
    [DE] Dieses Modul ist verantwortlich für die dynamische Erstellung der Benutzeroberfläche, das Binden der
         Daten aus dem Konfigurationsobjekt, die Verarbeitung von Benutzerinteraktionen (Klicks, Änderungen)
         und die Validierung der Eingaben. Es nutzt eine saubere Methode mit .default-Vorlagen für die
         Erstellung der Sprachdateien.
    [EN] This module is responsible for dynamically creating the user interface, binding data from the
         configuration object, handling user interactions (clicks, changes), and validating input.
         It uses a clean method with .default templates for creating the language files.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.15
    Last modified:  2025.09.01
    Version:        v10.3.1
    MUW-Regelwerk:  v7.7.0
    Notes:          [DE] PSScriptAnalyzer-Warnung behoben: 'Load-ConfigIntoGui' zu 'Initialize-GuiFromConfig' umbenannt.
                    [EN] Fixed PSScriptAnalyzer warning: Renamed 'Load-ConfigIntoGui' to 'Initialize-GuiFromConfig'.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Initialize-LocalizationFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$ConfigDirectory
    )
    
    $defaultFiles = @{
        'de-DE.json' = 'de-DE.json.default';
        'en-US.json' = 'en-US.json.default';
    }

    foreach ($targetFile in $defaultFiles.Keys) {
        $destinationPath = Join-Path $ConfigDirectory $targetFile
        $sourcePath = Join-Path $ConfigDirectory $defaultFiles[$targetFile]

        if (-not (Test-Path $destinationPath)) {
            Write-Log -Level INFO -Message "Localization file '$targetFile' not found. Creating from default template."
            if (-not (Test-Path $sourcePath)) {
                Write-Log -Level ERROR -Message "Default template '$($defaultFiles[$targetFile])' is missing. Cannot create localization file."
                continue
            }
            if ($PSCmdlet.ShouldProcess($destinationPath, "Create from template '$($defaultFiles[$targetFile])'")) {
                try {
                    Copy-Item -Path $sourcePath -Destination $destinationPath -Force
                }
                catch {
                    Write-Log -Level ERROR -Message "Failed to create localization file '$destinationPath': $($_.Exception.Message)"
                }
            }
        }
    }
}

function Show-MuwSetupGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$InitialConfig
    )

    try {
        Add-Type -AssemblyName PresentationFramework
    }
    catch {
        Write-Error "WPF Framework could not be loaded. GUI cannot be displayed."
        return
    }

    # Load Localization
    $langFile = Join-Path $Global:ScriptDirectory "Config\$($InitialConfig.Language).json"
    if (-not (Test-Path $langFile)) {
        Write-Warning "Language file '$langFile' not found. Falling back to en-US."
        $langFile = Join-Path $Global:ScriptDirectory "Config\en-US.json"
        if (-not (Test-Path $langFile)) {
            Write-Error "Fallback language file 'en-US.json' also not found. Cannot display GUI."
            return
        }
    }
    $L = Get-Content $langFile | ConvertFrom-Json
    
    #region --- XAML Definition ---
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="Window" Title="SetupGUI $($Global:ScriptName) - $($Global:ScriptVersion)" Height="600" Width="800"
        WindowStartupLocation="CenterScreen" MinHeight="550" MinWidth="750"
        Background="#F0F0F0">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <TabControl x:Name="TabControl">
            <!-- General Tab -->
            <TabItem Header="$($L.TabGeneral)">
                <StackPanel Margin="15">
                    <Label Content="$($L.LblLanguage)" FontWeight="Bold"/>
                    <ComboBox x:Name="LanguageComboBox" SelectedIndex="0" Margin="0,0,0,15">
                        <ComboBoxItem Content="de-DE"/>
                        <ComboBoxItem Content="en-US"/>
                    </ComboBox>

                    <Label Content="$($L.LblEnvironment)" FontWeight="Bold"/>
                    <ComboBox x:Name="EnvironmentComboBox" SelectedIndex="0" Margin="0,0,0,5">
                        <ComboBoxItem Content="DEV"/>
                        <ComboBoxItem Content="PROD"/>
                    </ComboBox>
                    <TextBlock Text="$($L.HelpEnv)" TextWrapping="Wrap" FontStyle="Italic" Margin="0,0,0,15"/>

                    <CheckBox x:Name="WhatIfCheckBox" Content="$($L.WhatIfLabel)" Margin="0,5,0,5"/>
                    <TextBlock Text="$($L.HelpWhatIf)" TextWrapping="Wrap" FontStyle="Italic"/>
                </StackPanel>
            </TabItem>

            <!-- Paths Tab -->
            <TabItem Header="$($L.TabPaths)">
                <Grid Margin="15">
                     <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*" />
                        <ColumnDefinition Width="Auto" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                         <RowDefinition Height="Auto"/>
                         <RowDefinition Height="Auto"/>
                         <RowDefinition Height="Auto"/>
                         <RowDefinition Height="Auto"/>
                         <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <Label Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="2" Content="$($L.GrpLoggingPaths)" FontWeight="Bold"/>
                    
                    <TextBox x:Name="LogPathTextBox" Grid.Row="1" Grid.Column="0" Margin="0,5,5,5"/>
                    <Button x:Name="BrowseLogPathButton" Grid.Row="1" Grid.Column="1" Content="$($L.BtnBrowse)" Width="30" Margin="0,5,0,5"/>
                    
                    <TextBox x:Name="ReportPathTextBox" Grid.Row="2" Grid.Column="0" Margin="0,5,5,15"/>
                    <Button x:Name="BrowseReportPathButton" Grid.Row="2" Grid.Column="1" Content="$($L.BtnBrowse)" Width="30" Margin="0,5,0,15"/>
                    
                    <CheckBox x:Name="ArchiveCheckBox" Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="2" Content="$($L.ChkArchive)" Margin="0,0,0,5"/>
                    <CheckBox x:Name="EventLogCheckBox" Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="2" Content="$($L.ChkEventLog)" Margin="0,0,0,15"/>
                </Grid>
            </TabItem>
            
            <!-- Update Tab -->
             <TabItem Header="$($L.TabUpdate)">
                <StackPanel Margin="15">
                    <CheckBox x:Name="GitUpdateCheckBox" Content="$($L.ChkGitUpdateEnabled)" FontWeight="Bold" Margin="0,0,0,5"/>
                    <TextBlock Text="$($L.HelpGitUpdate)" TextWrapping="Wrap" FontStyle="Italic" Margin="0,0,0,15"/>
                    <Label Content="$($L.LblGitRepoUrl)"/>
                    <TextBox x:Name="GitRepoUrlTextBox" Margin="0,0,0,10"/>
                    <Label Content="$($L.LblGitBranch)"/>
                    <TextBox x:Name="GitBranchTextBox" Margin="0,0,0,10"/>
                    <Label Content="$($L.LblGitCachePath)"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="GitCachePathTextBox" Grid.Column="0" Margin="0,0,5,0"/>
                        <Button x:Name="BrowseGitCachePathButton" Grid.Column="1" Content="$($L.BtnBrowse)" Width="30"/>
                    </Grid>
                </StackPanel>
            </TabItem>

            <!-- Mail Tab -->
            <TabItem Header="$($L.TabMail)">
                 <StackPanel Margin="15">
                    <CheckBox x:Name="MailCheckBox" Content="$($L.ChkMailEnabled)" FontWeight="Bold" Margin="0,0,0,15"/>
                    <Label Content="$($L.LblSmtpServer)"/>
                    <TextBox x:Name="SmtpServerTextBox" Margin="0,0,0,10"/>
                    <Label Content="$($L.LblSender)"/>
                    <TextBox x:Name="SenderTextBox" Margin="0,0,0,10"/>
                    <Label Content="$($L.LblDevRecipient)"/>
                    <TextBox x:Name="DevRecipientTextBox" Margin="0,0,0,10"/>
                    <Label Content="$($L.LblProdRecipient)"/>
                    <TextBox x:Name="ProdRecipientTextBox" Margin="0,0,0,5"/>
                    <TextBlock Text="$($L.HelpMailProd)" TextWrapping="Wrap" FontStyle="Italic"/>
                </StackPanel>
            </TabItem>

        </TabControl>

        <!-- Button Bar -->
        <Grid Grid.Row="1" Margin="0,10,0,0">
            <Button x:Name="CancelButton" Content="$($L.BtnCancel)" HorizontalAlignment="Left" Width="100" Height="25"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="ApplyButton" Content="$($L.BtnApply)" Width="100" Height="25" Margin="0,0,10,0"/>
                <Button x:Name="OkButton" Content="$($L.BtnOK)" Width="100" Height="25" FontWeight="Bold" Background="#111d4e" Foreground="White"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@
    #endregion

    # --- Create and load window ---
    $reader = [System.Xml.XmlNodeReader]::new([System.Xml.XmlDocument]([xml]$xaml))
    $Window = [Windows.Markup.XamlReader]::Load($reader)

    # --- Find all controls ---
    $controls = @{}
    $xaml.SelectNodes("//*[@x:Name]") | ForEach-Object { $controls[$_.Name] = $Window.FindName($_.Name) }

    # --- Helper Functions ---
    function Initialize-GuiFromConfig {
        param($config)
        $controls.LanguageComboBox.SelectedItem = $controls.LanguageComboBox.Items | Where-Object { $_.Content -eq $config.Language }
        $controls.EnvironmentComboBox.SelectedItem = $controls.EnvironmentComboBox.Items | Where-Object { $_.Content -eq $config.Environment }
        $controls.WhatIfCheckBox.IsChecked = $config.WhatIfMode
        $controls.LogPathTextBox.Text = $config.Logging.LogPath
        $controls.ReportPathTextBox.Text = $config.Logging.ReportPath
        $controls.ArchiveCheckBox.IsChecked = $config.Logging.ArchiveLogs
        $controls.EventLogCheckBox.IsChecked = $config.Logging.EventLogEnabled
        $controls.GitUpdateCheckBox.IsChecked = $config.GitUpdate.Enabled
        $controls.GitRepoUrlTextBox.Text = $config.GitUpdate.RepositoryUrl
        $controls.GitBranchTextBox.Text = $config.GitUpdate.Branch
        $controls.GitCachePathTextBox.Text = $config.GitUpdate.CachePath
        $controls.MailCheckBox.IsChecked = $config.Mail.Enabled
        $controls.SmtpServerTextBox.Text = $config.Mail.SmtpServer
        $controls.SenderTextBox.Text = $config.Mail.Sender
        $controls.DevRecipientTextBox.Text = $config.Mail.DevTo
        $controls.ProdRecipientTextBox.Text = $config.Mail.ProdTo
    }

    function Save-GuiToConfig {
        param($config)
        $config.Language = $controls.LanguageComboBox.SelectedItem.Content
        $config.Environment = $controls.EnvironmentComboBox.SelectedItem.Content
        $config.WhatIfMode = $controls.WhatIfCheckBox.IsChecked
        $config.Logging.LogPath = $controls.LogPathTextBox.Text
        $config.Logging.ReportPath = $controls.ReportPathTextBox.Text
        $config.Logging.ArchiveLogs = $controls.ArchiveCheckBox.IsChecked
        $config.Logging.EventLogEnabled = $controls.EventLogCheckBox.IsChecked
        $config.GitUpdate.Enabled = $controls.GitUpdateCheckBox.IsChecked
        $config.GitUpdate.RepositoryUrl = $controls.GitRepoUrlTextBox.Text
        $config.GitUpdate.Branch = $controls.GitBranchTextBox.Text
        $config.GitUpdate.CachePath = $controls.GitCachePathTextBox.Text
        $config.Mail.Enabled = $controls.MailCheckBox.IsChecked
        $config.Mail.SmtpServer = $controls.SmtpServerTextBox.Text
        $config.Mail.Sender = $controls.SenderTextBox.Text
        $config.Mail.DevTo = $controls.DevRecipientTextBox.Text
        $config.Mail.ProdTo = $controls.ProdRecipientTextBox.Text
        return $config
    }
    
    # --- Event Handlers ---
    $controls.OkButton.add_Click({
        $Global:Config = Save-GuiToConfig -config $Global:Config
        Save-Config -Config $Global:Config -Path $Global:ConfigFile
        $Window.DialogResult = $true
        $Window.Close()
    })

    $controls.ApplyButton.add_Click({
        $Global:Config = Save-GuiToConfig -config $Global:Config
        Save-Config -Config $Global:Config -Path $Global:ConfigFile
    })

    $controls.CancelButton.add_Click({
        $Window.DialogResult = $false
        $Window.Close()
    })
    
    $browseAction = {
        param($TextBox)
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dialog.ShowDialog() -eq 'OK') {
            $TextBox.Text = $dialog.SelectedPath
        }
    }
    $controls.BrowseLogPathButton.add_Click({ & $browseAction $controls.LogPathTextBox })
    $controls.BrowseReportPathButton.add_Click({ & $browseAction $controls.ReportPathTextBox })
    $controls.BrowseGitCachePathButton.add_Click({ & $browseAction $controls.GitCachePathTextBox })
    
    $controls.LanguageComboBox.add_SelectionChanged({
        if ($controls.LanguageComboBox.SelectedItem.Content -ne $InitialConfig.Language) {
            $result = [System.Windows.MessageBox]::Show($L.RestartMessage, $L.RestartTitle, 'YesNo', 'Question')
            if ($result -eq 'Yes') {
                $Global:Config = Save-GuiToConfig -config $Global:Config
                Save-Config -Config $Global:Config -Path $Global:ConfigFile
                $Window.Tag = 'Restart'
                $Window.Close()
            } else {
                # Revert selection
                $controls.LanguageComboBox.SelectedItem = $controls.LanguageComboBox.Items | Where-Object { $_.Content -eq $InitialConfig.Language }
            }
        }
    })

    # --- Load data and show window ---
    Initialize-GuiFromConfig -config $InitialConfig
    $null = $Window.ShowDialog()

    return $Window.Tag
}

# --- End of module --- v10.3.1 ; Regelwerk: v7.7.0 ---

