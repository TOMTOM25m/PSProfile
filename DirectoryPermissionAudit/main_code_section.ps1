#region Permission Analysis and Report Generation
function Export-ReportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("CSV", "JSON", "Human")]
        [string]$Format,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = $ReportsDir
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $folderName = Split-Path -Path $RootPath -Leaf
    $fileName = "$folderName-$timestamp"
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    switch ($Format) {
        "CSV" {
            $outFile = Join-Path -Path $OutputPath -ChildPath "$fileName.csv"
            $script:ReportData | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8
            Write-Log "Report exported to CSV: $outFile" -Level "SUCCESS"
        }
        "JSON" {
            $outFile = Join-Path -Path $OutputPath -ChildPath "$fileName.json"
            $script:ReportData | ConvertTo-Json -Depth 5 | Out-File -FilePath $outFile -Encoding UTF8
            Write-Log "Report exported to JSON: $outFile" -Level "SUCCESS"
        }
        "Human" {
            # Legacy compatible format
            $outFile = Join-Path -Path $OutputPath -ChildPath "$fileName.txt"
            $logHeader = "Auswertung der Berechtigungstruktur für das $RootPath -Verzeichnis"
            $logLine = '---------------------------------------------------------------------------------------'
            $Logstar = '***************************************************************************************'
            
            $logContent = @(
                $logLine,
                $logHeader,
                $logLine
            )
            
            foreach ($item in $script:VZinfosGesamt) {
                $logContent += $logLine
                $logContent += $item.Directory
                $logContent += $logLine
                
                foreach ($groupPerm in $item.GroupPermissions) {
                    $groupInfo = "BerechtigungsGruppe : $($groupPerm.GroupName), Berechtigung: $($groupPerm.GroupPermissions)"
                    $logContent += $Logstar
                    $logContent += $groupInfo
                    $logContent += $Logstar
                    $logContent += "Berechtigte Mitarbeiter:"
                    $logContent += "Name,FullName,User ist aktiv:"
                    
                    $users = $item.UserPermissions | Where-Object { $_.GroupName -eq $groupPerm.GroupName }
                    foreach ($user in $users) {
                        $logContent += "$($user.Name),$($user.FullName),$($user.Aktiv)"
                    }
                }
                
                $logContent += $logLine
            }
            
            $logContent += "`n$Logstar"
            $logContent | Out-File -FilePath $outFile -Encoding UTF8
            Write-Log "Report exported to text: $outFile" -Level "SUCCESS"
        }
    }
    
    return $outFile
}

