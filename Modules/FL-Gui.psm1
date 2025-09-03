# ==========================================================================
# Name: FL-Gui.psm1
# Version: v11.2.2
# Author: Admin
# Company: MedUni Wien
# Website: https://www.meduniwien.ac.at/
# Created: 2024-07-31
# Updated: 2024-08-29
# ==========================================================================
# Description:
# PowerShell GUI module for the Reset-PowerShellProfiles script following Regelwerk 8.0.2.
# Provides WPF-based GUI for configuration management with corporate design.
# ==========================================================================

# Import required modules
if (Get-Module -Name FL-Config) {
    Write-Verbose "Module FL-Config already loaded."
} else {
    try {
        Import-Module "$PSScriptRoot\FL-Config.psm1" -Force
        Write-Verbose "Module FL-Config imported successfully."
    } catch {
        Write-Error "Failed to import FL-Config module: $($_.Exception.Message)"
        throw
    }
}

# Global variable to store localized texts
$Global:LocalizedTexts = $null

function Get-LocalizedText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $false)][string]$Language = "en-US",
        [Parameter(Mandatory = $false)][string[]]$FormatArgs = @()
    )
    
    if ($null -eq $Global:LocalizedTexts -or $Global:LocalizedTexts.Language -ne $Language) {
        try {
            $languageFilePath = Join-Path $Global:ScriptDirectory "Config\$Language.json"
            if (Test-Path $languageFilePath) {
                $Global:LocalizedTexts = @{
                    Language = $Language
                    Texts = Get-Content -Path $languageFilePath -Raw | ConvertFrom-Json
                }
                Write-Log -Level DEBUG -Message "Loaded localization file: $languageFilePath"
            } else {
                Write-Log -Level WARNING -Message "Localization file not found: $languageFilePath. Using fallback."
                $Global:LocalizedTexts = @{
                    Language = "en-US"
                    Texts = @{ $Key = $Key }  # Fallback to key name
                }
            }
        } catch {
            Write-Log -Level ERROR -Message "Error loading localization file: $($_.Exception.Message)"
            return $Key  # Fallback to key name
        }
    }
    
    $text = $Global:LocalizedTexts.Texts.$Key
    if ([string]::IsNullOrEmpty($text)) {
        Write-Log -Level WARNING -Message "Localization key '$Key' not found for language '$Language'"
        return $Key  # Fallback to key name
    }
    
    # Apply string formatting if arguments provided
    if ($FormatArgs.Count -gt 0) {
        try {
            return [string]::Format($text, $FormatArgs)
        } catch {
            Write-Log -Level WARNING -Message "Error formatting localized text for key '$Key': $($_.Exception.Message)"
            return $text
        }
    }
    
    return $text
}

if (Get-Module -Name FL-Logging) {
    Write-Verbose "Module FL-Logging already loaded."
} else {
    try {
        Import-Module "$PSScriptRoot\FL-Logging.psm1" -Force
        Write-Verbose "Module FL-Logging imported successfully."
    } catch {
        Write-Error "Failed to import FL-Logging module: $($_.Exception.Message)"
        throw
    }
}

