<#
.SYNOPSIS
    Mass Deploy CertWebService from Excel - PowerShell 5.1 Compatible
.DESCRIPTION
    Reads Windows server list from Excel and deploys CertWebService to all servers.
    - Automatic credential management via FL-CredentialManager
    - Progress tracking and comprehensive reporting
    - Parallel deployment support
.NOTES
    Encoding: ASCII (PowerShell 5.1 compatible)
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExcelPath = "\\itscmgmt03.srv.meduniwien.ac.at\iso\WIndowsServerListe\Serverliste2025.xlsx",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerFilter = "*"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$BaseDomain = "meduniwien.ac.at"
$DefaultWorkgroupSegment = "srv"
$TempDir = "$env:TEMP\CertWebServiceDeploy"
$ServerListCacheFile = "$TempDir\ServerList_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

# Ensure temp directory exists
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

# Import credential manager
$CredManagerPath = Join-Path $ScriptDir "Modules\FL-CredentialManager.psm1"
if (Test-Path $CredManagerPath) {
    Import-Module $CredManagerPath -Force
    Write-Host "[OK] Credential manager loaded" -ForegroundColor Green
} else {
    Write-Warning "FL-CredentialManager.psm1 not found - credential features disabled"
}

# Import fast processing module (CrossUse from CertSurv)
$CertSurvPath = Split-Path -Parent $ScriptDir
$FastProcessingPath = Join-Path $CertSurvPath "CertSurv\Modules\FL-FastServerProcessing.psm1"
if (Test-Path $FastProcessingPath) {
    Import-Module $FastProcessingPath -Force
    Write-Host "[OK] Fast processing module loaded (CrossUse from CertSurv)" -ForegroundColor Green
} else {
    Write-Warning "FL-FastServerProcessing.psm1 not found in CertSurv - using standard processing"
}

# Samba credential management function with domain/workgroup defaults
function Get-SambaCredential {
    param(
        [string]$ServerName,
        [string]$ServerType = "Workgroup"  # "Domain" or "Workgroup"
    )
    
    # First try server-specific credential
    $serverCredName = "SAMBA_$ServerName"
    try {
        $storedCred = FL-CredentialManager\Get-StoredCredential -Target $serverCredName -ErrorAction SilentlyContinue
        if ($storedCred) {
            Write-Host "Using stored server-specific Samba credentials for $ServerName" -ForegroundColor Green
            return $storedCred
        }
    } catch { }
    
    # Try default credential based on server type
    $defaultCredName = if ($ServerType -eq "Domain") { "SAMBA_DEFAULT_DOMAIN" } else { "SAMBA_DEFAULT_WORKGROUP" }
    try {
        $defaultCred = FL-CredentialManager\Get-StoredCredential -Target $defaultCredName -ErrorAction SilentlyContinue
        if ($defaultCred) {
            Write-Host "Using default $ServerType Samba credentials for $ServerName" -ForegroundColor Cyan
            return $defaultCred
        }
    } catch { }
    
    # No stored credentials found - prompt for default first
    Write-Host "No Samba credentials found for $ServerName" -ForegroundColor Yellow
    $choice = Read-Host "Use (D)efault $ServerType credential or (S)erver-specific credential? [D/S]"
    
    if ($choice -match '^[Ss]') {
        # Store server-specific credential
        $cred = Get-Credential -Message "Enter server-specific Samba credentials for $ServerName"
        if ($cred) {
            try {
                Save-SecureCredential -TargetName $serverCredName -Credential $cred -ErrorAction Stop
                Write-Host "Server-specific Samba credentials stored" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to store server-specific credentials: $($_.Exception.Message)"
            }
            return $cred
        }
    } else {
        # Store default credential
        $cred = Get-Credential -Message "Enter default $ServerType Samba credentials (Administrator)"
        if ($cred) {
            try {
                Save-SecureCredential -TargetName $defaultCredName -Credential $cred -ErrorAction Stop
                Write-Host "Default $ServerType Samba credentials stored" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to store default credentials: $($_.Exception.Message)"
            }
            return $cred
        }
    }
    
    return $null
}

