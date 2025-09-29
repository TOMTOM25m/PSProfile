using namespace System.Net
#Requires -Version 5
#Requires -RunAsAdministrator
<#
.SYNOPSIS
 Win-Admin textbased Report Interface ,  Win-Admin-Tool

.OUTPUTS
 textbased Userinterface 4 win-admins

.NOTES
 Version:    v2.0.0.0
 Author:     Thomas Garnreiter 
 Creation Date: 20220112
 last Change Date: 20230308
 Purpose/Change: ready 4 review

.EXAMPLE

.DISCLAIMER
		 The sample script provided here are not supported by Thomas Garnreiter or his 
 		 employer. All scripts are provided AS IS without warranty of any kind. Thomas Garnreiter
		 and his employer further disclaims all implied warranties including, without 
 		 limitation, any implied warranties of merchantability or of fitness for a particular 
 		 purpose. The entire risk arising out of the use or performance of the sample scripts 
 		 and documentation remains with you. In no event shall Thomas Garnreiter or his 
 		 employer, its authors, or anyone else involved in the creation, production, or delivery
 		 of the scripts be liable for any damages whatsoever (including, without limitation,
 		 damages for loss of business profits, business interruption, loss of business information,
 		 or other pecuniary loss) arising out of the use of or inability to use the sample scripts
 		 or documentation, even if Thomas Garnreiter or his employer has been advised of the
 		 possibility of such damages.

#>
#region    ######################[Security TLS12]##############################
using namespace System.Net
using namespace System.Windows.Forms.FolderBrowserDialog

#if ($PSVersionTable.PSVersion.Major -eq '5') {
#    [ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12   #DevSkim: ignore DS440000,DS440020  #DevSkim: reviewed DS440001 on 2021-03-02
#}
#endregion ####################################################################

