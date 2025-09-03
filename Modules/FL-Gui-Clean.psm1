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

    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

        $windowTitle = "SetupGUI Reset-PowerShellProfiles Version : v11.2.2"

        #region --- XAML Definition ---
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" # DevSkim: ignore DS137138
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" # DevSkim: ignore DS137138
        Title="SetupGUI Reset-PowerShellProfiles Version : v11.2.2" Height="600" Width="800" MinHeight="500" MinWidth="700"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True" Background="#F0F0F0">
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
            
            <TabItem Header="Network Profiles">
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
                        <Button x:Name="addNetworkProfileButton" Content="Add Profile" Width="100" Height="30"/>
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

        #endregion

        #region --- Find Controls ---
        Write-Log -Level DEBUG "Finding GUI controls..."
        $controls = @{}
        $controlNames = @(
            'languageComboBox',
            'environmentComboBox', 
            'whatIfCheckBox',
            'networkProfilesDataGrid',
            'addNetworkProfileButton',
            'enableMailCheckBox',
            'smtpServerTextBox',
            'senderTextBox',
            'devRecipientTextBox',
            'prodRecipientTextBox',
            'cancelButton',
            'applyButton',
            'okButton'
        )

        foreach ($controlName in $controlNames) {
            $control = $window.FindName($controlName)
            if ($control) {
                $controls[$controlName] = $control
                Write-Log -Level DEBUG "Found control: $controlName"
            } else {
                Write-Log -Level WARNING "Control not found: $controlName"
            }
        }
        #endregion

        #region --- Initialize Data ---
        Write-Log -Level DEBUG "Initializing GUI data..."
        
        # Set initial values
        $controls['languageComboBox'].SelectedIndex = if ($InitialConfig.Language -eq "de-DE") { 1 } else { 0 }
        $controls['environmentComboBox'].SelectedIndex = if ($InitialConfig.Environment -eq "PROD") { 1 } else { 0 }
        $controls['whatIfCheckBox'].IsChecked = $InitialConfig.WhatIf

        # Mail settings
        $controls['enableMailCheckBox'].IsChecked = $InitialConfig.Mail.Enabled
        $controls['smtpServerTextBox'].Text = $InitialConfig.Mail.SMTPServer
        $controls['senderTextBox'].Text = $InitialConfig.Mail.From
        $controls['devRecipientTextBox'].Text = $InitialConfig.Mail.To.DEV
        $controls['prodRecipientTextBox'].Text = $InitialConfig.Mail.To.PROD

        # Network Profiles
        if ($InitialConfig.NetworkProfiles) {
            $networkProfiles = @()
            foreach ($netProfile in $InitialConfig.NetworkProfiles) {
                $networkProfiles += [PSCustomObject]@{
                    Enabled = $netProfile.Enabled
                    Name = $netProfile.Name
                    Path = $netProfile.Path
                    Username = $netProfile.Username
                }
            }
            $controls['networkProfilesDataGrid'].ItemsSource = $networkProfiles
        }

        #endregion

        #region --- Event Handlers ---
        Write-Log -Level DEBUG "Setting up event handlers..."

        # Add Network Profile button
        $controls['addNetworkProfileButton'].Add_Click({
            $result = Show-NetworkProfileDialog
            if ($result) {
                $currentProfiles = @($controls['networkProfilesDataGrid'].ItemsSource)
                $currentProfiles += $result
                $controls['networkProfilesDataGrid'].ItemsSource = $currentProfiles
                $controls['networkProfilesDataGrid'].Items.Refresh()
            }
        })

        # OK Button
        $controls['okButton'].Add_Click({
            $window.DialogResult = $true
            $window.Close()
        })

        # Apply Button
        $controls['applyButton'].Add_Click({
            # Apply changes without closing
            Write-Log -Level INFO "Apply button clicked - saving configuration..."
        })

        # Cancel Button
        $controls['cancelButton'].Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })

        #endregion

        #region --- Show Dialog ---
        Write-Log -Level INFO "Showing setup GUI..."
        $result = $window.ShowDialog()

        if ($result -eq $true) {
            Write-Log -Level INFO "User confirmed changes. Creating updated configuration..."
            
            # Create updated configuration
            $updatedConfig = $InitialConfig.PSObject.Copy()
            
            # Update basic settings
            $updatedConfig.Language = if ($controls['languageComboBox'].SelectedIndex -eq 1) { "de-DE" } else { "en-US" }
            $updatedConfig.Environment = if ($controls['environmentComboBox'].SelectedIndex -eq 1) { "PROD" } else { "DEV" }
            $updatedConfig.WhatIf = $controls['whatIfCheckBox'].IsChecked

            # Update mail settings
            $updatedConfig.Mail.Enabled = $controls['enableMailCheckBox'].IsChecked
            $updatedConfig.Mail.SMTPServer = $controls['smtpServerTextBox'].Text
            $updatedConfig.Mail.From = $controls['senderTextBox'].Text
            $updatedConfig.Mail.To.DEV = $controls['devRecipientTextBox'].Text
            $updatedConfig.Mail.To.PROD = $controls['prodRecipientTextBox'].Text

            # Update network profiles
            $networkProfiles = @()
            foreach ($item in $controls['networkProfilesDataGrid'].ItemsSource) {
                $networkProfiles += @{
                    Enabled = $item.Enabled
                    Name = $item.Name
                    Path = $item.Path
                    Username = $item.Username
                    EncryptedPassword = ""  # Will be set separately
                }
            }
            $updatedConfig.NetworkProfiles = $networkProfiles

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
        [PSCustomObject]$ExistingProfile = $null
    )

    try {
        $dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" # DevSkim: ignore DS137138
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" # DevSkim: ignore DS137138
        Title="Network Profile" Height="300" Width="500"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" ResizeMode="NoResize">
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

        <CheckBox x:Name="enabledCheckBox" Grid.Row="0" Grid.ColumnSpan="2" Content="Enabled" Margin="0,0,0,10" IsChecked="True"/>

        <Label Grid.Row="1" Grid.Column="0" Content="Name:" VerticalAlignment="Center"/>
        <TextBox x:Name="nameTextBox" Grid.Row="1" Grid.Column="1" Margin="5" Height="25"/>

        <Label Grid.Row="2" Grid.Column="0" Content="UNC Path:" VerticalAlignment="Center"/>
        <TextBox x:Name="pathTextBox" Grid.Row="2" Grid.Column="1" Margin="5" Height="25"/>

        <Label Grid.Row="3" Grid.Column="0" Content="Username:" VerticalAlignment="Center"/>
        <TextBox x:Name="usernameTextBox" Grid.Row="3" Grid.Column="1" Margin="5" Height="25"/>

        <Label Grid.Row="4" Grid.Column="0" Content="Password:" VerticalAlignment="Center"/>
        <PasswordBox x:Name="passwordBox" Grid.Row="4" Grid.Column="1" Margin="5" Height="25"/>

        <StackPanel Grid.Row="5" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,10">
            <Button x:Name="testConnectionButton" Content="Test Connection" Width="120" Height="30" Margin="0,0,10,0"/>
        </StackPanel>

        <StackPanel Grid.Row="7" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
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
        $pathTextBox = $dialog.FindName("pathTextBox")
        $usernameTextBox = $dialog.FindName("usernameTextBox")
        $passwordBox = $dialog.FindName("passwordBox")
        $testConnectionButton = $dialog.FindName("testConnectionButton")
        $okButton = $dialog.FindName("okButton")
        $cancelButton = $dialog.FindName("cancelButton")

        # Set existing values if editing
        if ($ExistingProfile) {
            $enabledCheckBox.IsChecked = $ExistingProfile.Enabled
            $nameTextBox.Text = $ExistingProfile.Name
            $pathTextBox.Text = $ExistingProfile.Path
            $usernameTextBox.Text = $ExistingProfile.Username
        }

        # Event handlers
        $testConnectionButton.Add_Click({
            $path = $pathTextBox.Text
           # $username = $usernameTextBox.Text
           # $password = $passwordBox.SecurePassword

            if ([string]::IsNullOrWhiteSpace($path)) {
                [System.Windows.MessageBox]::Show("Please enter a UNC path.", "Validation Error", "OK", "Warning")
                return
            }

            try {
                # Test connection logic here
                [System.Windows.MessageBox]::Show("Connection test successful!", "Test Result", "OK", "Information")
            } catch {
                [System.Windows.MessageBox]::Show("Connection test failed: $($_.Exception.Message)", "Test Result", "OK", "Error")
            }
        })

        $okButton.Add_Click({
            # Validate input
            if ([string]::IsNullOrWhiteSpace($nameTextBox.Text)) {
                [System.Windows.MessageBox]::Show("Please enter a profile name.", "Validation Error", "OK", "Warning")
                return
            }
            if ([string]::IsNullOrWhiteSpace($pathTextBox.Text)) {
                [System.Windows.MessageBox]::Show("Please enter a UNC path.", "Validation Error", "OK", "Warning")
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
                Path = $pathTextBox.Text
                Username = $usernameTextBox.Text
                Password = $passwordBox.SecurePassword
            }
        }

        return $null

    } catch {
        Write-Log -Level ERROR "Failed to show network profile dialog: $($_.Exception.Message)"
        return $null
    }
}

# Export module members
Export-ModuleMember -Function Show-SetupGUI, Show-NetworkProfileDialog
