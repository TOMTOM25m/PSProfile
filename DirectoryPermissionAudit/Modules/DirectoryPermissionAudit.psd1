@{
    RootModule        = 'DirectoryPermissionAudit.psm1'
    ModuleVersion     = '2.3.0'
    GUID              = '3f5383f7-1c25-4c3c-b4f0-1babc0cd1234'
    Author            = 'Thomas Garnreiter'
    CompanyName       = 'N/A'
    Copyright        = '(c) 2025 Thomas Garnreiter'
    Description       = 'Directory permission audit (ACL -> Groups -> Users) with multi-format export & filters.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Start-DirectoryPermissionAudit','Invoke-DirectoryPermissionAnalysis','Export-ReportData','Show-ScriptInfo','Send-DirectoryPermissionAuditMessage','Write-Log')
    PrivateData       = @{
        PSData = @{
            Tags = @('ACL','Audit','Permissions','ActiveDirectory','Reporting')
            LicenseUri = ''
            ProjectUri = ''
        }
    }
}