function Invoke-DirectoryPermissionAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 0,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeInherited,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSystemAccounts
    )
    
    Write-Log "Starting permission analysis for $RootPath" -Level "INFO"
    
    # Get folders to analyze
    $folders = Get-FolderList -RootFolder $RootPath -MaxDepth $MaxDepth
    if ($null -eq $folders -or $folders.Count -eq 0) {
        Write-Log "No folders found to analyze" -Level "WARNING"
        return
    }
    
    # Add root folder to the analysis
    if (Test-Path -LiteralPath $RootPath) {
        $rootFolderObject = Get-Item -Path $RootPath
        $folders = @($rootFolderObject) + $folders
    }
    
    $folderCount = $folders.Count
    $currentFolder = 0
    
    $script:VZinfosGesamt = @() # Legacy data structure
    
    foreach ($folder in $folders) {
        $currentFolder++
        Write-Progress -Activity "Analyzing folder permissions" -Status "$currentFolder of $folderCount" -PercentComplete (($currentFolder / $folderCount) * 100)
        
        # Skip inaccessible folders
        if (-not (Test-Path -LiteralPath $folder.FullName -ErrorAction SilentlyContinue)) {
            Write-Log "Skipping inaccessible folder: $($folder.FullName)" -Level "WARNING"
            continue
        }
        
        Write-Log "Analyzing: $($folder.FullName)" -Level "INFO"
        
        try {
            # Create container object for the current directory
            $folderData = [PSCustomObject]@{
                Directory = $folder.FullName
                GroupPermissions = @()
                UserPermissions = @()
            }
            
            # Get ACLs for the current folder
            $acl = Get-Acl -Path $folder.FullName -ErrorAction Stop
            
            # Filter ACLs based on parameters
            $aclEntries = $acl.Access
            
            if (-not $IncludeInherited) {
                $aclEntries = $aclEntries | Where-Object { $_.PropagationFlags -like '*None*' }
            }
            
            if (-not $IncludeSystemAccounts) {
                $aclEntries = $aclEntries | Where-Object { $_.IdentityReference -notlike 'NT AUTHORITY\*' }
                $aclEntries = $aclEntries | Where-Object { $_.IdentityReference -notlike '*\Domain Admins' }
                $aclEntries = $aclEntries | Where-Object { $_.IdentityReference -notlike '*\Administrator*' }
                $aclEntries = $aclEntries | Where-Object { $_.IdentityReference -notlike 'BUILTIN\*' }
                $aclEntries = $aclEntries | Where-Object { $_.IdentityReference -notlike '*SYSTEM' }
            }
            
            # Process ACL entries
            $groupPermissions = @()
            
            foreach ($ace in $aclEntries) {
                # Map permissions to human-readable format
                $permission = switch -Wildcard ($ace.FileSystemRights) {
                    'FullControl*' { 'Lesen/Schreiben/Löschen' }
                    'Modify, Synchronize*' { 'Lesen/Schreiben/Löschen' }
                    'ReadAndExecute, Synchronize*' { 'Lesen' }
                    'Write, ReadAndExecute, Synchronize*' { 'Lesen/Ausführen/Schreiben' }
                    default { $ace.FileSystemRights.ToString() }
                }
                
                # Extract identity name
                $identity = $ace.IdentityReference.ToString()
                if ($identity -like '*\*') {
                    $identityName = $identity.Split('\')[1]
                }
                else {
                    $identityName = $identity
                }
                
                # Create permission object
                $permissionObject = [PSCustomObject]@{
                    GroupName = $identityName
                    GroupPermissions = $permission
                }
                
                $groupPermissions += $permissionObject
            }
            
            $folderData.GroupPermissions = $groupPermissions
            
            # Process user memberships for each group with permissions
            $userPermissions = @()
            
            foreach ($groupPerm in $groupPermissions) {
                $groupName = $groupPerm.GroupName
                $group = $null
                $groupMembers = $null
                $objectClass = "Unknown"
                
                # Try to determine if identity is group or user
                if ($script:IsDomainJoined) {
                    try {
                        $adObject = Get-ADObject -Filter { (Name -eq $groupName) } -ErrorAction SilentlyContinue
                        if ($adObject) {
                            $objectClass = $adObject.ObjectClass
                        }
                    }
                    catch {
                        Write-Verbose "Error getting AD object for $groupName: $($_.Exception.Message)"
                    }
                }
                else {
                    # Local system - try to determine if it's a user or group
                    if (Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue) {
                        $objectClass = "group"
                    }
                    elseif (Get-LocalUser -Name $groupName -ErrorAction SilentlyContinue) {
                        $objectClass = "user"
                    }
                }
                
                # Process based on object type
                if ($objectClass -eq "group") {
                    Write-Verbose "Processing group: $groupName"
                    $group = Get-GroupDetails -GroupName $groupName
                    if ($group) {
                        $groupMembers = Get-GroupMembership -Group $group.Name
                        
                        foreach ($member in $groupMembers) {
                            $userId = if ($script:IsDomainJoined) { $member.Name } else { ($member.Name).Split('\')[1] }
                            $user = Get-UserDetails -UserId $userId
                            
                            if ($user) {
                                # Create user object with permissions inherited from group
                                if ($script:IsDomainJoined) {
                                    $userObject = [PSCustomObject]@{
                                        GroupName = $group.Name
                                        MUWID = $user.SamAccountName
                                        Name = if ($user.Surname) { $user.Surname.ToUpper() } else { "N/A" }
                                        FullName = if ($user.GivenName) { $user.GivenName } else { $user.SamAccountName }
                                        Aktiv = $user.Enabled.ToString()
                                    }
                                }
                                else {
                                    $userObject = [PSCustomObject]@{
                                        GroupName = $group.Name
                                        MUWID = $user.Name
                                        Name = $user.Name.ToUpper()
                                        FullName = if ($user.FullName) { $user.FullName } else { $user.Name }
                                        Aktiv = if ($null -ne $user.Enabled) { $user.Enabled.ToString() } else { "N/A" }
                                    }
                                }
                                
                                $userPermissions += $userObject
                            }
                        }
                    }
                }
                elseif ($objectClass -eq "user") {
                    Write-Verbose "Processing user: $groupName"
                    $user = Get-UserDetails -UserId $groupName
                    
                    if ($user) {
                        # Create user object with direct permissions
                        if ($script:IsDomainJoined) {
                            $userObject = [PSCustomObject]@{
                                GroupName = "DirectPermission"
                                MUWID = $user.SamAccountName
                                Name = if ($user.Surname) { $user.Surname.ToUpper() } else { "N/A" }
                                FullName = if ($user.GivenName) { $user.GivenName } else { $user.SamAccountName }
                                Aktiv = $user.Enabled.ToString()
                            }
                        }
                        else {
                            $userObject = [PSCustomObject]@{
                                GroupName = "DirectPermission"
                                MUWID = $user.Name
                                Name = $user.Name.ToUpper()
                                FullName = if ($user.FullName) { $user.FullName } else { $user.Name }
                                Aktiv = if ($null -ne $user.Enabled) { $user.Enabled.ToString() } else { "N/A" }
                            }
                        }
                        
                        $userPermissions += $userObject
                    }
                }
            }
            
            $folderData.UserPermissions = $userPermissions
            
            # Add to consolidated report data
            $script:VZinfosGesamt += $folderData
            
            # Build structured report entries
            foreach ($groupPerm in $groupPermissions) {
                $users = $userPermissions | Where-Object { $_.GroupName -eq $groupPerm.GroupName }
                
                foreach ($user in $users) {
                    $reportEntry = [PSCustomObject]@{
                        FolderPath = $folder.FullName
                        GroupName = $groupPerm.GroupName
                        Permission = $groupPerm.GroupPermissions
                        UserID = $user.MUWID
                        UserName = $user.Name
                        FullName = $user.FullName
                        IsActive = $user.Aktiv
                        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    }
                    
                    $script:ReportData += $reportEntry
                }
            }
        }
        catch {
            Write-Log "Error processing $($folder.FullName): $($_.Exception.Message)" -Level "ERROR"
            continue
        }
    }
    
    Write-Progress -Activity "Analyzing folder permissions" -Completed
    Write-Log "Permission analysis completed for $folderCount folders" -Level "SUCCESS"
}
#endregion

#region Main Execution
try {
    # Get folder path (interactive or parameter)
    $targetPath = $Path
    if ([string]::IsNullOrEmpty($targetPath)) {
        $targetPath = Show-FolderBrowserDialog
        if ([string]::IsNullOrEmpty($targetPath)) {
            Write-Log "No folder selected. Exiting." -Level "WARNING"
            exit
        }
    }
    
    # Validate path exists
    if (-not (Test-Path -Path $targetPath)) {
        Write-Log "Invalid path: $targetPath" -Level "ERROR"
        exit 1
    }
    
    # Set output path
    $outputPathToUse = $OutputPath
    if ([string]::IsNullOrEmpty($outputPathToUse)) {
        $outputPathToUse = $ReportsDir
    }
    
    # Execute permission analysis
    Invoke-DirectoryPermissionAnalysis -RootPath $targetPath -MaxDepth $Depth -IncludeInherited:$IncludeInherited.IsPresent -IncludeSystemAccounts:$IncludeSystemAccounts.IsPresent
    
    # Generate report
    if ($script:ReportData.Count -gt 0) {
        $reportFile = Export-ReportData -RootPath $targetPath -Format $OutputFormat -OutputPath $outputPathToUse
        Write-Log "Permission report complete. Results saved to: $reportFile" -Level "SUCCESS"
        
        # Send notification to any monitoring system
        try {
            Send-DirectoryPermissionAuditMessage -TargetScript "Monitoring" -Message "Permission audit completed for $targetPath" -Type "STATUS"
        }
        catch {
            Write-Verbose "Cross-script communication not critical: $($_.Exception.Message)"
        }
    }
    else {
        Write-Log "No permission data collected. Check folder access or filtering criteria." -Level "WARNING"
    }
}
catch {
    Write-Log "Error in Directory Permission Audit: $($_.Exception.Message)" -Level "ERROR"
    Write-Log $_.ScriptStackTrace -Level "ERROR"
    exit 1
}
finally {
    # Always indicate completion
    Write-Log "Directory Permission Audit operation completed" -Level "INFO"
}
#endregion