# Function to test Samba credential and fallback to server-specific if default fails
function Test-SambaCredentialWithFallback {
    param(
        [string]$ServerName,
        [string]$ServerType = "Workgroup"
    )
    
    # Get initial credential (default or server-specific)
    $cred = Get-SambaCredential -ServerName $ServerName -ServerType $ServerType
    if (-not $cred) {
        return $null
    }
    
    # Test the credential by trying to access the server
    $testPath = "\\$ServerName\C$"
    try {
        # Try to access with current credential
        $networkDrive = New-Object -ComObject WScript.Network
        $networkDrive.MapNetworkDrive("Z:", $testPath, $false, $cred.UserName, $cred.GetNetworkCredential().Password)
        $networkDrive.RemoveNetworkDrive("Z:", $true)
        
        Write-Host "Samba credentials verified for $ServerName" -ForegroundColor Green
        return $cred
    } catch {
        Write-Warning "Default credentials failed for $ServerName. Requesting server-specific credentials."
        
        # If we used default and it failed, try server-specific
        $defaultCredName = if ($ServerType -eq "Domain") { "SAMBA_DEFAULT_DOMAIN" } else { "SAMBA_DEFAULT_WORKGROUP" }
        $usedDefault = (Get-SecureCredential -TargetName $defaultCredName -ErrorAction SilentlyContinue) -ne $null
        
        if ($usedDefault) {
            # Prompt for server-specific credential
            $serverCred = Get-Credential -Message "Enter server-specific Samba credentials for $ServerName (default failed)"
            if ($serverCred) {
                try {
                    Save-SecureCredential -TargetName "SAMBA_$ServerName" -Credential $serverCred -ErrorAction Stop
                    Write-Host "Server-specific Samba credentials stored for $ServerName" -ForegroundColor Green
                    return $serverCred
                } catch {
                    Write-Warning "Failed to store server-specific credentials: $($_.Exception.Message)"
                    return $serverCred
                }
            }
        }
        
        return $null
    }
}

#region Helper Functions

function Write-Result {
    param(
        [string]$Message,
        [ValidateSet("OK", "ERROR", "SKIP", "RUN", "INFO")]
        [string]$Status = "INFO"
    )
    
    $colors = @{
        "OK"    = "Green"
        "ERROR" = "Red"
        "SKIP"  = "Yellow"
        "RUN"   = "Cyan"
        "INFO"  = "White"
    }
    
    Write-Host "[$Status] $Message" -ForegroundColor $colors[$Status]
}

