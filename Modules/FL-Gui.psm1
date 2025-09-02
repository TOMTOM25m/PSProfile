<#
.SYNOPSIS
    [DE] Modul für die grafische Benutzeroberfläche (GUI).
    [EN] Module for the Graphical User Interface (GUI).
.DESCRIPTION
    [DE] Enthält Funktionen zum Anzeigen von WPF-Fenstern für die Skripteinrichtung.
    [EN] Contains functions for displaying WPF windows for script setup.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.09.02
    Version:        v11.2.1
    MUW-Regelwerk:  v8.2.0
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Initialize-LocalizationFiles {
    [CmdletBinding()]
    param()
    Write-Log -Level DEBUG -Message "Initializing localization files..."
    $configDir = Join-Path -Path $Global:ScriptDirectory -ChildPath 'Config'
    $dePath = Join-Path -Path $configDir -ChildPath 'de-DE.json'
    $enPath = Join-Path -Path $configDir -ChildPath 'en-US.json'

    if (-not (Test-Path $dePath)) {
        Write-Log -Level INFO -Message "Creating German localization file: $dePath"
        Get-DefaultTranslations -Culture 'de-DE' | ConvertTo-Json -Depth 3 | Set-Content -Path $dePath -Encoding UTF8
    }
    if (-not (Test-Path $enPath)) {
        Write-Log -Level INFO -Message "Creating English localization file: $enPath"
        Get-DefaultTranslations -Culture 'en-US' | ConvertTo-Json -Depth 3 | Set-Content -Path $enPath -Encoding UTF8
    }
}

