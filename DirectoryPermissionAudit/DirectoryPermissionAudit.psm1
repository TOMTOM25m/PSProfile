# DirectoryPermissionAudit PowerShell Module
# Provides reusable functions for directory permission analysis.
# Follows Regelwerk v9.6.2

# Dot-source version / metadata & helper display + messaging functions
. (Join-Path $PSScriptRoot 'VERSION.ps1')

# Module scoped variables
$script:RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:LogDir = Join-Path -Path $PSScriptRoot -ChildPath 'LOG'
$script:ReportsDir = Join-Path -Path $script:LogDir -ChildPath 'Reports'
$script:ReportData = @()
$script:VZinfosGesamt = @()
$script:GroupMembershipCache = @{}
$script:UserCache = @{}
$script:ConfigPath = Join-Path (Join-Path $PSScriptRoot 'Config') 'DirectoryPermissionAudit.settings.psd1'
$script:Settings = @{}
if (Test-Path $script:ConfigPath) {
    try { $script:Settings = Import-PowerShellDataFile -Path $script:ConfigPath } catch { Write-Warning ("Failed to load settings file '{0}': {1}" -f $script:ConfigPath,$_.Exception.Message) }
}

foreach ($dir in @($script:LogDir, $script:ReportsDir)) {
    if (-not (Test-Path $dir)) {
        try {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        } catch {
            Write-Warning ("Failed to create directory '{0}': {1}" -f $dir, $_.Exception.Message)
        }
    }
}

#region Logging
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')][string]$Level = 'INFO',
        [string]$LogFile = $(Join-Path -Path $script:LogDir -ChildPath "DirectoryPermissionAudit_$script:RunId.log")
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) { 'INFO' {'White'} 'WARNING' {'Yellow'} 'ERROR' {'Red'} 'SUCCESS' {'Green'} Default {'White'} }
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logMessage
}
#endregion

#region Context
function Get-DomainContext {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    if ($env:COMPUTERNAME -eq $env:USERDOMAIN) { return $false } else { return $env:USERDOMAIN }
}
$script:IsDomainJoined = Get-DomainContext
#endregion

#region UI
function Show-FolderBrowserDialog {
    [CmdletBinding()] param(
        [string]$InitialDirectory = [Environment]::GetFolderPath('MyDocuments'),
        [string]$Description = 'Select folder to analyze permissions'
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = $Description
        $dlg.RootFolder = [System.Environment+SpecialFolder]::MyComputer
        $dlg.SelectedPath = $InitialDirectory
        if ($dlg.ShowDialog() -eq 'OK') { return $dlg.SelectedPath }
    } catch { Write-Log "Folder dialog error: $($_.Exception.Message)" -Level ERROR }
    finally { if ($dlg) { $dlg.Dispose() } }
}
#endregion

#region Group & User
function Get-GroupDetails {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$GroupName,[bool]$IsDomainContext = $script:IsDomainJoined)
    try { if ($IsDomainContext) { Get-ADGroup -Identity $GroupName -Properties * -ErrorAction SilentlyContinue } else { Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue } } catch { $null }
}
function Get-GroupMembership {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Group,[bool]$IsDomainContext = $script:IsDomainJoined)
    try { if ($IsDomainContext) { Get-ADGroupMember -Identity $Group -Recursive -ErrorAction SilentlyContinue } else { Get-LocalGroupMember -Group $Group -ErrorAction SilentlyContinue } } catch { @() }
}
function Get-UserDetails {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$UserId,[bool]$IsDomainContext = $script:IsDomainJoined)
    try {
        $userIdToUse = if ($UserId -like '*\\*') { ($UserId.Split('\\'))[1] } else { $UserId }
        if ($IsDomainContext) { Get-ADUser -Identity $userIdToUse -Properties * -ErrorAction SilentlyContinue } else { Get-LocalUser -Name $userIdToUse -ErrorAction SilentlyContinue }
    } catch { $null }
}
#endregion