function Read-ExcelFile {
    param(
        [string]$Path
    )
    
    Write-Result "Reading Excel file: $Path" -Status "RUN"
    
    # Try ImportExcel module first with intelligent header detection
    if (Get-Module -ListAvailable -Name ImportExcel) {
        try {
            Import-Module ImportExcel -ErrorAction Stop
            
            # Intelligent header detection (test rows 1-5)
            $excelData = $null
            $headerRowFound = 1
            
            for ($testRow = 1; $testRow -le 5; $testRow++) {
                try {
                    $testData = Import-Excel -Path $Path -StartRow $testRow -ErrorAction Stop
                    
                    if ($testData -and $testData.Count -gt 0) {
                        $sampleRow = $testData[0]
                        $columnNames = $sampleRow.PSObject.Properties.Name
                        
                        # Check if we have expected columns (ServerName and OS_Name)
                        if (($columnNames -contains "ServerName") -and ($columnNames -contains "OS_Name")) {
                            $excelData = $testData
                            $headerRowFound = $testRow
                            Write-Result "Detected valid header row $testRow with ServerName and OS_Name columns" -Status "OK"
                            break
                        }
                    }
                } catch {
                    continue
                }
            }
            
            if (-not $excelData) {
                throw "Could not find valid header row with ServerName and OS_Name columns"
            }
            
            Write-Result "Excel file loaded via ImportExcel module (Rows: $($excelData.Count), Header Row: $headerRowFound)" -Status "OK"
            return [PSCustomObject]@{
                Data = $excelData
                HeaderRow = $headerRowFound
            }
        } catch {
            Write-Result "ImportExcel module failed: $($_.Exception.Message)" -Status "ERROR"
        }
    }
    
    # Fallback to COM object
    Write-Result "Using Excel COM object fallback" -Status "INFO"
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        $workbook = $excel.Workbooks.Open($Path)
        $worksheet = $workbook.Worksheets.Item(1)
        
        $usedRange = $worksheet.UsedRange
        $rowCount = $usedRange.Rows.Count
        $colCount = $usedRange.Columns.Count
        
        # Detect header row by finding header text
        $headerRowFound = 2
        for ($row = 1; $row -le [Math]::Min(5, $rowCount); $row++) {
            $cellText = $worksheet.Cells.Item($row, 1).Text
            if ($cellText -eq "ServerName") {
                $headerRowFound = $row
                break
            }
        }

        # Read header row
        $headers = @()
        for ($col = 1; $col -le $colCount; $col++) {
            $header = $worksheet.Cells.Item($headerRowFound, $col).Text
            if ($header) {
                $headers += $header
            }
        }
        
        # Read data rows
        $data = @()
        for ($row = $headerRowFound + 1; $row -le $rowCount; $row++) {
            $rowData = @{}
            for ($col = 1; $col -le $colCount; $col++) {
                $rowData[$headers[$col - 1]] = $worksheet.Cells.Item($row, $col).Text
            }
            $data += [PSCustomObject]$rowData
        }
        
        $workbook.Close($false)
        $excel.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        
        Write-Result "Excel file loaded via COM object (Rows: $($data.Count), Header Row: $headerRowFound)" -Status "OK"
        return [PSCustomObject]@{
            Data = $data
            HeaderRow = $headerRowFound
        }
    } catch {
        throw "Failed to read Excel file: $($_.Exception.Message)"
    }
}