function Show-MuwSetupGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$InitialConfig
    )
    Write-Log -Level INFO "GUI mode started. Loading setup window..."

    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

        #region --- XAML Definition ---
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ConfigGUI $($Global:ScriptName) - $($Global:ScriptVersion)" Height="600" Width="800" MinHeight="500" MinWidth="700"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True" Background="#F0F0F0">
    <Window.Resources>
        <SolidColorBrush x:Key="PrimaryBrush" Color="#111d4e"/>
        <Style TargetType="TabItem">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="Background" Value="LightGray"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" BorderThickness="1,1,1,0" BorderBrush="Gainsboro" CornerRadius="4,4,0,0" Margin="2,0">
                            <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="10,2"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="{StaticResource PrimaryBrush}" />
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
        <Style TargetType="Button">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="MinWidth" Value="80"/>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{StaticResource PrimaryBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="White"/>
                                <Setter Property="Foreground" Value="{StaticResource PrimaryBrush}"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="{StaticResource PrimaryBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Label">
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Padding" Value="2"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <TabControl Grid.Row="0">
            <TabItem Header="General">
                <Grid Margin="10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>
                    <Label Grid.Row="0" Grid.Column="0" Content="Language:"/>
                    <ComboBox x:Name="languageComboBox" Grid.Row="0" Grid.Column="1" Margin="5" SelectedIndex="0">
                        <ComboBoxItem Content="English (en-US)"/>
                        <ComboBoxItem Content="Deutsch (de-DE)"/>
                    </ComboBox>

                    <Label Grid.Row="1" Grid.Column="0" Content="Environment:"/>
                    <ComboBox x:Name="environmentComboBox" Grid.Row="1" Grid.Column="1" Margin="5" SelectedIndex="0">
                        <ComboBoxItem Content="DEV"/>
                        <ComboBoxItem Content="PROD"/>
                    </ComboBox>

                    <Label Grid.Row="2" Grid.Column="0" Content="Simulation Mode (WhatIf):"/>
                    <CheckBox x:Name="whatIfCheckBox" Grid.Row="2" Grid.Column="1" Margin="5"/>
                </Grid>
            </TabItem>
            <TabItem Header="Logging">
                 <Grid Margin="10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="*" />
                        <ColumnDefinition Width="Auto" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <Label Grid.Row="0" Grid.Column="0" Content="Log Path:"/>
                    <TextBox x:Name="logPathTextBox" Grid.Row="0" Grid.Column="1" Margin="5"/>
                    <Button x:Name="browseLogPathButton" Grid.Row="0" Grid.Column="2" Content="..."/>

                    <Label Grid.Row="1" Grid.Column="0" Content="Report Path:"/>
                    <TextBox x:Name="reportPathTextBox" Grid.Row="1" Grid.Column="1" Margin="5"/>
                    <Button x:Name="browseReportPathButton" Grid.Row="1" Grid.Column="2" Content="..."/>

                    <Label Grid.Row="2" Grid.Column="0" Content="7-Zip Path:"/>
                    <TextBox x:Name="sevenZipPathTextBox" Grid.Row="2" Grid.Column="1" Margin="5"/>
                    <Button x:Name="browse7ZipPathButton" Grid.Row="2" Grid.Column="2" Content="..."/>

                    <Label Grid.Row="3" Grid.Column="0" Content="Archive Logs:"/>
                    <CheckBox x:Name="archiveLogsCheckBox" Grid.Row="3" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="4" Grid.Column="0" Content="Enable EventLog:"/>
                    <CheckBox x:Name="enableEventLogCheckBox" Grid.Row="4" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="5" Grid.Column="0" Content="Log Retention (Days):"/>
                    <TextBox x:Name="logRetentionDaysTextBox" Grid.Row="5" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="6" Grid.Column="0" Content="Archive Retention (Days):"/>
                    <TextBox x:Name="archiveRetentionDaysTextBox" Grid.Row="6" Grid.Column="1" Margin="5"/>
                </Grid>
            </TabItem>
            <TabItem Header="Mail">
                 <Grid Margin="10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <Label Grid.Row="0" Grid.Column="0" Content="Enable Mail:"/>
                    <CheckBox x:Name="enableMailCheckBox" Grid.Row="0" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="1" Grid.Column="0" Content="SMTP Server:"/>
                    <TextBox x:Name="smtpServerTextBox" Grid.Row="1" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="2" Grid.Column="0" Content="Sender Address:"/>
                    <TextBox x:Name="senderTextBox" Grid.Row="2" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="3" Grid.Column="0" Content="DEV Recipient:"/>
                    <TextBox x:Name="devRecipientTextBox" Grid.Row="3" Grid.Column="1" Margin="5"/>

                    <Label Grid.Row="4" Grid.Column="0" Content="PROD Recipient:"/>
                    <TextBox x:Name="prodRecipientTextBox" Grid.Row="4" Grid.Column="1" Margin="5"/>
                </Grid>
            </TabItem>
        </TabControl>

        <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="cancelButton" Content="Abbrechen" />
            <Button x:Name="applyButton" Content="Anwenden" Style="{StaticResource PrimaryButton}"/>
            <Button x:Name="okButton" Content="OK" Style="{StaticResource PrimaryButton}" IsDefault="True"/>
        </StackPanel>
    </Grid>
</Window>
'@
        #endregion --- XAML Definition ---

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        
        #region --- Control Discovery ---
        $controls = @{
            # General Tab
            languageComboBox = $window.FindName('languageComboBox');
            environmentComboBox = $window.FindName('environmentComboBox');
            whatIfCheckBox = $window.FindName('whatIfCheckBox');
            
            # Logging Tab
            logPathTextBox = $window.FindName('logPathTextBox');
            browseLogPathButton = $window.FindName('browseLogPathButton');
            reportPathTextBox = $window.FindName('reportPathTextBox');
            browseReportPathButton = $window.FindName('browseReportPathButton');
            sevenZipPathTextBox = $window.FindName('sevenZipPathTextBox');
            browse7ZipPathButton = $window.FindName('browse7ZipPathButton');
            archiveLogsCheckBox = $window.FindName('archiveLogsCheckBox');
            enableEventLogCheckBox = $window.FindName('enableEventLogCheckBox');
            logRetentionDaysTextBox = $window.FindName('logRetentionDaysTextBox');
            archiveRetentionDaysTextBox = $window.FindName('archiveRetentionDaysTextBox');

            # Mail Tab
            enableMailCheckBox = $window.FindName('enableMailCheckBox');
            smtpServerTextBox = $window.FindName('smtpServerTextBox');
            senderTextBox = $window.FindName('senderTextBox');
            devRecipientTextBox = $window.FindName('devRecipientTextBox');
            prodRecipientTextBox = $window.FindName('prodRecipientTextBox');

            # Main Buttons
            okButton = $window.FindName('okButton');
            cancelButton = $window.FindName('cancelButton');
            applyButton = $window.FindName('applyButton');
        }
        #endregion --- Control Discovery ---

        #region --- Helper Functions ---
        function Load-ConfigIntoGui($config, $controls) {
            # General
            $controls.languageComboBox.SelectedIndex = if ($config.Language -eq 'de-DE') { 1 } else { 0 }
            $controls.environmentComboBox.SelectedItem = $config.Environment
            $controls.whatIfCheckBox.IsChecked = $config.WhatIfMode

            # Logging
            $controls.logPathTextBox.Text = $config.Logging.LogPath
            $controls.reportPathTextBox.Text = $config.Logging.ReportPath
            $controls.sevenZipPathTextBox.Text = $config.Logging.SevenZipPath
            $controls.archiveLogsCheckBox.IsChecked = $config.Logging.ArchiveLogs
            $controls.enableEventLogCheckBox.IsChecked = $config.Logging.EnableEventLog
            $controls.logRetentionDaysTextBox.Text = $config.Logging.LogRetentionDays
            $controls.archiveRetentionDaysTextBox.Text = $config.Logging.ArchiveRetentionDays

            # Mail
            $controls.enableMailCheckBox.IsChecked = $config.Mail.Enabled
            $controls.smtpServerTextBox.Text = $config.Mail.SmtpServer
            $controls.senderTextBox.Text = $config.Mail.Sender
            $controls.devRecipientTextBox.Text = $config.Mail.DevRecipient
            $controls.prodRecipientTextBox.Text = $config.Mail.ProdRecipient
        }

        function Save-ConfigFromGui($config, $controls) {
            # General
            $config.Language = if ($controls.languageComboBox.SelectedIndex -eq 1) { 'de-DE' } else { 'en-US' }
            $config.Environment = $controls.environmentComboBox.SelectedItem.Content
            $config.WhatIfMode = $controls.whatIfCheckBox.IsChecked

            # Logging
            $config.Logging.LogPath = $controls.logPathTextBox.Text
            $config.Logging.ReportPath = $controls.reportPathTextBox.Text
            $config.Logging.SevenZipPath = $controls.sevenZipPathTextBox.Text
            $config.Logging.ArchiveLogs = $controls.archiveLogsCheckBox.IsChecked
            $config.Logging.EnableEventLog = $controls.enableEventLogCheckBox.IsChecked
            $config.Logging.LogRetentionDays = [int]$controls.logRetentionDaysTextBox.Text
            $config.Logging.ArchiveRetentionDays = [int]$controls.archiveRetentionDaysTextBox.Text

            # Mail
            $config.Mail.Enabled = $controls.enableMailCheckBox.IsChecked
            $config.Mail.SmtpServer = $controls.smtpServerTextBox.Text
            $config.Mail.Sender = $controls.senderTextBox.Text
            $config.Mail.DevRecipient = $controls.devRecipientTextBox.Text
            $config.Mail.ProdRecipient = $controls.prodRecipientTextBox.Text
            return $config
        }

        function Select-Path($initialPath, $isFile) {
            Add-Type -AssemblyName System.Windows.Forms
            if ($isFile) {
                $dialog = New-Object Microsoft.Win32.OpenFileDialog
                if (-not [string]::IsNullOrEmpty($initialPath) -and (Test-Path (Split-Path $initialPath -Parent))) {
                    $dialog.InitialDirectory = (Split-Path $initialPath -Parent)
                }
            } else {
                $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                if (-not [string]::IsNullOrEmpty($initialPath) -and (Test-Path $initialPath)) {
                    $dialog.SelectedPath = $initialPath
                }
            }
            if ($dialog.ShowDialog() -eq $true) {
                return if ($isFile) { $dialog.FileName } else { $dialog.SelectedPath }
            } else {
                return $initialPath
            }
        }
        #endregion --- Helper Functions ---

        #region --- Event Handlers ---
        $applyLogic = {
            Write-Log -Level INFO "Applying GUI changes..."
            $Global:Config = Save-ConfigFromGui -config $Global:Config -controls $controls
            Save-Config -Config $Global:Config -Path $Global:ConfigFile
            Write-Log -Level INFO "Configuration saved."
        }

        $controls.okButton.add_Click({
            & $applyLogic
            $window.Close()
        })

        $controls.applyButton.add_Click($applyLogic)

        $controls.cancelButton.add_Click({
            $window.Close()
        })

        $controls.browseLogPathButton.add_Click({
            $controls.logPathTextBox.Text = Select-Path -initialPath $controls.logPathTextBox.Text -isFile $false
        })
        $controls.browseReportPathButton.add_Click({
            $controls.reportPathTextBox.Text = Select-Path -initialPath $controls.reportPathTextBox.Text -isFile $false
        })
        $controls.browse7ZipPathButton.add_Click({
            $controls.sevenZipPathTextBox.Text = Select-Path -initialPath $controls.sevenZipPathTextBox.Text -isFile $true
        })

        #endregion --- Event Handlers ---

        # Load initial data and show the window
        Load-ConfigIntoGui -config $InitialConfig -controls $controls
        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Log -Level ERROR "Failed to create or show GUI. Error: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Initialize-LocalizationFiles, Show-MuwSetupGui

# --- End of module --- v11.2.1 ; Regelwerk: v8.2.0 ---