#region    ###########################[If Domain]##############################
Function Get.DomainMembership() {
    if ($env:computername -eq $env:userdomain ) { return $false } 
    else { return $env:userdomain }
}
$DOM = Get.DomainMembership
#endregion ####################################################################
#region    ######################[Get Folder Dialog]###########################
Function BrowseFolder ($initialDirectory) {
    [System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = 'Select a folder'
    $foldername.rootfolder = 'MyComputer'
    $foldername.SelectedPath = $initialDirectory

    if ($foldername.ShowDialog() -eq 'OK') {
        $folder += $foldername.SelectedPath
    }
    return $folder
}
#endregion ####################################################################
#region    ####################[definition Output Log]#########################

function WriteToLogFile ($logfilepath) {
    Add-Content -Path $logfilepath[0] -Value $logfilepath[1] -Encoding 'UTF8'
}



#endregion ####################################################################
#region    ######################[Get Usergroup]###############################
Function GetGroup($initialGroup) {
    If ($DOM -ne $false) {
        $group = Get-ADGroup -Identity $initialGroup -Properties * -ErrorAction SilentlyContinue
    } else {
        $group = Get-LocalGroup -Name $initialGroup -ErrorAction SilentlyContinue
    }
    return $group
}
#endregion ####################################################################
#region    ####################[Get AD Group Member]###########################
Function GetGroupMembership($group) {
    If ($DOM -ne $false) {
        $GroupMembers = Get-ADGroupMember -Identity $group -Recursive -ErrorAction silentlyContinue
    } else {
        $GroupMembers = Get-LocalGroupMember -Group $group -ErrorAction silentlyContinue
    }
    return $GroupMembers
}
#endregion ####################################################################
#region    ###########################[Get folders ]###########################
Function Get.Folders($Folder) {
    $Folderss = Get-ChildItem -Directory -Path $Folder -Recurse -Depth 0 
    $Folders = $Folderss | Where-Object { $_ -notlike '*\.*' }
    return $Folders
}
#endregion ####################################################################
#region    ########################[Get User name]#############################
Function Get.UserNameFromMUWID($MUWID) {
    If ($DOM -ne $false) {
        $User = Get-ADUser -Identity $MUWID -Properties * -ErrorAction SilentlyContinue
    } else {
        if ($MUWID -like '*\*') {
            $MUWIDtrim = ($MUWID.Split('\'))[1]
        } else {
            $MUWIDtrim = $MUWID
        }
        $User = Get-LocalUser -Name $MUWIDtrim -ErrorAction SilentlyContinue
    }
    return $User
}
#endregion ####################################################################
#region    ######################[Get Folder Dialog]###########################
$StepinFolder = BrowseFolder
$Folders = Get.Folders($StepinFolder)
$VA = @()
$VZinfosGesamt = @()
foreach ($Dir in $Folders) {
    $VAprops = @{Directory = $Dir }
    $VA = New-Object PSObject -Property $VAprops
    $ACL = @()
    #endregion ####################################################################
    #region    ####################[Get ACL from Folder]###########################
    $TPath = Test-Path -LiteralPath $Dir -ErrorAction SilentlyContinue
    if ($TPath) {
        $ACL1 = $((Get-Acl -Path $Dir).Access)
    }
    $ACL2 = $ACL1 | Where-Object { $_.PropagationFlags -like '*None*' }
    $ACL3 = $ACL2 | Where-Object { $_.IdentityReference -notlike 'NT AUTHORITY\*' }
    $ACL4 = $ACL3 | Where-Object { $_.IdentityReference -notlike '*\Domain Admins' }
    $ACL5 = $ACL4 | Where-Object { $_.IdentityReference -notlike '*\Administrator*' }
    $ACL6 = $ACL5 | Where-Object { $_.IdentityReference -notlike 'BUILTIN\*' }
    $ACL = $ACL6 | Where-Object { $_.IdentityReference -notlike '*SYSTEM' }
    

    $ACLArray = @()  
    #endregion ####################################################################
    #region    ######################[ForEach schleife]###########################
    if ($null -ne $ACL) {

        foreach ($currentItemName in $ACL) {
            $permissions = $null
            switch ($($currentItemName.FileSystemRights)) {
                'FullControl' { $permissions = 'Lesen/Schreiben/Löschen' }
                'Modify, Synchronize' { $permissions = 'Lesen/Schreiben/Löschen' }
                'ReadAndExecute, Synchronize' { $permissions = 'Lesen' }
                'Write, ReadAndExecute, Synchronize' { $permissions = 'Lesen/Ausführen/Schreiben' }
            }
            $Istem = $currentItemName.IdentityReference.ToString()
            $Istam = $Istem.Split('\')[1]
            $props = @{ GroupName = $Istam
                GroupPermissions  = $permissions
            }
            $ServiceObject = New-Object -TypeName PSObject -Property $props
            $ACLArray += $ServiceObject
        }
    }
    $VA | Add-Member -type NoteProperty -Name GroupPermissions -Value $ACLArray
   
    #endregion ####################################################################
    $Usrarray = @()
    $UserInGroup = ''
    #region    ##################[Get User From ACL Group]#########################
    if ($null -ne $ACL) {
        foreach ($currentItemName in $ACLArray) {
            [String]$GroupName = $currentItemName.GroupName
            
            if ($DOM) {
                $grp = Get-ADObject -Filter { (Name -eq $GroupName) }
                
                if ($grp.ObjectClass -eq 'group') {
                    $UserInGroup = GetGroupMembership($grp.Name)
                    Write-Host "Group $($grp.Name) Found"
                } elseif ($grp.ObjectClass -eq 'User') {
                    Write-Host "User $($grp.Name) Found"
                    $UserInGroup = Get.UserNameFromMUWID($grp.Name) 
                }
                break
               
            } else {
                $grp = Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue
                if ($grp) {
                    Write-Host "Group $($grp.Name) Found"
                    $UserInGroup = GetGroupMembership($grp.Name)
                } else {
                    $grp = Get-LocalUser -Name $GroupName -ErrorAction SilentlyContinue
                    Write-Host "User $($grp.Name) Found"
                    $UserInGroup = Get.UserNameFromMUWID($grp.Name) 
                }
            }

            foreach ($UsrinGrp in $UserInGroup) {
                If ($DOM -ne $false) {
                    $User = Get.UserNameFromMUWID -MUWID $UsrinGrp.Name
                } else {
                    $User = Get.UserNameFromMUWID -MUWID (($UsrinGrp.Name).Split('\'))[1]
                }

                If ($DOM -ne $false) {
                    $props = @{ GroupName = $($grp.Name).ToString()
                        MUWID             = $User.SamAccountName.ToString()
                        Name              = If ($User.SurName) { ($User.SurName).ToString().ToUpper() }else { 'N/A' }
                        FullName          = If ($User.GivenName) { ($User.GivenName).ToString() }else { $User.SamAccountName.ToString() } 
                        Aktiv             = $User.Enabled.ToString()
                    }
                } else {
                    $props = @{ GroupName = $($grp.Name).ToString()
                        MUWID             = $User.Name.ToString()
                        Name              = If ($User.Name) { ($User.Name).ToString().ToUpper() }else { $User.Name.ToString() }
                        FullName          = If ($User.FullName) { ($User.FullName).ToString() }else { $User.Name.ToString() } 
                        Aktiv             = If ($User.Enabled) { ($User.Enabled).ToString() } else { 'N/A' } 
                    }
                }
                $SO1 = New-Object -TypeName PSObject -Property $props
                $Usrarray += $SO1 
            }
        }
        $VA | Add-Member -type NoteProperty -Name UserPermissions -Value $Usrarray
    } 
    $VZinfosGesamt += $VA
}
#endregion ####################################################################
#region    ######################[LogFile Parameter]###########################
$logfilepath = $null
$todaysdate = Get-Date -Format 'yyyy-MM-dd'
$logfile = ($StepinFolder.Split('\')[-1]) + '_' + $todaysdate + '_log.csv'
$logfilepath = $StepinFolder + '\' + $logfile
if (Test-Path $logfilepath ) {
    Remove-Item -Path $logfilepath -Force
    New-Item -Path $logfilepath -ItemType 'file'`
        -Value ''`
        -ErrorAction SilentlyContinue | Out-Null
} 
$logHeader = "Auswertung der Berechtigungstruktur für das  $StepinFolder -Verzeichnis"
$logLine = '---------------------------------------------------------------------------------------'
$Logstar = '***************************************************************************************'
$logUserlist = 'Berechtigte Mitarbeiter:'
$logBerechtigterMitarbeiterHeader = 'Name,FullName,User ist aktiv:'
#$logBerechtigterMitarbeiterHeader = 'Name,FullName,User ist aktiv:,MUWID'

#endregion ####################################################################

WriteToLogFile ($logfilepath, $logLine) #'----------------------------------------------------------------------------------'
WriteToLogFile ($logfilepath, $logfilepath)
WriteToLogFile ($logfilepath, $logHeader)

foreach ($Item0 in $VZinfosGesamt) {
    $logVerzeihnis = $Item0.Directory
    Write-Host "$logVerzeihnis"
    WriteToLogFile ($logfilepath, $logLine) 
    WriteToLogFile ($logfilepath, $logVerzeihnis)
    WriteToLogFile ($logfilepath, $logLine)   
    $GRPperm = $Item0.GroupPermissions 
    $USRperm = $Item0.UserPermissions

    foreach ($GItem1 in $GRPperm ) {
        
        $logVZgrp = "BerechtigungsGruppe : $($GItem1.GroupName),Berechtigung: $($GItem1.GroupPermissions)"
        WriteToLogFile ($logfilepath, $Logstar)
        WriteToLogFile ($logfilepath, $logVZgrp)
        WriteToLogFile ($logfilepath, $Logstar)
        WriteToLogFile ($logfilepath, $logUserlist)
        #WriteToLogFile ($logfilepath, $logLine)
        WriteToLogFile ($logfilepath, $logBerechtigterMitarbeiterHeader)
       
        foreach ($UItem1 in $USRperm) {
            IF ($($UItem1.FullName) -notlike 'N/A*') {
               
                #$logUserAngabe = "$(($UItem1[0]).Name),$(($UItem1[0]).FullName),$(($UItem1[0]).Aktiv),$(($UItem1[0]).MUWID)"
                $logUserAngabe = "$(($UItem1[0]).Name),$(($UItem1[0]).FullName),$(($UItem1[0]).Aktiv)"
                WriteToLogFile ($logfilepath, $logUserAngabe)
            }
        }
    }
    WriteToLogFile ($logfilepath, $logLine)
}
WriteToLogFile ($logfilepath, $("`n" + $Logstar))



# SIG # Begin signature block
# MIIbqAYJKoZIhvcNAQcCoIIbmTCCG5UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBiRejxD3SN5FED
# fE9DqMiwYdhwxnKengwFzrolM5hVm6CCFgEwggL2MIIB3qADAgECAhBXv4pDAvsn
# nkowT7KPgIZ8MA0GCSqGSIb3DQEBBQUAMBMxETAPBgNVBAMMCHRnYXJucjU0MB4X
# DTE5MDUwOTA2NDYwOVoXDTI0MDUwOTA2NTYxMFowEzERMA8GA1UEAwwIdGdhcm5y
# NTQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC2IZymajnDNCp2J+Ys
# FIpeSq14ceszIqzWN03W2TFR6pFWp1s7oqPLFDWeiTaJrFwnyJxGvtdCPgua+EfI
# 9RyfxzxmUFntIWZ9n66GSBXwLJgfH8SdzKy34WVVUa+YK2ukO0RMm2F7Sb7MizkU
# TdFZl7aBvjWgzXAUnBoT15rlLHAGuGJCmLCR0I+A6BOgIndZ+Jo7eaSoTxh9dSkL
# DKnReBbOzZWOswd86xkp7US7PkEGPpjrZly5aNuY2wiygzRCD8Ozxmc8ml6MBFKy
# tb4v8AgRng1qTotqnqC8gn3OLBbZpkaL2SulY3i+5PMRZWZG1wtd6ufZbqYJqg9D
# 9pYdAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcD
# AzAdBgNVHQ4EFgQU+rv6H0MhGeKlzvEBAe1bfA8GGZcwDQYJKoZIhvcNAQEFBQAD
# ggEBAAp9ePElg8qIbH2Yx3c7Nv2ZOdkA7JtHRuU2X19HSEVqqSmNI5WpyQz+NEDL
# w9gkU6Yz0aORI7KK1Wq1i02sFsleCnD6cibJv9B3xTCmBxBX7TuJs+lv753oQAew
# iaVrybvCz0mPAP3QzmnyKyYF5nYm3cZxec8BQCWa6QKSlp96sXHekZNAk87naX3Y
# OQ6MVUHKOqJ/W9cTUEvYPAVepKafF5pnUqVpt1weJ4YZmcjvW6begQeZbzpjA7Z3
# t4nGLE9l39tfkQ0MgbXDd7alUNeguFnRnWGFxB9wnCDBp4ohRKlXKAZCnBOMVa6c
# JfQUfZti0YVCxEXAUUSrkXWRTwIwggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOII
# QBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0Rp
# Z2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTEx
# MDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/m
# kHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4
# FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMy
# lNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq8
# 68nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe
# 3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMq
# bpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxG
# j2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORF
# JYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhE
# lRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0vias
# tkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LW
# RV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNV
# HRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYI
# KwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDAR
# BgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6Cj
# dBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/
# gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcud
# T6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3o
# sdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1
# VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eq
# XijiuZQwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3DQEB
# CwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNV
# BAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQg
# Um9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJBgNV
# BAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNl
# cnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE8pE3
# qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBMLJnOW
# bfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU5ygt
# 69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLydkf3
# YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFkdECn
# wHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgmf6Aa
# RyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9abJTy
# UpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwYSH8U
# NM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80VgvCON
# WPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5FBAS
# A31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9Rp61
# 03a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAd
# BgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7NfjgtJx
# XWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGln
# aWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJo
# dHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNy
# bDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQEL
# BQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp+3CK
# Daopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9qVbP
# FXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8ZCaH
# bJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6ZJxur
# JB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnEtp/N
# h4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fxZsNB
# zU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV77Qpf
# MzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT1Oby
# F5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkPCr2B
# 2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvmfxqk
# hQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIGwDCCBKig
# AwIBAgIQDE1pckuU+jwqSj0pB4A9WjANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0
# IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTIy
# MDkyMTAwMDAwMFoXDTMzMTEyMTIzNTk1OVowRjELMAkGA1UEBhMCVVMxETAPBgNV
# BAoTCERpZ2lDZXJ0MSQwIgYDVQQDExtEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMiAt
# IDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDP7KUmOsap8mu7jcEN
# mtuh6BSFdDMaJqzQHFUeHjZtvJJVDGH0nQl3PRWWCC9rZKT9BoMW15GSOBwxApb7
# crGXOlWvM+xhiummKNuQY1y9iVPgOi2Mh0KuJqTku3h4uXoW4VbGwLpkU7sqFudQ
# SLuIaQyIxvG+4C99O7HKU41Agx7ny3JJKB5MgB6FVueF7fJhvKo6B332q27lZt3i
# XPUv7Y3UTZWEaOOAy2p50dIQkUYp6z4m8rSMzUy5Zsi7qlA4DeWMlF0ZWr/1e0Bu
# bxaompyVR4aFeT4MXmaMGgokvpyq0py2909ueMQoP6McD1AGN7oI2TWmtR7aeFgd
# Oej4TJEQln5N4d3CraV++C0bH+wrRhijGfY59/XBT3EuiQMRoku7mL/6T+R7Nu8G
# RORV/zbq5Xwx5/PCUsTmFntafqUlc9vAapkhLWPlWfVNL5AfJ7fSqxTlOGaHUQhr
# +1NDOdBk+lbP4PQK5hRtZHi7mP2Uw3Mh8y/CLiDXgazT8QfU4b3ZXUtuMZQpi+ZB
# pGWUwFjl5S4pkKa3YWT62SBsGFFguqaBDwklU/G/O+mrBw5qBzliGcnWhX8T2Y15
# z2LF7OF7ucxnEweawXjtxojIsG4yeccLWYONxu71LHx7jstkifGxxLjnU15fVdJ9
# GSlZA076XepFcxyEftfO4tQ6dwIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkw
# FzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaa
# L3WMaiCPnshvMB0GA1UdDgQWBBRiit7QYfyPMRTtlwvNPSqUFN9SnDBaBgNVHR8E
# UzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcB
# AQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgG
# CCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQBVqioa80bzeFc3MPx140/WhSPx/PmVOZsl5vdyipjDd9Rk/BX7
# NsJJUSx4iGNVCUY5APxp1MqbKfujP8DJAJsTHbCYidx48s18hc1Tna9i4mFmoxQq
# RYdKmEIrUPwbtZ4IMAn65C3XCYl5+QnmiM59G7hqopvBU2AJ6KO4ndetHxy47JhB
# 8PYOgPvk/9+dEKfrALpfSo8aOlK06r8JSRU1NlmaD1TSsht/fl4JrXZUinRtytIF
# Zyt26/+YsiaVOBmIRBTlClmia+ciPkQh0j8cwJvtfEiy2JIMkU88ZpSvXQJT657i
# nuTTH4YBZJwAwuladHUNPeF5iL8cAZfJGSOA1zZaX5YWsWMMxkZAO85dNdRZPkOa
# GK7DycvD+5sTX2q1x+DzBcNZ3ydiK95ByVO5/zQQZ/YmMph7/lxClIGUgp2sCovG
# SxVK05iQRWAzgOAj3vgDpPZFR+XOuANCR+hBNnF3rf2i6Jd0Ti7aHh2MWsgemtXC
# 8MYiqE+bvdgcmlHEL5r2X6cnl7qWLoVXwGDneFZ/au/ClZpLEQLIgpzJGgV8unG1
# TnqZbPTontRamMifv427GFxD9dAq6OJi7ngE273R+1sKqHB+8JeEeOMIA11HLGOo
# JTiXAdI/Otrl5fbmm9x+LMz/F0xNAKLY1gEOuIvu5uByVYksJxlh9ncBjDGCBP0w
# ggT5AgEBMCcwEzERMA8GA1UEAwwIdGdhcm5yNTQCEFe/ikMC+yeeSjBPso+Ahnww
# DQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAvBgkqhkiG9w0BCQQxIgQgpak3QTtpXbDD1qioZoVoeX2a8tLa6MZgiSJU
# JjFPKxowDQYJKoZIhvcNAQEBBQAEggEAEl/TUS8PxZkjveSRpgz/taJ0eI79aAX7
# 8daT28GgFgQjR+wDL/plK9VUEKOlYOtkIKMOeJDxLO39ZSkTCuExTrjXsGph5kEz
# WITUlSZn0JoyYklVxgarP43C342OPWiHRKoaf+uROXWDgodi0nwb/qAmbDHcLUTf
# fWmgCWetGLFGdKfkPwJDQX6QP90G5UPew8vUdZMQTllf1aXFHGlI5FpJ7BT6ND0d
# /k2rec/yODvyPfuSzsDxCSR3qzIuNRSbzVARtlmXpPjeziriX6PquHTY1Pw+JtUX
# RFBvQR4hr1fE0GAxnN2xJQK3kdU1BwFgUwJoy49G6CsEazTKl0zdNqGCAyAwggMc
# BgkqhkiG9w0BCQYxggMNMIIDCQIBATB3MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBS
# U0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0ECEAxNaXJLlPo8Kko9KQeAPVow
# DQYJYIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqG
# SIb3DQEJBTEPFw0yMzAzMDgwNzE5MjVaMC8GCSqGSIb3DQEJBDEiBCDUmZDg2UQS
# A+EIhmSy1U8UScbbOXwrQr1uQl066oNoBTANBgkqhkiG9w0BAQEFAASCAgCEnrru
# qlJB1sNwJ6pK8rJtwlnd/1z+1wMkXWqeNv2FOxHhjK5CINGP69FMp4LBvDK48Vt8
# p50BvMEAcwU+db1q6X3xvaQ7Vqken3TRF0YwUNQ2e/zzU6zcZ9YMuUx/xLq5GOhB
# Ct5SPTTk3GXZyg6WMEqUFwSAWleNG7iN2uUf/lZIG121pIzJM6N4MMz4rP8wzZDy
# UNgzahHrzkhEtTkJo7VeWI0Y6/Wja3T1tjII+ZZZKJyn/5O5QQzLNfeXkwafJZiC
# /v0M7HSoHlRRx6Aa5Mr1zvFXX8Avjh3JkudqHWWUPdqDb+IJSMU5wBsIprKYcbwV
# YGmzYH/r8hk0fzngfFomDmus5+YkaCN9WFVwuSSROZW5ovZnpylzIZfn9qDbt91K
# 4tTmrTECiFVDmzuJRMiGUsRn1ayKRJ9VZDiEmeCCqlgVHbpCB7K3umFuu1u682fB
# JZrC1BMhMTS+7erHYyxQmSV5JaA7hCMe/rgd3g31tF07XNhkbNUHGaQtETD0gict
# 4Rlua7eAbSBPvx+Lo/yWqNU8DsIJByVUOAfAakopT8eXRS3ZLws3qmshFlsZdMbN
# 56VCT4MDfJeDHaf1889oZpDqhU9LCOXqA0N/vvT8A2gIo+MYu649SrnF5bo2S4Sv
# XhE6FBrvMtjYj6NS7RcvVT8vpk98Yk/rZ1H4PA==
# SIG # End signature block