function Get-ExcelServerMetadata {
    param(
        [string]$Path,
        [int]$HeaderRow
    )

    $metadata = @{}
    $currentSegment = $DefaultWorkgroupSegment
    $currentType = "Workgroup"

    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Open($Path)
        $worksheet = $workbook.Worksheets.Item(1)

        $totalRows = $worksheet.UsedRange.Rows.Count

        for ($row = 1; $row -le $totalRows; $row++) {
            $cell = $worksheet.Cells.Item($row, 1)
            $text = ($cell.Text).Trim()

            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            # Detect domain/workgroup headers: (DOMAIN)segment, (WORKGROUP)segment, and special cases like (Domain-ADsync)syncad
            $domainMatch = [regex]::Match($text, '^\(Domain(?:-[\w]+)?\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $workgroupMatch = [regex]::Match($text, '^\(Workgroup\)([\w-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

            if ($domainMatch.Success) {
                $currentSegment = $domainMatch.Groups[1].Value.ToLower()
                $currentType = "Domain"
                continue
            }

            if ($workgroupMatch.Success) {
                $currentSegment = $workgroupMatch.Groups[1].Value.ToLower()
                $currentType = "Workgroup"
                continue
            }

            if ($text -match '^SUMME:?$') {
                $currentSegment = $DefaultWorkgroupSegment
                $currentType = "Workgroup"
                continue
            }

            if ($row -le $HeaderRow) { continue }

            $metadata[$text] = [PSCustomObject]@{
                IsStrikethrough = [bool]$cell.Font.Strikethrough
                DomainSegment = $currentSegment
                IsDomain = ($currentType -eq "Domain")
            }
        }

        $workbook.Close($false)
        $excel.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
    } catch {
        Write-Result "Metadata extraction failed: $($_.Exception.Message)" -Status "ERROR"
    }

    return $metadata
}

function ConvertTo-IpAddress {
    param(
        [string]$IpValue
    )

    if ([string]::IsNullOrWhiteSpace($IpValue)) {
        return $null
    }

    $trimmed = $IpValue.Trim()

    if ($trimmed -match '^(?:\d{1,3}\.){3}\d{1,3}$') {
        return $trimmed
    }

    if ($trimmed -match '^\d{12}$') {
        $octets = @(
            $trimmed.Substring(0, 3),
            $trimmed.Substring(3, 3),
            $trimmed.Substring(6, 3),
            $trimmed.Substring(9, 3)
        )

        return ($octets -join '.')
    }

    return $trimmed
}

function Get-ServerFqdnCandidates {
    param(
        [string]$ServerName,
        [string]$IpAddress,
        [pscustomobject]$Metadata
    )

    $cleanName = $ServerName.Trim()
    if ([string]::IsNullOrWhiteSpace($cleanName)) {
        return @()
    }

    $candidates = @()

    # CANDIDATE 1: DNS lookup from IP address
    if ($IpAddress) {
        try {
            $hostEntry = [System.Net.Dns]::GetHostEntry($IpAddress)
            if ($hostEntry.HostName) {
                $dnsName = $hostEntry.HostName.ToLower()
                if (-not $dnsName.EndsWith(".meduniwien.ac.at")) {
                    $dnsName = "$dnsName.meduniwien.ac.at"
                }
                $candidates += [PSCustomObject]@{ FQDN = $dnsName; Source = "DNS-Lookup"; Priority = 1 }
            }
        } catch {
            # ignore lookup failures
        }
    }

    # CANDIDATE 2: Server name with dots (if provided)
    if ($cleanName -match '\.') {
        $fqdn = $cleanName.ToLower()
        if (-not $fqdn.EndsWith(".meduniwien.ac.at")) {
            $fqdn = "$fqdn.meduniwien.ac.at"
        }
        $candidates += [PSCustomObject]@{ FQDN = $fqdn; Source = "Provided-Name"; Priority = 2 }
    }

    # CANDIDATE 3: Excel metadata segment
    if ($Metadata -and $Metadata.DomainSegment) {
        $segment = $Metadata.DomainSegment.ToLower()
        $fqdn = ("{0}.{1}.{2}" -f $cleanName.ToLower(), $segment, $BaseDomain)
        $candidates += [PSCustomObject]@{ FQDN = $fqdn; Source = "Excel-Metadata"; Priority = 3 }
    }

    # CANDIDATE 4: Default srv segment (fallback)
    $defaultFqdn = ("{0}.{1}.{2}" -f $cleanName.ToLower(), $DefaultWorkgroupSegment, $BaseDomain)
    $candidates += [PSCustomObject]@{ FQDN = $defaultFqdn; Source = "Default-SRV"; Priority = 4 }

    # Remove duplicates
    $uniqueCandidates = $candidates | Sort-Object FQDN -Unique
    
    return $uniqueCandidates
}

function Resolve-ServerFqdn {
    param(
        [string]$ServerName,
        [string]$IpAddress,
        [pscustomobject]$Metadata
    )

    $candidates = Get-ServerFqdnCandidates -ServerName $ServerName -IpAddress $IpAddress -Metadata $Metadata
    
    if ($candidates.Count -eq 0) {
        return $null
    }

    # Test each candidate and return the first reachable one
    foreach ($candidate in ($candidates | Sort-Object Priority)) {
        $connectivity = Test-ServerConnectivity -ServerName $candidate.FQDN
        if ($connectivity.IsReachable) {
            Write-Verbose "Selected FQDN: $($candidate.FQDN) (Source: $($candidate.Source), Priority: $($candidate.Priority))"
            return $candidate.FQDN
        }
    }

    # If no candidate is reachable, return the highest priority one
    $bestCandidate = $candidates | Sort-Object Priority | Select-Object -First 1
    Write-Verbose "No reachable FQDN found, using: $($bestCandidate.FQDN) (Source: $($bestCandidate.Source))"
    return $bestCandidate.FQDN
}

function Get-ActiveServerRecords {
    param(
        [array]$Data,
        [hashtable]$Metadata,
        [string]$Filter = "*"
    )

    Write-Result "Filtering Windows servers (Pattern: $Filter)" -Status "RUN"

    $activeServers = @()
    $processedServers = @{}
    $totalRows = $Data.Count
    $currentRow = 0

    foreach ($row in $Data) {
        $currentRow++
        
        # Update progress bar
        $percentComplete = [math]::Round(($currentRow / $totalRows) * 100, 1)
        Write-Progress -Activity "Processing Excel data" -Status "Row $currentRow of $totalRows ($percentComplete%)" -PercentComplete $percentComplete
        $serverNameRaw = $row.ServerName
        if ([string]::IsNullOrWhiteSpace($serverNameRaw)) { continue }
        $serverName = $serverNameRaw.Trim()
        if ($serverName -match '^\(Domain' -or $serverName -match '^\(Workgroup' -or $serverName -match '^SUMME:?$') { continue }
        $meta = if ($Metadata -and $Metadata.ContainsKey($serverName)) { $Metadata[$serverName] } else { $null }
        if ($meta -and $meta.IsStrikethrough) { continue }

        # Filter by OS column to Windows Servers
        if (-not ($row.OS_Name -match "Windows.*Server")) { continue }

    $ipAddress = ConvertTo-IpAddress -IpValue $row.'IP-Adresse'
    $fqdn = Resolve-ServerFqdn -ServerName $serverName -IpAddress $ipAddress -Metadata $meta

        if (-not $fqdn) { continue }

        if ($Filter -and $Filter -ne "*") {
            if (($serverName -notlike $Filter) -and ($fqdn -notlike $Filter)) {
                continue
            }
        }

        if ($processedServers.ContainsKey($serverName)) { continue }
        $processedServers[$serverName] = $true

        # Test connectivity to final FQDN
        Write-Progress -Activity "Processing Excel data" -Status "Testing connectivity for $fqdn ($currentRow of $totalRows)" -PercentComplete $percentComplete
        $connectivity = Test-ServerConnectivity -ServerName $fqdn

        # Determine server type based on metadata
        $serverType = "Workgroup"  # Default
        if ($meta -and $meta.Type -eq "Domain") {
            $serverType = "Domain"
        } elseif ($fqdn -match "\.uvw\.meduniwien\.ac\.at$") {
            $serverType = "Domain"
        }
        
        $activeServers += [PSCustomObject]@{
            ServerName = $serverName
            FQDN = $fqdn
            IPAddress = $ipAddress
            ServerType = $serverType
            IsReachable = $connectivity.IsReachable
            Connectivity = $connectivity
            Metadata = $meta
            Row = $row
        }
    }

    # Complete progress bar
    Write-Progress -Activity "Processing Excel data" -Completed
    
    Write-Result "Found $($activeServers.Count) Windows servers matching filter" -Status "OK"
    return $activeServers
}

function Test-ServerConnectivity {
    param(
        [string]$ServerName
    )
    
    $connectivity = [PSCustomObject]@{
        ServerName = $ServerName
        PingSuccess = $false
        Port80 = $false
        Port443 = $false
        Port9080 = $false
        Port9443 = $false
        SambaSuccess = $false
        IsReachable = $false
    }
    
    # Test normal ping (ICMP)
    try {
        $connectivity.PingSuccess = Test-Connection -ComputerName $ServerName -Count 1 -Quiet -ErrorAction SilentlyContinue
    } catch {
        $connectivity.PingSuccess = $false
    }
    
    # Test port connectivity
    $ports = @(80, 443, 9080, 9443)
    foreach ($port in $ports) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ServerName, $port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
            
            if ($wait) {
                try {
                    $tcpClient.EndConnect($connect)
                    $isOpen = $true
                } catch {
                    $isOpen = $false
                }
            } else {
                $isOpen = $false
            }
            
            $tcpClient.Close()
            
            switch ($port) {
                80 { $connectivity.Port80 = $isOpen }
                443 { $connectivity.Port443 = $isOpen }
                9080 { $connectivity.Port9080 = $isOpen }
                9443 { $connectivity.Port9443 = $isOpen }
            }
        } catch {
            # Port test failed, leave as false
        }
    }
    
    # Test Samba connectivity (SMB port 445)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($ServerName, 445, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
        
        if ($wait) {
            try {
                $tcpClient.EndConnect($connect)
                $connectivity.SambaSuccess = $true
            } catch {
                $connectivity.SambaSuccess = $false
            }
        } else {
            $connectivity.SambaSuccess = $false
        }
        
        $tcpClient.Close()
    } catch {
        $connectivity.SambaSuccess = $false
    }
    
    # Server is considered reachable if ping works OR any port is open OR Samba works
    $connectivity.IsReachable = $connectivity.PingSuccess -or $connectivity.Port80 -or $connectivity.Port443 -or $connectivity.Port9080 -or $connectivity.Port9443 -or $connectivity.SambaSuccess
    
    return $connectivity
}

