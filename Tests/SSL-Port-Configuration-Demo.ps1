# SSL-Port-Configuration-Demo.ps1
# Demonstration der SSL-Port-Konfiguration
# Author: Flecki Garnreiter
# Version: v1.0.0
# Date: 2025.09.04

Add-Type -AssemblyName PresentationFramework

# Aktuelle Konfiguration laden
$ConfigPath = "f:\DEV\repositories\CertSurv\Config\Config-Cert-Surveillance.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

Write-Host "=== SSL-Port-Konfiguration Demo ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Aktuelle Konfiguration:" -ForegroundColor Yellow
Write-Host "Standard-Port: $($Config.Certificate.Port)" -ForegroundColor Green
Write-Host "Auto-Port-Detection: $($Config.Certificate.EnableAutoPortDetection)" -ForegroundColor Green
Write-Host "SSL-Ports: $($Config.Certificate.CommonSSLPorts -join ', ')" -ForegroundColor Green
Write-Host ""

# Einfache GUI für Port-Konfiguration
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="SSL-Port-Konfiguration" Height="400" Width="600" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="SSL-Port-Konfiguration / SSL Port Configuration" 
                   FontSize="16" FontWeight="Bold" Margin="0,0,0,20" HorizontalAlignment="Center"/>
        
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,5">
            <Label Content="Standard-Port:" Width="150"/>
            <TextBox Name="StandardPortBox" Width="100" Text="443"/>
        </StackPanel>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,5">
            <Label Content="Auto-Port-Detection:" Width="150"/>
            <CheckBox Name="AutoPortCheckBox" IsChecked="True" VerticalAlignment="Center"/>
        </StackPanel>
        
        <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,5">
            <Label Content="SSL-Ports (komma-getrennt):" Width="150"/>
            <TextBox Name="SSLPortsBox" Width="300" Text="443,9443,8443,4443,10443,8080,8081"/>
        </StackPanel>
        
        <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,5">
            <Label Content="Timeout (ms):" Width="150"/>
            <TextBox Name="TimeoutBox" Width="100" Text="10000"/>
        </StackPanel>
        
        <StackPanel Grid.Row="5" Orientation="Horizontal" Margin="0,5">
            <Label Content="Methode:" Width="150"/>
            <ComboBox Name="MethodBox" Width="150" SelectedIndex="1">
                <ComboBoxItem Content="Socket"/>
                <ComboBoxItem Content="Browser"/>
            </ComboBox>
        </StackPanel>
        
        <Separator Grid.Row="6" Margin="0,15"/>
        
        <TextBlock Grid.Row="7" Text="Test-Server:" FontWeight="Bold" Margin="0,10,0,5"/>
        <StackPanel Grid.Row="8" Orientation="Horizontal" Margin="0,5">
            <Label Content="Server:" Width="150"/>
            <TextBox Name="TestServerBox" Width="200" Text="www.google.com"/>
            <Button Name="TestButton" Content="Test Ports" Width="100" Margin="10,0,0,0"/>
        </StackPanel>
        
        <StackPanel Grid.Row="9" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button Name="SaveButton" Content="Speichern" Width="100" Margin="0,0,10,0"/>
            <Button Name="CancelButton" Content="Abbrechen" Width="100"/>
        </StackPanel>
    </Grid>
</Window>
"@

try {
    $reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    # Controls abrufen
    $standardPortBox = $window.FindName("StandardPortBox")
    $autoPortCheckBox = $window.FindName("AutoPortCheckBox")
    $sslPortsBox = $window.FindName("SSLPortsBox")
    $timeoutBox = $window.FindName("TimeoutBox")
    $methodBox = $window.FindName("MethodBox")
    $testServerBox = $window.FindName("TestServerBox")
    $testButton = $window.FindName("TestButton")
    $saveButton = $window.FindName("SaveButton")
    $cancelButton = $window.FindName("CancelButton")
    
    # Aktuelle Werte laden
    $standardPortBox.Text = $Config.Certificate.Port.ToString()
    $autoPortCheckBox.IsChecked = $Config.Certificate.EnableAutoPortDetection
    $sslPortsBox.Text = ($Config.Certificate.CommonSSLPorts -join ',')
    $timeoutBox.Text = $Config.Certificate.Timeout.ToString()
    $methodBox.Text = $Config.Certificate.Method
    
    # Test Button Event
    $testButton.Add_Click({
        try {
            $testServer = $testServerBox.Text
            $testPorts = $sslPortsBox.Text -split ',' | ForEach-Object { [int]$_.Trim() }
            $timeout = [int]$timeoutBox.Text
            $method = $methodBox.Text
            
            Write-Host ""
            Write-Host "Testing SSL ports for $testServer..." -ForegroundColor Cyan
            
            foreach ($port in $testPorts) {
                Write-Host "Testing port $port..." -NoNewline
                
                try {
                    if ($method -eq "Browser") {
                        $url = if ($port -eq 443) { "https://$testServer" } else { "https://${testServer}:$port" }
                        $request = [System.Net.HttpWebRequest]::Create($url)
                        $request.Method = "HEAD"
                        $request.Timeout = $timeout
                        $response = $request.GetResponse()
                        $response.Close()
                        Write-Host " ✓ OK" -ForegroundColor Green
                    } else {
                        $tcpClient = New-Object System.Net.Sockets.TcpClient
                        $tcpClient.ReceiveTimeout = $timeout
                        $tcpClient.SendTimeout = $timeout
                        $connectTask = $tcpClient.ConnectAsync($testServer, $port)
                        if ($connectTask.Wait($timeout)) {
                            $tcpClient.Close()
                            Write-Host " ✓ OK" -ForegroundColor Green
                        } else {
                            Write-Host " ✗ Timeout" -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Host " ✗ Failed" -ForegroundColor Red
                }
            }
        } catch {
            [System.Windows.MessageBox]::Show("Test error: $($_.Exception.Message)", "Error", "OK", "Error")
        }
    })
    
    # Save Button Event
    $saveButton.Add_Click({
        try {
            # Konfiguration aktualisieren
            $Config.Certificate.Port = [int]$standardPortBox.Text
            $Config.Certificate.EnableAutoPortDetection = $autoPortCheckBox.IsChecked
            $Config.Certificate.CommonSSLPorts = ($sslPortsBox.Text -split ',' | ForEach-Object { [int]$_.Trim() })
            $Config.Certificate.Timeout = [int]$timeoutBox.Text
            $Config.Certificate.Method = $methodBox.Text
            
            # Speichern
            $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            
            [System.Windows.MessageBox]::Show("Konfiguration gespeichert!", "Erfolg", "OK", "Information")
            $window.Close()
        } catch {
            [System.Windows.MessageBox]::Show("Fehler beim Speichern: $($_.Exception.Message)", "Fehler", "OK", "Error")
        }
    })
    
    # Cancel Button Event
    $cancelButton.Add_Click({
        $window.Close()
    })
    
    # GUI anzeigen
    Write-Host "SSL-Port-Konfiguration GUI wird geöffnet..." -ForegroundColor Green
    $window.ShowDialog() | Out-Null
    
} catch {
    Write-Error "GUI Error: $($_.Exception.Message)"
}