function Show-SetupGUI {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$InitialConfig
    )
    Write-Log -Level INFO "GUI mode started. Loading setup window..."
    
    # Initialize localization
    $currentLanguage = $InitialConfig.Language
    Write-Log -Level DEBUG "Initializing localization for language: $currentLanguage"

    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

        $windowTitle = "SetupGUI $($Global:ScriptName -replace '.ps1', '') Version : $($Global:ScriptVersion)"

        #region --- XAML Definition ---
        # DevSkim: ignore DS137138 - XAML namespace URLs are required for WPF functionality
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SetupGUI Reset-PowerShellProfiles" Height="600" Width="800" MinHeight="500" MinWidth="700"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True" Background="#F0F0F0"
        Topmost="True" ShowActivated="True" Focusable="True" WindowState="Normal">
    <Window.Resources>
        <SolidColorBrush x:Key="PrimaryBrush" Color="#111d4e"/>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="MinWidth" Value="80"/>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{StaticResource PrimaryBrush}"/>
            <Setter Property="Foreground" Value="White"/>
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
            
            <TabItem Header="Network Profiles" x:Name="networkProfilesTab">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <DataGrid x:Name="networkProfilesDataGrid" Grid.Row="0" Margin="5" AutoGenerateColumns="False" CanUserAddRows="False">
                        <DataGrid.Columns>
                            <DataGridCheckBoxColumn Header="Enabled" Binding="{Binding Enabled}" Width="60"/>
                            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="150"/>
                            <DataGridTextColumn Header="UNC Path" Binding="{Binding Path}" Width="250"/>
                            <DataGridTextColumn Header="Username" Binding="{Binding Username}" Width="120"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Left" Margin="5">
                        <Button x:Name="addNetworkProfileButton" Content="Add Profile" Width="100" Height="30" Margin="0,0,10,0"/>
                        <Button x:Name="deleteNetworkProfileButton" Content="Delete Profile" Width="100" Height="30"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <TabItem Header="Templates" x:Name="templatesTab">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <DataGrid x:Name="templatesDataGrid" Grid.Row="0" Margin="5" AutoGenerateColumns="False" CanUserAddRows="False">
                        <DataGrid.Columns>
                            <DataGridCheckBoxColumn Header="Enabled" Binding="{Binding Enabled}" Width="60"/>
                            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/>
                            <DataGridTextColumn Header="File Path" Binding="{Binding FilePath}" Width="300"/>
                            <DataGridTextColumn Header="Description" Binding="{Binding Description}" Width="250"/>
                        </DataGrid.Columns>
                    </DataGrid>
                    
                    <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Left" Margin="5">
                        <Button x:Name="addTemplateButton" Content="Add Template" Width="100" Height="30" Margin="0,0,10,0"/>
                        <Button x:Name="deleteTemplateButton" Content="Delete Template" Width="100" Height="30"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <TabItem Header="Mail">
                <Grid Margin="10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto" />
                        <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
                        <RowDefinition Height="Auto" />
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
        #endregion

        #region --- Load XAML ---
        Write-Log -Level DEBUG "Loading XAML definition..."
        $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
        $window.Title = $windowTitle

        # Ensure window appears in foreground and is focused
        $window.Topmost = $true
        $window.ShowActivated = $true
        $window.WindowState = [System.Windows.WindowState]::Normal

        #endregion

        #region --- Find Controls ---
        Write-Log -Level DEBUG "Finding GUI controls..."
        $languageComboBox = $window.FindName('languageComboBox')
        $environmentComboBox = $window.FindName('environmentComboBox')
        $whatIfCheckBox = $window.FindName('whatIfCheckBox')
        $networkProfilesDataGrid = $window.FindName('networkProfilesDataGrid')
        $addNetworkProfileButton = $window.FindName('addNetworkProfileButton')
        $deleteNetworkProfileButton = $window.FindName('deleteNetworkProfileButton')
        $templatesDataGrid = $window.FindName('templatesDataGrid')
        $addTemplateButton = $window.FindName('addTemplateButton')
        $deleteTemplateButton = $window.FindName('deleteTemplateButton')
        $enableMailCheckBox = $window.FindName('enableMailCheckBox')
        $smtpServerTextBox = $window.FindName('smtpServerTextBox')
        $senderTextBox = $window.FindName('senderTextBox')
        $devRecipientTextBox = $window.FindName('devRecipientTextBox')
        $prodRecipientTextBox = $window.FindName('prodRecipientTextBox')
        $cancelButton = $window.FindName('cancelButton')
        $applyButton = $window.FindName('applyButton')
        $okButton = $window.FindName('okButton')

        # Log found controls
        if ($languageComboBox) { Write-Log -Level DEBUG "Found control: languageComboBox" }
        if ($environmentComboBox) { Write-Log -Level DEBUG "Found control: environmentComboBox" }
        if ($whatIfCheckBox) { Write-Log -Level DEBUG "Found control: whatIfCheckBox" }
        if ($networkProfilesDataGrid) { Write-Log -Level DEBUG "Found control: networkProfilesDataGrid" }
        if ($addNetworkProfileButton) { Write-Log -Level DEBUG "Found control: addNetworkProfileButton" }
        if ($deleteNetworkProfileButton) { Write-Log -Level DEBUG "Found control: deleteNetworkProfileButton" }
        if ($enableMailCheckBox) { Write-Log -Level DEBUG "Found control: enableMailCheckBox" }
        if ($smtpServerTextBox) { Write-Log -Level DEBUG "Found control: smtpServerTextBox" }
        if ($senderTextBox) { Write-Log -Level DEBUG "Found control: senderTextBox" }
        if ($devRecipientTextBox) { Write-Log -Level DEBUG "Found control: devRecipientTextBox" }
        if ($prodRecipientTextBox) { Write-Log -Level DEBUG "Found control: prodRecipientTextBox" }
        if ($cancelButton) { Write-Log -Level DEBUG "Found control: cancelButton" }
        if ($applyButton) { Write-Log -Level DEBUG "Found control: applyButton" }
        if ($okButton) { Write-Log -Level DEBUG "Found control: okButton" }
        #endregion

        #region --- Apply Localization ---
        Write-Log -Level DEBUG "Applying localization texts..."
        
        # Find and localize tab headers
        $networkProfilesTab = $window.FindName('networkProfilesTab')
        if ($networkProfilesTab) { 
            $networkProfilesTab.Header = Get-LocalizedText -Key "TabNetworkProfiles" -Language $currentLanguage
        }
        
        $templatesTab = $window.FindName('templatesTab')
        if ($templatesTab) { 
            $templatesTab.Header = Get-LocalizedText -Key "TabTemplates" -Language $currentLanguage
        }
        
        # Localize Network Profiles buttons
        if ($addNetworkProfileButton) { 
            $addNetworkProfileButton.Content = Get-LocalizedText -Key "BtnAddProfile" -Language $currentLanguage
        }
        if ($deleteNetworkProfileButton) { 
            $deleteNetworkProfileButton.Content = Get-LocalizedText -Key "BtnDeleteProfile" -Language $currentLanguage
        }
        
        # Localize Templates buttons
        if ($addTemplateButton) { 
            $addTemplateButton.Content = Get-LocalizedText -Key "BtnAddTemplate" -Language $currentLanguage
        }
        if ($deleteTemplateButton) { 
            $deleteTemplateButton.Content = Get-LocalizedText -Key "BtnDeleteTemplate" -Language $currentLanguage
        }
        
        # Localize main buttons
        if ($okButton) { 
            $okButton.Content = Get-LocalizedText -Key "BtnOK" -Language $currentLanguage
        }
        if ($applyButton) { 
            $applyButton.Content = Get-LocalizedText -Key "BtnApply" -Language $currentLanguage
        }
        if ($cancelButton) { 
            $cancelButton.Content = Get-LocalizedText -Key "BtnCancel" -Language $currentLanguage
        }
        
        Write-Log -Level DEBUG "Localization applied successfully"
        #endregion

        #region --- Initialize Data ---
        Write-Log -Level DEBUG "Initializing GUI data..."
        
        # Set initial values
        if ($languageComboBox) { $languageComboBox.SelectedIndex = if ($InitialConfig.Language -eq "de-DE") { 1 } else { 0 } }
        if ($environmentComboBox) { $environmentComboBox.SelectedIndex = if ($InitialConfig.Environment -eq "PROD") { 1 } else { 0 } }
        if ($whatIfCheckBox) { $whatIfCheckBox.IsChecked = $InitialConfig.WhatIfMode }

        # Mail settings
        if ($enableMailCheckBox) { $enableMailCheckBox.IsChecked = $InitialConfig.Mail.Enabled }
        if ($smtpServerTextBox) { $smtpServerTextBox.Text = $InitialConfig.Mail.SmtpServer }
        if ($senderTextBox) { $senderTextBox.Text = $InitialConfig.Mail.Sender }
        if ($devRecipientTextBox) { $devRecipientTextBox.Text = $InitialConfig.Mail.DevRecipient }
        if ($prodRecipientTextBox) { $prodRecipientTextBox.Text = $InitialConfig.Mail.ProdRecipient }

        # Network Profiles
        if ($InitialConfig.NetworkProfiles -and $networkProfilesDataGrid) {
            $networkProfiles = @()
            foreach ($prof in $InitialConfig.NetworkProfiles) {
                $networkProfiles += [PSCustomObject]@{
                    Enabled = $prof.Enabled
                    Name = $prof.Name
                    Path = $prof.Path
                    Username = $prof.Username
                    EncryptedPassword = $prof.EncryptedPassword
                }
            }
            $networkProfilesDataGrid.ItemsSource = $networkProfiles
            Write-Log -Level DEBUG "Loaded $($networkProfiles.Count) network profiles into DataGrid"
        }

        # Templates
        if ($InitialConfig.Templates -and $templatesDataGrid) {
            $templates = @()
            foreach ($template in $InitialConfig.Templates) {
                $templates += [PSCustomObject]@{
                    Enabled = $template.Enabled
                    Name = $template.Name
                    FilePath = $template.FilePath
                    Description = $template.Description
                }
            }
            $templatesDataGrid.ItemsSource = $templates
            Write-Log -Level DEBUG "Loaded $($templates.Count) templates into DataGrid"
        }

        #endregion

        #region --- Event Handlers ---
        Write-Log -Level DEBUG "Setting up event handlers..."

        # Add Network Profile button
        if ($addNetworkProfileButton) {
            $addNetworkProfileButton.Add_Click({
                try {
                    Write-Log -Level DEBUG "Add Network Profile button clicked"
                    $result = Show-NetworkProfileDialog -Language $currentLanguage
                    if ($result) {
                        Write-Log -Level DEBUG "Network Profile dialog returned valid result: $($result.Name)"
                        $currentProfiles = @()
                        if ($networkProfilesDataGrid.ItemsSource) {
                            $currentProfiles = @($networkProfilesDataGrid.ItemsSource)
                        }
                        $currentProfiles += $result
                        $networkProfilesDataGrid.ItemsSource = $currentProfiles
                        $networkProfilesDataGrid.Items.Refresh()
                        Write-Log -Level INFO "Network profile '$($result.Name)' added successfully"
                    } else {
                        Write-Log -Level DEBUG "Network Profile dialog was cancelled or returned null"
                    }
                } catch {
                    Write-Log -Level ERROR "Error adding network profile: $($_.Exception.Message)"
                    [System.Windows.MessageBox]::Show("Error adding network profile: $($_.Exception.Message)", "Error", "OK", "Error")
                }
            })
        }

        # Delete Network Profile button
        if ($deleteNetworkProfileButton) {
            $deleteNetworkProfileButton.Add_Click({
                try {
                    Write-Log -Level DEBUG "Delete Network Profile button clicked"
                    
                    # Check if a profile is selected
                    if ($null -eq $networkProfilesDataGrid.SelectedItem) {
                        $msgText = Get-LocalizedText -Key "MsgSelectProfile" -Language $currentLanguage
                        $msgTitle = Get-LocalizedText -Key "MsgNoSelection" -Language $currentLanguage
                        [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                        return
                    }
                    
                    $selectedProfile = $networkProfilesDataGrid.SelectedItem
                    $profileName = $selectedProfile.Name
                    
                    # Confirm deletion
                    $confirmMsg = Get-LocalizedText -Key "MsgConfirmDelete" -Language $currentLanguage -FormatArgs @($profileName)
                    $confirmTitle = Get-LocalizedText -Key "MsgConfirmDeleteTitle" -Language $currentLanguage
                    $result = [System.Windows.MessageBox]::Show($confirmMsg, $confirmTitle, "YesNo", "Question")
                    
                    if ($result -eq "Yes") {
                        # Remove from DataGrid
                        $currentProfiles = @($networkProfilesDataGrid.ItemsSource)
                        $updatedProfiles = $currentProfiles | Where-Object { $_.Name -ne $profileName }
                        $networkProfilesDataGrid.ItemsSource = $updatedProfiles
                        $networkProfilesDataGrid.Items.Refresh()
                        
                        Write-Log -Level INFO "Network profile '$profileName' deleted successfully"
                        $successMsg = Get-LocalizedText -Key "MsgProfileDeleted" -Language $currentLanguage -FormatArgs @($profileName)
                        $successTitle = Get-LocalizedText -Key "MsgProfileDeletedTitle" -Language $currentLanguage
                        [System.Windows.MessageBox]::Show($successMsg, $successTitle, "OK", "Information")
                    }
                } catch {
                    Write-Log -Level ERROR "Error deleting network profile: $($_.Exception.Message)"
                    $errorMsg = Get-LocalizedText -Key "MsgErrorDeletingProfile" -Language $currentLanguage -FormatArgs @($_.Exception.Message)
                    $errorTitle = Get-LocalizedText -Key "MsgError" -Language $currentLanguage
                    [System.Windows.MessageBox]::Show($errorMsg, $errorTitle, "OK", "Error")
                }
            })
        }

        # Add Template button
        if ($addTemplateButton) {
            $addTemplateButton.Add_Click({
                try {
                    Write-Log -Level DEBUG "Add Template button clicked"
                    $result = Show-TemplateDialog -Language $currentLanguage
                    if ($result) {
                        Write-Log -Level DEBUG "Template dialog returned valid result: $($result.Name)"
                        $currentTemplates = @()
                        if ($templatesDataGrid.ItemsSource) {
                            $currentTemplates = @($templatesDataGrid.ItemsSource)
                        }
                        $currentTemplates += $result
                        $templatesDataGrid.ItemsSource = $currentTemplates
                        $templatesDataGrid.Items.Refresh()
                        Write-Log -Level INFO "Template '$($result.Name)' added successfully"
                    }
                } catch {
                    Write-Log -Level ERROR "Error adding template: $($_.Exception.Message)"
                    $errorMsg = Get-LocalizedText -Key "MsgErrorAddingTemplate" -Language $currentLanguage -FormatArgs @($_.Exception.Message)
                    $errorTitle = Get-LocalizedText -Key "MsgError" -Language $currentLanguage
                    [System.Windows.MessageBox]::Show($errorMsg, $errorTitle, "OK", "Error")
                }
            })
        }

        # Delete Template button
        if ($deleteTemplateButton) {
            $deleteTemplateButton.Add_Click({
                try {
                    Write-Log -Level DEBUG "Delete Template button clicked"
                    
                    # Check if a template is selected
                    if ($null -eq $templatesDataGrid.SelectedItem) {
                        $msgText = Get-LocalizedText -Key "MsgSelectTemplate" -Language $currentLanguage
                        $msgTitle = Get-LocalizedText -Key "MsgNoSelection" -Language $currentLanguage
                        [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                        return
                    }
                    
                    $selectedTemplate = $templatesDataGrid.SelectedItem
                    $templateName = $selectedTemplate.Name
                    
                    # Confirm deletion
                    $confirmMsg = Get-LocalizedText -Key "MsgConfirmDeleteTemplate" -Language $currentLanguage -FormatArgs @($templateName)
                    $confirmTitle = Get-LocalizedText -Key "MsgConfirmDeleteTitle" -Language $currentLanguage
                    $result = [System.Windows.MessageBox]::Show($confirmMsg, $confirmTitle, "YesNo", "Question")
                    
                    if ($result -eq "Yes") {
                        # Remove from DataGrid
                        $currentTemplates = @($templatesDataGrid.ItemsSource)
                        $updatedTemplates = $currentTemplates | Where-Object { $_.Name -ne $templateName }
                        $templatesDataGrid.ItemsSource = $updatedTemplates
                        $templatesDataGrid.Items.Refresh()
                        
                        Write-Log -Level INFO "Template '$templateName' deleted successfully"
                        $successMsg = Get-LocalizedText -Key "MsgTemplateDeleted" -Language $currentLanguage -FormatArgs @($templateName)
                        $successTitle = Get-LocalizedText -Key "MsgTemplateDeletedTitle" -Language $currentLanguage
                        [System.Windows.MessageBox]::Show($successMsg, $successTitle, "OK", "Information")
                    }
                } catch {
                    Write-Log -Level ERROR "Error deleting template: $($_.Exception.Message)"
                    $errorMsg = Get-LocalizedText -Key "MsgErrorDeletingTemplate" -Language $currentLanguage -FormatArgs @($_.Exception.Message)
                    $errorTitle = Get-LocalizedText -Key "MsgError" -Language $currentLanguage
                    [System.Windows.MessageBox]::Show($errorMsg, $errorTitle, "OK", "Error")
                }
            })
        }

        # OK Button
        if ($okButton) {
            $okButton.Add_Click({
                $window.DialogResult = $true
                $window.Close()
            })
        }

        # Apply Button
        if ($applyButton) {
            $applyButton.Add_Click({
                # Apply changes without closing
                Write-Log -Level INFO "Apply button clicked - saving configuration..."
                
                try {
                    # Create updated configuration (same logic as OK button)
                    $updatedConfig = $InitialConfig.PSObject.Copy()
                    
                    # Update basic settings
                    if ($languageComboBox) { $updatedConfig.Language = if ($languageComboBox.SelectedIndex -eq 1) { "de-DE" } else { "en-US" } }
                    if ($environmentComboBox) { $updatedConfig.Environment = if ($environmentComboBox.SelectedIndex -eq 1) { "PROD" } else { "DEV" } }
                    if ($whatIfCheckBox) { $updatedConfig.WhatIfMode = $whatIfCheckBox.IsChecked }

                    # Update mail settings
                    if ($enableMailCheckBox) { $updatedConfig.Mail.Enabled = $enableMailCheckBox.IsChecked }
                    if ($smtpServerTextBox) { $updatedConfig.Mail.SmtpServer = $smtpServerTextBox.Text }
                    if ($senderTextBox) { $updatedConfig.Mail.Sender = $senderTextBox.Text }
                    if ($devRecipientTextBox) { $updatedConfig.Mail.DevRecipient = $devRecipientTextBox.Text }
                    if ($prodRecipientTextBox) { $updatedConfig.Mail.ProdRecipient = $prodRecipientTextBox.Text }

                    # Update network profiles
                    $networkProfiles = @()
                    if ($networkProfilesDataGrid -and $networkProfilesDataGrid.ItemsSource) {
                        foreach ($item in $networkProfilesDataGrid.ItemsSource) {
                            $networkProfiles += @{
                                Enabled = $item.Enabled
                                Name = $item.Name
                                Path = $item.Path
                                Username = $item.Username
                                EncryptedPassword = $item.EncryptedPassword
                            }
                        }
                    }
                    $updatedConfig.NetworkProfiles = $networkProfiles

                    # Save the configuration
                    Save-Config -Config $updatedConfig -Path (Join-Path $Global:ScriptDirectory "Config\Config-Reset-PowerShellProfiles.ps1.json")
                    
                    # Update global config
                    $Global:Config = $updatedConfig
                    
                    Write-Log -Level INFO "Configuration applied and saved successfully."
                    [System.Windows.MessageBox]::Show("Configuration saved successfully!", "Apply Changes", "OK", "Information")
                } catch {
                    Write-Log -Level ERROR "Error applying configuration: $($_.Exception.Message)"
                    [System.Windows.MessageBox]::Show("Error applying configuration: $($_.Exception.Message)", "Error", "OK", "Error")
                }
            })
        }

        # Cancel Button
        if ($cancelButton) {
            $cancelButton.Add_Click({
                $window.DialogResult = $false
                $window.Close()
            })
        }

        #endregion

        #region --- Show Dialog ---
        Write-Log -Level INFO "Showing setup GUI..."
        
        # Additional activation to ensure the window appears in foreground
        $window.Activate()
        $window.Focus()
        
        # Temporarily set Topmost to true, then false to bring to front
        $window.Topmost = $true
        $window.Topmost = $false
        
        $result = $window.ShowDialog()

        if ($result -eq $true) {
            Write-Log -Level INFO "User confirmed changes. Creating updated configuration..."
            
            # Create updated configuration
            $updatedConfig = $InitialConfig.PSObject.Copy()
            
            # Update basic settings
            if ($languageComboBox) { $updatedConfig.Language = if ($languageComboBox.SelectedIndex -eq 1) { "de-DE" } else { "en-US" } }
            if ($environmentComboBox) { $updatedConfig.Environment = if ($environmentComboBox.SelectedIndex -eq 1) { "PROD" } else { "DEV" } }
            if ($whatIfCheckBox) { $updatedConfig.WhatIfMode = $whatIfCheckBox.IsChecked }

            # Update mail settings
            if ($enableMailCheckBox) { $updatedConfig.Mail.Enabled = $enableMailCheckBox.IsChecked }
            if ($smtpServerTextBox) { $updatedConfig.Mail.SmtpServer = $smtpServerTextBox.Text }
            if ($senderTextBox) { $updatedConfig.Mail.Sender = $senderTextBox.Text }
            if ($devRecipientTextBox) { $updatedConfig.Mail.DevRecipient = $devRecipientTextBox.Text }
            if ($prodRecipientTextBox) { $updatedConfig.Mail.ProdRecipient = $prodRecipientTextBox.Text }

            # Update network profiles
            $networkProfiles = @()
            if ($networkProfilesDataGrid -and $networkProfilesDataGrid.ItemsSource) {
                foreach ($item in $networkProfilesDataGrid.ItemsSource) {
                    $networkProfiles += @{
                        Enabled = $item.Enabled
                        Name = $item.Name
                        Path = $item.Path
                        Username = $item.Username
                        EncryptedPassword = $item.EncryptedPassword
                    }
                }
            }
            $updatedConfig.NetworkProfiles = $networkProfiles

            # Update templates
            $templates = @()
            if ($templatesDataGrid -and $templatesDataGrid.ItemsSource) {
                foreach ($item in $templatesDataGrid.ItemsSource) {
                    $templates += @{
                        Enabled = $item.Enabled
                        Name = $item.Name
                        FilePath = $item.FilePath
                        Description = $item.Description
                    }
                }
            }
            $updatedConfig.Templates = $templates

            Write-Log -Level INFO "Configuration updated successfully."
            return $updatedConfig
        } else {
            Write-Log -Level INFO "User cancelled setup."
            return $null
        }
        #endregion

    } catch {
        Write-Log -Level ERROR "Failed to create or show GUI. Error: $($_.Exception.Message)"
        Write-Log -Level DEBUG "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}

function Show-NetworkProfileDialog {
    param(
        [PSCustomObject]$ExistingProfile = $null,
        [string]$Language = "en-US"
    )

    try {
        # DevSkim: ignore DS137138 - XAML namespace URLs are required for WPF functionality
        $dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Network Profile" Height="450" Width="550" MinHeight="400" MinWidth="500"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" ResizeMode="CanResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <CheckBox x:Name="enabledCheckBox" Grid.Row="0" Grid.ColumnSpan="2" Content="Enabled" Margin="0,0,0,15" IsChecked="True"/>

        <Label Grid.Row="1" Grid.Column="0" Content="Name:" VerticalAlignment="Center"/>
        <TextBox x:Name="nameTextBox" Grid.Row="1" Grid.Column="1" Margin="10,5" Height="25"/>

        <Label Grid.Row="2" Grid.Column="0" Content="UNC Path:" VerticalAlignment="Center"/>
        <TextBox x:Name="pathTextBox" Grid.Row="2" Grid.Column="1" Margin="10,5" Height="25"/>

        <Label Grid.Row="3" Grid.Column="0" Content="Username:" VerticalAlignment="Center"/>
        <TextBox x:Name="usernameTextBox" Grid.Row="3" Grid.Column="1" Margin="10,5" Height="25"/>

        <Label Grid.Row="4" Grid.Column="0" Content="Password:" VerticalAlignment="Center"/>
        <PasswordBox x:Name="passwordBox" Grid.Row="4" Grid.Column="1" Margin="10,5" Height="25"/>

        <StackPanel Grid.Row="5" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,20,0,10">
            <Button x:Name="testConnectionButton" Content="Test Connection" Width="140" Height="35" Margin="0,0,10,0"/>
        </StackPanel>

        <StackPanel Grid.Row="7" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,25,0,0">
            <Button x:Name="cancelButton" Content="Cancel" Width="90" Height="35" Margin="0,0,10,0"/>
            <Button x:Name="okButton" Content="OK" Width="90" Height="35" Margin="0,0,0,0" IsDefault="True"/>
        </StackPanel>
    </Grid>
</Window>
'@

        $reader = [System.Xml.XmlNodeReader]::new([xml]$dialogXaml)
        $dialog = [Windows.Markup.XamlReader]::Load($reader)

        # Find controls
        $enabledCheckBox = $dialog.FindName("enabledCheckBox")
        $nameTextBox = $dialog.FindName("nameTextBox")
        $pathTextBox = $dialog.FindName("pathTextBox")
        $usernameTextBox = $dialog.FindName("usernameTextBox")
        $passwordBox = $dialog.FindName("passwordBox")
        $testConnectionButton = $dialog.FindName("testConnectionButton")
        $okButton = $dialog.FindName("okButton")
        $cancelButton = $dialog.FindName("cancelButton")

        # Debug: Check if controls were found
        Write-Log -Level DEBUG "Controls found: EnabledCheckBox=$($null -ne $enabledCheckBox), NameTextBox=$($null -ne $nameTextBox), OkButton=$($null -ne $okButton), CancelButton=$($null -ne $cancelButton)"

        if (-not $okButton -or -not $cancelButton) {
            Write-Log -Level ERROR "Critical controls not found in Network Profile dialog"
            return $null
        }

        # Apply localization to dialog
        $dialog.Title = Get-LocalizedText -Key "NetworkProfileDialogTitle" -Language $Language
        if ($enabledCheckBox) { $enabledCheckBox.Content = Get-LocalizedText -Key "ChkEnabled" -Language $Language }
        if ($testConnectionButton) { $testConnectionButton.Content = Get-LocalizedText -Key "BtnTestConnection" -Language $Language }
        if ($okButton) { $okButton.Content = Get-LocalizedText -Key "BtnOK" -Language $Language }
        if ($cancelButton) { $cancelButton.Content = Get-LocalizedText -Key "BtnCancel" -Language $Language }

        # Set existing values if editing
        if ($ExistingProfile) {
            $enabledCheckBox.IsChecked = $ExistingProfile.Enabled
            $nameTextBox.Text = $ExistingProfile.Name
            $pathTextBox.Text = $ExistingProfile.Path
            $usernameTextBox.Text = $ExistingProfile.Username
        }

        # Event handlers
        if ($testConnectionButton) {
            $testConnectionButton.Add_Click({
                $path = $pathTextBox.Text
                $username = $usernameTextBox.Text
                $password = $passwordBox.SecurePassword

                if ([string]::IsNullOrWhiteSpace($path)) {
                    $msgText = Get-LocalizedText -Key "MsgEnterUncPath" -Language $Language
                    $msgTitle = Get-LocalizedText -Key "MsgValidationError" -Language $Language
                    [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                    return
                }

                try {
                    Write-Log -Level DEBUG "Testing connection to '$path' with username '$username'"
                    
                    # Disable the test button during test
                    $testConnectionButton.IsEnabled = $false
                    $testConnectionButton.Content = Get-LocalizedText -Key "MsgTestingConnection" -Language $Language
                    
                    # Test connection with proper credential handling
                    $testResult = Test-NetworkConnection -UncPath $path -Username $username -SecurePassword $password
                    
                    if ($testResult.Success) {
                        Write-Log -Level INFO "Network connection test successful: $($testResult.Message)"
                        $successMsg = Get-LocalizedText -Key "MsgConnectionSuccess" -Language $Language
                        $successTitle = Get-LocalizedText -Key "MsgTestResult" -Language $Language
                        [System.Windows.MessageBox]::Show("$successMsg`n`nDetails: $($testResult.Message)", $successTitle, "OK", "Information")
                    } else {
                        Write-Log -Level WARNING "Network connection test failed: $($testResult.Message)"
                        $failMsg = Get-LocalizedText -Key "MsgConnectionFailed" -Language $Language
                        $failTitle = Get-LocalizedText -Key "MsgTestResult" -Language $Language
                        [System.Windows.MessageBox]::Show("$failMsg`n`nError: $($testResult.Message)", $failTitle, "OK", "Warning")
                    }
                } catch {
                    Write-Log -Level ERROR "Network connection test error: $($_.Exception.Message)"
                    $errorMsg = Get-LocalizedText -Key "MsgConnectionFailed" -Language $Language
                    $errorTitle = Get-LocalizedText -Key "MsgTestResult" -Language $Language
                    [System.Windows.MessageBox]::Show("$errorMsg $($_.Exception.Message)", $errorTitle, "OK", "Error")
                } finally {
                    # Re-enable the test button
                    $testConnectionButton.IsEnabled = $true
                    $testConnectionButton.Content = Get-LocalizedText -Key "BtnTestConnection" -Language $Language
                }
            })
        }

        if ($okButton) {
            $okButton.Add_Click({
                try {
                    # Validate input
                    if ([string]::IsNullOrWhiteSpace($nameTextBox.Text)) {
                        $msgText = Get-LocalizedText -Key "MsgEnterProfileName" -Language $Language
                        $msgTitle = Get-LocalizedText -Key "MsgValidationError" -Language $Language
                        [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                        return
                    }
                    if ([string]::IsNullOrWhiteSpace($pathTextBox.Text)) {
                        $msgText = Get-LocalizedText -Key "MsgEnterUncPath" -Language $Language
                        $msgTitle = Get-LocalizedText -Key "MsgValidationError" -Language $Language
                        [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                        return
                    }

                    Write-Log -Level DEBUG "Network Profile dialog - OK button clicked with valid data"
                    $dialog.DialogResult = $true
                    $dialog.Close()
                } catch {
                    Write-Log -Level ERROR "Error in Network Profile dialog OK button: $($_.Exception.Message)"
                    $errorMsg = Get-LocalizedText -Key "MsgError" -Language $Language
                    [System.Windows.MessageBox]::Show("An error occurred: $($_.Exception.Message)", $errorMsg, "OK", "Error")
                }
            })
        }

        if ($cancelButton) {
            $cancelButton.Add_Click({
                $dialog.DialogResult = $false
                $dialog.Close()
            })
        }

        $result = $dialog.ShowDialog()

        if ($result -eq $true) {
            # Validate that we have the necessary data
            if ([string]::IsNullOrWhiteSpace($nameTextBox.Text) -or 
                [string]::IsNullOrWhiteSpace($pathTextBox.Text)) {
                Write-Log -Level ERROR "Invalid network profile data - name or path is empty"
                return $null
            }

            # Encrypt password if provided
            $encryptedPassword = ""
            if ($passwordBox -and -not [string]::IsNullOrEmpty($passwordBox.Password)) {
                $encryptedPassword = ConvertTo-SecureCredential -PlainTextPassword $passwordBox.Password
                Write-Log -Level DEBUG "Password encrypted for network profile"
            }

            # Create the return object with safe property access
            $profileResult = [PSCustomObject]@{
                Enabled = if ($enabledCheckBox) { $enabledCheckBox.IsChecked } else { $true }
                Name = if ($nameTextBox) { $nameTextBox.Text } else { "" }
                Path = if ($pathTextBox) { $pathTextBox.Text } else { "" }
                Username = if ($usernameTextBox) { $usernameTextBox.Text } else { "" }
                EncryptedPassword = $encryptedPassword
            }
            
            Write-Log -Level DEBUG "Network profile created: Name='$($profileResult.Name)', Path='$($profileResult.Path)'"
            return $profileResult
        }

        return $null

    } catch {
        Write-Log -Level ERROR "Failed to show network profile dialog: $($_.Exception.Message)"
        return $null
    }
}

function Show-TemplateDialog {
    param(
        [PSCustomObject]$ExistingTemplate = $null,
        [string]$Language = "en-US"
    )

    try {
        # DevSkim: ignore DS137138 - XAML namespace URLs are required for WPF functionality
        $dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Template Configuration" Height="350" Width="600" MinHeight="300" MinWidth="500"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" ResizeMode="CanResize"
        Topmost="True" ShowActivated="True" Focusable="True" WindowState="Normal">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <CheckBox x:Name="enabledCheckBox" Grid.Row="0" Grid.ColumnSpan="3" Content="Enabled" Margin="0,0,0,10" IsChecked="True"/>

        <Label Grid.Row="1" Grid.Column="0" Content="Name:" VerticalAlignment="Center"/>
        <TextBox x:Name="nameTextBox" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2" Margin="5" Height="25"/>

        <Label Grid.Row="2" Grid.Column="0" Content="File Path:" VerticalAlignment="Center"/>
        <TextBox x:Name="filePathTextBox" Grid.Row="2" Grid.Column="1" Margin="5" Height="25"/>
        <Button x:Name="browseButton" Grid.Row="2" Grid.Column="2" Content="Browse..." Width="80" Height="25" Margin="5,5,0,5"/>

        <Label Grid.Row="3" Grid.Column="0" Content="Description:" VerticalAlignment="Top" Margin="0,5,0,0"/>
        <TextBox x:Name="descriptionTextBox" Grid.Row="3" Grid.Column="1" Grid.ColumnSpan="2" Margin="5" Height="60" 
                 AcceptsReturn="True" TextWrapping="Wrap" ScrollViewer.VerticalScrollBarVisibility="Auto"/>

        <StackPanel Grid.Row="5" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,10">
            <Button x:Name="testTemplateButton" Content="Test Template" Width="120" Height="30" Margin="0,0,10,0"/>
        </StackPanel>

        <StackPanel Grid.Row="6" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button x:Name="okButton" Content="OK" Width="80" Height="30" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="cancelButton" Content="Cancel" Width="80" Height="30"/>
        </StackPanel>
    </Grid>
</Window>
'@

        $reader = [System.Xml.XmlNodeReader]::new([xml]$dialogXaml)
        $dialog = [Windows.Markup.XamlReader]::Load($reader)

        # Find controls
        $enabledCheckBox = $dialog.FindName("enabledCheckBox")
        $nameTextBox = $dialog.FindName("nameTextBox")
        $filePathTextBox = $dialog.FindName("filePathTextBox")
        $browseButton = $dialog.FindName("browseButton")
        $descriptionTextBox = $dialog.FindName("descriptionTextBox")
        $testTemplateButton = $dialog.FindName("testTemplateButton")
        $okButton = $dialog.FindName("okButton")
        $cancelButton = $dialog.FindName("cancelButton")

        # Localize dialog
        $dialog.Title = Get-LocalizedText -Key "TitleTemplateDialog" -Language $Language
        if ($enabledCheckBox) { $enabledCheckBox.Content = Get-LocalizedText -Key "LblEnabled" -Language $Language }
        if ($browseButton) { $browseButton.Content = Get-LocalizedText -Key "BtnBrowse" -Language $Language }
        if ($testTemplateButton) { $testTemplateButton.Content = Get-LocalizedText -Key "BtnTestTemplate" -Language $Language }
        if ($okButton) { $okButton.Content = Get-LocalizedText -Key "BtnOK" -Language $Language }
        if ($cancelButton) { $cancelButton.Content = Get-LocalizedText -Key "BtnCancel" -Language $Language }

        # Set existing values if editing
        if ($ExistingTemplate) {
            $enabledCheckBox.IsChecked = $ExistingTemplate.Enabled
            $nameTextBox.Text = $ExistingTemplate.Name
            $filePathTextBox.Text = $ExistingTemplate.FilePath
            $descriptionTextBox.Text = $ExistingTemplate.Description
        }

        # Event handlers
        $browseButton.Add_Click({
            try {
                $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
                $openFileDialog.InitialDirectory = "$PSScriptRoot\..\Templates"
                
                if ($openFileDialog.ShowDialog() -eq $true) {
                    $filePathTextBox.Text = $openFileDialog.FileName
                    
                    # Auto-generate name from filename if empty
                    if ([string]::IsNullOrWhiteSpace($nameTextBox.Text)) {
                        $nameTextBox.Text = [System.IO.Path]::GetFileNameWithoutExtension($openFileDialog.FileName)
                    }
                }
            } catch {
                Write-Log -Level ERROR "Error browsing for template file: $($_.Exception.Message)"
                $errorMsg = Get-LocalizedText -Key "MsgErrorBrowsingFile" -Language $Language -FormatArgs @($_.Exception.Message)
                $errorTitle = Get-LocalizedText -Key "MsgError" -Language $Language
                [System.Windows.MessageBox]::Show($errorMsg, $errorTitle, "OK", "Error")
            }
        })

        $testTemplateButton.Add_Click({
            $filePath = $filePathTextBox.Text

            if ([string]::IsNullOrWhiteSpace($filePath)) {
                $msgText = Get-LocalizedText -Key "MsgEnterFilePath" -Language $Language
                $msgTitle = Get-LocalizedText -Key "MsgValidationError" -Language $Language
                [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                return
            }

            try {
                if (Test-Path $filePath) {
                    $successMsg = Get-LocalizedText -Key "MsgTemplateTestSuccess" -Language $Language
                    $successTitle = Get-LocalizedText -Key "MsgTestResult" -Language $Language
                    [System.Windows.MessageBox]::Show($successMsg, $successTitle, "OK", "Information")
                } else {
                    $errorMsg = Get-LocalizedText -Key "MsgTemplateNotFound" -Language $Language -FormatArgs @($filePath)
                    $errorTitle = Get-LocalizedText -Key "MsgTestResult" -Language $Language
                    [System.Windows.MessageBox]::Show($errorMsg, $errorTitle, "OK", "Warning")
                }
            } catch {
                $errorMsg = Get-LocalizedText -Key "MsgTemplateTestFailed" -Language $Language -FormatArgs @($_.Exception.Message)
                $errorTitle = Get-LocalizedText -Key "MsgTestResult" -Language $Language
                [System.Windows.MessageBox]::Show($errorMsg, $errorTitle, "OK", "Error")
            }
        })

        $okButton.Add_Click({
            # Validate input
            if ([string]::IsNullOrWhiteSpace($nameTextBox.Text)) {
                $msgText = Get-LocalizedText -Key "MsgEnterTemplateName" -Language $Language
                $msgTitle = Get-LocalizedText -Key "MsgValidationError" -Language $Language
                [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                return
            }
            if ([string]::IsNullOrWhiteSpace($filePathTextBox.Text)) {
                $msgText = Get-LocalizedText -Key "MsgEnterFilePath" -Language $Language
                $msgTitle = Get-LocalizedText -Key "MsgValidationError" -Language $Language
                [System.Windows.MessageBox]::Show($msgText, $msgTitle, "OK", "Warning")
                return
            }

            $dialog.DialogResult = $true
            $dialog.Close()
        })

        $cancelButton.Add_Click({
            $dialog.DialogResult = $false
            $dialog.Close()
        })

        $result = $dialog.ShowDialog()

        if ($result -eq $true) {
            return [PSCustomObject]@{
                Enabled = $enabledCheckBox.IsChecked
                Name = $nameTextBox.Text
                FilePath = $filePathTextBox.Text
                Description = $descriptionTextBox.Text
            }
        }

        return $null

    } catch {
        Write-Log -Level ERROR "Failed to show template dialog: $($_.Exception.Message)"
        return $null
    }
}

# Export module members
Export-ModuleMember -Function Show-SetupGUI, Show-NetworkProfileDialog, Show-TemplateDialog

# SIG # Begin signature block
# MIIb/gYJKoZIhvcNAQcCoIIb7zCCG+sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPrC74yba1dV1Ed/r4etJN+8F
# F1GgghZgMIIDIjCCAgqgAwIBAgIQSrQKC5vlGaZCUpHrJkIsMTANBgkqhkiG9w0B
# AQsFADApMRQwEgYDVQQKDAtZb3VyQ29tcGFueTERMA8GA1UEAwwIWW91ck5hbWUw
# HhcNMjUwOTAzMTAyOTA0WhcNMzAwOTAzMTAzOTA0WjApMRQwEgYDVQQKDAtZb3Vy
# Q29tcGFueTERMA8GA1UEAwwIWW91ck5hbWUwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCnipm3cYerBn8htsu7JHe+iONzVLuTaocSedCEGTSFfaLeVEUE
# SO3I8nElPYdaj18doUNoo1jHtuPsIjvDTF9BjuiGhL3AvAVopL+JJgVbQuL6sR0H
# mycTzwJliVGN407OZ1F1tC5O2sUWvDcFe6KpqcOHKBpuErB0aUkdR44tdlOYCIL1
# xyMDe6pIzkrttPKgxLWh0ZXd3pukYRaVX+3PsAIWFbz3iJ1kS3qTq65/bvIMR3jt
# ZHQQBRulw6viscaGgYE+cR+WMNz5brsVoebZHiqdZv6m03QNidj/oL2w3KpZcCX1
# abwwtJ4vEAElgzjZG6I3A2N1CGQCQ3R0vuqtAgMBAAGjRjBEMA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU7Saz/ceN2QTiqREx
# Oxv3P2Ij13UwDQYJKoZIhvcNAQELBQADggEBAIJV6u7yU7Cp0LgIqBV4c6bwgHta
# hnFN2/68DYSJoDE2rXgOk7SVg98hUtBqJVpf1l+d0+cmEqQDhK+4cZ8XaYi7mxI8
# sq9juiuR+T+XD5LTQaEF3SNRjnLMLAaRH1t+wcSphfVDrDL1ibTO5BQce9zsqBoI
# v1/GqTftZ/T5WDhqb0XsUR1biTWFC+mkUTqz7w9W9azdCS9vdEfmn3vhPvpYjt9T
# I5Ubp3tRNai8qzwRYEgaUwyIAaa4CZlyp9n23fmpv6qGVMcPJQZtwLOWR5Zf/ds2
# T6iTA2QJgSAwjEiVHqTKRFq1niCL4WjmazcvTuQX2bVIQoEwTWbBjoGaLb4wggWN
# MIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK
# 2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/G
# nhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJ
# IB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4M
# K7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN
# 2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I
# 11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KIS
# G2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9
# HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4
# pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpy
# FiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS31
# 2amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs
# 1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd
# 823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzAB
# hhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9j
# YWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQw
# RQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZI
# hvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4
# hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3
# rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs
# 9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K
# 2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0n
# ftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwgga0MIIEnKADAgECAhANx6xX
# Bf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAf
# BgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBa
# Fw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2Vy
# dCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBp
# bmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1D
# ahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn
# 5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLux
# BG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3I
# fDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cV
# FBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQ
# T/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gby
# lsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rK
# WDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6
# z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9Vne
# Ps6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQAB
# o4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6
# yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYD
# VR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGsw
# aTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUF
# BzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeB
# DAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2
# cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe3
# 6zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMD
# PjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2
# AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410
# ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47O
# vgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39
# OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9v
# ODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3
# s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5
# TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXK
# UjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC0cR2
# p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0
# YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAwMFoX
# DTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1lc3Rh
# bXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA69HF
# TBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6wW2R6
# kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00Cll8
# pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOMA3Co
# B/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmotuQhc
# g9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1Opbyb
# pMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeHVZlc
# 4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1roSrg
# HjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSUROwnu7
# zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+giAwW00aHz
# rDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGVMIIB
# kTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM6DAf
# BgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMCB4Aw
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKGUWh0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVT
# dGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSgUqBQ
# hk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1l
# U3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAIBgZn
# gQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcEua5g
# QezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/YmRDfx
# T7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8AQ/U
# dKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/EABgf
# ZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQVTeL
# ni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gVutDo
# jBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85EE8L
# UkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hggt8l
# 2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJgKf4
# 7CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLvUxxV
# ZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7POGT7
# 5qaL6vdCvHlshtjdNXOCIUjsarfNZzGCBQgwggUEAgEBMD0wKTEUMBIGA1UECgwL
# WW91ckNvbXBhbnkxETAPBgNVBAMMCFlvdXJOYW1lAhBKtAoLm+UZpkJSkesmQiwx
# MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3
# DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEV
# MCMGCSqGSIb3DQEJBDEWBBR+ZEluwtwAg/g8pQdvRe/h8Cqc0DANBgkqhkiG9w0B
# AQEFAASCAQBXigtmiDLs036idHSciVMBHNa1baboPW+9R0ioIR7mA5Ur5XUgKmIS
# 6mGp6ICyw5QfNGRmLHCIc41WaKJ3/4CCNT8aKaHpH+QnMXWXOvSGZV6fFLM8C841
# +Wzgj+zEYkXyZOVraxqSBcU5+UTCdth0R6O5CfKGEabJ3OUXPfAcu4lNwCkTccWA
# ti/SvdMAXYVAG05wcWuUGj2xJznKr0fv78QZZSxFvTiOHTj23Pjhjozj/4AGAhUO
# d4Mh5SpQx8t720J/F9l0Hk/wGriT3dO6EblIMQKExFNGLNdamm+rtCi9611zH6lX
# Ux+c7yrn/RIdRrLp+Z3+zRs5k2wp3kO9oYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMw
# ggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0
# MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTI1MDkwMzEwNDYxMlowLwYJKoZIhvcNAQkEMSIEIOfQry+jf7w4qa9lquv8vWO9
# 6qGJJAmP74OAnxgJIzHlMA0GCSqGSIb3DQEBAQUABIICAE0/cGu7vRQrlYvCAo54
# WbxDQ7fIA3u0IQZ1XVCfaoyZQ090QwO41o8QYd2eHS82eYv7GW3D+5bnhNeCE0c3
# JxI06hrbHe/j3MOSv7z6/hovvwgyy39kvREbcbSg/Ore48VYtUULrEElSGeCa5xo
# rxEtIyTbf2XyumEX2TcTrd/OMaoOnhkDHF8+QlaInNhmWQ4hGdOGLb3d+lj5wRQg
# AdlFSQ345ejq4OuY0lemE9ASkbpE/1slnj4rcuXAwfwLNR2gipNtR8I7prVdTlI1
# 9340g9x2DBnMvML0zYBB35RDZuZb8jxskeClBJpnRMuqNbMgdJ7W+eJHGOmtFQDW
# MevD4UYjsk0zfko3ulY+9tt1+Yf5Psg8eyZe1Qc1/lxz8hH07ZFf3wuBBqm5yauL
# MnJMq9NYUIQXPxnBGHFFAw17G2QVuDQiNiq+INW1SIT0mY1796UcGGTHwq+95hNJ
# KocWubERFViJGxvoFYbYiisIE0hnE/jl0f4AOx6FMTgWN67+b+Egmnjju2xrKjbr
# BiRodHNvYkhPys0JEPkxgxFgeYAs9QwwTjB3mRLTSTMLOiwYvRd047hYZaWM5iPi
# a62F1lQHvpdULmJ2mh6K3k1R+wK/eU6FzTAmGL3WOPaG48u90ICG0CROwVjr2XbG
# ve0WqhmMVIpJZewWxJI3yqQ5
# SIG # End signature block