function Deploy-ToServer {
    param(
        [pscustomobject]$ServerInfo,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    $deployScript = Join-Path $ScriptDir "Deploy-CertWebService.ps1"
    
    if (-not (Test-Path $deployScript)) {
        throw "Deploy-CertWebService.ps1 not found in $ScriptDir"
    }

    $targetServer = if ($ServerInfo.FQDN) { $ServerInfo.FQDN } else { $ServerInfo.ServerName }

    # Execute deployment
    $params = @{
        FilePath = "powershell.exe"
        ArgumentList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $deployScript,
            "-TargetServer", $targetServer
        )
        NoNewWindow = $true
        Wait = $true
        PassThru = $true
    }
    
    if ($Credential) {
        $params.Credential = $Credential
    }
    
    $process = Start-Process @params
    return $process.ExitCode -eq 0
}

#endregion

#region Main Execution

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CertWebService Mass Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate Excel file
if (-not (Test-Path $ExcelPath)) {
    Write-Result "Excel file not found: $ExcelPath" -Status "ERROR"
    exit 1
}

# Read server list
try {
    $excelInfo = Read-ExcelFile -Path $ExcelPath
    $excelData = $excelInfo.Data
    $headerRow = $excelInfo.HeaderRow

    $metadata = Get-ExcelServerMetadata -Path $ExcelPath -HeaderRow $headerRow
    
    # Phase 1: Fast server extraction without connectivity tests
    $cacheFile = "$TempDir\ServerList_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $serverListFast = Get-ServerListFast -Data $excelData -Metadata $metadata -Filter $ServerFilter
    
    if ($serverListFast.Count -eq 0) {
        Write-Result "No servers found matching filter: $ServerFilter" -Status "ERROR"
        exit 1
    }
    
    # Cache server list for potential reuse
    Save-ServerListCache -ServerList $serverListFast -CacheFile $cacheFile
    
    # Phase 2: Parallel connectivity testing
    $servers = Test-ServersConnectivityParallel -ServerList $serverListFast -MaxThreads 15
} catch {
    Write-Result "Failed to read server list: $($_.Exception.Message)" -Status "ERROR"
    exit 1
}