#region Folder
function Get-FolderList {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$RootFolder,
        [int]$MaxDepth = 0,
        [switch]$IncludeHidden
    )
    try {
        $folderItems = if ($MaxDepth -gt 0) { Get-ChildItem -Directory -Path $RootFolder -Recurse -Depth $MaxDepth -ErrorAction Stop } else { Get-ChildItem -Directory -Path $RootFolder -ErrorAction Stop }
        if (-not $IncludeHidden) { $folderItems = $folderItems | Where-Object { $_.FullName -notlike '*\.*' } }
        return $folderItems
    } catch { Write-Log "Error getting folder list: $($_.Exception.Message)" -Level ERROR; @() }
}
#endregion

#region Report Export
function Export-ReportData {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][ValidateSet('CSV','JSON','Human','HTML','Excel')][string]$Format,
        [string]$OutputPath = $script:ReportsDir
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $folderName = Split-Path -Path $RootPath -Leaf
    $fileName = "$folderName-$timestamp"
    if (-not (Test-Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null }
    switch ($Format) {
        'CSV' { $outFile = Join-Path $OutputPath "$fileName.csv"; $script:ReportData | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8 }
        'JSON' { $outFile = Join-Path $OutputPath "$fileName.json"; $script:ReportData | ConvertTo-Json -Depth 5 | Out-File -FilePath $outFile -Encoding UTF8 }
        'Human' {
            $outFile = Join-Path $OutputPath "$fileName.txt"
            $line = '---------------------------------------------------------------------------------------'
            $star = '***************************************************************************************'
            $logContent = @($line, "Auswertung der Berechtigungstruktur für das $RootPath -Verzeichnis", $line)
            foreach ($item in $script:VZinfosGesamt) {
                $logContent += $line; $logContent += $item.Directory; $logContent += $line
                foreach ($gp in $item.GroupPermissions) {
                    $logContent += $star
                    $logContent += "BerechtigungsGruppe : $($gp.GroupName), Berechtigung: $($gp.GroupPermissions)"
                    $logContent += $star
                    $logContent += 'Berechtigte Mitarbeiter:'
                    $logContent += 'Name,FullName,User ist aktiv:'
                    $users = $item.UserPermissions | Where-Object { $_.GroupName -eq $gp.GroupName }
                    foreach ($u in $users) { $logContent += "$($u.Name),$($u.FullName),$($u.Aktiv)" }
                }
            }
            $logContent | Out-File -FilePath $outFile -Encoding UTF8
        }
        'HTML' {
            $outFile = Join-Path $OutputPath "$fileName.html"
            $grouped = $script:ReportData | Group-Object FolderPath
            $style = @"
<style>
body{font-family:Segoe UI,Arial;margin:14px;}
table{border-collapse:collapse;font-size:12px;min-width:900px;}
th,td{border:1px solid #ccc;padding:4px 6px;}
th{background:#003366;color:#fff;position:sticky;top:0;}
tr:nth-child(even){background:#f5f5f5;}
h2{color:#003366;margin-bottom:4px;}
h3{color:#003366;border-bottom:1px solid #ccc;padding-top:18px;}
.inactive{color:#888;}
.direct{background:#fff4ce;}
.legend span{display:inline-block;margin-right:14px;padding:4px 8px;border:1px solid #ccc;font-size:11px;border-radius:3px;}
.legend .inactive{background:#f2f2f2;}
.legend .direct{background:#fff4ce;}
.meta{font-size:11px;color:#444;margin-bottom:12px;}
footer{margin-top:24px;font-size:10px;color:#555;}
</style>
"@
            $summary = ($script:ReportData | Group-Object GroupName | Select-Object Name,Count | Sort-Object Count -Descending | Select-Object -First 10) | ConvertTo-Html -Fragment -PreContent '<h3>Top Gruppen (nach Einträgen)</h3>'
            $sectionFragments = foreach ($g in $grouped) {
                $rows = foreach ($entry in $g.Group) {
                    $cls = @()
                    if (-not $entry.IsActive) { $cls += 'inactive' }
                    if ($entry.GroupName -eq 'DirectPermission') { $cls += 'direct' }
                    $classAttr = if ($cls.Count) { " class='${($cls -join ' ')}'" } else { '' }
                    "<tr$classAttr><td>$($entry.FolderPath)</td><td>$($entry.GroupName)</td><td>$($entry.Permission)</td><td>$($entry.UserID)</td><td>$($entry.UserName)</td><td>$($entry.FullName)</td><td>$($entry.IsActive)</td></tr>"
                }
                $table = @('<table><thead><tr><th>FolderPath</th><th>Group</th><th>Permission</th><th>UserID</th><th>UserName</th><th>FullName</th><th>Active</th></tr></thead><tbody>') + $rows + '</tbody></table>' -join "`n"
                "<h3>$($g.Name)</h3>$table"
            }
            $bodyContent = @(
                '<h2>Directory Permission Audit Report</h2>',
                "<div class='meta'>Root: $RootPath<br/>Generated: $(Get-Date)</div>",
                "<div class='legend'><span class='inactive'>Inactive User</span><span class='direct'>Direct Permission</span></div>",
                $summary
            ) + $sectionFragments
            $html = @('<!DOCTYPE html><html><head><meta charset="UTF-8" />',$style,'<title>Directory Permission Audit</title></head><body>') + $bodyContent + '<footer>Generated by DirectoryPermissionAudit Module</footer></body></html>' -join "`n"
            $html | Out-File -FilePath $outFile -Encoding UTF8
        }
        'Excel' {
            $outFile = Join-Path $OutputPath "$fileName.xlsx"
            Write-Log 'Excel export selected: implementing basic CSV fallback (install ImportExcel module for native XLSX).' -Level WARNING
            $csvTemp = Join-Path $OutputPath "$fileName.temp.csv"
            $script:ReportData | Export-Csv -Path $csvTemp -NoTypeInformation -Encoding UTF8
            if (Get-Module -ListAvailable -Name ImportExcel) {
                try {
                    Import-Module ImportExcel -ErrorAction Stop
                    $script:ReportData | Export-Excel -Path $outFile -WorksheetName 'Permissions' -AutoSize -FreezeTopRow
                    Remove-Item $csvTemp -ErrorAction SilentlyContinue
                } catch { Write-Log "Failed native Excel export: $($_.Exception.Message) – keeping CSV fallback $csvTemp" -Level ERROR; $outFile = $csvTemp }
            } else { $outFile = $csvTemp }
        }
    }
    Write-Log "Report exported: $outFile" -Level SUCCESS
    return $outFile
}
#endregion

#region Core Analysis
function Invoke-DirectoryPermissionAnalysis {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$RootPath,
        [int]$MaxDepth = 0,
        [switch]$IncludeInherited,
        [switch]$IncludeSystemAccounts,
        [switch]$Parallel,
        [int]$Throttle = 5
    )
    Write-Log "Analyzing permissions for $RootPath" -Level INFO
    $folders = Get-FolderList -RootFolder $RootPath -MaxDepth $MaxDepth
    if (Test-Path -LiteralPath $RootPath) { $folders = ,(Get-Item -Path $RootPath) + $folders }
    $script:VZinfosGesamt = @()
    $script:ReportData = @()
    $total = $folders.Count; $i = 0
    $processFolder = {
        param($folder,$IncludeInherited,$IncludeSystemAccounts,$isDomain,$filters)
        if (-not (Test-Path -LiteralPath $folder.FullName -ErrorAction SilentlyContinue)) { return }
        try {
            $folderData = [PSCustomObject]@{ Directory = $folder.FullName; GroupPermissions = @(); UserPermissions = @() }
            $acl = Get-Acl -Path $folder.FullName -ErrorAction Stop
            $aclEntries = $acl.Access
            if (-not $IncludeInherited) { $aclEntries = $aclEntries | Where-Object { $_.PropagationFlags -like '*None*' } }
            if (-not $IncludeSystemAccounts) { foreach ($f in $filters) { $aclEntries = $aclEntries | Where-Object { $_.IdentityReference -notlike $f } } }
            $groupPermissions = foreach ($ace in $aclEntries) {
                $permission = switch -Wildcard ($ace.FileSystemRights) {
                    'FullControl*' { 'Lesen/Schreiben/Löschen' }
                    'Modify, Synchronize*' { 'Lesen/Schreiben/Löschen' }
                    'ReadAndExecute, Synchronize*' { 'Lesen' }
                    'Write, ReadAndExecute, Synchronize*' { 'Lesen/Ausführen/Schreiben' }
                    default { $ace.FileSystemRights.ToString() }
                }
                $identity = $ace.IdentityReference.ToString(); $identityName = if ($identity -like '*\\*') { $identity.Split('\\')[1] } else { $identity }
                [PSCustomObject]@{ GroupName = $identityName; GroupPermissions = $permission }
            }
            $folderData.GroupPermissions = $groupPermissions
            $userPermissions = @()
            foreach ($gp in $groupPermissions) {
                $groupName = $gp.GroupName; $objectClass = 'Unknown'
                if ($isDomain) {
                    try { $adObj = Get-ADObject -Filter { (Name -eq $groupName) } -ErrorAction SilentlyContinue; if ($adObj) { $objectClass = $adObj.ObjectClass } } catch {}
                } else {
                    if (Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue) { $objectClass = 'group' } elseif (Get-LocalUser -Name $groupName -ErrorAction SilentlyContinue) { $objectClass = 'user' }
                }
                if ($objectClass -eq 'group') {
                    if (-not $script:GroupMembershipCache.ContainsKey($groupName)) { $script:GroupMembershipCache[$groupName] = (Get-GroupMembership -Group $groupName) }
                    $members = $script:GroupMembershipCache[$groupName]
                    foreach ($m in $members) {
                        $uid = if ($isDomain) { $m.Name } else { ($m.Name).Split('\\')[1] }
                        if (-not $script:UserCache.ContainsKey($uid)) { $script:UserCache[$uid] = Get-UserDetails -UserId $uid }
                        $u = $script:UserCache[$uid]; if (-not $u) { continue }
                        if ($isDomain) {
                            $userObj = [PSCustomObject]@{ GroupName=$groupName; MUWID=$u.SamAccountName; Name=($u.Surname? $u.Surname.ToUpper():'N/A'); FullName=($u.GivenName?$u.GivenName:$u.SamAccountName); Aktiv=$u.Enabled }
                        } else {
                            $userObj = [PSCustomObject]@{ GroupName=$groupName; MUWID=$u.Name; Name=$u.Name.ToUpper(); FullName=($u.FullName?$u.FullName:$u.Name); Aktiv= if ($null -ne $u.Enabled) { $u.Enabled } else { $true } }
                        }
                        $userPermissions += $userObj
                    }
                } elseif ($objectClass -eq 'user') {
                    $uid = $groupName
                    if (-not $script:UserCache.ContainsKey($uid)) { $script:UserCache[$uid] = Get-UserDetails -UserId $uid }
                    $u = $script:UserCache[$uid]
                    if ($u) {
                        if ($isDomain) { $userObj = [PSCustomObject]@{ GroupName='DirectPermission'; MUWID=$u.SamAccountName; Name=($u.Surname? $u.Surname.ToUpper():'N/A'); FullName=($u.GivenName?$u.GivenName:$u.SamAccountName); Aktiv=$u.Enabled } }
                        else { $userObj = [PSCustomObject]@{ GroupName='DirectPermission'; MUWID=$u.Name; Name=$u.Name.ToUpper(); FullName=($u.FullName?$u.FullName:$u.Name); Aktiv= if ($null -ne $u.Enabled) { $u.Enabled } else { $true } } }
                        $userPermissions += $userObj
                    }
                }
            }
            $folderData.UserPermissions = $userPermissions
            # Build structured entries
            $entries = @()
            foreach ($gp in $groupPermissions) {
                $users = $userPermissions | Where-Object { $_.GroupName -eq $gp.GroupName }
                foreach ($user in $users) {
                    $entries += [PSCustomObject]@{ FolderPath=$folder.FullName; GroupName=$gp.GroupName; Permission=$gp.GroupPermissions; UserID=$user.MUWID; UserName=$user.Name; FullName=$user.FullName; IsActive=$user.Aktiv; Timestamp=Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }
                }
            }
            return [PSCustomObject]@{ FolderData=$folderData; Entries=$entries }
        } catch { Write-Log "Error processing $($folder.FullName): $($_.Exception.Message)" -Level ERROR }
    }

    $filters = 'NT AUTHORITY\*','*\Domain Admins','*\Administrator*','BUILTIN\*','*SYSTEM'
    $isDomain = $script:IsDomainJoined
    if ($Parallel -and $PSVersionTable.PSVersion.Major -ge 7) {
        $results = $folders | ForEach-Object -Parallel $processFolder -ThrottleLimit $Throttle -ArgumentList $IncludeInherited.IsPresent,$IncludeSystemAccounts.IsPresent,$isDomain,$filters
        $i=0; foreach ($r in $results) { $i++; Write-Progress -Activity 'Aggregating results' -Status "$i / $($results.Count)" -PercentComplete (($i/$($results.Count))*100); if ($r) { $script:VZinfosGesamt += $r.FolderData; $script:ReportData += $r.Entries } }
    } else {
        $total = $folders.Count; $i=0
        foreach ($folder in $folders) {
            $i++; Write-Progress -Activity 'Analyzing folder permissions' -Status "$i / $total" -PercentComplete (($i/$total)*100)
            $r = & $processFolder $folder $IncludeInherited.IsPresent $IncludeSystemAccounts.IsPresent $isDomain $filters
            if ($r) { $script:VZinfosGesamt += $r.FolderData; $script:ReportData += $r.Entries }
        }
    }
    Write-Progress -Activity 'Analyzing folder permissions' -Completed
    Write-Log "Analysis complete: processed $($folders.Count) folders (Parallel=$Parallel)" -Level SUCCESS
}
#endregion

#region Public Entry Point
function Start-DirectoryPermissionAudit {
    [CmdletBinding()] param(
        [Parameter(Position=0)][string]$Path,
        [int]$Depth = 0,
    [ValidateSet('CSV','JSON','Human','HTML','Excel')][string]$OutputFormat = 'Human',
        [string]$OutputPath,
        [switch]$IncludeInherited,
        [switch]$IncludeSystemAccounts,
        [switch]$Interactive,
        [switch]$NoLogo,
        [switch]$Parallel,
        [int]$Throttle = 5
    )
    if (-not $NoLogo) { Show-ScriptInfo -ScriptName 'Directory Permission Audit Tool (Module)' -CurrentVersion $ScriptVersion -Context 'Module' }
    # Apply defaults from settings file for parameters not explicitly bound
    if (-not $PSBoundParameters.ContainsKey('OutputFormat') -and $script:Settings.DefaultOutputFormat) { $OutputFormat = $script:Settings.DefaultOutputFormat }
    if (-not $PSBoundParameters.ContainsKey('Depth') -and $null -ne $script:Settings.DefaultDepth) { $Depth = [int]$script:Settings.DefaultDepth }
    if (-not $PSBoundParameters.ContainsKey('IncludeInherited') -and $script:Settings.IncludeInherited) { $IncludeInherited = $true }
    if (-not $PSBoundParameters.ContainsKey('IncludeSystemAccounts') -and $script:Settings.IncludeSystemAccounts) { $IncludeSystemAccounts = $true }
    if (-not $PSBoundParameters.ContainsKey('Parallel') -and $script:Settings.Parallel) { $Parallel = $true }
    if (-not $PSBoundParameters.ContainsKey('Throttle') -and $script:Settings.Throttle) { $Throttle = [int]$script:Settings.Throttle }
    if ($Interactive -or -not $Path) { $Path = Show-FolderBrowserDialog }
    if (-not $Path) { Write-Log 'No path specified or selected.' -Level WARNING; return }
    if (-not (Test-Path -Path $Path)) { Write-Log "Invalid path: $Path" -Level ERROR; return }
    $outDir = if ($OutputPath) { $OutputPath } else { $script:ReportsDir }
    Invoke-DirectoryPermissionAnalysis -RootPath $Path -MaxDepth $Depth -IncludeInherited:$IncludeInherited.IsPresent -IncludeSystemAccounts:$IncludeSystemAccounts.IsPresent -Parallel:$Parallel.IsPresent -Throttle $Throttle
    if ($script:ReportData.Count -gt 0) { Export-ReportData -RootPath $Path -Format $OutputFormat -OutputPath $outDir } else { Write-Log 'No data collected.' -Level WARNING }
}
#endregion

Export-ModuleMember -Function Show-ScriptInfo, Send-DirectoryPermissionAuditMessage, Write-Log, Get-DomainContext, Show-FolderBrowserDialog, Get-GroupDetails, Get-GroupMembership, Get-UserDetails, Get-FolderList, Invoke-DirectoryPermissionAnalysis, Export-ReportData, Start-DirectoryPermissionAudit