# Dry run mode
if ($DryRun) {
    Write-Host ""
    Write-Result "DRY RUN MODE - No deployment will be executed" -Status "INFO"
    Write-Host ""
    Write-Host "Servers to deploy ($($servers.Count)):" -ForegroundColor Yellow
    foreach ($server in $servers) {
        $ipInfo = if ($server.IPAddress) { " [$($server.IPAddress)]" } else { "" }
        $conn = $server.Connectivity
        
        Write-Host "  - $($server.ServerName) -> $($server.FQDN)$ipInfo ($($server.ServerType))" -ForegroundColor Gray
        
        # Show ping status
        $pingStatus = if ($conn.PingSuccess) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $pingColor = if ($conn.PingSuccess) { "Green" } else { "Red" }
        Write-Host "    PING: $pingStatus" -ForegroundColor $pingColor
        
        # Show individual port status
        $port80Status = if ($conn.Port80) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $port80Color = if ($conn.Port80) { "Green" } else { "Red" }
        Write-Host "    Port 80: $port80Status" -ForegroundColor $port80Color
        
        $port443Status = if ($conn.Port443) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $port443Color = if ($conn.Port443) { "Green" } else { "Red" }
        Write-Host "    Port 443: $port443Status" -ForegroundColor $port443Color
        
        $port9080Status = if ($conn.Port9080) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $port9080Color = if ($conn.Port9080) { "Green" } else { "Red" }
        Write-Host "    Port 9080: $port9080Status" -ForegroundColor $port9080Color
        
        $port9443Status = if ($conn.Port9443) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $port9443Color = if ($conn.Port9443) { "Green" } else { "Red" }
        Write-Host "    Port 9443: $port9443Status" -ForegroundColor $port9443Color
        
        # Show Samba status
        $sambaStatus = if ($conn.SambaSuccess) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $sambaColor = if ($conn.SambaSuccess) { "Green" } else { "Red" }
        Write-Host "    Samba (Port 445): $sambaStatus" -ForegroundColor $sambaColor
        
        # Collect Samba credentials if server is reachable
        if ($server.IsReachable -and $conn.SambaSuccess) {
            Write-Host "    Verifying Samba credentials..." -ForegroundColor Yellow
            $sambaCred = Test-SambaCredentialWithFallback -ServerName $server.FQDN -ServerType $server.ServerType
            if ($sambaCred) {
                Write-Host "    Samba credentials: OK" -ForegroundColor Green
            } else {
                Write-Host "    Samba credentials: FAILED" -ForegroundColor Red
            }
        }
        
        # Overall status
        $overallStatus = if ($server.IsReachable) { "ERREICHBAR" } else { "NICHT ERREICHBAR" }
        $overallColor = if ($server.IsReachable) { "Green" } else { "Red" }
        Write-Host "    Gesamt: $overallStatus" -ForegroundColor $overallColor
        
        Write-Host "" # Empty line between servers
    }
    Write-Host ""
    $onlineCount = ($servers | Where-Object { $_.IsReachable }).Count
    $offlineCount = $servers.Count - $onlineCount
    Write-Host "Connectivity Summary: $onlineCount online, $offlineCount offline" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Initialize deployment tracking
$results = @{
    Success = @()
    Failed = @()
    Skipped = @()
}

$totalServers = $servers.Count
$currentServer = 0

Write-Host ""
Write-Result "Starting deployment to $totalServers servers..." -Status "RUN"
Write-Host ""

# Deploy to each server
foreach ($server in $servers) {
    $currentServer++
    $percentComplete = [math]::Round(($currentServer / $totalServers) * 100)
    
    Write-Host "[$currentServer/$totalServers] $($server.ServerName) -> $($server.FQDN)" -ForegroundColor Cyan
    Write-Progress -Activity "Mass Deployment" -Status "Processing $($server.FQDN)" -PercentComplete $percentComplete
    
    # Test connectivity
    Write-Result "Testing connectivity..." -Status "RUN"
    $connTest = Test-ServerConnectivity -ServerName $server.FQDN
    if (-not $connTest.IsReachable) {
        Write-Result "Server unreachable - skipping" -Status "SKIP"
        $results.Skipped += $server
        Write-Host ""
        continue
    }
    
    # Show what connectivity methods worked
    $connMethods = @()
    if ($connTest.PingSuccess) { $connMethods += "PING" }
    if ($connTest.Port80) { $connMethods += "Port 80" }
    if ($connTest.Port443) { $connMethods += "Port 443" }
    if ($connTest.Port9080) { $connMethods += "Port 9080" }
    if ($connTest.Port9443) { $connMethods += "Port 9443" }
    
    Write-Result "Server online via: $($connMethods -join ', ')" -Status "OK"
    
    # Get credentials if available
    $cred = $null
    if (Get-Command Get-SecureCredential -ErrorAction SilentlyContinue) {
        try {
            $credTarget = if ($server.FQDN) { $server.FQDN } else { $server.ServerName }
            $cred = Get-SecureCredential -TargetName $credTarget -PromptIfNotFound -PromptMessage "Enter credentials for $credTarget"
            if ($cred) {
                Write-Result "Credentials ready for $credTarget" -Status "OK"
            }
        } catch {
            Write-Result "No stored credentials found - will attempt without" -Status "INFO"
        }
    }
    
    # Execute deployment
    Write-Result "Deploying CertWebService..." -Status "RUN"
    try {
        $success = Deploy-ToServer -ServerInfo $server -Credential $cred
        
        if ($success) {
            Write-Result "Deployment successful" -Status "OK"
            $results.Success += $server
        } else {
            Write-Result "Deployment failed" -Status "ERROR"
            $results.Failed += $server
        }
    } catch {
        Write-Result "Deployment error: $($_.Exception.Message)" -Status "ERROR"
        $results.Failed += $server
    }
    
    Write-Host ""
}

Write-Progress -Activity "Mass Deployment" -Completed

#endregion

#region Summary Report

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total Servers: $totalServers" -ForegroundColor White
Write-Host "  [OK]   Success: $($results.Success.Count)" -ForegroundColor Green
Write-Host "  [ERROR] Failed: $($results.Failed.Count)" -ForegroundColor Red
Write-Host "  [SKIP]  Skipped: $($results.Skipped.Count)" -ForegroundColor Yellow
Write-Host ""

if ($results.Failed.Count -gt 0) {
    Write-Host "Failed Servers:" -ForegroundColor Red
    foreach ($item in $results.Failed) {
        Write-Host "  - $($item.ServerName) -> $($item.FQDN)" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($results.Skipped.Count -gt 0) {
    Write-Host "Skipped Servers:" -ForegroundColor Yellow
    foreach ($item in $results.Skipped) {
        Write-Host "  - $($item.ServerName) -> $($item.FQDN)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Generate report file
$reportPath = Join-Path $ScriptDir "Deployment-Report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
$successLines = ($results.Success | ForEach-Object { "{0} -> {1}" -f $_.ServerName, $_.FQDN }) -join "`n"
$failedLines = ($results.Failed | ForEach-Object { "{0} -> {1}" -f $_.ServerName, $_.FQDN }) -join "`n"
$skippedLines = ($results.Skipped | ForEach-Object { "{0} -> {1}" -f $_.ServerName, $_.FQDN }) -join "`n"
$reportContent = @"
CertWebService Mass Deployment Report
======================================
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Excel Source: $ExcelPath
Server Filter: $ServerFilter

Summary
-------
Total Servers: $totalServers
Success: $($results.Success.Count)
Failed: $($results.Failed.Count)
Skipped: $($results.Skipped.Count)

Successful Deployments
----------------------
$successLines

Failed Deployments
------------------
$failedLines

Skipped Servers
---------------
$skippedLines
"@

$reportContent | Out-File -FilePath $reportPath -Encoding ASCII
Write-Result "Report saved: $reportPath" -Status "OK"

# Exit code based on results
# Cleanup temp files
Remove-ServerListCache -TempDir $TempDir

if ($results.Failed.Count -gt 0) {
    exit 1
} else {
    exit 0
}

#endregion
